# SIGMA · Investigación Azure Machine Learning

**Objetivo:** dejar probado, de punta a punta y **sin costo**, el camino con el
que SIGMA AI va a aprender de verdad — empezando por **SIGMA FAILURE 30 días**
(probabilidad de que un equipo registre una falla en los 30 días siguientes).

**Estado (18-09-2026):** camino completo probado con datos reales de Hamburgo
para el dataset y con un dataset sintético para el entrenamiento (el
historial real tiene 8 fallas: no alcanza para aprender). **Azure ML ya
recibió una corrida y un modelo registrados desde el entrenador con la cuenta
de Bryan** (`SIGMA_FAILURE_30D` v1, experimento `SIGMA_FAILURE_30D`). La
lectura desde la API queda sin configurar: el tenant de grupoexpro no permite
registrar aplicaciones en Entra ID, y sin entidad de servicio un servidor no
tiene cómo identificarse (§4.3).

---

## 1. Por qué así y no de otra forma

| Decisión | Motivo |
|---|---|
| **Entrenar en el computador de quien entrena**, no en Azure | Lo que Azure ML factura es el **cómputo** (instancias, clústeres, jobs serverless, endpoints). Una regresión logística sobre unos miles de filas tarda segundos en cualquier PC. Costo: cero. |
| **Azure ML solo como registro y trazabilidad** (MLflow tracking, registro de modelos, artefactos) | El área de trabajo, el servidor de MLflow y el registro no tienen cargo. Lo único que se guarda son metadatos y el `.onnx` (menos de 1 KB). La cuenta de almacenamiento `sigmacodigocreativo` ya existe para los archivos de SIGMA; unos KB más no mueven la factura. |
| **Puntuar dentro de la API** con los pesos de la versión publicada (`PuntuadorFalla.cs`) | Un endpoint administrado de Azure ML cuesta desde que se despliega, aunque nadie lo llame. Una logística son 15 multiplicaciones y una sigmoide; los pesos viven en `Modelo_Predictivo_Version.mpv_parametro` y el ONNX es el artefacto oficial (hash en `mpv_hash`). El entrenador comprueba que ONNX y pesos den lo mismo antes de registrar. |
| **ONNX como formato** | Es lo que el catálogo `Modelo_Formato` ya declaraba y el estándar portable. Cuando se agregue ONNX Runtime a la API (dos paquetes NuGet, `Microsoft.ML.OnnxRuntime` + `.Managed`), el puntuador de pesos pasa a ser el contraste. |
| **SIGMA FAILURE primero** | Es el único objetivo cuyo label sale de una tabla que ya se llena en operación (`Falla`). RUL necesita retiros de repuestos con motivo; VISION, imágenes etiquetadas. |
| **Sin fuga de información** | Cada fila es (equipo, fecha de corte). Las 15 características se calculan con lo que pasó **antes** del corte y el label con lo que pasó **después**. La función lleva el corte como parámetro para que eso sea verificable leyendo el SQL (`FNC_ML_ACTIVO_HISTORICO_V1`). |

---

## 2. Lo construido (commits «Investigación Azure Machine Learning»)

### Base de datos — `BD/245_SIGMA_AI_FAILURE_30D.sql`
- `Modelo_Predictivo` **SIGMA FAILURE 30D** (objetivo PROBABILIDAD FALLA, horizonte 30 d, alerta ≥ 0,50, crítico ≥ 0,80) y sus **15 características** en `Caracteristica_Modelo`: criticidad, edad, lectura del medidor, fallas 90 d / total / días desde la última, OT cerradas y correctivas 180 d, días desde la última mantención, mediciones 30 d (cantidad, sobre advertencia, cercanía al crítico, tendencia), incidentes de bitácora 30 d, minutos indisponible 90 d.
- `Modelo_Predictivo_Version.mpv_parametro` (nueva columna): los pesos en JSON.
- `FNC_ML_ACTIVO_HISTORICO_V1(@CLIENTE, @CORTE)`: la «vista versionada» del modelo lógico §11, con el corte como parámetro.
- `API_SEL_ML_DATASET_FALLA` (cortes cada N días entre dos fechas; `@HOY=1` = la fila de hoy sin label), `API_INS_ML_DATASET`, `API_INS_ML_ENTRENAMIENTO`, `API_INS_ML_MODELO_VERSION` (borrador), `API_UPD_ML_MODELO_VERSION_PUBLICAR` (retira la anterior), `API_SEL_ML` (@TIPO 1–6), `API_INS_PREDICCION_FALLA` (predicción + características + razones + alerta tipo PREDICCION RIESGO si supera el umbral; una por equipo, versión y día).
- Permiso **ENTRENAR MODELOS** (jefe, planificador, administrador del cliente); `VER PREDICCIONES` pasa a ámbito web y app; menú **SIGMA AI › Experimentos** con la función «Entrenar y publicar».

### API — `Controllers/SigmaAiController.cs` (`/sigma-ai`)
| Método | Ruta | Permiso | Qué hace |
|---|---|---|---|
| GET | `estado` | VER PREDICCIONES | Modelo, versión publicada, contadores, si Azure ML está configurado (sin secretos). |
| GET | `dataset?desde&hasta&paso&formato=json\|csv` | VER PREDICCIONES | Las filas; en CSV para el entrenador. |
| POST | `datasets` | ENTRENAR MODELOS | Arma el dataset y lo registra con filas, positivas y SHA‑256. |
| GET | `datasets` · `entrenamientos` · `versiones` · `predicciones` | VER PREDICCIONES | Listados. |
| POST | `entrenamientos` | ENTRENAR MODELOS | El entrenador informa la corrida (métricas, entorno) y la versión con sus pesos. |
| POST | `versiones/{id}/publicar` | ENTRENAR MODELOS | Publica y retira la anterior. |
| POST | `predecir` | ENTRENAR MODELOS | Puntúa hoy a todos los equipos (o `{activo}`), guarda y devuelve razones. |
| POST | `simular` | VER PREDICCIONES | «¿Qué diría el modelo si…?» con valores a mano, sin guardar. |
| GET | `azure` · `azure/modelos[?nombre]` · `azure/experimentos[?id]` | VER PREDICCIONES | Lo que hay en el área de trabajo (solo lectura). |

- `Utils/PuntuadorFalla.cs`: estandariza, aplica pesos, sigmoide; contribución por característica y una frase en español por cada una de las que más pesan (nunca en afirmativo).
- `Utils/AzureMl.cs`: cliente REST del plano de control y del MLflow del área de trabajo (client credentials). Claves `AzureML.*` en `Web.config`.
- `Utils/ClaveServicio.cs`: la web presenta a la persona en sesión con `X-Api-Key` + `X-Sigma-Usuario` / `X-Sigma-Cliente`; `SigmaAiController.Entrar()` arma con eso la misma identidad que un JWT, solo si la clave es correcta. Acotado a este controller (el `TokenValidationHandler` no se tocó).

### Web — `View/SigmaAI/Experimentos.aspx`
Cuaderno de laboratorio en cinco pasos con el estado real del plan, KPIs, muestra del dataset, registro, comando del entrenador, corridas, versiones (publicar), puntuar y consulta a Azure ML. Todo pasa por la API vía `Services` (nuevo `GetJsonLibre` para respuestas que son arreglos; `Preparar()` agrega los encabezados de la persona).

### Entrenador — `ML/entrenar_falla.py`
Entra a la API, baja el dataset registrado (o `--csv`, o `--demo N` sintético), entrena `StandardScaler + LogisticRegression(class_weight=balanced)`, valida con K‑fold estratificado (AUC, precisión, recall, F1 fuera de muestra), exporta pesos JSON y ONNX, **comprueba ONNX = pesos** (aborta si difieren), registra en MLflow/Azure ML si hay `MLFLOW_TRACKING_URI`, e informa a la API.

---

## 3. Lo probado (18-09-2026, cliente Hamburgo, usuario rodrigo)

| Paso | Resultado |
|---|---|
| Dataset real | 12 filas (2 equipos con puesta en marcha anterior a agosto × 6 cortes semanales), **0 positivas**: las 8 fallas son del 14‑09 y ningún corte observable las alcanza. Registrado como `FALLA30-20260918-0120`. |
| Fila de hoy | 22 equipos con sus 15 características (p. ej. Revolvedora 1: 13 mediciones, 10 sobre advertencia, 107 % del crítico, tendencia +10 %/día). |
| Entrenamiento | `--demo 800 --sin-azure`: 279 positivas, AUC 0,763 · P 0,564 · R 0,667 · F1 0,611 (5‑fold). ONNX 756 bytes; **diferencia ONNX vs pesos 1,1e‑7**. Corrida 1 y versión v1 en borrador vía API. |
| Publicar | v1 PUBLICADO. |
| Puntuar | 22 equipos: ACT‑40 99,8 % (crítica, alerta #81), ACT‑35 77,7 %, ACT‑37 73,1 %, ACT‑34 66,0 % (alta) … con sus razones. |
| Simular | `{FALLAS_90D:3, MED_30D_RATIO_CRITICO:1.2, TENDENCIA_30D:0.05}` → 99,05 %. |
| Pantalla | KPIs, plan, muestra, registro, corridas, versiones, puntuar y «Azure ML no está configurado: faltan ClientId, ClientSecret». Capturas en `Fase 2/Pruebas/capturas/AzureML/`. |
| **Azure ML real** | `az login` por código de dispositivo con la cuenta de Bryan; `--demo 800` con `MLFLOW_TRACKING_URI` del área: corrida `319576fc-5bc5-4422-b5cc-ca9f799c8bcf` en el experimento `SIGMA_FAILURE_30D` (métricas, parámetros, `.onnx` y JSON como artefactos) y modelo **SIGMA_FAILURE_30D v1** (`az ml model show`: tipo `mlflow_model`, ruta en `workspaceartifactstore`). `az ml compute list` vacío: no se creó cómputo. Versión v2 en SIGMA con la ruta `azureml://…/models/SIGMA_FAILURE_30D/versions/1`, publicada; 22 equipos puntuados con v2. |

> La versión v1 publicada viene de un **dataset sintético** y está marcada así en `mpv_observacion`. Sirve para que el camino esté vivo, **no para decidir sobre una máquina**. El modelo de línea base (Tendencia de variable medida) sigue operando en paralelo.

---

## 4. Guía para Bryan: dejarlo funcionando con Azure

### 4.1 En tu computador (una vez)
```bash
cd C:\Capstone\SIGMA\ML
pip install -r requirements.txt
```
Instala también la **CLI de Azure** (gratis). En este equipo no hay `winget`, así que se instaló con pip en un entorno aislado (`python -m venv C:\Capstone\_scratchzcli` + `pip install azure-cli`; el ejecutable es `…zcli\Scriptsz.bat`). Entra con tu cuenta; si el navegador no se abre solo, por código:
```bash
az login --use-device-code --tenant e3430037-16f9-4613-8257-37c436e01a82
```
(abre https://login.microsoft.com/device y escribe el código que imprime). Con eso el entrenador se identifica ante Azure ML **con tu propia cuenta** (la misma con que creaste SIGMA_AI). **No hace falta ningún client id ni secret para entrenar y registrar.** La sesión queda guardada en `%USERPROFILE%\.azure`.

> `mlflow` debe ser **2.x** (`mlflow<3`, ya fijado en `requirements.txt`): `azureml-mlflow` 1.60 no sube artefactos con mlflow 3 (`azureml_artifacts_builder() got an unexpected keyword argument 'tracking_uri'`).

### 4.2 Entrenar y registrar en SIGMA_AI
```bash
set SIGMA_API=http://localhost/SIGMA/Servicio/API
set MLFLOW_TRACKING_URI=azureml://eastus2.api.azureml.ms/mlflow/v1.0/subscriptions/af092419-a7e8-453a-b29a-8ef889109f66/resourceGroups/SIGMA/providers/Microsoft.MachineLearningServices/workspaces/SIGMA_AI
python entrenar_falla.py --usuario rodrigo.quezada@hamburgo.cl --demo 800
```
Después, en **Studio › Trabajos (jobs)** aparece el experimento `SIGMA_FAILURE_30D` con su corrida (métricas y parámetros) y en **Modelos** el modelo `SIGMA_FAILURE_30D` con el `.onnx` y el JSON de pesos. Nada de esto crea cómputo. Con un dataset real: `--dataset <id>` (el id sale de la tarjeta 1 de Experimentos).

Luego en la web: **SIGMA AI › Experimentos › 3 Versiones › Publicar** y **4 Puntuar**.

### 4.3 Que la API lea Azure ML (opcional)
La API es un servidor: no puede hacer `az login`. Para que la tarjeta 5 lea el área de trabajo hace falta una **entidad de servicio**, que es gratis (Entra ID, no depende del plan de la suscripción):

1. Portal › **Microsoft Entra ID › Registros de aplicaciones › Nuevo registro** → nombre `sigma-api-ml`, cuenta de este directorio → **Registrar**. Anota *Id. de aplicación (cliente)*.
2. **Certificados y secretos › Nuevo secreto de cliente** → copia el **valor** (solo se ve una vez).
3. Portal › área de trabajo **SIGMA_AI › Control de acceso (IAM) › Agregar › Agregar asignación de roles › AzureML Data Scientist** → Miembros: *Usuario, grupo o entidad de servicio* → busca `sigma-api-ml` → Revisar y asignar.
4. En `Solucion/SIGMA/API/Web.config`: `AzureML.ClientId` = id de aplicación, `AzureML.ClientSecret` = el valor del secreto. Tenant, suscripción, grupo, área y región ya están puestos. **Nunca por chat ni correo.**

**Es el caso hoy (18-09-2026):** el tenant de grupoexpro no deja entrar a Entra ID ni registrar aplicaciones. La investigación no se detiene: la API puntúa sin Azure, y Azure se usa desde el entrenador con tu cuenta. La tarjeta 5 seguirá diciendo «no configurado», que es la verdad. Cuando SIGMA tenga tenant propio (o el administrador de grupoexpro cree la entidad de servicio), son los cuatro pasos de arriba y dos claves en `Web.config`.

### 4.4 Lo que NO hay que crear (porque cuesta)
Instancias de proceso (Compute instances), clústeres, jobs serverless, endpoints en línea o por lotes, y los «Ejemplos de cuadernos» del inicio de Studio (todos piden una instancia). El área de trabajo Basic, el registro, MLflow y el Key Vault que creó por defecto no tienen cargo por uso.

---

## 4.5 Azure ML entrega el modelo sin entidad de servicio (bloque 246)

El registro de modelos guarda los artefactos en la cuenta de almacenamiento del área
de trabajo (`sigmacodigocreativo`, contenedor `azureml`, ruta
`ExperimentRun/dcid.<corrida>/modelo/`), la misma a la que la API ya accede con el
SAS del módulo de archivos. Por ahí la API:

- `GET /sigma-ai/versiones/{id}/artefactos`: lista los archivos del modelo registrado,
  baja el `.onnx`, compara su SHA‑256 con el que informó el entrenador
  (`mpv_hash`) y compara los pesos del JSON con `mpv_parametro`; si coincide deja
  `mpv_fecha_verificacion_utc`.
- `POST /sigma-ai/versiones/{id}/sincronizar`: toma los pesos desde el artefacto de
  Azure (solo con hash coincidente). Con eso la fuente de los pesos es Azure ML, no
  lo que pegó el entrenador.
- `mpv_registro` = `SIGMA_FAILURE_30D:<versión>` del registro; `mpv_ruta` = ruta del
  artefacto en el datastore (lo que `az ml model show` devuelve como `path`); el
  entrenador ya manda las dos.

Probado el 18‑09: v2 (`SIGMA_FAILURE_30D:1`, corrida `319576fc…`) y v3
(`SIGMA_FAILURE_30D:2`, corrida `092b2045…`): hash del `.onnx` en Azure = hash del
entrenador, pesos iguales, sincronización OK, puntuación con los pesos de Azure.
`Web.config`: `AzureML.ContenedorArtefactos=azureml` (otro datastore se declara como
`AzureML.Contenedor.<datastore>`).

**Lo que NO se hace:** puntos de conexión en tiempo real. El panel «Implementar» de
Studio propone 3 instancias Standard_D2as_v4 a 0,10 USD/h cada una (~216 USD/mes)
cobradas desde que existen, aunque nadie las llame.

## 4.6 Los tres modelos por el mismo camino (bloques 247 y 248)

Todo endpoint de `/sigma-ai/*` recibe `?modelo=FALLA|RUL|VISION` y la pantalla
Experimentos tiene un selector; el resto (dataset → registro → entrenamiento →
versión → publicar → puntuar → artefacto en Azure) es el mismo.

| | SIGMA FAILURE 30D | SIGMA RUL | SIGMA VISION |
|---|---|---|---|
| Sujeto | equipo × corte | **instalación de repuesto** × corte | imagen |
| Función / SP | `FNC_ML_ACTIVO_HISTORICO_V1` · `API_SEL_ML_DATASET_FALLA` | `FNC_ML_COMPONENTE_HISTORICO_V1` (reusa la del equipo al mismo corte) · `API_SEL_ML_DATASET_RUL` | `API_SEL_ML_DATASET_VISION` (solo etiquetas **confirmadas por una persona**) |
| Label | `FALLO_EN_30D` | `DIAS_RESTANTES` (+ `HORAS_RESTANTES`) y **`CENSURADO`** | `ETIQUETA` |
| Entrenador | `entrenar_falla.py` · logística | `entrenar_rul.py` · **AFT log-normal con censura** (scipy): los retiros preventivos entran como «duró al menos» | `entrenar_vision.py` · **Azure Custom Vision F0** (claves, sin Entra ID), exporta ONNX |
| Puntuador en la API | `PuntuadorFalla` → probabilidad | `PuntuadorRul` → mediana de días, intervalo 80 %, fecha | Custom Vision predice; la API guarda (`API_INS_ANALISIS_VISUAL`) |
| Sale a | `Prediccion` + alerta ≥ 0,5 | `Prediccion` (`pre_dia_restante`, intervalos, `pre_componente_repuesto_instalacion`) + alerta ≤ 30 días | `Analisis_Visual_Revision/Deteccion` **sin confirmar**; `API_UPD_ANALISIS_VISUAL_CONFIRMAR` alimenta el próximo dataset |
| Umbrales | probabilidad 0,50 / 0,80 | fracción del horizonte (90 d): 30 / 7 días (`CK_MPR_UMBRAL` obliga 0–1) | probabilidad 0,60 / 0,85 |
| Probado 18-09 | real 12 filas / demo 800: AUC 0,763 | real 39 filas (26 observadas) / demo 600: MAE 90 d, error mediano 25 d, cobertura 77 %; `SIGMA_RUL:1` en Azure; instalación vigente → 54 días (5–587) | recurso `SIGMAVISIONMODEL` (Training + Prediction, F0) y proyecto SIGMA VISION (General compact); `--demo 36`: 36 imágenes sintéticas subidas, entrenadas (P/R 1,0 en sintético), iteración `sigma-vision` publicada, ONNX 5 MB exportado y registrado como `SIGMA_VISION:1` en Azure ML, hash verificado por la API; v1 publicada; fotos reales clasificadas (`pieza.png` → CORROSION 75 %), una corregida a NORMAL por Rodrigo y convertida en la primera fila del dataset real |

`sigma_ml.py` concentra lo común (sesión, dataset registrado, ONNX contrastado, MLflow/Azure ML, informe a la API).

**Custom Vision (lo que crea Bryan, una vez):** portal › Crear un recurso › **Custom Vision** (no *Computer Vision*; enlace directo `portal.azure.com/#create/Microsoft.CognitiveServicesCustomVision`), opciones de creación **Ambos**, F0 en los dos, grupo SIGMA, East US; customvision.ai › New Project «SIGMA VISION», Classification, Multiclass, **General (compact)** (lo que permite exportar a ONNX). Claves de predicción en `Web.config` (`CustomVision.PredictionEndpoint/PredictionKey/ProjectId`, `IterationName=sigma-vision`); las de entrenamiento en el entorno (`CV_TRAINING_ENDPOINT`, `CV_TRAINING_KEY`, `CV_PROJECT_ID`, `CV_PREDICTION_RESOURCE_ID` para publicar). El recurso `SIGMAVISION` (Computer Vision F0) que también existe es el genérico: sirve para OCR de placas, no para SIGMA VISION. Las claves de ambos recursos aparecieron en el chat durante la configuración: **regenerarlas** (Key1 y Key2) y volver a pegar la nueva en `Web.config` / `ML/.env`. `ML/.env` (ignorado por git) es donde viven las claves de entrenamiento; `ML/.env.ejemplo` documenta el formato. Cuota F0 de predicción: 10.000/mes y 2 llamadas/segundo.

## 4.7 Producción: dónde corre Python

Python solo se necesita para **reentrenar**; la puntuación vive en la API. Opciones sin costo real, todas con identidad administrada (sin Entra ID): **Azure Container Apps Jobs** (grant mensual permanente 180.000 vCPU-s + 360.000 GiB-s; un reentrenamiento gasta ~120 vCPU-s), **Azure Functions** Python con timer (1 M ejecuciones/mes), o GitHub Actions (sin identidad hacia Azure ML hasta tener tenant propio). La imagen del entrenador va en **GitHub Container Registry**, no en Azure Container Registry (Basic ~5 USD/mes; el Standard «gratis» vence a los 12 meses). El job llama `GET /sigma-ai/dataset` → entrena → registra → `POST /sigma-ai/entrenamientos`; publicar sigue siendo humano.

**Lo que no se crea porque cobra:** puntos de conexión en tiempo real (Studio propone 3 × Standard_D2as_v4 ≈ 216 USD/mes), instancias/clústeres de cómputo, Container Registry, VMs.

## 5. Lo que falta para que sea SIGMA AI de verdad

1. **Historial**: con 8 fallas no hay nada que aprender. El dataset crece solo con la operación (fallas, OT, mediciones); el corte semanal ya genera una fila por equipo y semana.
2. **ONNX Runtime en la API** (dos NuGet) para puntuar el artefacto oficial; el puntuador de pesos queda como contraste.
3. **Monitoreo**: `Prediccion_Resultado` (¿ocurrió?) y `Modelo_Monitoreo` para medir la versión publicada contra lo que pasó; hoy las tablas existen y nadie las llena.
4. **SIGMA RUL** necesita ~30 retiros observados por par repuesto/componente; **SIGMA VISION** necesita ≥ 5 imágenes confirmadas por etiqueta (mínimo de Custom Vision) y el recurso Custom Vision F0 creado.
5. Un job programado (`predecir` una vez al día) cuando haya una versión que valga la pena operar.
