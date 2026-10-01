# SIGMA — Pautas de inspección 360

## Prompt maestro en español
Diseñar nueve capturas independientes: listado, Resumen, Configuración, Estructura, Versiones, Programaciones, Ocurrencias y ejecuciones, Hallazgos de la pauta y bandeja transversal de Hallazgos. Conservar topbar y diseño del sidebar SIGMA. Sora, Material Symbols Rounded, blanco, gris frío, navy y violeta. Mantener tamaños, márgenes y alineación consistentes. Usar imágenes de referencia y los prompts específicos adjuntos.

## Navegación
Consolidar los accesos de inspección en Pautas de inspección y Hallazgos de inspección. Mantener todos los demás menús del sistema. Estructura absorbe ChecklistPlantillaVista; Versiones absorbe menú 2212; Programaciones absorbe 2213/2214. Estas referencias provienen de la propuesta del usuario; no se han verificado en código.
Ocultar accesos redundantes no significa borrar registros, permisos ni endpoints: conservar enlaces históricos y redirigirlos al centro con pauta y pestaña correspondientes. Validar permisos por pestaña y acción.

## Reglas funcionales
- Separar publicación de versión y habilitación de pauta.
- Código único por cliente, no editable después del alta. No convertir campos opcionales en obligatorios por la apariencia de un mockup.
- Planta vacía: todas; tipo de activo vacío: cualquiera, según formulario de referencia.
- Editar estructura mediante borrador; versión publicada inmutable. Comparar ítems, opciones, validaciones y dependencias antes de publicar.
- Las ejecuciones históricas conservan versión, preguntas, respuestas, umbrales y evidencias originales. Publicar no migra silenciosamente ocurrencias existentes.
- Programar sobre versión publicada. Objetivo: al menos activo o área, conforme a la referencia. Validar cómo se combinan ambos antes de implementación.
- Guardar una programación deshabilitada debe permitirse si sus datos son válidos. Separar Guardar de Activar. No bloquear Guardar solo por estar la pauta deshabilitada.
- El nombre de la pauta no determina recurrencia; la frecuencia procede de la programación.
- Cumplimiento: definir ocurrencias exigibles del período; excluir futuras y canceladas. Completar no equivale a resultado conforme.
- Mostrar fecha programada, inicio real, término y sincronización por separado.
- Cada respuesta conserva su foto y origen. No modificar respuestas cerradas sin una corrección trazable.
- Hallazgos de pauta: filtro de pauta fijo, no selector para navegar a otra pauta. Bandeja global: filtro de pauta editable.
- Generar OT conserva vínculo al hallazgo y no lo resuelve. Si existe OT vinculada, mostrar Abrir OT y evitar duplicados.
- Descartar pide motivo contextual de al menos 10 caracteres, confirmación y registro de usuario/fecha. Nunca eliminar la evidencia histórica.
- Mantener filtros y selección al volver desde pauta, ejecución, activo u OT.

## Alcance de las imágenes
Son propuestas estáticas generadas, con datos y fotografías ilustrativos. Hay variaciones de texto, datos y elementos del sidebar entre imágenes; no son reglas de negocio ni especificaciones exactas. Para implementación prevalecen las reglas anteriores y el sistema real. Los ejemplos de umbral deben mantenerse consistentes dentro de una versión y validarse por equipo; no son recomendaciones operativas. El ejemplo de 7,1 mm/s no es un umbral universal. No interpretar cifras ilustrativas como registros de producción.

Los prompts específicos se incluyen completos en prompts/. Abre INDICE.html para recorrer las nueve imágenes.
