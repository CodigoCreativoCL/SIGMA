# -*- coding: utf-8 -*-
"""
SIGMA AI · worker automatico (sin botones).

Es un proceso que se deja encendido y hace solo lo que hoy exige apretar botones:

  CADA N MINUTOS   Puntua (POST /sigma-ai/predecir) FALLA y RUL: las predicciones,
                   sus razones y las alertas se mantienen al dia aunque nadie
                   tenga la web abierta.
  CADA CIERRE DE   Consulta cada pocos minutos GET /sigma-ai/senal (cuantas OT hay
  OT               cerradas y cuando fue la ultima). Si cambio, espera unos minutos
                   (por si cierran varias seguidas), y reentrena cada modelo,
                   compara la version nueva con la vigente y la PUBLICA sola
                   unicamente si pasa las compuertas. Si no, queda en BORRADOR y
                   el motivo se escribe en el log.
  RESPALDO DIARIO  Una vez al dia revisa igual, por si se perdio alguna senal.

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


def cargar_cuentas():
    """Una cuenta de servicio por EMPRESA con plan SIGMA AI. Variables:
       SIGMA_USUARIO / SIGMA_CLAVE            (una sola empresa)
       SIGMA_USUARIO_1 / SIGMA_CLAVE_1 ...    (varias; hasta _20)
    La sesion queda ligada a la empresa del usuario: cada empresa se puntua y se
    entrena con SUS datos y nunca se mezclan."""
    c = []
    if os.environ.get('SIGMA_USUARIO'):
        c.append({'login': os.environ['SIGMA_USUARIO'], 'clave': os.environ.get('SIGMA_CLAVE', '')})
    for n in range(1, 21):
        u = os.environ.get('SIGMA_USUARIO_%d' % n)
        if u:
            c.append({'login': u, 'clave': os.environ.get('SIGMA_CLAVE_%d' % n, '')})
    return c


class Config:
    def __init__(self):
        self.api = os.environ.get('SIGMA_API', 'http://localhost/SIGMA/Servicio/API')
        self.cuentas = cargar_cuentas()
        self.minutos_puntuar = env_num('WORKER_PUNTUAR_MIN', 15, int)
        self.hora_entrenar = env_num('WORKER_HORA_ENTRENAR', 3, int)       # 0-23, respaldo diario
        self.minutos_senal = env_num('WORKER_SENAL_MIN', 2, int)           # cada cuanto mira si se cerro una OT
        self.espera_cierre_min = env_num('WORKER_ESPERA_CIERRE_MIN', 5, int)  # tranquilidad tras el ultimo cierre
        self.min_positivas = {'FALLA': env_num('WORKER_MIN_POSITIVAS_FALLA', 10, int),
                              'RUL': env_num('WORKER_MIN_FILAS_RUL', 30, int)}
        self.nuevas_min = env_num('WORKER_NUEVAS_MIN', 0, int)              # positivas nuevas exigidas (0 = basta con un cierre)
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


def senal_cambio(senal, visto):
    """True si hubo un cierre de OT posterior al ultimo que el worker ya proceso.
    senal / visto: {'CIERRES': n, 'ULTIMO_CIERRE': 'texto', 'ULTIMO_ID': n}."""
    if not senal:
        return False
    if visto is None:
        return False   # primer vistazo: se toma como linea base, no se reentrena al arrancar
    return (senal.get('CIERRES'), senal.get('ULTIMO_CIERRE'), senal.get('ULTIMO_ID')) !=            (visto.get('CIERRES'), visto.get('ULTIMO_CIERRE'), visto.get('ULTIMO_ID'))


def cierre_estable(senal, ahora_utc, espera_min):
    """El ultimo cierre tiene al menos `espera_min` minutos: no se reentrena en medio de una racha."""
    from datetime import datetime
    txt = (senal or {}).get('ULTIMO_CIERRE')
    if not txt:
        return True
    try:
        t = datetime.strptime(txt[:19].replace('T', ' '), '%Y-%m-%d %H:%M:%S')
    except ValueError:
        return True
    return (ahora_utc - t).total_seconds() >= espera_min * 60


def hay_datos_nuevos(cfg, modelo, dataset, version_vigente):
    """Compuertas 1 y 2: datos minimos y datos nuevos desde la vigente."""
    positivas = int(dataset.get('positivas') or 0)
    minimo = cfg.min_positivas[modelo]
    if positivas < minimo:
        return False, 'solo %d casos positivos (minimo %d)' % (positivas, minimo)
    if version_vigente is not None and cfg.nuevas_min > 0:
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

class Cuenta:
    """Una empresa: su usuario de servicio, su sesion y lo que el worker lleva anotado de ella."""
    def __init__(self, login, clave):
        self.login = login
        self.clave = clave
        self.api = None
        self.visto = None          # ultima senal de cierres procesada (linea base al arrancar)
        self.pendiente = False
        self.ultimo_dia = None
        self.proximo_puntuar = 0.0

    def entrar(self, cfg):
        if not self.login or not self.clave:
            raise SystemExit('Falta la clave de la cuenta %r (SIGMA_CLAVE / SIGMA_CLAVE_n).' % self.login)
        self.api = Api(cfg.api, self.login, self.clave)
        return self.api


def puntuar(api):
    for modelo in MODELOS:
        try:
            r = api.post('/sigma-ai/predecir?modelo=' + modelo, {})
            log('puntuado %s: %s' % (modelo, {k: r.get(k) for k in ('equipos', 'alertas', 'predicciones') if k in r} or 'ok'))
        except SystemExit as e:
            log('ERROR al puntuar %s: %s' % (modelo, e))


def reentrenar(cfg, cuenta, modelo, seco):
    api = cuenta.api
    m = MODELOS[modelo]
    versiones = api.get('/sigma-ai/versiones?modelo=' + modelo).json()
    vig = vigente(versiones)
    ds = api.post('/sigma-ai/datasets?modelo=' + modelo, {'paso_dias': 7, 'observacion': 'worker automatico'})
    ok, motivo = hay_datos_nuevos(cfg, modelo, ds, vig)
    if not ok:
        log('[%s] %s: no se reentrena: %s' % (cuenta.login, modelo, motivo))
        return
    log('[%s] %s: reentrenando con el dataset %s (%s filas, %s positivas)' % (cuenta.login, modelo, ds.get('codigo'), ds.get('filas'), ds.get('positivas')))
    entorno = dict(os.environ, SIGMA_API=cfg.api, SIGMA_CLAVE=cuenta.clave)
    cmd = [sys.executable, os.path.join(ML, m['script']), '--usuario', cuenta.login,
           '--dataset', str(ds['id']), '--sin-azure']
    r = subprocess.run(cmd, env=entorno, capture_output=True, text=True, timeout=3600)
    if r.returncode != 0:
        log('[%s] %s: el entrenador fallo (codigo %s); no se publica. %s' % (cuenta.login, modelo, r.returncode, (r.stdout + r.stderr)[-400:].replace(chr(10), ' | ')))
        return
    versiones = api.get('/sigma-ai/versiones?modelo=' + modelo).json()
    nueva = mas_nueva_borrador(versiones)
    if nueva is None:
        log('[%s] %s: el entrenador termino pero no dejo ningun BORRADOR; no se publica.' % (cuenta.login, modelo))
        return
    ok, motivo = mejora(cfg, modelo, nueva, vigente(versiones))
    if not ok:
        log('[%s] %s: la v%s queda en BORRADOR: %s' % (cuenta.login, modelo, nueva.get('mpv_numero'), motivo))
        return
    if seco or not cfg.publicar_auto:
        log('[%s] %s: publicaria la v%s (%s) pero PUBLICAR_AUTO/--seco lo impide.' % (cuenta.login, modelo, nueva.get('mpv_numero'), motivo))
        return
    api.post('/sigma-ai/versiones/%s/publicar' % nueva['mpv_id'], {})
    log('[%s] %s: PUBLICADA la v%s (%s)' % (cuenta.login, modelo, nueva.get('mpv_numero'), motivo))
    puntuar(api)   # las predicciones salen ya con el modelo nuevo


# ---------------------------------------------------------------- bucle

def leer_senal(api):
    try:
        return api.get('/sigma-ai/senal').json()
    except SystemExit as e:
        log('no se pudo leer la senal de cierres: %s' % e)
        return None


def ciclo_entrenamiento(cfg, cuenta, seco):
    for modelo in MODELOS:
        try:
            reentrenar(cfg, cuenta, modelo, seco)
        except (SystemExit, requests.RequestException, subprocess.SubprocessError) as e:
            log('[%s] ERROR reentrenando %s: %s' % (cuenta.login, modelo, e))


def turno(cfg, cuenta, seco):
    """Un vistazo a una empresa: puntua si toca, mira la senal de cierres y reentrena si corresponde."""
    from datetime import datetime
    if time.time() >= cuenta.proximo_puntuar:
        puntuar(cuenta.api)
        cuenta.proximo_puntuar = time.time() + cfg.minutos_puntuar * 60
    senal = leer_senal(cuenta.api)
    if senal_cambio(senal, cuenta.visto):
        cuenta.pendiente = True
        log('[%s] cierre de OT detectado (%s cierres, ultimo %s): reentrenamiento pendiente' % (cuenta.login, senal.get('CIERRES'), senal.get('ULTIMO_CIERRE')))
        cuenta.visto = senal
    elif cuenta.visto is None:
        cuenta.visto = senal
    if cuenta.pendiente and cierre_estable(senal, datetime.utcnow(), cfg.espera_cierre_min):
        ciclo_entrenamiento(cfg, cuenta, seco)
        cuenta.pendiente = False
    ahora = time.localtime()
    hoy = time.strftime('%Y-%m-%d', ahora)
    if ahora.tm_hour == cfg.hora_entrenar and cuenta.ultimo_dia != hoy:
        ciclo_entrenamiento(cfg, cuenta, seco)
        cuenta.ultimo_dia = hoy


def main():
    cargar_env()
    ap = argparse.ArgumentParser(description='Worker automatico de SIGMA AI')
    ap.add_argument('--una-vez', action='store_true', help='un ciclo completo por empresa y sale')
    ap.add_argument('--solo-puntuar', action='store_true')
    ap.add_argument('--seco', action='store_true', help='no publica nada')
    a = ap.parse_args()
    cfg = Config()
    if not cfg.cuentas:
        raise SystemExit('No hay cuentas: defina SIGMA_USUARIO/SIGMA_CLAVE (o SIGMA_USUARIO_1/SIGMA_CLAVE_1 ...) en el entorno o en ML/.env.')
    cuentas = [Cuenta(c['login'], c['clave']) for c in cfg.cuentas]
    for c in cuentas:
        try:
            c.entrar(cfg)
        except SystemExit as e:
            log('[%s] no se pudo entrar: %s' % (c.login, e))

    if a.una_vez or a.solo_puntuar:
        for c in cuentas:
            if c.api is None:
                continue
            puntuar(c.api)
            if not a.solo_puntuar:
                ciclo_entrenamiento(cfg, c, a.seco)
        return

    log('worker en marcha para %d empresa(s): mira cierres de OT cada %d min (espera %d min tras el ultimo); puntua cada %d min; respaldo diario a las %02d:00'
        % (len(cuentas), cfg.minutos_senal, cfg.espera_cierre_min, cfg.minutos_puntuar, cfg.hora_entrenar))
    for c in cuentas:
        if c.api is not None:
            c.visto = leer_senal(c.api)    # linea base: no se reentrena por lo que ya estaba cerrado
    while True:
        for c in cuentas:
            try:
                if c.api is None:
                    c.entrar(cfg)
                turno(cfg, c, a.seco)
            except SystemExit as e:
                log('[%s] sesion perdida o error de la API (%s); se vuelve a entrar' % (c.login, e))
                try:
                    c.entrar(cfg)
                except SystemExit as e2:
                    log('[%s] no se pudo volver a entrar: %s' % (c.login, e2))
        time.sleep(cfg.minutos_senal * 60)


if __name__ == '__main__':
    main()
