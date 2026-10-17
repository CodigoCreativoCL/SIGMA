# Índice de base de datos (por contexto)

Las migraciones viven en `BD/` con número correlativo (= orden de ejecución). Para saber **qué migración toca un tema**, abrir la nota de su contexto; no listar `BD/`.

| Contexto | Migraciones | Primera | Última |
|---|---|---|---|
| [[App móvil y API]] | 77 | `55_SPLIT_Y_APP.sql` | `436_GALERIA_RUTA_API.sql` |
| [[Seguridad, menús y permisos]] | 104 | `02_MENUS_PERMISOS.sql` | `460_PERFIL_EJECUTIVO_COMERCIAL.sql` |
| [[Suscripción y comercial]] | 11 | `08_SUSCRIPCION.sql` | `467_COBROS_PLAN_MODULOS.sql` |
| [[Alertas e inteligencia (SIGMA AI)]] | 31 | `19_TERCEROS_ALERTAS.sql` | `475_SIGMA_AI_DESEMPENO.sql` |
| [[Planificación y programación]] | 62 | `13_PROGRAMACION.sql` | `429_CALENDARIO_MEDIDOR_EDITABLE.sql` |
| [[Órdenes y operación]] | 59 | `15_CHECKLIST.sql` | `472_JOBS_FRECUENTES_OT_AUTOMATICA.sql` |
| [[Inventario y bodegas]] | 41 | `12_REPUESTOS_INVENTARIO.sql` | `375_BODEGA_AREA_TIPO.sql` |
| [[Activos y componentes]] | 73 | `11_ACTIVOS_MEDICIONES.sql` | `463_COBRO_INTERNACIONAL_MODELO.sql` |
| [[Terceros y clientes]] | 8 | `29_SPRINT1_CLIENTE_PLANTA.sql` | `468_CLIENTE_COBRO_DRAWER.sql` |
| [[Soporte, notificaciones y ayuda]] | 20 | `07_VOZ_INCLUSION.sql` | `445_BITACORA_RECTIFICACION_DEMO.sql` |
| [[Organización, catálogos y cargas]] | 41 | `00_MAESTRO.sql` | `476_CARGA_ARCHIVO_REPETIDO.sql` |
| [[Otros y transversales]] | 25 | `27_SPRINT1_ORGANIZACION.sql` | `474_INDICADORES.sql` |

**Otros directorios de BD/**: `Semillas/` (datos de demo y pruebas), `Respaldos/` (copias y propuestas), `Carga masiva/`, `Reinicio/`.

Reglas: SP-first, idempotentes (`CREATE OR ALTER`), una migración nueva = siguiente número libre. Ver [[Patrones y convenciones]] y [[Base de datos y entornos]].
