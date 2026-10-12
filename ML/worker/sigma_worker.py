# -*- coding: utf-8 -*-
"""
SIGMA AI · worker automatico (sin botones).

Es un proceso que se deja encendido y hace solo lo que hoy exige apretar botones:

  CADA N MINUTOS   Puntua (POST /sigma-ai/predecir) FALLA y RUL: las predicciones,
                   sus razones y las alertas se mantienen al dia aunque nadie
                   tenga la web abierta.
  UNA VEZ AL DIA   Reentrena cada modelo SOLO si hay datos nuevos suficientes,
                   compara la version nueva con la vigente y la PUBLICA sola
                   unicamente si pasa las compuertas. Si no, queda en BORRADOR y
                   el motivo se escribe en el log.

COMPUERTAS PARA PUBLICAR (todas deben cumplirse)
  1. Datos minimos del modelo (positivas FALLA / filas RUL).
  2. Datos nuevos desde la version vigente (no se reentrena por reentrenar).
  3. Mejora la metrica de la vigente en un margen (FALLA: AUC sube; RUL: MAE baja).
  4. Si el entrenador no termina bien (ONNX distinto de los pesos, etc.) no se
     registra nada y no se publica.

SEGURIDAD
  Entra con un USUARIO DE SERVICIO (permisos: VER PREDICCIONES y ENTRENAR MODELOS).
  Usuario y clave van en variables de entorno del servidor (SIGMA_USUARIO,
  SIGMA_CLAVE) o en ML/.env (esta en .gitignore). Nunca por chat ni al repo.

COMO SE CORRE
  pip install -r ../requirements.txt
  set SIGMA_API=https://<host>/SIGMA/Servicio/API
  set SIGMA_USUARIO=sigma-ai-worker
  set SIGMA_CLAVE=<la define quien crea el usuario; no la comparta por chat>
  python sigma_worker.py                 (queda corriendo)
  python sigma_worker.py --una-vez       (un ciclo completo y sale: para probar o para el cron)
  python sigma_worker.py --solo-puntuar  (solo el recalculo de predicciones)
  python sigma_worker.py --seco          (no publica: solo dice que haria)
"""
import argparse
import os
import subprocess
import sys
import time

import requests

AQUI = os.path.dirname(os.path.abspath(__file__))
ML = os.path.dirname(AQUI)
sys.path.insert(0, ML)
from sigma_ml import Api, cargar_env, log  # noqa: E402

# modelo de la API -> (script entrenador, metrica, mejor)
MODELOS = {
    'FALLA': {'script': 'entrenar_falla.py', 'metrica': 'mpv_metrica_auc', 'mejor': 'alta'},
    'RUL':   {'script': 'entrenar_rul.py',   'metrica': 'mpv_metrica_mae', 'mejor': 'baja'},
}


def env_num(nombre, defecto, tipo=float):
    try:
        return tipo(os.environ.get(nombre, defecto))
    except (TypeError, ValueError):
        return tipo(defecto)


class Config:
    def __init__(self):
        self.api = os.environ.get('SIGMA_API', 'http://localhost/SIGMA/Servicio/API')
        self.usuario = os.environ.get('SIGMA_USUARIO', '')
        self.clave = os.environ.get('SIGMA_CLAVE', '')
        self.minutos_puntuar = env_num('WORKER_PUNTUAR_MIN', 15, int)
        self.hora_entrenar = env_num('WORKER_HORA_ENTRENAR', 3, int)       # 0-23, hora del servidor
        self.min_positivas = {'FALLA': env_num('WORKER_MIN_POSITIVAS_FALLA', 10, int),
                              'RUL': env_num('WORKER_MIN_FILAS_RUL', 30, int)}
        self.nuevas_min = env_num('WORKER_NUEVAS_MIN', 3, int)              # positivas nuevas para reentrenar
        self.margen_auc = env_num('WORKER_MARGEN_AUC', 0.01)
        self.margen_mae = env_num('WORKER_MARGEN_MAE', 0.02)                # 2 % de mejora relativa
        self.auc_minimo_primera = env_num('WORKER_AUC_MIN_PRIMERA', 0.65)
        self.publicar_auto = os.environ.get('WORKER_PUBLICAR_AUTO', '1') == '1'


# ---------------------------------------------------------------- compuertas (puras, testeables)

def vigente(versiones):
    pub = [v for v in versiones if str(v.get('ESTADO', '')).upper().startswith('PUBLICADO')]
    return max(pub, key=lambda v: v.get('mpv_numero') or 0) if pub else None


def mas_nueva_borrador(versiones):
    bor = [v for v in versiones if str(v.get('ESTADO', '')).upper().startswith('BORRADOR')]
    return max(bor, key=lambda v: v.get('mpv_numero') or 0) if bor else None


def hay_datos_nuevos(cfg, modelo, dataset, version_vigente):
    """Compuertas 1 y 2: datos minimos y datos nuevos desde la vigente."""
    positivas = int(dataset.get('positivas') or 0)
    minimo = cfg.min_positivas[modelo]
    if positivas < minimo:
        return False, 'solo %d casos positivos (minimo %d)' % (positivas, minimo)
    if version_vigente is not None:
        previas = int(version_vigente.get('DATASET_POSITIVAS') or 0)
        if positivas - previas < cfg.nuevas_min:
            return False, 'solo %d casos nuevos desde la v%s (se piden %d)' % (positivas - previas, version_vigente.get('mpv_numero'), cfg.nuevas_min)
    return True, 'ok'


def mejora(cfg, modelo, nueva, version_vigente):
    """Compuerta 3: la nueva es mejor que la vigente en la metrica del modelo."""
    m = MODELOS[modelo]
    nv = nueva.get(m['metrica'])
    if nv is None:
        return False, 'la version nueva no trae %s' % m['metrica']
    nv = float(nv)
    if version_vigente is None:
        if m['mejor'] == 'alta' and nv < cfg.auc_minimo_primera:
            return False, 'AUC %.3f menor que el minimo para una primera version (%.2f)' % (nv, cfg.auc_minimo_primera)
        return True, 'primera version (%s=%.3f)' % (m['metrica'], nv)
    vv = version_vigente.get(m['metrica'])
    if vv is None:
        return True, 'la vigente no tiene metrica comparable'
    vv = float(vv)
    if m['mejor'] == 'alta':
        return (nv >= vv + cfg.margen_auc,
                'AUC %.3f vs vigente %.3f (se pide +%.2f)' % (nv, vv, cfg.margen_auc))
    return (nv <= vv * (1 - cfg.margen_mae),
            'MAE %.2f vs vigente %.2f (se pide -%.0f %%)' % (nv, vv, cfg.margen_mae * 100))


# ---------------------------------------------------------------- acciones contra la API

def entrar(cfg):
    if not cfg.usuario or not cfg.clave:
        raise SystemExit('Faltan SIGMA_USUARIO y/o SIGMA_CLAVE (variables de entorno o ML/.env).')
    return Api(cfg.api, cfg.usuario, cfg.clave)


def puntuar(api):
    for modelo in MODELOS:
        try:
            r = api.post('/sigma-ai/predecir?modelo=' + modelo, {})
            log('puntuado %s: %s' % (modelo, {k: r.get(k) for k in ('equipos', 'alertas', 'predicciones') if k in r} or 'ok'))
        except SystemExit as e:
            log('ERROR al puntuar %s: %s' % (modelo, e))


def reentrenar(cfg, api, modelo, seco):
    m = MODELOS[modelo]
    versiones = api.get('/sigma-ai/versiones?modelo=' + modelo).json()
    vig = vigente(versiones)
    ds = api.post('/sigma-ai/datasets?modelo=' + modelo, {'paso_dias': 7, 'observacion': 'worker automatico'})
    ok, motivo = hay_datos_nuevos(cfg, modelo, ds, vig)
    if not ok:
        log('%s: no se reentrena: %s' % (modelo, motivo))
        return
    log('%s: reentrenando con el dataset %s (%s filas, %s positivas)' % (modelo, ds.get('codigo'), ds.get('filas'), ds.get('positivas')))
    entorno = dict(os.environ, SIGMA_API=cfg.api, SIGMA_CLAVE=cfg.clave)
    cmd = [sys.executable, os.path.join(ML, m['script']), '--usuario', cfg.usuario,
           '--dataset', str(ds['id']), '--sin-azure']
    r = subprocess.run(cmd, env=entorno, capture_output=True, text=True, timeout=3600)
    if r.returncode != 0:
        log('%s: el entrenador fallo (codigo %s); no se publica. %s' % (modelo, r.returncode, (r.stdout + r.stderr)[-400:].replace('\n', ' | ')))
        return
    versiones = api.get('/sigma-ai/versiones?modelo=' + modelo).json()
    nueva = mas_nueva_borrador(versiones)
    if nueva is None:
        log('%s: el entrenador termino pero no dejo ningun BORRADOR; no se publica.' % modelo)
        return
    ok, motivo = mejora(cfg, modelo, nueva, vigente(versiones))
    if not ok:
        log('%s: la v%s queda en BORRADOR: %s' % (modelo, nueva.get('mpv_numero'), motivo))
        return
    if seco or not cfg.publicar_auto:
        log('%s: publicaria la v%s (%s) pero PUBLICAR_AUTO/--seco lo impide.' % (modelo, nueva.get('mpv_numero'), motivo))
        return
    api.post('/sigma-ai/versiones/%s/publicar' % nueva['mpv_id'], {})
    log('%s: PUBLICADA la v%s (%s)' % (modelo, nueva.get('mpv_numero'), motivo))
    puntuar(api)   # las predicciones salen ya con el modelo nuevo


# ---------------------------------------------------------------- bucle

def ciclo_entrenamiento(cfg, api, seco):
    for modelo in MODELOS:
        try:
            reentrenar(cfg, api, modelo, seco)
        except (SystemExit, requests.RequestException, subprocess.SubprocessError) as e:
            log('ERROR reentrenando %s: %s' % (modelo, e))


def main():
    cargar_env()
    ap = argparse.ArgumentParser(description='Worker automatico de SIGMA AI')
    ap.add_argument('--una-vez', action='store_true', help='un ciclo completo y sale')
    ap.add_argument('--solo-puntuar', action='store_true')
    ap.add_argument('--seco', action='store_true', help='no publica nada')
    a = ap.parse_args()
    cfg = Config()
    api = entrar(cfg)

    if a.una_vez or a.solo_puntuar:
        puntuar(api)
        if not a.solo_puntuar:
            ciclo_entrenamiento(cfg, api, a.seco)
        return

    log('worker en marcha: puntua cada %d min; reentrena a las %02d:00 (hora del servidor)' % (cfg.minutos_puntuar, cfg.hora_entrenar))
    ultimo_dia_entrenado = None
    while True:
        try:
            puntuar(api)
            ahora = time.localtime()
            hoy = time.strftime('%Y-%m-%d', ahora)
            if ahora.tm_hour == cfg.hora_entrenar and ultimo_dia_entrenado != hoy:
                ciclo_entrenamiento(cfg, api, a.seco)
                ultimo_dia_entrenado = hoy
        except SystemExit as e:
            log('sesion perdida o error de la API (%s); se vuelve a entrar' % e)
            try:
                api = entrar(cfg)
            except SystemExit as e2:
                log('no se pudo volver a entrar: %s' % e2)
        time.sleep(cfg.minutos_puntuar * 60)


if __name__ == '__main__':
    main()
