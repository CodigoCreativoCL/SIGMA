# -*- coding: utf-8 -*-
"""
SIGMA AI · lo que comparten los entrenadores (falla, RUL, vision).

  Api            entra a la API de SIGMA con un usuario y llama /sigma-ai/*
  registrar_mlflow   deja la corrida y registra el modelo en MLflow / Azure ML
  exportar_onnx  convierte un Pipeline de scikit-learn a ONNX y lo contrasta
                 con una funcion de puntuacion "a mano" (la misma que usa la
                 API en C#): si no dan lo mismo, no se registra nada.
  sha256         la huella de un archivo
"""
import hashlib
import io
import os
import re
import time

import numpy as np
import pandas as pd
import requests


def log(msg):
    print(time.strftime('%H:%M:%S'), msg, flush=True)


def cargar_env():
    """Lee ML/.env (CLAVE=valor por linea) al entorno, sin pisar lo que ya
    esta. Es donde van las claves de entrenamiento de Custom Vision y el
    MLFLOW_TRACKING_URI: fuera del chat, fuera de git (.gitignore)."""
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
    if not os.path.exists(ruta):
        return
    with open(ruta, encoding='utf-8-sig') as f:
        for linea in f:
            linea = linea.strip()
            if not linea or linea.startswith('#') or '=' not in linea:
                continue
            k, v = linea.split('=', 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"'))


cargar_env()


# ---------------------------------------------------------------------------
# LA API
# ---------------------------------------------------------------------------
class Api:
    def __init__(self, base, usuario, clave):
        self.base = base.rstrip('/')
        r = requests.post(self.base + '/sesion', json={'login': usuario, 'password': clave}, timeout=60)
        if r.status_code != 200:
            raise SystemExit('No se pudo entrar a la API (%s): %s' % (r.status_code, r.text[:300]))
        s = r.json()
        self.h = {'Authorization': 'Bearer ' + s['token']}
        log('sesion de %s en cliente %s (%s)' % (s.get('login'), s.get('cliente'), s.get('cliente_nombre')))

    def get(self, ruta, **kw):
        r = requests.get(self.base + ruta, headers=self.h, timeout=600, **kw)
        if r.status_code >= 300:
            raise SystemExit('GET %s -> %s: %s' % (ruta, r.status_code, r.text[:400]))
        return r

    def post(self, ruta, cuerpo):
        r = requests.post(self.base + ruta, headers=self.h, json=cuerpo, timeout=600)
        if r.status_code >= 300:
            raise SystemExit('POST %s -> %s: %s' % (ruta, r.status_code, r.text[:400]))
        return r.json()

    def dataset_registrado(self, den_id, modelo):
        """El CSV exacto del dataset registrado (den_ruta guarda la consulta)."""
        lista = self.get('/sigma-ai/datasets?modelo=' + modelo).json()
        d = next((x for x in lista if x['den_id'] == den_id), None)
        if d is None:
            raise SystemExit('El dataset %s no existe para este cliente y modelo. Registrelo en SIGMA AI > Experimentos.' % den_id)
        log('dataset %s · %s · %s filas · %s positivas' % (d['den_codigo'], d['den_nombre'], d['den_fila_total'], d['den_fila_positiva']))
        csv = self.get('/' + d['den_ruta'].lstrip('/')).content
        huella = hashlib.sha256(csv).hexdigest()
        if d.get('den_hash_datos') and huella != d['den_hash_datos']:
            log('AVISO: la huella del CSV (%s…) no coincide con la registrada (%s…): la base cambio desde que se registro.'
                % (huella[:10], d['den_hash_datos'][:10]))
        return pd.read_csv(io.BytesIO(csv)), d


def sha256(ruta):
    with open(ruta, 'rb') as f:
        c = f.read()
    return hashlib.sha256(c).hexdigest(), len(c)


# ---------------------------------------------------------------------------
# ONNX
# ---------------------------------------------------------------------------
def exportar_onnx(pipeline, X, puntuar_a_mano, ruta, salida_indice=None, tolerancia=1e-4):
    """Convierte el pipeline a ONNX y comprueba que su salida es la de
    `puntuar_a_mano(X)` (lo que hace la API con los pesos). Devuelve la ruta
    o None si skl2onnx no esta instalado. Aborta si difieren."""
    try:
        from skl2onnx import convert_sklearn
        from skl2onnx.common.data_types import FloatTensorType
    except ImportError:
        log('skl2onnx no esta instalado: se omite el ONNX (pip install skl2onnx onnxruntime).')
        return None
    onx = convert_sklearn(pipeline, initial_types=[('entrada', FloatTensorType([None, X.shape[1]]))],
                          options={'zipmap': False} if hasattr(pipeline, 'predict_proba') else None, target_opset=15)
    with open(ruta, 'wb') as f:
        f.write(onx.SerializeToString())
    log('ONNX escrito: %s (%d bytes)' % (ruta, os.path.getsize(ruta)))
    try:
        import onnxruntime as ort
        s = ort.InferenceSession(ruta, providers=['CPUExecutionProvider'])
        salida = s.run(None, {'entrada': X.astype(np.float32)})
        if salida_indice is None:
            o = salida[1] if len(salida) > 1 else salida[0]
        else:
            o = salida[salida_indice]
        o = np.asarray(o)
        p_onnx = o[:, 1] if o.ndim == 2 and o.shape[1] == 2 else o.reshape(len(X), -1)[:, 0] if o.ndim == 2 else o
        p_mano = np.asarray(puntuar_a_mano(X)).reshape(-1)
        dif = float(np.abs(p_onnx.reshape(-1) - p_mano).max())
        log('ONNX vs pesos: diferencia maxima %.2e sobre %d filas' % (dif, len(X)))
        if dif > tolerancia:
            raise SystemExit('El ONNX y los pesos NO dan lo mismo: no se registra nada.')
    except ImportError:
        log('onnxruntime no esta instalado: no se pudo contrastar el ONNX con los pesos.')
    return ruta


# ---------------------------------------------------------------------------
# MLFLOW / AZURE ML
# ---------------------------------------------------------------------------
def registrar_mlflow(nombre_modelo, parametros, metricas, hiper, archivos, etiquetas):
    """Deja la corrida y registra el modelo. Con MLFLOW_TRACKING_URI de Azure
    ML va al area de trabajo (azureml-mlflow + `az login`); sin URI, a
    ML/mlruns. Devuelve (entorno, ruta_artefacto, registro) o (None,)*3."""
    try:
        import mlflow
    except ImportError:
        log('mlflow no esta instalado: no se registra en Azure ML (pip install "mlflow<3" azureml-mlflow).')
        return None, None, None
    uri = os.environ.get('MLFLOW_TRACKING_URI', '')
    if not uri:
        mlflow.set_tracking_uri('file:' + os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mlruns'))
        uri = mlflow.get_tracking_uri()
    mlflow.set_experiment(nombre_modelo)
    with mlflow.start_run(run_name=time.strftime(nombre_modelo.lower() + '-%Y%m%d-%H%M')) as run:
        mlflow.set_tags(etiquetas)
        mlflow.log_params({k: str(v) for k, v in hiper.items()})
        mlflow.log_metrics({k: v for k, v in metricas.items() if isinstance(v, (int, float))})
        for a in archivos:
            if a and os.path.exists(a):
                mlflow.log_artifact(a, 'modelo')
        run_id = run.info.run_id

    ruta_modelo, registro = None, None
    m = re.search(r'subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/[^/]+/workspaces/([^/?]+)', uri)
    if m:
        # Donde quedaron los archivos en el area de trabajo: lo que `az ml
        # model show` devuelve como `path` y lo que la API descarga con el
        # SAS del almacenamiento (bloque 246), sin entidad de servicio.
        ruta_modelo = ('azureml://subscriptions/%s/resourceGroups/%s/workspaces/%s/datastores/workspaceartifactstore'
                       '/paths/ExperimentRun/dcid.%s/modelo' % (m.group(1), m.group(2), m.group(3), run_id))
    try:
        origen = 'runs:/%s/modelo' % run_id
        mv = mlflow.register_model(origen, nombre_modelo)
        registro = '%s:%s' % (nombre_modelo, mv.version)
        if not m:
            ruta_modelo = origen
        log('modelo registrado: %s' % registro)
    except Exception as e:  # el registro es deseable, no obligatorio
        log('no se pudo registrar el modelo en MLflow: %s' % str(e)[:300])
    entorno = ('azureml' if 'azureml' in uri else 'mlflow local') + ' · run ' + run_id
    log('corrida %s en %s' % (run_id, uri[:80]))
    return entorno, ruta_modelo, registro


def informar(api, modelo, dataset_id, entorno, inicio, metricas, origen, version, sin_informar=False, error=None):
    """POST /sigma-ai/entrenamientos: la corrida y la version (o el error)."""
    if sin_informar:
        log('no se informa a la API (--sin-informar).')
        return None
    if error:
        api.post('/sigma-ai/entrenamientos?modelo=' + modelo, {'dataset': dataset_id, 'entorno': 'local', 'estado': 4,
                                                             'segundos': int(time.time() - inicio), 'mensaje': str(error)})
        log('corrida informada como ERROR a la API.')
        return None
    r = api.post('/sigma-ai/entrenamientos?modelo=' + modelo, {
        'dataset': dataset_id, 'entorno': entorno, 'estado': 3, 'segundos': int(time.time() - inicio),
        'metrica': metricas, 'mensaje': 'Entrenado con ' + origen, 'version': version})
    log('corrida %s informada; version %s en BORRADOR. Publiquela en SIGMA AI > Experimentos.' % (r.get('id'), r.get('version')))
    return r
