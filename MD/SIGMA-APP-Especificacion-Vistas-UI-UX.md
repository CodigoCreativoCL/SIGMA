# SIGMA APP — Especificación completa de vistas UI/UX

**Proyecto:** Sistema Integrado de Gestión de Mantenimiento Industrial  
**Aplicación:** Flutter · Android/iOS  
**Base funcional:** Sprint Backlogs S1–S6 · tareas de tipo **Móvil**  
**Lenguaje visual:** Material Design 3 · Sora · Dark/Light · identidad SIGMA y SIGMA AI  
**Objetivo:** transformar SIGMA en una aplicación industrial moderna, clara, rápida y comercialmente diferenciadora.

---

## 1. Principios globales

### 1.1 Experiencia

- Cada pantalla debe responder con claridad: **qué ocurre, dónde ocurre, qué debo hacer y qué sucederá después**.
- Las acciones más frecuentes deben poder completarse con una mano y usando guantes.
- Todo objetivo táctil debe medir al menos `48 × 48 dp`.
- La información crítica debe reconocerse por texto, icono y color.
- Evitar formularios extensos en una sola superficie. Usar pasos, tabs o secciones progresivas.
- No llenar la interfaz con bordes. Separar mediante espacio, jerarquía tipográfica, cambios suaves de superficie y divisores puntuales.
- Una acción visual siempre debe tener comportamiento, validación y respuesta.
- La aplicación debe conservar el trabajo cuando no exista conexión.
- Toda operación pendiente debe mostrar si está guardada localmente, en cola, sincronizando, sincronizada o con conflicto.

### 1.2 Alineación y ritmo visual

- Retícula base de `4 dp` con ritmo principal de `8 dp`.
- Margen horizontal móvil: `16 dp`.
- Separación entre bloques principales: `24 dp`.
- Separación entre controles relacionados: `12–16 dp`.
- Altura de inputs: `52–56 dp`.
- Radio de tarjetas: `20–24 dp`.
- Radio de botones principales: `16–18 dp` o pill cuando corresponda.
- Títulos, labels, valores y acciones deben compartir líneas de alineación.
- Los valores numéricos deben usar cifras tabulares.
- No mezclar más de dos niveles de superficie dentro de una tarjeta.

### 1.3 Material Design 3

Usar componentes M3 nativos o equivalentes:

- `NavigationBar` para navegación principal.
- `TopAppBar` y `SliverAppBar` en fichas con imágenes.
- `FilledButton` para la acción principal.
- `FilledTonalButton` para acciones secundarias frecuentes.
- `OutlinedButton` solo cuando el borde ayude a comprender la acción.
- `FilterChip`, `InputChip` y `AssistChip` para filtros, selecciones y acciones contextuales.
- `SegmentedButton` para decisiones mutuamente excluyentes.
- `Badge` para cantidades y estados.
- `SearchBar` para búsquedas.
- `NavigationDrawer` solo en tablet.
- `BottomSheet` para acciones breves y selección contextual.
- `Dialog` para confirmaciones críticas.
- `Snackbar` para resultados transitorios.

### 1.4 Tipografía Sora

| Uso | Tamaño | Peso |
|---|---:|---:|
| Display breve | 28–32 sp | 700–800 |
| Título de pantalla | 22–24 sp | 700 |
| Título de sección | 17–18 sp | 650–700 |
| Título de tarjeta | 15–16 sp | 600–700 |
| Texto principal | 15–16 sp | 400–500 |
| Label | 13–14 sp | 600 |
| Metadato | 12–13 sp | 400–500 |

El usuario podrá aumentar el tamaño de texto sin perder información ni cortar controles.

### 1.5 Dark y Light

Ambos temas deben usar los mismos componentes y jerarquía.

**Dark**

- Fondo base: `#080C17`.
- Superficie: `#111827`.
- Superficie elevada: `#182235`.
- Texto principal: `#F8FAFC`.
- Texto secundario: `#A8B2C3`.

**Light**

- Fondo base: `#EFF3F9`.
- Superficie: `#FFFFFF`.
- Superficie secundaria: `#F5F7FB`.
- Texto principal: `#0B0F1A`.
- Texto secundario: `#4C5A72`.

**Marca y estados**

- Primario SIGMA: `#6C5CFF`.
- Cian SIGMA: `#00E0C2`.
- Azul: `#2563EB`.
- Éxito: verde.
- Advertencia: ámbar.
- Crítico: rojo.

No usar degradados en todos los controles. Reservarlos para marca, SIGMA AI, indicadores clave y acciones principales.

### 1.6 Fotografías y galerías

Los siguientes registros deben soportar imagen de portada y galería:

- Activos.
- Componentes.
- Repuestos.
- Órdenes de trabajo.
- Tareas.
- Checklists ejecutados.
- Permisos de trabajo.
- Hallazgos y bitácoras cuando corresponda.

Cada imagen debe almacenar y mostrar cuando exista:

- Miniatura y vista completa.
- Fecha y hora real de captura.
- Usuario que la tomó.
- Origen: cámara, archivo o sincronización.
- Registro relacionado.
- Observación o descripción.
- Estado: local, en cola, sincronizando, enviada o pendiente de revisión.
- Integridad verificada.

Las miniaturas necesarias para el trabajo asignado deben quedar disponibles sin conexión.

---

## 2. Asistente de voz SIGMA

### 2.1 Decisión UX

Se utilizará una solución híbrida:

1. **Botón global de voz:** permite al usuario completar varios campos hablando de forma natural.
2. **Micrófono por campo:** queda disponible como alternativa en inputs de texto, números, fechas, horas, cantidades y mediciones.

El botón global evita repetir micrófonos visualmente en todo el formulario. El botón local ayuda cuando el usuario necesita corregir o completar un campo específico.

### 2.2 Ejemplo de captura global

El usuario dice:

> “Activo bomba BMB-001, vibración 8 coma 4 milímetros por segundo, temperatura 68 grados, observación ruido intermitente en lado acople.”

SIGMA debe interpretar y proponer:

| Campo | Valor detectado |
|---|---|
| Activo | BMB-001 |
| Vibración RMS | 8,4 mm/s |
| Temperatura | 68 °C |
| Observación | Ruido intermitente en lado acople |

### 2.3 Comportamiento obligatorio

- Mostrar transcripción en tiempo real.
- Resaltar cada campo a medida que se completa.
- Mostrar los valores interpretados antes de guardar.
- Solicitar confirmación cuando exista ambigüedad.
- Permitir corregir por voz: “cambia la temperatura a 72”.
- Respetar el tipo de campo y su unidad.
- Nunca convertir automáticamente una fecha, cantidad o medición dudosa.
- En campos numéricos, reconocer decimales, unidades y signos.
- En listas, comparar la voz con valores disponibles y mostrar coincidencias.
- El audio no debe conservarse después de obtener la transcripción, salvo autorización y requerimiento explícito.
- Registrar que el valor fue ingresado por voz para trazabilidad.
- Soportar dictado sin conexión si el dispositivo lo permite.
- Si no existe reconocimiento offline, conservar la captura manual como flujo principal.

### 2.4 Panel global de voz

Debe abrirse como un `BottomSheet` con:

- Estado: escuchando, procesando, revisando o detenido.
- Onda de audio discreta.
- Transcripción editable.
- Campos reconocidos.
- Campos pendientes.
- Botones **Aplicar valores**, **Corregir**, **Volver a escuchar** y **Cancelar**.

---

## 3. Arquitectura de navegación

### Navegación principal

1. **Inicio**.
2. **Mi trabajo**.
3. **Escanear**.
4. **Alertas**.
5. **Más**.

### Sección Más

- Activos.
- Inventario.
- Bodegas y ubicaciones.
- Permisos de trabajo.
- Bitácora.
- Sincronización.
- Perfil y accesibilidad.

### Navegación contextual

Desde una OT, activo, componente, repuesto, bodega o alerta se debe poder abrir directamente el registro relacionado, manteniendo una ruta de retorno clara.

---

# 4. Vistas de acceso y contexto

## 4.1 Splash

**Objetivo:** presentar la marca y preparar el estado local.

Debe contener:

- Isotipo o app icon oficial de SIGMA.
- Indicador breve de carga.
- Validación de sesión local.
- Revisión de datos pendientes de sincronización.
- Tema Dark/Light del dispositivo.
- Estado accesible para lector de pantalla.

## 4.2 Inicio de sesión

**HU:** HU-001, HU-003, HU-004, HU-193.

Debe contener:

- Logo oficial apropiado para el tema.
- Correo.
- Contraseña.
- Mostrar u ocultar contraseña.
- Ingreso biométrico cuando esté configurado.
- Recuperar contraseña.
- Mensajes para credenciales incorrectas, cuenta deshabilitada, bloqueo y suscripción vencida.
- Aviso de que los registros locales pendientes se conservarán.
- Versión de la aplicación.

## 4.3 Recuperar contraseña

- Correo registrado.
- Confirmación de solicitud.
- Estado del enlace: válido, usado o vencido.
- Volver al acceso.

## 4.4 Selección de cliente e instalación

**HU:** HU-002, HU-006.

- Clientes permitidos para el usuario.
- Instalaciones asociadas.
- Cliente e instalación usados recientemente.
- Búsqueda cuando existan muchas opciones.
- Estado de sincronización disponible para el contexto.
- Acción **Continuar**.
- Posibilidad de cambiar contexto durante la sesión.

---

# 5. Inicio y SIGMA AI

## 5.1 Inicio operativo

**HU:** HU-121, HU-151, HU-156, HU-173.

Debe responder qué tiene que hacer el usuario hoy.

Bloques:

- Saludo y contexto activo.
- Estado de conexión.
- Progreso de la jornada.
- Trabajos asignados.
- Trabajos críticos o vencidos.
- Registros pendientes de sincronizar.
- Acceso al escáner.
- Siguiente trabajo recomendado.
- Resumen de alertas activas.
- Panel SIGMA AI.

### Panel SIGMA AI

- Predicciones vigentes ordenadas por riesgo y fecha.
- Imagen del activo relacionado.
- Equipo y ubicación.
- Probabilidad o nivel de riesgo real.
- Horizonte estimado.
- Tres razones principales.
- Equipos vigilados cuando no existan predicciones.
- Aviso de datos insuficientes y lecturas faltantes.
- Acción **Ver análisis**.
- Acción para reconocer o tomar la alerta cuando corresponda.

---

# 6. Mi trabajo y órdenes

## 6.1 Bandeja de trabajo

**HU:** HU-112, HU-113, HU-121.

- Buscador por OT, tarea, activo, código o ubicación.
- Tabs o chips: Hoy, Prioritarias, Disponibles, Próximas y Completadas.
- Estado offline visible.
- Cada tarjeta debe mostrar prioridad, tipo, título, imagen del activo, ubicación, plazo, responsable y avance.
- Acción **Tomar trabajo** para órdenes disponibles.
- Acción **Sumar compañero** cuando la regla lo permita.
- Reasignación disponible solo para perfiles autorizados.

## 6.2 Nueva OT correctiva

**HU:** HU-110.

Flujo sugerido:

1. Identificación.
2. Contexto y diagnóstico inicial.
3. Evidencias y revisión.

Campos:

- Título.
- Activo opcional.
- Ubicación.
- Tipo y estrategia.
- Prioridad.
- Fecha real del evento si es registro posterior.
- Descripción.
- Diagnóstico inicial.
- Estado posterior del equipo.
- Indisponibilidad planificada o no planificada.
- Fotografías.

Debe incluir voz global y micrófono por campo.

## 6.3 Ficha de OT

- Código, tipo, prioridad y estado.
- Imagen del activo.
- Activo, componente y ubicación.
- Descripción y diagnóstico.
- Responsable y participantes.
- Fecha de creación y fecha real del evento.
- Tiempo transcurrido.
- Permisos requeridos.
- Progreso general.
- Tabs: Resumen, Pasos, Recursos, Evidencias, Firmas e Historial.

## 6.4 Ejecución de pasos

**HU:** HU-114.

- Progreso `X de Y`.
- Paso actual y navegación entre pasos.
- Obligatorio, opcional o no aplicable.
- Medición con unidad.
- Observación por texto o voz.
- Evidencia obligatoria cuando aplique.
- Confirmación antes de marcar un paso como no aplicable.
- Guardado local automático.
- Identificación exacta de pasos pendientes antes de finalizar.

## 6.5 Mano de obra

**HU:** HU-115.

- Ejecutante.
- Inicio y término.
- Duración calculada.
- Tipo: interna o externa.
- Empresa externa cuando corresponda.
- Especialidad.
- Observación.
- Edición mediante voz.

## 6.6 Repuestos consumidos

**HU:** HU-116.

- Escaneo de repuesto.
- Imagen y código.
- Bodega y ubicación de retiro.
- Stock disponible.
- Cantidad usada.
- Unidad.
- Número de lote cuando aplique.
- Horómetro de la pieza.
- Devolución de sobrante.
- Advertencia por existencia insuficiente.

## 6.7 Firmas

**HU:** HU-118.

- Tipo: aceptación, ejecución o validación.
- Nombre, identificador y rol del firmante.
- Firma manuscrita.
- Fecha y hora.
- Estado aceptada o rechazada.
- Motivo de rechazo.
- Nueva validación sin eliminar el registro anterior.

## 6.8 Finalizar OT

**HU:** HU-119, HU-123, HU-124.

- Resumen de pasos.
- Mano de obra.
- Repuestos.
- Evidencias.
- Firmas requeridas.
- Diagnóstico definitivo.
- Acción provisoria o definitiva.
- Estado final del activo.
- Indisponibilidad registrada.
- Lista exacta de requisitos pendientes.
- Confirmación final.

---

# 7. Escáner y activos

## 7.1 Escáner QR

**HU:** HU-067, HU-154.

- Cámara a pantalla completa.
- Marco de lectura claro.
- Linterna.
- Acceso a galería cuando esté permitido.
- Ingreso manual del código.
- Estado de catálogo local.
- Resultado con fotografía, código, nombre, estado y ubicación.
- Estados: código reconocido, no reconocido, posición vacía y consulta offline.
- Acción **Abrir ficha**.

## 7.2 Listado de activos

- Buscador por código, nombre, serie o ubicación.
- Filtros por planta, área, tipo, estado y criticidad.
- Vistas lista y cuadrícula.
- Fotografía principal.
- Estado operativo.
- Alertas activas.
- Próxima mantención.
- Orden por criticidad, riesgo, nombre o última intervención.

## 7.3 Ficha del activo

**HU:** HU-037, HU-038, HU-142, HU-155.

La ficha debe conservar el concepto de la referencia y potenciarlo.

### Encabezado visual

- Galería o fotografía de portada.
- Cantidad de fotografías.
- Código.
- Estado operativo.
- Criticidad.
- Indicador SIGMA AI si el activo está monitoreado.
- Nombre, ubicación y posición.

### Acciones rápidas

- Registrar lectura.
- Crear OT.
- Cambiar estado con motivo.
- Agregar componente descubierto.
- Compartir referencia interna.

### Tabs

1. **Ficha**.
2. **Historial**.
3. **Medidores**.
4. **Componentes**.
5. **Documentos**.
6. **Galería**.

### Tab Ficha

- Salud del activo y tendencia cuando existan datos.
- Tipo, marca, modelo y número de serie.
- Planta, área, ubicación y posición.
- Criticidad.
- Horas de uso.
- Cantidad de OT abiertas y cerradas.
- MTBF y MTTR cuando estén disponibles.
- Última y próxima intervención.
- Componentes críticos.
- Alertas vigentes.

### Tab Historial

- Línea de tiempo cronológica.
- Filtros: Todo, OT, lecturas, estados, fallas, componentes y evidencias.
- Cambio de estado con estado anterior y nuevo.
- Usuario, fecha real, motivo y evidencia.
- OT con duración, responsables y repuestos.
- Lecturas con valor, unidad y umbral.
- Rectificaciones visibles sin borrar el dato original.

### Tab Medidores

- Nombre y tipo de medidor.
- Última lectura.
- Unidad.
- Fecha.
- Tendencia.
- Estado normal, advertencia o crítico.
- Acción **Registrar lectura**.
- Acceso al historial del medidor.

### Tab Componentes

- Fotografía.
- Código y nombre.
- Estado.
- Fecha de instalación.
- Horas de uso.
- Vida útil esperada.
- Alertas y OT relacionadas.
- Acción **Abrir ficha**.

## 7.4 Galería del activo

- Portada del activo.
- Cuadrícula cronológica.
- Filtros: General, OT, Fallas, Componentes, Documentos y Sin sincronizar.
- Capturar foto.
- Seleccionar archivo.
- Vista completa con zoom.
- Fecha, autor, origen y relación.
- Agregar observación por voz.
- Seleccionar imagen de portada según permisos.
- Descarga offline de miniaturas.

---

# 8. Componentes

## 8.1 Listado de componentes

- Acceso desde el activo o desde búsqueda global.
- Fotografía.
- Código y nombre.
- Activo padre.
- Ubicación dentro del activo.
- Estado.
- Criticidad.
- Vida útil o contador.
- Alertas activas.

## 8.2 Ficha del componente

- Fotografía principal y galería.
- Código y nombre.
- Activo padre con acceso directo.
- Posición técnica.
- Estado.
- Criticidad.
- Marca, modelo, serie y especificaciones.
- Fecha de instalación.
- Horas o ciclos de uso.
- Vida útil estimada.
- Última sustitución.
- Repuesto asociado.
- OT, fallas y mediciones relacionadas.
- Señal de SIGMA AI cuando el modelo considere ese componente.

Acciones:

- Crear OT.
- Registrar condición.
- Cambiar estado.
- Sustituir componente.
- Agregar evidencia.

## 8.3 Historial del componente

- Instalación.
- Cambios de estado.
- Lecturas.
- Fallas.
- Reparaciones.
- Sustituciones.
- OT asociadas.
- Comentarios y rectificaciones.

## 8.4 Galería del componente

- Fotografía principal.
- Fotografías de instalación, daño, reparación y sustitución.
- Comparación antes/después.
- Relación con OT o hallazgo.
- Fecha, usuario y observación.
- Estado de sincronización.
- Voz para describir evidencia.

---

# 9. Medidores y condición

## 9.1 Registrar lectura

**HU:** HU-043, HU-044.

- Activo y medidor.
- Última lectura y fecha.
- Valor actual.
- Unidad bloqueada según configuración.
- Fecha y hora real.
- Incremento calculado.
- Observación.
- Evidencia opcional u obligatoria.
- Captura por voz global o local.
- Advertencia por salto no razonable.
- Advertencia por valor fuera de umbral.
- Confirmación antes de aceptar unidad distinta.
- Guardado local y cola offline.

## 9.2 Historial de lecturas

- Gráfico de tendencia.
- Rango temporal.
- Umbrales visibles.
- Valores normales, advertencias y críticos.
- Tabla o lista de lecturas.
- Usuario, fecha real, modo de ingreso y observación.
- Acceso a alerta o OT relacionada.

---

# 10. Inventario, bodegas y ubicaciones

## 10.1 Centro de inventario

**HU:** HU-054, HU-055, HU-056, HU-057.

Debe permitir comprender el estado del inventario de un vistazo.

### Encabezado

- Bodega activa.
- Selector de bodega.
- Estado de sincronización.
- Escáner de repuesto o ubicación.
- Búsqueda global.

### Indicadores

- Repuestos críticos.
- Bajo mínimo.
- Sobre máximo.
- Sin existencia.
- Por vencer.
- Pendientes de reposición o revisión, solo cuando el modelo funcional los soporte.
- Movimientos pendientes de sincronizar.

### Secciones

- **Requieren atención:** tarjetas visuales ordenadas por gravedad.
- **Movimientos rápidos:** Ingreso, Entrega, Devolución, Traslado y Ajuste.
- **Bodegas:** resumen de cada bodega.
- **Ubicaciones:** pasillos, estantes y posiciones.
- **Últimos movimientos**.
- **Repuestos más utilizados** cuando exista información.

### Tarjeta de repuesto en alerta

- Fotografía.
- Código y nombre.
- Bodega y ubicación.
- Existencia actual.
- Mínimo y máximo.
- Diferencia contra umbral.
- OT que requieren el repuesto.
- Último movimiento.
- Acción contextual.

## 10.2 Listado de repuestos

- Buscar por código, nombre, fabricante, modelo o código de barras.
- Filtros por bodega, ubicación, categoría y estado de stock.
- Fotografía.
- Disponible, reservado y comprometido.
- Mínimo y máximo.
- Lote o vencimiento cuando corresponda.
- Indicador crítico.
- Orden por urgencia, nombre, stock o consumo.

## 10.3 Ficha del repuesto

- Fotografía principal y galería.
- Código interno, código del fabricante y código de barras.
- Nombre y descripción.
- Categoría y unidad.
- Marca, fabricante y modelo.
- Repuestos equivalentes o sustitutos.
- Existencia total.
- Existencia por bodega y ubicación.
- Disponible, reservado y comprometido.
- Mínimo y máximo por bodega.
- Lotes, vencimientos y series cuando apliquen.
- Consumo promedio y última salida cuando existan datos.
- Activos y componentes compatibles.
- OT relacionadas.
- Historial de movimientos.

Acciones:

- Ingresar.
- Entregar contra OT.
- Devolver.
- Trasladar.
- Ajustar con motivo.
- Escanear ubicación.
- Agregar evidencia.

## 10.4 Galería del repuesto

- Imagen de portada.
- Producto, empaque, etiqueta, código de barras y estado físico.
- Fotografías asociadas a recepción, ajuste o devolución.
- Fecha, usuario, bodega, ubicación y movimiento relacionado.
- Observación por voz.
- Vista completa y zoom.
- Estado de sincronización.

## 10.5 Listado de bodegas

- Nombre y código.
- Instalación.
- Responsable.
- Cantidad de ubicaciones.
- Cantidad de SKU.
- Repuestos críticos y bajo mínimo.
- Movimientos pendientes.
- Estado habilitada/deshabilitada.

## 10.6 Ficha de bodega

- Nombre, código e instalación.
- Responsable y contacto.
- Estado.
- Indicadores de inventario.
- Mapa lógico de ubicaciones.
- Repuestos críticos.
- Últimos movimientos.
- Usuarios autorizados.
- Acciones: escanear ubicación, traslado y ajuste según permiso.

## 10.7 Listado de ubicaciones

- Jerarquía: zona, pasillo, estante, nivel y posición.
- Código QR.
- Bodega.
- Capacidad cuando exista.
- Cantidad de repuestos.
- Estado ocupada, disponible o bloqueada.
- Alertas de incompatibilidad o capacidad cuando apliquen.

## 10.8 Ficha de ubicación

- Código y QR.
- Ruta completa dentro de la bodega.
- Estado.
- Capacidad.
- Repuestos almacenados con fotografía y cantidad.
- Último conteo.
- Últimos movimientos.
- Acción para trasladar, ingresar, retirar o contar.

## 10.9 Ingreso de repuesto

- Repuesto.
- Bodega y ubicación.
- Cantidad.
- Unidad.
- Lote, serie y vencimiento cuando apliquen.
- Documento de respaldo.
- Fotografías.
- Observación y voz.
- Resumen antes de confirmar.

## 10.10 Entrega contra OT

- OT obligatoria.
- Repuesto.
- Bodega y ubicación.
- Existencia disponible.
- Cantidad.
- Técnico receptor.
- Evidencia o firma si la regla lo exige.
- Bloqueo ante existencia insuficiente.

## 10.11 Devolución

- OT de origen.
- Repuesto y cantidad entregada.
- Cantidad devuelta.
- Estado físico.
- Bodega y ubicación destino.
- Motivo.
- Fotografías.

## 10.12 Traslado

- Bodega y ubicación de origen.
- Bodega y ubicación de destino.
- Repuesto y cantidad.
- Validación de existencia.
- Validación de ubicación.
- Confirmación de recepción cuando corresponda.

## 10.13 Ajuste

- Repuesto.
- Existencia del sistema.
- Conteo real.
- Diferencia calculada.
- Motivo obligatorio.
- Evidencia.
- Usuario y fecha real.
- Permiso validado en servidor.

---

# 11. Permisos de trabajo

## 11.1 Bandeja de permisos

**HU:** HU-063, HU-064.

- Vigentes.
- Próximos a vencer.
- Vencidos.
- Por OT.
- Por proveedor.
- Tipo de permiso.
- Fecha y tiempo restante.
- Evidencia disponible.

## 11.2 Ficha del permiso

- Tipo.
- OT.
- Trabajo y ubicación.
- Responsable.
- Proveedor.
- Inicio y término.
- Estado.
- Evidencias.
- Historial de cambios.
- Acción renovar, reemplazar o adjuntar evidencia según permisos.

## 11.3 Registrar permiso

- OT y tipo.
- Vigencia.
- Responsable.
- Proveedor.
- Observación.
- Fotografías o documento.
- Voz global y por campo.
- Validación de fechas.
- Resumen antes de guardar.

---

# 12. Checklists y tareas

## 12.1 Checklist en terreno

**HU:** HU-095, HU-160, HU-161.

- Una pregunta o grupo coherente por bloque.
- Avance total.
- Tipo de respuesta.
- Unidad.
- Rango esperado.
- Obligatorio.
- Evidencia.
- Observación.
- Voz global y micrófono local.
- Lectura en voz alta.
- Hallazgo automático por valor fuera de rango.
- Estado local y sincronización.

## 12.2 Resumen del checklist

- Respondidos, pendientes y no aplicables.
- Hallazgos.
- Valores fuera de rango.
- Evidencias.
- Confirmación antes de completar.
- Acceso directo al ítem con error.

## 12.3 Ficha de tarea

**HU:** HU-103, HU-104.

- Título y descripción.
- Prioridad y plazo.
- Activo o ubicación.
- Responsables.
- Estado.
- Evidencia requerida.
- Comentarios y respuestas.
- Voz para observaciones y comentarios.
- Acción iniciar, pausar o completar.

---

# 13. Bitácora y evidencias

## 13.1 Bitácora

**HU:** HU-130, HU-131.

- Contexto de planta, área o activo.
- Línea de tiempo.
- Entradas con atención requerida.
- Texto o dictado.
- Comentarios.
- Rectificación con motivo obligatorio.
- Registro original siempre visible.
- Fotografías y documentos.
- Estado offline.

## 13.2 Centro de evidencias

**HU:** HU-140, HU-141, HU-142.

- Cámara.
- Galería del dispositivo.
- Archivo.
- Miniaturas.
- Registro relacionado.
- Progreso de carga.
- Reanudación automática.
- Integridad.
- Pendiente de revisión.
- Reintentar o cancelar.

---

# 14. Alertas y SIGMA AI

## 14.1 Centro de alertas

**HU:** HU-174, HU-184.

- Activas.
- Críticas.
- En gestión.
- Sin responsable.
- Resueltas.
- Filtros por tipo, prioridad, activo, ubicación y responsable.
- Imagen del activo, repuesto o componente relacionado.
- Estado de lectura separado del estado operacional.
- Acción **Tomar alerta**.
- Acción **Abrir origen**.
- Acción contextual real.
- Resolver o descartar con motivo cuando corresponda.

Las alertas determinísticas y las predicciones deben distinguirse visualmente.

## 14.2 Detalle SIGMA AI

**HU:** HU-175.

- Logo oficial SIGMA AI.
- Imagen del activo o componente.
- Predicción.
- Riesgo.
- Horizonte estimado.
- Tres razones principales.
- Variable determinante y gráfico.
- Intervalo de estimación.
- Datos usados.
- Fecha del cálculo.
- Modelo y versión.
- Evidencia relacionada.
- Acción para reconocer la predicción.
- Acción para abrir una OT predictiva cuando el usuario tenga permiso.

No mostrar porcentajes, causas ni recomendaciones si el modelo no los entrega.

---

# 15. Sincronización y trabajo offline

## 15.1 Centro de sincronización

**HU:** HU-150, HU-151, HU-152, HU-153, HU-156.

- Estado online/offline permanente.
- Última sincronización completa.
- Datos descargados.
- Cambios pendientes.
- Archivos pendientes.
- Espacio local disponible.
- Progreso.
- Reintento.
- Errores comprensibles.
- Acción **Sincronizar ahora**.

## 15.2 Conflicto de sincronización

- Registro afectado.
- Versión local.
- Versión del servidor.
- Diferencias resaltadas.
- Fecha real de cada cambio.
- Usuario.
- Opciones autorizadas para resolver.
- No mostrar conflicto si los datos son equivalentes.
- Registrar la decisión.

---

# 16. Perfil y accesibilidad

## 16.1 Perfil

**HU:** HU-005, HU-006.

- Fotografía o avatar.
- Nombre.
- Correo y teléfono.
- Perfil, especialidad y permisos relevantes.
- Cliente e instalación actual.
- Editar datos.
- Cambiar contraseña.
- Cerrar sesión.

## 16.2 Accesibilidad

**HU:** HU-161, HU-162.

- Tamaño del texto.
- Alto contraste.
- Dark/Light/Sistema.
- Movimiento reducido.
- Avisos sonoros.
- Horario de silencio.
- Lectura en voz alta.
- Velocidad de lectura.
- Confirmación háptica.
- Preferencias persistentes por usuario.

---

# 17. Estados obligatorios por vista

Toda vista debe considerar cuando corresponda:

- Cargando.
- Sin información.
- Sin resultados.
- Sin conexión.
- Información local disponible.
- Guardado local.
- En cola.
- Sincronizando.
- Sincronizado.
- Conflicto.
- Error recuperable.
- Error de permisos.
- Suscripción vencida.
- Éxito.

Los estados vacíos deben indicar qué puede hacer el usuario a continuación.

---

# 18. Matriz de vistas principales

| Área | Vistas |
|---|---|
| Acceso | Splash, Login, Recuperación, Cliente e instalación |
| Inicio | Inicio operativo, Panel SIGMA AI |
| Trabajo | Bandeja, Nueva OT, Ficha OT, Pasos, Mano de obra, Repuestos, Firmas, Finalización |
| Activos | Listado, Escáner, Ficha, Historial, Medidores, Componentes, Galería |
| Componentes | Listado, Ficha, Historial, Galería |
| Inventario | Centro, Repuestos, Ficha repuesto, Galería repuesto, Bodegas, Ficha bodega, Ubicaciones, Ficha ubicación, Movimientos |
| Permisos | Bandeja, Ficha, Registro |
| Ejecución | Checklist, Resumen checklist, Tarea |
| Registro | Bitácora, Evidencias |
| Inteligencia | Alertas, Detalle SIGMA AI |
| Sistema | Sincronización, Conflictos, Perfil, Accesibilidad |

---

# 19. Criterios de aceptación UI/UX

La propuesta se considerará completa cuando:

1. Todas las vistas usen Sora y componentes M3 de manera consistente.
2. Dark y Light mantengan contraste, jerarquía y marca.
3. Activos, repuestos y componentes tengan imagen de portada y galería.
4. La ficha del activo permita navegar realmente entre sus tabs.
5. Existan ficha y galería independientes para repuesto y componente.
6. Inventario muestre repuestos críticos, bajo mínimo, sobre máximo y sin stock a simple vista.
7. Bodegas y ubicaciones formen parte del flujo de inventario.
8. Los movimientos indiquen bodega y ubicación de origen y destino.
9. La captura por voz global complete varios campos mediante palabras clave.
10. Cada input editable tenga acceso a dictado local o al asistente global.
11. Los valores interpretados por voz se confirmen antes de guardar.
12. Todas las acciones principales funcionen en el prototipo.
13. Las pantallas mantengan alineación, ritmo y espaciado consistente.
14. No existan bordes decorativos innecesarios.
15. Las acciones críticas incluyan confirmación y mensajes claros.
16. Todo registro realizado sin conexión quede guardado y visible en la cola.
17. Las alertas distingan lectura, gestión y resolución.
18. SIGMA AI aparezca en Inicio, Alertas y fichas relacionadas solo cuando existan datos predictivos.
19. La navegación funcione con teclado, lector de pantalla y ampliación de texto.
20. Cada vista conserve trazabilidad con las historias móviles de los Sprints 1–6.

---

# 20. Orden recomendado de implementación

## Fase 1 — Sistema base

- Tokens Dark/Light.
- Sora.
- Componentes M3.
- Navegación.
- Manejo de estados.
- Sincronización local.
- Asistente de voz.

## Fase 2 — Operación

- Inicio.
- Mi trabajo.
- OT.
- Checklist.
- Tareas.
- Evidencias.

## Fase 3 — Activos

- Escáner.
- Listado y ficha del activo.
- Historial.
- Medidores.
- Componentes.
- Galerías.

## Fase 4 — Inventario

- Centro de inventario.
- Repuestos.
- Bodegas.
- Ubicaciones.
- Movimientos.
- Galerías.

## Fase 5 — Inteligencia y cierre

- Alertas.
- SIGMA AI.
- Permisos.
- Bitácora.
- Accesibilidad.
- Validación completa offline.

