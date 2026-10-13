# Trampas conocidas
- QUOTED_IDENTIFIER en DML con sqlcmd; combos ReadOnly rompen `validaControl`; AutoPostBack + botón = doble postback.
- «No se puede serializar X» → estaba en Session; mover a HttpRuntime.Cache.
- Rutas Git Bash rompen MSBuild/aspnet_compiler → `MSYS_NO_PATHCONV=1`.
- Marcadores `<<<<<<<` históricos en el MD: anclar ediciones por línea.
- Un blower = soplador.
- Lecturas paralelas lentas por conexiones nuevas → Min Pool Size.
- Planes y pautas se versionan clonando actividades e ítems con ids nuevos (`INS_PLAN_VERSION_NUEVA`, `INS_PLAN_DUPLICAR`, `GET_CHECKLIST_BORRADOR`): todo lo que cuelgue de una actividad o un ítem debe copiarse ahí, y quitarse en los borrados físicos de borradores. Las imágenes de referencia ya lo hacen (BD/454).
- `LIMPIAR_CHECKLIST_BORRADOR` no lo llama nadie y falla por `FK_CID_OPCION` (no borra dependencias). No usarlo sin arreglarlo.
