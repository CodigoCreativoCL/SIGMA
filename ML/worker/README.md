# SIGMA AI worker (automático, sin botones)
`sigma_worker.py` deja encendido el ciclo completo: **puntúa** FALLA y RUL cada N minutos y **reentrena y publica** cada noche solo si pasa las compuertas. Detalle de diseño: `Boveda/SIGMA AI automatico.md`.

## Variables de entorno (servidor o `ML/.env`, que no se versiona)
| Variable | Defecto | Qué es |
|---|---|---|
| `SIGMA_API` | `http://localhost/SIGMA/Servicio/API` | URL de la API |
| `SIGMA_USUARIO` / `SIGMA_CLAVE` | — | Usuario de servicio (permisos `VER PREDICCIONES` y `ENTRENAR MODELOS`). La clave **nunca** por chat ni al repo |
| `WORKER_PUNTUAR_MIN` | 15 | Cada cuántos minutos recalcula predicciones |
| `WORKER_HORA_ENTRENAR` | 3 | Hora (0–23, del servidor) del reentrenamiento diario |
| `WORKER_MIN_POSITIVAS_FALLA` / `WORKER_MIN_FILAS_RUL` | 10 / 30 | Datos mínimos para entrenar |
| `WORKER_NUEVAS_MIN` | 3 | Casos nuevos desde la vigente para reentrenar |
| `WORKER_MARGEN_AUC` / `WORKER_MARGEN_MAE` | 0.01 / 0.02 | Mejora exigida para publicar |
| `WORKER_AUC_MIN_PRIMERA` | 0.65 | AUC mínimo de una primera versión |
| `WORKER_PUBLICAR_AUTO` | 1 | `0` = deja siempre en BORRADOR |

## Uso
```
python ML/worker/sigma_worker.py              # queda corriendo
python ML/worker/sigma_worker.py --una-vez    # un ciclo y sale (prueba o cron)
python ML/worker/sigma_worker.py --solo-puntuar
python ML/worker/sigma_worker.py --seco       # no publica nada
```
Si pierde la sesión (token vencido) vuelve a entrar solo. Todo queda en el log y en `Entrenamiento_Ejecucion`.

## Pendiente
- Reversión automática si `Modelo_Monitoreo` muestra que la versión publicada rinde peor.
- Crear el usuario de servicio en SIGMA (lo hace quien administra; la clave va directo al servidor).
- Probado: compilación y las compuertas con datos simulados. **No se ha probado contra una API real**.
