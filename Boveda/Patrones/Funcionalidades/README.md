# Funcionalidades portables

Guías para **portar un módulo completo** de un proyecto WebForms del grupo a
otro. A diferencia de los patrones (`BaseDatos/`, `Desarrollo/`), que describen
*cómo se escribe* el código, estos documentos describen *un módulo concreto*:
qué archivos lo componen, qué infraestructura asume y con qué trampas te vas a
encontrar al llevarlo a otra base y otro sitio.

| Funcionalidad | Qué hace | Origen |
|---|---|---|
| [`Funcionalidad_MaterialApoyo.md`](Funcionalidad_MaterialApoyo.md) | Adjunta material de ayuda (video/PDF/Office) a un menú y lo muestra en la barra superior de esa pantalla, con estadísticas de visto / me gusta | FacilityGes → SGF |

---

## Estructura de una guía de funcionalidad

Al documentar un módulo nuevo, seguir estas secciones (en este orden):

1. **Qué es y cómo funciona** — flujo en texto, punto clave del diseño.
2. **Inventario de archivos** — tabla capa → ruta, para copiar sin olvidar nada.
3. **Evaluación previa** — qué debe existir en el destino (código, BD,
   servidor, convenciones visuales) **antes** de copiar. Es la sección que
   evita la mitad de los problemas.
4. **Modelo de datos** — tablas, SPs, triggers.
5. **Pasos de implementación** — orden concreto.
6. **Trampas conocidas** — cada bug real encontrado en un port, con su causa y
   su fix. Se agregan tras cada port nuevo.
7. **Verificación** — compilación, pruebas funcionales numeradas, rollback.

---

## Reglas

- La guía se escribe **después** del primer port real, no antes: las trampas
  son lo más valioso y solo aparecen portando.
- Tras portar el módulo a un proyecto nuevo, volver a la guía y agregar lo que
  falló ahí (sección 6) e indicar en la tabla de arriba el nuevo destino.
- Los ids concretos (menús, módulos de `LOG`, perfiles) se dejan como
  marcadores `<N>`: son distintos en cada base.
- Todo lo que sea patrón general (cómo se escribe un SP, cómo se declara un
  grid) **no** se repite aquí: se enlaza a `../BaseDatos/` o `../Desarrollo/`.
