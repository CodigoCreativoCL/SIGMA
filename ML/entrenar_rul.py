# -*- coding: utf-8 -*-
"""
SIGMA AI · SIGMA RUL · el entrenador.                              (bloque 247)

QUE PREDICE
  Cuantos dias mas va a durar un repuesto instalado, mirando lo que paso
  hasta la fecha de corte. Sale la mediana, un intervalo del 80 % y la
  fecha estimada.

COMO LO APRENDE: AFT LOG-NORMAL CON CENSURA
  log(dias_restantes) = b + w · x_estandarizado + sigma · e,  e ~ N(0, 1)
  Las filas CENSURADAS (sigue puesto hoy, o se retiro por otro motivo que
  falla/desgaste) entran como cota inferior: se maximiza
    sum_no_censuradas  log phi(z)      con z = (log t - b - w·x) / sigma
    sum_censuradas     log (1 - Phi(z))
  Es la regla 2 del modelo logico §11.3 hecha numero: un retiro preventivo
  a las 6.920 h dice "duro AL MENOS 6.920 h", no "duro 6.920 h".

LO QUE RECIBE LA API
  Los mismos pesos (media, desviacion, coeficientes, intercepto) mas
  `sigma`, y puntua en C# igual que aqui: mediana = exp(b + w·x),
  intervalo 80 % = exp(b + w·x -+ 1,2816 sigma). El ONNX que se registra es
  la parte lineal (StandardScaler + LinearRegression con esos pesos) y se
  contrasta contra la formula antes de registrar.

COMO SE CORRE
  python entrenar_rul.py --usuario <login> --dataset <id>
  python entrenar_rul.py --usuario <login> --demo 600 --sin-azure
"""
import argparse
import getpass
import json
import os
import sys
import time

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.stats import norm
from sklearn.linear_model import LinearRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from sigma_ml import Api, exportar_onnx, informar, log, registrar_mlflow, sha256

MODELO = 'SIGMA_RUL'
MODELO_API = 'RUL'
CARACTERISTICAS = ['DIAS_CORRIENDO', 'HORAS_CORRIENDO', 'VIDA_NOMINAL_HORAS', 'VIDA_NOMINAL_DIAS', 'RATIO_CONSUMIDO',
                   'INSTALACIONES_PREVIAS', 'DURACION_PREVIA_DIAS', 'FALLOS_PREVIOS', 'CRITICIDAD',
                   'FALLAS_90D', 'DIAS_DESDE_MANTENCION', 'MED_30D_ADVERTENCIA', 'MED_30D_RATIO_CRITICO', 'TENDENCIA_30D']
Z80 = 1.2815515655446004   # cuantil 0,90 de la normal: intervalo central del 80 %


# ---------------------------------------------------------------------------
# DATASET SINTETICO: curvas de degradacion que terminan en falla (HU-171 #3)
# ---------------------------------------------------------------------------
def dataset_sintetico(n, semilla=11):
    """Cada fila es una instalacion mirada en un corte. La vida total sale de
    una log-normal cuya mediana baja con el desgaste (ratio consumido,
    mediciones altas, tendencia) y sube con vida nominal alta; el 35 % se
    censura como si se hubiera retirado antes por politica preventiva."""
    rng = np.random.default_rng(semilla)
    vida_nominal_h = rng.choice([0, 4000, 8000, 12000, 20000], n, p=[.2, .2, .3, .2, .1])
    horas_corriendo = np.where(vida_nominal_h > 0, rng.uniform(0, 1.1, n) * np.maximum(vida_nominal_h, 4000), rng.uniform(0, 9000, n)).round(0)
    dias_corriendo = (horas_corriendo / rng.uniform(8, 22, n)).round(0).astype(int)
    ratio = np.where(vida_nominal_h > 0, horas_corriendo / np.maximum(vida_nominal_h, 1), 0).round(3)
    df = pd.DataFrame({
        'INSTALACION': np.arange(1, n + 1), 'COMPONENTE': rng.integers(1, 80, n), 'COMPONENTE_CODIGO': 'CMP-SIN', 'COMPONENTE_NOMBRE': 'sintetico',
        'ACTIVO': rng.integers(1, 40, n), 'ACTIVO_CODIGO': 'ACT-SIN', 'REPUESTO': rng.integers(1, 30, n), 'REPUESTO_CODIGO': 'REP-SIN', 'REPUESTO_NOMBRE': 'sintetico',
        'INSTALADO': pd.Timestamp('2025-01-01'), 'CORTE': pd.Timestamp('2025-01-01') + pd.to_timedelta(dias_corriendo, 'D'),
        'DIAS_CORRIENDO': dias_corriendo, 'HORAS_CORRIENDO': horas_corriendo, 'VIDA_NOMINAL_HORAS': vida_nominal_h,
        'VIDA_NOMINAL_DIAS': 0, 'RATIO_CONSUMIDO': ratio,
        'INSTALACIONES_PREVIAS': rng.poisson(1.2, n), 'DURACION_PREVIA_DIAS': rng.choice([0, 180, 300, 420, 600], n),
        'FALLOS_PREVIOS': rng.poisson(0.4, n), 'CRITICIDAD': rng.integers(1, 5, n),
        'FALLAS_90D': rng.poisson(0.3, n), 'DIAS_DESDE_MANTENCION': rng.integers(1, 366, n),
        'MED_30D_ADVERTENCIA': rng.poisson(0.8, n), 'MED_30D_RATIO_CRITICO': rng.uniform(0.2, 1.3, n).round(3),
        'TENDENCIA_30D': rng.normal(0.0, 0.02, n).round(4),
    })
    # vida total (dias) de la instalacion: mediana ~ 400 dias, baja con el desgaste
    log_mediana = (np.log(400) + 0.25 * np.log1p(vida_nominal_h / 8000) - 0.9 * ratio
                   - 0.35 * (df.MED_30D_RATIO_CRITICO - 0.8).clip(lower=0) * 3 - 8 * df.TENDENCIA_30D
                   - 0.15 * df.FALLOS_PREVIOS + 0.12 * (df.DURACION_PREVIA_DIAS > 300))
    vida_total = np.exp(log_mediana + rng.normal(0, 0.45, n))
    restante = np.maximum(vida_total - dias_corriendo, 1)
    censurado = rng.uniform(0, 1, n) < 0.35
    # el censurado se retiro (o sigue) antes: solo se sabe que duro al menos una parte
    observado = np.where(censurado, restante * rng.uniform(0.2, 0.9, n), restante)
    df['DIAS_RESTANTES'] = observado.round(0).astype(int)
    df['HORAS_RESTANTES'] = np.nan
    df['CENSURADO'] = censurado.astype(int)
    return df


# ---------------------------------------------------------------------------
# AFT LOG-NORMAL
# ---------------------------------------------------------------------------
def ajustar_aft(Xs, t, censurado, l2=0.01):
    """Maxima verosimilitud con censura por la derecha. Xs ya estandarizado.
    Devuelve (intercepto, coeficientes, sigma)."""
    y = np.log(np.maximum(t, 1.0))
    k = Xs.shape[1]
    # arranque: minimos cuadrados sobre todo, sigma = desviacion residual
    b0 = np.linalg.lstsq(np.c_[np.ones(len(y)), Xs], y, rcond=None)[0]
    theta0 = np.r_[b0, np.log(max(np.std(y - np.c_[np.ones(len(y)), Xs] @ b0), 0.1))]
    nc = ~censurado.astype(bool)

    def neg_log_ver(theta):
        b, w, ls = theta[0], theta[1:1 + k], theta[-1]
        s = np.exp(ls)
        z = (y - b - Xs @ w) / s
        ll = np.sum(norm.logpdf(z[nc]) - ls) + np.sum(norm.logsf(z[~nc]))
        return -ll + l2 * np.sum(w * w)

    r = minimize(neg_log_ver, theta0, method='L-BFGS-B')
    return float(r.x[0]), [float(v) for v in r.x[1:1 + k]], float(np.exp(r.x[-1])), bool(r.success)


def entrenar(df, folds=5):
    df = df[df['DIAS_RESTANTES'].notna()].copy()
    faltan = [c for c in CARACTERISTICAS if c not in df.columns]
    if faltan:
        raise SystemExit('Al dataset le faltan columnas: %s' % faltan)
    X = df[CARACTERISTICAS].astype(float).fillna(0.0).values
    t = df['DIAS_RESTANTES'].astype(float).values
    cen = df['CENSURADO'].astype(int).values
    n, nc = len(t), int((cen == 0).sum())
    log('filas: %d · no censuradas (se sabe cuanto duraron): %d · censuradas: %d' % (n, nc, n - nc))
    if nc < 5:
        raise SystemExit('No se puede entrenar: hacen falta al menos 5 retiros por falla o desgaste con fecha. '
                         'Con el historial de hoy use --demo para probar el camino.')
    if nc < 30:
        log('AVISO: menos de 30 retiros observados (el modelo logico pide ~30). Sirve para probar el camino, no para operar.')

    esc = StandardScaler().fit(X)
    Xs = esc.transform(X)

    # validacion cruzada: error absoluto mediano en dias sobre las NO censuradas
    k = max(2, min(folds, nc))
    idx = np.arange(n)
    rng = np.random.default_rng(7)
    rng.shuffle(idx)
    partes = np.array_split(idx, k)
    err, cobertura = [], []
    for p in partes:
        entren = np.setdiff1d(idx, p)
        b, w, s, _ = ajustar_aft(Xs[entren], t[entren], cen[entren])
        prueba = p[cen[p] == 0]
        if len(prueba) == 0:
            continue
        mu = b + Xs[prueba] @ np.array(w)
        pred = np.exp(mu)
        err.extend(np.abs(pred - t[prueba]))
        cobertura.extend((t[prueba] >= np.exp(mu - Z80 * s)) & (t[prueba] <= np.exp(mu + Z80 * s)))
    mae = float(np.mean(err)) if err else None
    mediana_err = float(np.median(err)) if err else None
    cob = float(np.mean(cobertura)) if cobertura else None
    log('validacion %d-fold (no censuradas): MAE %.1f dias · error mediano %.1f dias · cobertura del intervalo 80 %%: %.0f %%'
        % (k, mae or 0, mediana_err or 0, 100 * (cob or 0)))

    b, w, s, ok = ajustar_aft(Xs, t, cen)
    if not ok:
        log('AVISO: el optimizador no reporto convergencia; se usan los pesos obtenidos.')
    metricas = {'mae_dias': mae, 'error_mediano_dias': mediana_err, 'cobertura_80': cob, 'sigma': s,
                'filas': n, 'no_censuradas': nc, 'censuradas': n - nc, 'folds': k}
    parametros = {
        'algoritmo': 'AFT log-normal con censura (scipy L-BFGS-B), StandardScaler',
        'objetivo': 'log(dias_restantes)',
        'caracteristicas': CARACTERISTICAS,
        'media': [float(v) for v in esc.mean_],
        'desviacion': [float(v) for v in esc.scale_],
        'coeficientes': w, 'intercepto': b, 'sigma': s, 'z_intervalo': Z80,
    }
    # el ONNX: la parte lineal, con los pesos del AFT puestos a mano
    lr = LinearRegression()
    lr.coef_ = np.array(w)
    lr.intercept_ = float(b)
    lr.n_features_in_ = len(w)
    pipe = Pipeline([('escala', esc), ('lineal', lr)])
    return pipe, X, parametros, metricas, {'l2': 0.01, 'folds': k, 'intervalo': 0.80}


def log_mediana_con_pesos(p, X):
    return p['intercepto'] + ((X - np.array(p['media'])) / np.array(p['desviacion'])) @ np.array(p['coeficientes'])


def main():
    ap = argparse.ArgumentParser(description='Entrena SIGMA RUL y lo informa a la API.')
    ap.add_argument('--api', default=os.environ.get('SIGMA_API', 'http://localhost/SIGMA/Servicio/API'))
    ap.add_argument('--usuario', required=True)
    ap.add_argument('--clave', default=os.environ.get('SIGMA_CLAVE'))
    ap.add_argument('--dataset', type=int)
    ap.add_argument('--csv')
    ap.add_argument('--demo', type=int, metavar='N')
    ap.add_argument('--folds', type=int, default=5)
    ap.add_argument('--sin-azure', action='store_true')
    ap.add_argument('--sin-informar', action='store_true')
    a = ap.parse_args()
    if not (a.dataset or a.csv or a.demo):
        ap.error('indique --dataset ID, --csv ruta o --demo N')

    api = Api(a.api, a.usuario, a.clave or getpass.getpass('Contrasena de %s: ' % a.usuario))
    inicio = time.time()
    salida = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'salida')
    os.makedirs(salida, exist_ok=True)
    marca = time.strftime('%Y%m%d-%H%M%S')

    dataset_id, origen = None, ''
    if a.dataset:
        df, d = api.dataset_registrado(a.dataset, MODELO_API)
        dataset_id, origen = d['den_id'], d['den_codigo']
    elif a.csv:
        df, origen = pd.read_csv(a.csv), 'csv ' + os.path.basename(a.csv)
    else:
        df, origen = dataset_sintetico(a.demo), 'SINTETICO %d filas (solo prueba del camino)' % a.demo
        log(origen)

    try:
        pipe, X, parametros, metricas, hiper = entrenar(df, a.folds)
    except SystemExit as e:
        log(str(e))
        informar(api, MODELO_API, dataset_id, None, inicio, None, origen, None, a.sin_informar, error=e)
        return 1

    ruta_json = os.path.join(salida, 'rul-%s.json' % marca)
    with open(ruta_json, 'w', encoding='utf-8') as f:
        json.dump({'parametros': parametros, 'metricas': metricas, 'hiperparametros': hiper, 'origen': origen}, f, indent=2)
    ruta_onnx = exportar_onnx(pipe, X, lambda Xv: log_mediana_con_pesos(parametros, Xv),
                              os.path.join(salida, 'rul-%s.onnx' % marca), salida_indice=0, tolerancia=1e-3)
    hash_onnx, bytes_onnx = sha256(ruta_onnx) if ruta_onnx else (None, None)

    entorno, ruta_modelo, registro = ('local · sin MLflow', None, None)
    if not a.sin_azure:
        e, r, g = registrar_mlflow(MODELO, parametros, metricas, hiper, [ruta_json, ruta_onnx],
                                   {'sigma_modelo': 'SIGMA RUL', 'dataset': origen, 'onnx_sha256': hash_onnx or ''})
        if e:
            entorno, ruta_modelo, registro = e, r, g

    informar(api, MODELO_API, dataset_id, entorno, inicio, metricas, origen, {
        'formato': 'ONNX' if ruta_onnx else 'PICKLE', 'algoritmo': parametros['algoritmo'], 'hiperparametro': hiper,
        'parametro': parametros, 'ruta': ruta_modelo, 'registro': registro, 'hash': hash_onnx, 'bytes': bytes_onnx,
        'mae': round(metricas['mae_dias'], 4) if metricas['mae_dias'] is not None else None,
        'observacion': ('DATASET SINTETICO: no usar para operar. ' if a.demo else '') + 'ONNX ' + (ruta_onnx or 'no generado'),
    }, a.sin_informar)
    return 0


if __name__ == '__main__':
    sys.exit(main())
