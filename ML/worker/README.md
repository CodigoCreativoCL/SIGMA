# SIGMA AI worker (automático, sin botones)
`sigma_worker.py` deja encendido el ciclo completo: **puntúa** FALLA y RUL cada N minutos y **reentrena y publica** solo, **cada vez que se cierra una OT**, si pasa las compuertas. Sin botones: consulta `GET /sigma-ai/senal` (BD 453, `API_SEL_ML_SENAL`) cada 2 min; al ver un cierre nuevo espera 5 min de calma (por si cierran varias seguidas) y reentrena. Detalle de diseño: `Boveda/SIGMA AI automatico.md`.

## Variables de entorno (servidor o `ML/.env`, que no se versiona)
| Variable | Defecto | Qué es |
|---|---|---|
| `SIGMA_API` | `http://localhost/SIGMA/Servicio/API` | URL de la API |
| `SIGMA_USUARIO` / `SIGMA_CLAVE` | — | Usuario de servicio de **una** empresa (permisos `VER PREDICCIONES` y `ENTRENAR MODELOS`). La clave **nunca** por chat ni al repo |
| `SIGMA_USUARIO_1` / `SIGMA_CLAVE_1` … `_20` | — | Una cuenta por **cada empresa con plan SIGMA AI**. Cada sesión queda ligada a su empresa: se puntúa y entrena con sus datos, sin mezclar |
| `WORKER_PUNTUAR_MIN` | 15 | Cada cuántos minutos recalcula predicciones |
| `WORKER_SENAL_MIN` | 2 | Cada cuántos minutos mira si se cerró una OT |
| `WORKER_ESPERA_CIERRE_MIN` | 5 | Calma tras el último cierre antes de reentrenar |
| `WORKER_HORA_ENTRENAR` | 3 | Hora (0–23, del servidor) del **respaldo** diario, por si se perdió alguna señal |
| `WORKER_MIN_POSITIVAS_FALLA` / `WORKER_MIN_FILAS_RUL` | 10 / 30 | Datos mínimos para entrenar |
| `WORKER_NUEVAS_MIN` | 0 | Casos positivos nuevos exigidos desde la vigente (0 = basta un cierre) |
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

## Una cuenta por empresa con plan SIGMA AI
La API puntúa y reentrena con la empresa de la sesión. Por eso se crea **un usuario de servicio por cada empresa que tenga el plan SIGMA AI** (la función `SIGMA AI CHAT` del plan) y se agrega como `SIGMA_USUARIO_n`. Una empresa nueva con el plan = un usuario nuevo + dos variables; sin tocar código. Si una empresa pierde el plan, se desactiva su usuario.
Cuidados al crear cada usuario:
- Su perfil debe **operar en la app** (`POST /sesion` entra con ámbito 2): un perfil solo-web recibe 403.
- Si la suscripción de la empresa no está vigente, el login responde 402 y el worker deja ese error en el log y sigue con las demás.
- Solo los dos permisos de arriba; nada más.

## Requisito de despliegue
El worker llama a `GET /sigma-ai/senal`, que existe solo desde la migración **453** y la API compilada con ese endpoint: hay que aplicarlas en el entorno donde corra (hoy solo en desarrollo).

## Pendiente
- Reversión automática si `Modelo_Monitoreo` muestra que la versión publicada rinde peor.
- Crear el usuario de servicio en SIGMA (lo hace quien administra; la clave va directo al servidor).
- Probado: compilación y las compuertas con datos simulados. **No se ha probado contra una API real**.
