# BD — Suscripción y comercial

11 migraciones (generado por `Dev/indexar_bd.py`; no editar). Ruta: `BD/<archivo>`. Ver [[Indice de base de datos]].

| Archivo | Qué hace |
|---|---|
| `08_SUSCRIPCION.sql` | MODELO COMERCIAL: PLANES, SUSCRIPCION, UF Y RENOVACION. |
| `09_COSTOS_NUBE.sql` | BLOQUE RETIRADO. NO CREA NADA. |
| `40_SUSCRIPCION_UF.sql` | BLOQUE A. EL VALOR DE LA UF. |
| `41_SUSCRIPCION_SPS.sql` | BLOQUE B. SPs DE SUSCRIPCION, PERIODOS Y PAGOS. |
| `42_SUSCRIPCION_ARCHIVOS.sql` | BLOQUE C.1 SPs DE ARCHIVO PARA EL COMPROBANTE DE PAGO. |
| `45_SUSCRIPCION_KEY.sql` | BLOQUE C.4 REEMISION DE LA CLAVE DE SUSCRIPCION. |
| `228_PLAN_COMERCIAL_SIN_PRECIO.sql` | UN PLAN COMERCIAL RECIEN CREADO, SIN PRECIO, TIENE QUE |
| `455_CENTRO_COMERCIAL_MODELO.sql` |  |
| `456_CENTRO_COMERCIAL_SP.sql` |  |
| `457_CENTRO_COMERCIAL_CATALOGO.sql` | 0 · planes estándar (públicos) con la mensualidad vigente |
| `467_COBROS_PLAN_MODULOS.sql` |  |
