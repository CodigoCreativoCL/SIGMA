# Reglas del equipo (para Bryan, Emilio, Catalina y sus sesiones de Claude)
Acuerdos que antes vivían solo en la memoria local de cada uno; aquí son comunes.

**Código y datos**
- Leer el patrón de [[Patrones/README|Patrones]] antes de escribir SQL o C#. Compilar la API/Intranet tras cada cambio en C#; los SP se aplican con `Dev/sql_aplicar.py`.
- Seguridad por datos: pantalla nueva = INSERT en `Menus` ([[Seguridad por datos]]). Nada anónimo lleva header Authorization.
- Fechas con `SigmaCalendario` (nunca `type=date/time`). Perfiles dinámicos: nunca «supervisor»/«técnico» en UI o código.

**UI** ([[Estandar UI]])
- Solo drawer, sin modales, pocos clics, cambios visibles al instante; sin recorridos guiados; sin degradados en cabeceras.
- Rediseño de Mantenimiento: header del Centro de Planificación, SigmaCombo/Calendario; «Ronda» = «Inspección».
- En las pruebas del navegador se elige siempre la empresa **Hamburgo**.

**Proceso**
- Una persona hace la historia completa (código, pruebas y validación); se agrupan historias que tocan el mismo código.
- La app móvil se entrega en el Sprint 6; no marcar lo móvil como entregado antes.
- Al cerrar un sprint: validaciones de la PO = Terminadas; la retro incluye el feedback del cliente de la Review.
- Entregables Fase 2: 12 documentos obligatorios (estado en el MD §Entregables).
- `MD/SIGMA_ESTADO_DESARROLLO.md` se actualiza al cerrar cada bloque ([[Flujo de trabajo y git]]).

**Entorno**
- Claves nunca por chat ni en notas. Backups, evidencia y borradores personales fuera del repo y de `C:\Capstone` (p. ej. `C:\Capstone_Archivo`).
- Evidencia de pruebas: un informe consolidado por sprint, no archivos sueltos.
