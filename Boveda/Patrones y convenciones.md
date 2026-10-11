# Patrones y convenciones
Estándar del grupo: `Boveda/Patrones/` (CONVENCIONES.md siempre; luego BaseDatos/PATRON_SP, PATRON_TABLAS, Desarrollo/PATRON_MVC, PATRON_CONTROLES, PATRON_GRID_EVENTS; CHECKLIST_ENTIDAD_NUEVA). Gana lo que ya existe en el proyecto.
- Archivos **UTF-8 con BOM y CRLF** (`_scratch/bom.py`).
- Dentro del `<form>` del master todo `<button>` lleva `type="button"`.
- Compilar tras tocar C#: `aspnet_compiler -v /Check -p Web/Intranet ...` (en Git Bash anteponer `MSYS_NO_PATHCONV=1`). Salidas a `_scratch`, **nunca** dentro del repo (`_program files_git*` y `.codex-compile-*` están ignoradas y se borran).
- SQL con `sqlcmd` / `_scratch/aplicar_sql.py` (`-I` si el SP usa FOR XML o índices filtrados; DML requiere QUOTED_IDENTIFIER).
- Fechas: nunca `type=date/time`; `.sigma-modal-fecha` + `SigmaCalendario.conectar()` tras render.
- App móvil copia la arquitectura de FacilityGes/ControlGate, no su dominio.

Ver [[Estandar UI]], [[Trampas conocidas]].
