# SIGMA AI automático (diseño, 12-10-2026)
Requisito de Bryan: **nadie ejecuta un botón**. Datos entran → se predice → se reentrena → se publica, solo.

## Qué ya es automático (revisado en el repo)
- **Alertas**: `GEN_ALERTA_DETECTAR` tiene freno atómico de 5 min en la base (`Alerta_Deteccion`, BD 85); hoy lo dispara el navegador al consultar `WsAlertas` cada pocos segundos → **depende de que haya un usuario con la web abierta**.
- **Job nocturno**: `JOB_SIGMA_NOCTURNO` (BD 386) genera ocurrencias de planes/tareas/rondas; es idempotente, pero necesita **alguien que lo programe** (Azure SQL no tiene SQL Agent; SQL Express tampoco).
- **Predicción**: la API de .NET puntúa con pesos JSON (`FNC_ML_ACTIVO_HISTORICO_V1`, `API_SEL_ML_DATASET_*`). Entrenar es `ML/entrenar_*.py`; la versión nueva queda en BORRADOR hasta que alguien la publica (**esto es lo manual**).

## Qué falta: un orquestador siempre encendido (servicio Python, `sigma-ai-worker`)
1. **Cada 5 min**: dispara la detección de alertas y el recálculo de predicciones de los activos con datos nuevos (sin navegador abierto).
2. **Cada noche**: `EXEC JOB_SIGMA_NOCTURNO`.
3. **Reentrenamiento automático**: si hay ≥ N casos etiquetados nuevos desde la última versión → corre el entrenador (K-fold) → compara con la versión vigente.
4. **Publicación automática con compuertas** (sin botón): se publica sola solo si (a) supera el mínimo de datos del modelo (RUL ≥ ~30 retiros observados; VISION ≥ 5 imágenes por etiqueta), (b) mejora la métrica de la vigente en un margen, (c) pasa la verificación ONNX = pesos. Si no, queda en borrador y se registra por qué.
5. **Reversión automática**: si `Modelo_Monitoreo` detecta que la versión publicada rinde peor que la anterior, vuelve a la anterior.
6. **Chat**: endpoint que reenvía a un modelo de lenguaje externo (el costo es por uso).

## Seguridad
- El worker entra a la API con un **usuario de servicio** con solo las facultades necesarias; sus credenciales y la clave del modelo van en variables de entorno del servidor, **nunca por chat ni en el repo**.
- Todo queda auditado en `Entrenamiento_Ejecucion` y `Job_Ejecucion`.

## Dónde corre
Servicio liviano (FastAPI + APScheduler) en una instancia Linux pequeña (AWS t3.micro u Oracle Always Free). Los datos son pequeños (decenas de filas hoy): entrenar toma segundos.

Relacionado: [[Rendimiento]], [[Base de datos y entornos]], [[Base de datos/Indice de base de datos]].

## Estado de la implementación (12-10-2026)
- **Reentrenar por cada cierre de OT, sin botón:** BD 453 `API_SEL_ML_SENAL` + `GET /sigma-ai/senal` (cuenta OT cerradas y último cierre). El worker lo consulta cada 2 min; al ver un cierre nuevo espera 5 min de calma y reentrena (compuertas intactas). Al arrancar toma una línea base: no reentrena por lo que ya estaba cerrado. Hay un respaldo diario a las 3:00.
- **Hecho:** `ML/worker/sigma_worker.py` (+ README): puntúa FALLA/RUL cada N min, reentrena de noche con compuertas (datos mínimos, datos nuevos, mejora de AUC/MAE) y publica solo. Reutiliza `sigma_ml.Api` y los entrenadores; la API ya trae `predecir`, `versiones`, `publicar`. Compuertas probadas con datos simulados; **no probado contra una API real**.
- **Recomendaciones (paso 2):** ya existen en la página SIGMA AI: el Copiloto (`WsAiCentro.Copiloto`) responde con **reglas** sobre la cola de predicciones, sus razones (`SEL_AI_DETALLE`) y RUL, y ofrece acciones (Crear OT, Pedir repuesto). No usa modelo de lenguaje: es gratis y auditable. Falta que se generen **solas** (hoy salen al preguntar).
- **Pendiente:** usuario de servicio, reversión automática, recomendaciones proactivas.
