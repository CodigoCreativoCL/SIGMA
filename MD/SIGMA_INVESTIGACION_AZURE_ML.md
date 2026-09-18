# SIGMA · Investigación Azure Machine Learning

**Objetivo:** dejar probado, de punta a punta y **sin costo**, el camino con el
que SIGMA AI va a aprender de verdad — empezando por **SIGMA FAILURE 30 días**
(probabilidad de que un equipo registre una falla en los 30 días siguientes).

**Estado (18-09-2026):** camino completo probado con datos reales de Hamburgo
para el dataset y con un dataset sintético para el entrenamiento (el
historial real tiene 8 fallas: no alcanza para aprender). Azure ML queda
conectado desde el entrenador (cuenta de Bryan) y opcional desde la API
(entidad de servicio, ver §5).

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

> La versión v1 publicada viene de un **dataset sintético** y está marcada así en `mpv_observacion`. Sirve para que el camino esté vivo, **no para decidir sobre una máquina**. El modelo de línea base (Tendencia de variable medida) sigue operando en paralelo.

---

## 4. Guía para Bryan: dejarlo funcionando con Azure

### 4.1 En tu computador (una vez)
```bash
cd C:\Capstone\SIGMA\ML
pip install -r requirements.txt
```
Instala también la **CLI de Azure** (gratis, `winget install Microsoft.AzureCLI`) y entra con tu cuenta:
```bash
az login
```
Con eso el entrenador se identifica ante Azure ML **con tu propia cuenta** (la misma con que creaste SIGMA_AI). **No hace falta ningún client id ni secret para entrenar y registrar.**

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

Si el tenant de grupoexpro no te deja registrar aplicaciones («no tiene permiso»), la investigación no se detiene: la API puntúa sin Azure, y Azure se usa desde el entrenador con tu cuenta. La tarjeta 5 seguirá diciendo «no configurado», que es la verdad.

### 4.4 Lo que NO hay que crear (porque cuesta)
Instancias de proceso (Compute instances), clústeres, jobs serverless, endpoints en línea o por lotes, y los «Ejemplos de cuadernos» del inicio de Studio (todos piden una instancia). El área de trabajo Basic, el registro, MLflow y el Key Vault que creó por defecto no tienen cargo por uso.

---

## 5. Lo que falta para que sea SIGMA AI de verdad

1. **Historial**: con 8 fallas no hay nada que aprender. El dataset crece solo con la operación (fallas, OT, mediciones); el corte semanal ya genera una fila por equipo y semana.
2. **ONNX Runtime en la API** (dos NuGet) para puntuar el artefacto oficial; el puntuador de pesos queda como contraste.
3. **Monitoreo**: `Prediccion_Resultado` (¿ocurrió?) y `Modelo_Monitoreo` para medir la versión publicada contra lo que pasó; hoy las tablas existen y nadie las llena.
4. **SIGMA RUL** (retiros de repuestos censurados) y **SIGMA VISION** (imágenes etiquetadas), cuando existan los datos.
5. Un job programado (`predecir` una vez al día) cuando haya una versión que valga la pena operar.
