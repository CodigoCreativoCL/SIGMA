# -*- coding: utf-8 -*-
"""
SIGMA AI · SIGMA VISION · el entrenador.                           (bloque 248)

QUE HACE, EN ORDEN
  1. Entra a la API de SIGMA y baja el dataset de imagenes con etiqueta
     confirmada por una persona (GET /sigma-ai/dataset?modelo=VISION), o
     fabrica imagenes sinteticas etiquetadas (--demo) para probar el camino.
  2. Baja cada imagen por la API (/archivo/ver) y la sube al proyecto de
     Azure Custom Vision con su etiqueta (crea las etiquetas que falten).
  3. Entrena (nivel F0: 1 hora de entrenamiento al mes, 5.000 imagenes por
     proyecto, minimo 5 imagenes por etiqueta y 2 etiquetas), espera, lee la
     precision / recall / AP de la iteracion y la publica con el nombre que
     la API espera (CustomVision.IterationName, por omision `sigma-vision`).
  4. Exporta la iteracion a ONNX (dominio "compact"), la baja, calcula su
     SHA-256 y la registra en Azure ML como los otros dos modelos (mlflow).
  5. Informa a la API (POST /sigma-ai/entrenamientos?modelo=VISION): la
     corrida, las metricas y la version. Los "pesos" aqui son descriptivos
     (etiquetas, iteracion, proyecto): quien predice es Custom Vision.

CLAVES
  Las de ENTRENAMIENTO van por variables de entorno, nunca en la API:
    CV_TRAINING_ENDPOINT   https://<recurso>.cognitiveservices.azure.com/
    CV_TRAINING_KEY        clave 1 del recurso de entrenamiento
    CV_PROJECT_ID          id del proyecto (customvision.ai > engranaje)

COMO SE CORRE
  python entrenar_vision.py --usuario <login> --dataset <id>
  python entrenar_vision.py --usuario <login> --demo 60 --sin-azure
  python entrenar_vision.py --usuario <login> --demo 60 --solo-preparar   (sin Custom Vision: solo arma y muestra el dataset)
"""
import argparse
import getpass
import io
import json
import os
import sys
import time

import numpy as np
import requests

from sigma_ml import Api, informar, log, registrar_mlflow, sha256

MODELO = 'SIGMA_VISION'
MODELO_API = 'VISION'
ETIQUETAS = ['NORMAL', 'CORROSION', 'FUGA', 'DESGASTE', 'ROTURA', 'SUCIEDAD']


# ---------------------------------------------------------------------------
# CUSTOM VISION (REST v3.3, sin SDK: tres llamadas y un bucle de espera)
# ---------------------------------------------------------------------------
class CustomVision:
    def __init__(self):
        self.base = os.environ.get('CV_TRAINING_ENDPOINT', '').rstrip('/')
        self.key = os.environ.get('CV_TRAINING_KEY', '')
        self.project = os.environ.get('CV_PROJECT_ID', '')
        if not (self.base and self.key and self.project):
            raise SystemExit('Faltan CV_TRAINING_ENDPOINT, CV_TRAINING_KEY o CV_PROJECT_ID en el entorno.')
        self.h = {'Training-Key': self.key}
        self.url = self.base + '/customvision/v3.3/training/projects/' + self.project

    def _r(self, metodo, ruta, **kw):
        r = requests.request(metodo, self.url + ruta, headers=self.h, timeout=300, **kw)
        if r.status_code >= 300:
            raise SystemExit('Custom Vision %s %s -> %s: %s' % (metodo, ruta, r.status_code, r.text[:400]))
        return r.json() if r.content and 'json' in r.headers.get('Content-Type', '') else r

    def etiquetas(self):
        return {t['name'].upper(): t['id'] for t in self._r('GET', '/tags')}

    def etiqueta(self, nombre, existentes):
        if nombre.upper() in existentes:
            return existentes[nombre.upper()]
        t = self._r('POST', '/tags', params={'name': nombre.upper()})
        existentes[nombre.upper()] = t['id']
        log('etiqueta creada en Custom Vision: %s' % nombre.upper())
        return t['id']

    def subir(self, imagen, tag_id):
        r = self._r('POST', '/images', params={'tagIds': tag_id}, data=imagen, headers={**self.h, 'Content-Type': 'application/octet-stream'})
        ok = r.get('isBatchSuccessful') and all(i.get('status') in ('OK', 'OKDuplicate') for i in r.get('images', []))
        return ok, [i.get('status') for i in r.get('images', [])]

    def entrenar(self):
        it = self._r('POST', '/train', params={'forceTrain': 'true'})
        iid = it['id']
        log('entrenando iteracion %s (%s)…' % (it.get('name'), iid))
        while True:
            time.sleep(15)
            it = self._r('GET', '/iterations/' + iid)
            if it['status'] in ('Completed', 'Failed'):
                break
            log('  estado: %s' % it['status'])
        if it['status'] != 'Completed':
            raise SystemExit('El entrenamiento termino en %s' % it['status'])
        return it

    def desempeno(self, iid):
        p = self._r('GET', '/iterations/%s/performance' % iid, params={'threshold': 0.5})
        return {'precision': p.get('precision'), 'recall': p.get('recall'), 'ap': p.get('averagePrecision'),
                'por_etiqueta': [{'etiqueta': t['name'], 'precision': t.get('precision'), 'recall': t.get('recall'), 'ap': t.get('averagePrecision')}
                                 for t in p.get('perTagPerformance', [])]}

    def publicar(self, iid, nombre, prediction_resource_id):
        # desprograma otra iteracion con el mismo nombre (F0 permite pocas publicadas)
        for it in self._r('GET', '/iterations'):
            if it.get('publishName') == nombre and it['id'] != iid:
                self._r('DELETE', '/iterations/%s/publish' % it['id'])
        self._r('POST', '/iterations/%s/publish' % iid, params={'publishName': nombre, 'predictionId': prediction_resource_id})
        log('iteracion publicada como "%s"' % nombre)

    def exportar_onnx(self, iid, destino):
        try:
            self._r('POST', '/iterations/%s/export' % iid, params={'platform': 'ONNX', 'flavor': 'ONNX16'})
        except SystemExit as e:
            if 'already' not in str(e).lower() and 'exists' not in str(e).lower():
                raise
        for _ in range(40):
            time.sleep(10)
            for ex in self._r('GET', '/iterations/%s/export' % iid):
                if ex.get('platform', '').upper() == 'ONNX' and ex.get('status') == 'Done' and ex.get('downloadUri'):
                    z = requests.get(ex['downloadUri'], timeout=300).content
                    import zipfile
                    with zipfile.ZipFile(io.BytesIO(z)) as zf:
                        nombre = next((n for n in zf.namelist() if n.lower().endswith('.onnx')), None)
                        if not nombre:
                            raise SystemExit('El zip exportado no trae un .onnx')
                        with open(destino, 'wb') as f:
                            f.write(zf.read(nombre))
                    log('ONNX exportado: %s (%d bytes)' % (destino, os.path.getsize(destino)))
                    return destino
                if ex.get('status') == 'Failed':
                    raise SystemExit('La exportacion a ONNX fallo: el dominio del proyecto debe ser "compact".')
            log('  esperando la exportacion…')
        raise SystemExit('La exportacion a ONNX no termino a tiempo.')


# ---------------------------------------------------------------------------
# IMAGENES SINTETICAS ETIQUETADAS (solo para probar el camino)
# ---------------------------------------------------------------------------
def imagenes_sinteticas(n, semilla=5):
    """Texturas de color por etiqueta (256x256 PNG): NORMAL gris uniforme,
    CORROSION manchas ocres, FUGA charco oscuro, DESGASTE rayas, ROTURA una
    grieta negra, SUCIEDAD ruido pardo. No se parecen a una maquina; sirven
    para que Custom Vision tenga algo que separar."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        raise SystemExit('pip install pillow para las imagenes sinteticas.')
    rng = np.random.default_rng(semilla)
    salida = []
    for i in range(n):
        et = ETIQUETAS[i % len(ETIQUETAS)]
        base = rng.integers(120, 170)
        img = Image.new('RGB', (256, 256), (base, base, base + 5))
        d = ImageDraw.Draw(img)
        if et == 'CORROSION':
            for _ in range(rng.integers(8, 20)):
                x, y, r = rng.integers(0, 256), rng.integers(0, 256), rng.integers(8, 40)
                d.ellipse([x - r, y - r, x + r, y + r], fill=(int(rng.integers(120, 190)), int(rng.integers(50, 90)), int(rng.integers(10, 40))))
        elif et == 'FUGA':
            x, y = rng.integers(60, 200), rng.integers(120, 230)
            d.ellipse([x - 70, y - 25, x + 70, y + 25], fill=(30, 25, 20))
        elif et == 'DESGASTE':
            for k in range(0, 256, int(rng.integers(6, 14))):
                d.line([(k, 0), (k + int(rng.integers(-20, 20)), 256)], fill=(base - 40, base - 40, base - 40), width=2)
        elif et == 'ROTURA':
            pts = [(int(rng.integers(0, 60)), int(rng.integers(0, 256)))]
            for _ in range(8):
                pts.append((pts[-1][0] + int(rng.integers(15, 35)), pts[-1][1] + int(rng.integers(-40, 40))))
            d.line(pts, fill=(10, 10, 10), width=int(rng.integers(3, 7)))
        elif et == 'SUCIEDAD':
            px = np.array(img).astype(int)
            px += rng.integers(-60, 20, px.shape)
            px[..., 2] -= 30
            img = Image.fromarray(np.clip(px, 0, 255).astype('uint8'))
        b = io.BytesIO()
        img.save(b, format='PNG')
        salida.append({'nombre': 'sintetica-%03d-%s.png' % (i, et.lower()), 'etiqueta': et, 'bytes': b.getvalue()})
    return salida


def main():
    ap = argparse.ArgumentParser(description='Entrena SIGMA VISION en Azure Custom Vision y lo informa a la API.')
    ap.add_argument('--api', default=os.environ.get('SIGMA_API', 'http://localhost/SIGMA/Servicio/API'))
    ap.add_argument('--usuario', required=True)
    ap.add_argument('--clave', default=os.environ.get('SIGMA_CLAVE'))
    ap.add_argument('--dataset', type=int)
    ap.add_argument('--demo', type=int, metavar='N', help='N imagenes sinteticas (multiplo de 6; minimo 30)')
    ap.add_argument('--iteracion', default=os.environ.get('CV_ITERATION_NAME', 'sigma-vision'))
    ap.add_argument('--prediction-resource-id', default=os.environ.get('CV_PREDICTION_RESOURCE_ID'),
                    help='/subscriptions/.../providers/Microsoft.CognitiveServices/accounts/<recurso-Prediction> (para publicar)')
    ap.add_argument('--sin-azure', action='store_true', help='no registrar en Azure ML')
    ap.add_argument('--sin-informar', action='store_true')
    ap.add_argument('--solo-preparar', action='store_true', help='arma el dataset y no toca Custom Vision')
    a = ap.parse_args()
    if not (a.dataset or a.demo):
        ap.error('indique --dataset ID o --demo N')

    api = Api(a.api, a.usuario, a.clave or getpass.getpass('Contrasena de %s: ' % a.usuario))
    inicio = time.time()
    salida = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'salida')
    os.makedirs(salida, exist_ok=True)
    marca = time.strftime('%Y%m%d-%H%M%S')

    # ---- 1. el dataset
    dataset_id, origen, imagenes = None, '', []
    if a.dataset:
        df, d = api.dataset_registrado(a.dataset, MODELO_API)
        dataset_id, origen = d['den_id'], d['den_codigo']
        for _, fila in df.iterrows():
            r = api.get('/archivo/ver', params={'ruta': fila['RUTA']})
            imagenes.append({'nombre': fila['NOMBRE'], 'etiqueta': str(fila['ETIQUETA']).upper(), 'bytes': r.content, 'archivo': int(fila['ARCHIVO'])})
        log('%d imagenes bajadas por la API' % len(imagenes))
    else:
        n = max(30, a.demo)
        imagenes = imagenes_sinteticas(n)
        origen = 'SINTETICO %d imagenes (solo prueba del camino)' % n
        log(origen)

    conteo = {}
    for im in imagenes:
        conteo[im['etiqueta']] = conteo.get(im['etiqueta'], 0) + 1
    log('por etiqueta: %s' % conteo)
    pocas = [e for e, c in conteo.items() if c < 5]
    if len(conteo) < 2 or pocas:
        msg = 'Custom Vision exige al menos 2 etiquetas con 5 imagenes cada una; faltan en %s.' % (pocas or 'etiquetas')
        log(msg)
        informar(api, MODELO_API, dataset_id, None, inicio, None, origen, None, a.sin_informar, error=msg)
        return 1
    if a.solo_preparar:
        log('--solo-preparar: dataset listo, no se toca Custom Vision.')
        return 0

    # ---- 2. subir y entrenar
    cv = CustomVision()
    tags = cv.etiquetas()
    subidas, fallidas = 0, 0
    for im in imagenes:
        ok, estados = cv.subir(im['bytes'], cv.etiqueta(im['etiqueta'], tags))
        subidas += 1 if ok else 0
        fallidas += 0 if ok else 1
    log('subidas %d · fallidas %d' % (subidas, fallidas))

    try:
        it = cv.entrenar()
    except SystemExit as e:
        log(str(e))
        informar(api, MODELO_API, dataset_id, 'custom vision', inicio, None, origen, None, a.sin_informar, error=e)
        return 1

    metricas = cv.desempeno(it['id'])
    metricas.update({'imagenes': len(imagenes), 'etiquetas': len(conteo), 'iteracion': it['id'], 'entrenado_utc': it.get('trainedAt')})
    log('desempeno (umbral 0,5): precision %.3f · recall %.3f · AP %.3f' % (metricas['precision'] or 0, metricas['recall'] or 0, metricas['ap'] or 0))

    if a.prediction_resource_id:
        cv.publicar(it['id'], a.iteracion, a.prediction_resource_id)
    else:
        log('AVISO: sin --prediction-resource-id no se publica la iteracion; publiquela en customvision.ai como "%s".' % a.iteracion)

    # ---- 3. ONNX y registro en Azure ML
    ruta_onnx = None
    try:
        ruta_onnx = cv.exportar_onnx(it['id'], os.path.join(salida, 'vision-%s.onnx' % marca))
    except SystemExit as e:
        log(str(e))
    hash_onnx, bytes_onnx = sha256(ruta_onnx) if ruta_onnx else (None, None)

    parametros = {'algoritmo': 'Azure Custom Vision, clasificacion multiclase, dominio General (compact)',
                  'etiquetas': sorted(conteo.keys()), 'proyecto': cv.project, 'iteracion': it['id'], 'publicada_como': a.iteracion,
                  'caracteristicas': sorted(conteo.keys()), 'coeficientes': [], 'intercepto': 0}
    ruta_json = os.path.join(salida, 'vision-%s.json' % marca)
    with open(ruta_json, 'w', encoding='utf-8') as f:
        json.dump({'parametros': parametros, 'metricas': metricas, 'origen': origen}, f, indent=2)

    entorno, ruta_modelo, registro = ('custom vision · iteracion ' + it['id'], None, None)
    if not a.sin_azure:
        e, r, g = registrar_mlflow(MODELO, parametros, {k: v for k, v in metricas.items() if isinstance(v, (int, float))},
                                   {'dominio': 'General (compact)', 'umbral': 0.5}, [ruta_json, ruta_onnx],
                                   {'sigma_modelo': 'SIGMA VISION', 'dataset': origen, 'onnx_sha256': hash_onnx or '', 'custom_vision_iteracion': it['id']})
        if e:
            entorno, ruta_modelo, registro = entorno + ' · ' + e, r, g

    informar(api, MODELO_API, dataset_id, entorno, inicio, metricas, origen, {
        'formato': 'ONNX' if ruta_onnx else 'PICKLE', 'algoritmo': parametros['algoritmo'],
        'hiperparametro': {'dominio': 'General (compact)', 'umbral': 0.5}, 'parametro': parametros,
        'ruta': ruta_modelo, 'registro': registro, 'hash': hash_onnx, 'bytes': bytes_onnx,
        'precision': metricas['precision'], 'recall': metricas['recall'],
        'observacion': ('DATASET SINTETICO: no usar para operar. ' if a.demo else '') + 'Custom Vision iteracion ' + it['id'],
    }, a.sin_informar)
    return 0


if __name__ == '__main__':
    sys.exit(main())
