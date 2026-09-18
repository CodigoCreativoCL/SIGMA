# -*- coding: utf-8 -*-
"""
SIGMA AI · SIGMA FAILURE 30D · el entrenador.                  (bloque 245)

QUE HACE, EN ORDEN
  1. Entra a la API de SIGMA con tu usuario (POST /sesion).
  2. Baja el dataset registrado (GET /sigma-ai/dataset?...&formato=csv) o
     lee un CSV local, o fabrica uno sintetico (--demo) con el MISMO esquema
     para recorrer el camino cuando el historial real es chico.
  3. Entrena una regresion logistica (StandardScaler + LogisticRegression,
     class_weight=balanced), la valida con K-fold estratificado y calcula
     AUC, precision, recall y F1 sobre las predicciones fuera de muestra.
  4. Exporta los PESOS a JSON (caracteristicas, media, desviacion,
     coeficientes, intercepto): es lo que la API usa para puntuar.
  5. Si skl2onnx esta instalado, convierte a ONNX y comprueba que ONNX y
     pesos dan la misma probabilidad para todo el dataset (si no, aborta).
  6. Si MLFLOW_TRACKING_URI apunta a Azure ML (y no se paso --sin-azure),
     deja la corrida con parametros, metricas y artefactos y registra el
     modelo. Solo escribe metadatos y unos KB: no crea computo, no cuesta.
     Sin URI, deja todo en ML/mlruns (MLflow local).
  7. Informa a la API (POST /sigma-ai/entrenamientos): la corrida y la
     version, que queda en BORRADOR hasta que alguien la publique.

COMO SE CORRE
  pip install scikit-learn pandas requests            (obligatorio)
  pip install skl2onnx onnxruntime                    (ONNX, recomendado)
  pip install mlflow azureml-mlflow                   (Azure ML, opcional)
  az login                                            (una vez; identidad de tu cuenta)
  set SIGMA_API=http://localhost/SIGMA/Servicio/API
  set MLFLOW_TRACKING_URI=azureml://eastus2.api.azureml.ms/mlflow/v1.0/subscriptions/<sub>/resourceGroups/SIGMA/providers/Microsoft.MachineLearningServices/workspaces/SIGMA_AI
  python entrenar_falla.py --usuario rodrigo --dataset 1
  python entrenar_falla.py --usuario rodrigo --demo 800 --sin-azure

NO SE ENTRENA CON LO QUE VINO DESPUES DEL CORTE
  Las columnas que NO son caracteristicas se quitan a mano y por nombre
  (ACTIVO, ACTIVO_CODIGO, ACTIVO_NOMBRE, INSTALACION, CORTE, FALLO_EN_30D):
  un modelo que aprende el id del equipo o la fecha no aprende deterioro.
"""
import argparse
import getpass
import hashlib
import io
import json
import os
import re
import sys
import time

import numpy as np
import pandas as pd
import requests
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score, precision_score, recall_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold, cross_val_predict
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

MODELO = 'SIGMA_FAILURE_30D'
NO_CARACTERISTICAS = ['ACTIVO', 'ACTIVO_CODIGO', 'ACTIVO_NOMBRE', 'INSTALACION', 'CORTE', 'FALLO_EN_30D']
CARACTERISTICAS = ['CRITICIDAD', 'EDAD_DIAS', 'LECTURA_MEDIDOR', 'FALLAS_90D', 'FALLAS_TOTAL', 'DIAS_DESDE_FALLA',
                   'OT_CERRADAS_180D', 'OT_CORRECTIVAS_180D', 'DIAS_DESDE_MANTENCION', 'MED_30D_N',
                   'MED_30D_ADVERTENCIA', 'MED_30D_RATIO_CRITICO', 'TENDENCIA_30D', 'BITACORA_30D', 'INDISP_MIN_90D']


def log(msg):
    print(time.strftime('%H:%M:%S'), msg, flush=True)


# ---------------------------------------------------------------------------
# 1. LA API
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


# ---------------------------------------------------------------------------
# 2. EL DATASET
# ---------------------------------------------------------------------------
def dataset_registrado(api, den_id):
    """El CSV exacto del dataset registrado: la API guarda en den_ruta la
    consulta (rango y paso) con que se armo, asi que se vuelve a pedir igual."""
    lista = api.get('/sigma-ai/datasets').json()
    d = next((x for x in lista if x['den_id'] == den_id), None)
    if d is None:
        raise SystemExit('El dataset %s no existe para este cliente. Registrelo en SIGMA AI > Experimentos.' % den_id)
    log('dataset %s · %s · %s filas · %s positivas' % (d['den_codigo'], d['den_nombre'], d['den_fila_total'], d['den_fila_positiva']))
    csv = api.get('/' + d['den_ruta'].lstrip('/')).content
    huella = hashlib.sha256(csv).hexdigest()
    if d.get('den_hash_datos') and huella != d['den_hash_datos']:
        log('AVISO: la huella del CSV (%s…) no coincide con la registrada (%s…): la base cambio desde que se registro.'
            % (huella[:10], d['den_hash_datos'][:10]))
    return pd.read_csv(io.BytesIO(csv)), d


def dataset_sintetico(n, semilla=7):
    """El mismo esquema, con una regla de deterioro conocida. Sirve para
    probar el camino completo, NO para decidir nada sobre una maquina."""
    rng = np.random.default_rng(semilla)
    df = pd.DataFrame({
        'ACTIVO': rng.integers(1, 60, n),
        'ACTIVO_CODIGO': ['SIN-%03d' % i for i in range(n)],
        'ACTIVO_NOMBRE': 'Equipo sintetico',
        'INSTALACION': 1,
        'CORTE': pd.Timestamp('2026-01-01') + pd.to_timedelta(rng.integers(0, 240, n), 'D'),
        'CRITICIDAD': rng.integers(1, 5, n),
        'EDAD_DIAS': rng.integers(30, 6000, n),
        'LECTURA_MEDIDOR': rng.uniform(0, 20000, n).round(1),
        'FALLAS_90D': rng.poisson(0.4, n),
        'FALLAS_TOTAL': rng.poisson(2.0, n),
        'DIAS_DESDE_FALLA': rng.integers(1, 366, n),
        'OT_CERRADAS_180D': rng.poisson(2.0, n),
        'OT_CORRECTIVAS_180D': rng.poisson(0.7, n),
        'DIAS_DESDE_MANTENCION': rng.integers(1, 366, n),
        'MED_30D_N': rng.poisson(6, n),
        'MED_30D_ADVERTENCIA': rng.poisson(1.0, n),
        'MED_30D_RATIO_CRITICO': rng.uniform(0.2, 1.3, n).round(3),
        'TENDENCIA_30D': rng.normal(0.0, 0.02, n).round(4),
        'BITACORA_30D': rng.poisson(0.5, n),
        'INDISP_MIN_90D': rng.exponential(200, n).round(0),
    })
    z = (-2.2 + 1.1 * df.FALLAS_90D + 0.35 * df.OT_CORRECTIVAS_180D + 2.2 * (df.MED_30D_RATIO_CRITICO - 0.8).clip(lower=0)
         + 12 * df.TENDENCIA_30D + 0.004 * df.DIAS_DESDE_MANTENCION - 0.004 * df.DIAS_DESDE_FALLA + 0.3 * df.MED_30D_ADVERTENCIA
         + 0.25 * (df.CRITICIDAD - 2) + rng.normal(0, 0.6, n))
    df['FALLO_EN_30D'] = (rng.uniform(0, 1, n) < 1 / (1 + np.exp(-z))).astype(int)
    return df


# ---------------------------------------------------------------------------
# 3. ENTRENAR Y VALIDAR
# ---------------------------------------------------------------------------
def entrenar(df, folds=5, C=1.0):
    df = df[df['FALLO_EN_30D'].notna()].copy()
    faltan = [c for c in CARACTERISTICAS if c not in df.columns]
    if faltan:
        raise SystemExit('Al dataset le faltan columnas: %s' % faltan)
    X = df[CARACTERISTICAS].astype(float).fillna(0.0).values
    y = df['FALLO_EN_30D'].astype(int).values
    n, pos = len(y), int(y.sum())
    log('filas etiquetadas: %d · positivas: %d (%.1f %%)' % (n, pos, 100.0 * pos / max(n, 1)))
    if pos < 2 or pos == n:
        raise SystemExit('No se puede entrenar: hacen falta al menos 2 filas positivas y 2 negativas. '
                         'Con el historial de hoy use --demo para probar el camino.')
    if pos < 20:
        log('AVISO: menos de 20 positivas. El modelo que salga sirve para probar el camino, no para operar.')

    modelo = Pipeline([('escala', StandardScaler()),
                       ('lr', LogisticRegression(C=C, class_weight='balanced', max_iter=2000))])

    k = max(2, min(folds, pos))
    cv = StratifiedKFold(n_splits=k, shuffle=True, random_state=7)
    p_cv = cross_val_predict(modelo, X, y, cv=cv, method='predict_proba')[:, 1]
    umbral = 0.5
    metricas = {
        'auc': float(roc_auc_score(y, p_cv)),
        'precision': float(precision_score(y, p_cv >= umbral, zero_division=0)),
        'recall': float(recall_score(y, p_cv >= umbral, zero_division=0)),
        'f1': float(f1_score(y, p_cv >= umbral, zero_division=0)),
        'filas': n, 'positivas': pos, 'folds': k, 'umbral': umbral,
    }
    log('validacion %d-fold: AUC %.3f · precision %.3f · recall %.3f · F1 %.3f' %
        (k, metricas['auc'], metricas['precision'], metricas['recall'], metricas['f1']))

    modelo.fit(X, y)
    esc, lr = modelo.named_steps['escala'], modelo.named_steps['lr']
    parametros = {
        'algoritmo': 'Regresion logistica (scikit-learn %s), StandardScaler, class_weight=balanced' % __import__('sklearn').__version__,
        'caracteristicas': CARACTERISTICAS,
        'media': [float(v) for v in esc.mean_],
        'desviacion': [float(v) for v in esc.scale_],
        'coeficientes': [float(v) for v in lr.coef_[0]],
        'intercepto': float(lr.intercept_[0]),
    }
    return modelo, X, parametros, metricas, {'C': C, 'class_weight': 'balanced', 'max_iter': 2000, 'folds': k}


def puntuar_con_pesos(p, X):
    """Lo mismo que hace PuntuadorFalla.cs: estandarizar, pesos, sigmoide."""
    z = p['intercepto'] + ((X - np.array(p['media'])) / np.array(p['desviacion'])) @ np.array(p['coeficientes'])
    return 1.0 / (1.0 + np.exp(-z))


# ---------------------------------------------------------------------------
# 4. ONNX
# ---------------------------------------------------------------------------
def exportar_onnx(modelo, X, parametros, ruta):
    try:
        from skl2onnx import convert_sklearn
        from skl2onnx.common.data_types import FloatTensorType
    except ImportError:
        log('skl2onnx no esta instalado: se omite el ONNX (pip install skl2onnx onnxruntime).')
        return None
    onx = convert_sklearn(modelo, initial_types=[('entrada', FloatTensorType([None, X.shape[1]]))],
                          options={'zipmap': False}, target_opset=15)
    with open(ruta, 'wb') as f:
        f.write(onx.SerializeToString())
    log('ONNX escrito: %s (%d bytes)' % (ruta, os.path.getsize(ruta)))
    try:
        import onnxruntime as ort
        s = ort.InferenceSession(ruta, providers=['CPUExecutionProvider'])
        salida = s.run(None, {'entrada': X.astype(np.float32)})
        p_onnx = salida[1][:, 1] if salida[1].ndim == 2 else salida[1]
        p_pesos = puntuar_con_pesos(parametros, X)
        dif = float(np.abs(p_onnx - p_pesos).max())
        log('ONNX vs pesos: diferencia maxima %.2e sobre %d filas' % (dif, len(X)))
        if dif > 1e-4:
            raise SystemExit('El ONNX y los pesos NO dan lo mismo: no se registra nada.')
    except ImportError:
        log('onnxruntime no esta instalado: no se pudo contrastar el ONNX con los pesos.')
    return ruta


# ---------------------------------------------------------------------------
# 5. MLFLOW / AZURE ML
# ---------------------------------------------------------------------------
def registrar_mlflow(parametros, metricas, hiper, archivos, etiquetas):
    """Deja la corrida y registra el modelo. Con MLFLOW_TRACKING_URI de Azure
    ML, va al area de trabajo (azureml-mlflow + `az login`); sin URI, a
    ML/mlruns. Devuelve (entorno, ruta_modelo) o (None, None) si no hay mlflow."""
    try:
        import mlflow
    except ImportError:
        log('mlflow no esta instalado: no se registra en Azure ML (pip install mlflow azureml-mlflow).')
        return None, None, None
    uri = os.environ.get('MLFLOW_TRACKING_URI', '')
    if not uri:
        mlflow.set_tracking_uri('file:' + os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mlruns'))
        uri = mlflow.get_tracking_uri()
    mlflow.set_experiment(MODELO)
    with mlflow.start_run(run_name=time.strftime('falla30-%Y%m%d-%H%M')) as run:
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
        # Donde quedaron los archivos en el area de trabajo: es lo que `az ml
        # model show` devuelve como `path` y lo que la API descarga con el
        # SAS del almacenamiento (bloque 246), sin entidad de servicio.
        ruta_modelo = ('azureml://subscriptions/%s/resourceGroups/%s/workspaces/%s/datastores/workspaceartifactstore'
                       '/paths/ExperimentRun/dcid.%s/modelo' % (m.group(1), m.group(2), m.group(3), run_id))
    try:
        origen = 'runs:/%s/modelo' % run_id
        mv = mlflow.register_model(origen, MODELO)
        registro = '%s:%s' % (MODELO, mv.version)
        if not m:
            ruta_modelo = origen
        log('modelo registrado: %s' % registro)
    except Exception as e:  # el registro es deseable, no obligatorio
        log('no se pudo registrar el modelo en MLflow: %s' % str(e)[:300])
    entorno = ('azureml' if 'azureml' in uri else 'mlflow local') + ' · run ' + run_id
    log('corrida %s en %s' % (run_id, uri[:80]))
    return entorno, ruta_modelo, registro


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description='Entrena SIGMA FAILURE 30D y lo informa a la API.')
    ap.add_argument('--api', default=os.environ.get('SIGMA_API', 'http://localhost/SIGMA/Servicio/API'))
    ap.add_argument('--usuario', required=True, help='login de SIGMA con permiso ENTRENAR MODELOS')
    ap.add_argument('--clave', default=os.environ.get('SIGMA_CLAVE'), help='si no viene, se pide')
    ap.add_argument('--dataset', type=int, help='id del dataset registrado (den_id)')
    ap.add_argument('--csv', help='un CSV local con el esquema del dataset')
    ap.add_argument('--demo', type=int, metavar='N', help='dataset sintetico de N filas (solo para probar el camino)')
    ap.add_argument('--C', type=float, default=1.0, help='regularizacion inversa de la logistica')
    ap.add_argument('--folds', type=int, default=5)
    ap.add_argument('--sin-azure', action='store_true', help='no usar MLflow/Azure ML aunque haya URI')
    ap.add_argument('--sin-informar', action='store_true', help='no llamar a POST /sigma-ai/entrenamientos')
    a = ap.parse_args()

    if not (a.dataset or a.csv or a.demo):
        ap.error('indique --dataset ID, --csv ruta o --demo N')

    clave = a.clave or getpass.getpass('Contrasena de %s: ' % a.usuario)
    api = Api(a.api, a.usuario, clave)

    inicio = time.time()
    salida = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'salida')
    os.makedirs(salida, exist_ok=True)
    marca = time.strftime('%Y%m%d-%H%M%S')

    dataset_id, origen = None, ''
    if a.dataset:
        df, d = dataset_registrado(api, a.dataset)
        dataset_id, origen = d['den_id'], d['den_codigo']
    elif a.csv:
        df = pd.read_csv(a.csv)
        origen = 'csv ' + os.path.basename(a.csv)
    else:
        df = dataset_sintetico(a.demo)
        origen = 'SINTETICO %d filas (solo prueba del camino)' % a.demo
        log(origen)

    try:
        modelo, X, parametros, metricas, hiper = entrenar(df, a.folds, a.C)
    except SystemExit as e:
        log(str(e))
        if not a.sin_informar:
            api.post('/sigma-ai/entrenamientos', {'dataset': dataset_id, 'entorno': 'local', 'estado': 4,
                                                 'segundos': int(time.time() - inicio), 'mensaje': str(e)})
            log('corrida informada como ERROR a la API.')
        return 1

    ruta_json = os.path.join(salida, 'falla30-%s.json' % marca)
    with open(ruta_json, 'w', encoding='utf-8') as f:
        json.dump({'parametros': parametros, 'metricas': metricas, 'hiperparametros': hiper, 'origen': origen}, f, indent=2)
    ruta_onnx = exportar_onnx(modelo, X, parametros, os.path.join(salida, 'falla30-%s.onnx' % marca))

    hash_onnx = bytes_onnx = None
    if ruta_onnx:
        with open(ruta_onnx, 'rb') as f:
            contenido = f.read()
        hash_onnx, bytes_onnx = hashlib.sha256(contenido).hexdigest(), len(contenido)

    entorno, ruta_modelo, registro = ('local · sin MLflow', None, None)
    if not a.sin_azure:
        e, r, g = registrar_mlflow(parametros, metricas, hiper, [ruta_json, ruta_onnx],
                                   {'sigma_modelo': 'SIGMA FAILURE 30D', 'dataset': origen, 'onnx_sha256': hash_onnx or ''})
        if e:
            entorno, ruta_modelo, registro = e, r, g

    if a.sin_informar:
        log('no se informa a la API (--sin-informar). Pesos en %s' % ruta_json)
        return 0

    r = api.post('/sigma-ai/entrenamientos', {
        'dataset': dataset_id, 'entorno': entorno, 'estado': 3, 'segundos': int(time.time() - inicio),
        'metrica': metricas, 'mensaje': 'Entrenado con ' + origen,
        'version': {
            'formato': 'ONNX' if ruta_onnx else 'PICKLE',
            'algoritmo': parametros['algoritmo'], 'hiperparametro': hiper, 'parametro': parametros,
            'ruta': ruta_modelo, 'registro': registro, 'hash': hash_onnx, 'bytes': bytes_onnx,
            'auc': round(metricas['auc'], 6), 'precision': round(metricas['precision'], 6),
            'recall': round(metricas['recall'], 6), 'f1': round(metricas['f1'], 6),
            'observacion': ('DATASET SINTETICO: no usar para operar. ' if a.demo else '') + 'ONNX ' + (ruta_onnx or 'no generado'),
        }})
    log('corrida %s informada; version %s en BORRADOR. Publiquela en SIGMA AI > Experimentos.' % (r.get('id'), r.get('version')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
