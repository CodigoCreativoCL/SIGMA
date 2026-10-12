# Índice de base de datos (por contexto)

Las migraciones viven en `BD/` con número correlativo (= orden de ejecución). Para saber **qué migración toca un tema**, abrir la nota de su contexto; no listar `BD/`.

| Contexto | Migraciones | Primera | Última |
|---|---|---|---|
| [[App móvil y API]] | 77 | `55_SPLIT_Y_APP.sql` | `436_GALERIA_RUTA_API.sql` |
| [[Seguridad, menús y permisos]] | 102 | `02_MENUS_PERMISOS.sql` | `452_MENU_ACCESIBILIDAD.sql` |
| [[Suscripción y comercial]] | 7 | `08_SUSCRIPCION.sql` | `228_PLAN_COMERCIAL_SIN_PRECIO.sql` |
| [[Alertas e inteligencia (SIGMA AI)]] | 30 | `19_TERCEROS_ALERTAS.sql` | `453_ML_SENAL_CIERRE_OT.sql` |
| [[Planificación y programación]] | 62 | `13_PROGRAMACION.sql` | `429_CALENDARIO_MEDIDOR_EDITABLE.sql` |
| [[Órdenes y operación]] | 58 | `15_CHECKLIST.sql` | `435_ACTIVO_GALERIA_PASOS_REFERENCIAS.sql` |
| [[Inventario y bodegas]] | 41 | `12_REPUESTOS_INVENTARIO.sql` | `375_BODEGA_AREA_TIPO.sql` |
| [[Activos y componentes]] | 72 | `11_ACTIVOS_MEDICIONES.sql` | `444_ACTIVO_BITACORA_RECTIFICACION_WEB.sql` |
| [[Terceros y clientes]] | 7 | `29_SPRINT1_CLIENTE_PLANTA.sql` | `424_ARREGLOS_PRUEBAS_CLIENTE.sql` |
| [[Soporte, notificaciones y ayuda]] | 20 | `07_VOZ_INCLUSION.sql` | `445_BITACORA_RECTIFICACION_DEMO.sql` |
| [[Organización, catálogos y cargas]] | 39 | `00_MAESTRO.sql` | `420_CARGA_LABORAL.sql` |
| [[Otros y transversales]] | 14 | `27_SPRINT1_ORGANIZACION.sql` | `321_HU090_PLANTILLA_NACE_CON_VERSION_1.sql` |

**Otros directorios de BD/**: `Semillas/` (datos de demo y pruebas), `Respaldos/` (copias y propuestas), `Carga masiva/`, `Reinicio/`.

Reglas: SP-first, idempotentes (`CREATE OR ALTER`), una migración nueva = siguiente número libre. Ver [[Patrones y convenciones]] y [[Base de datos y entornos]].
