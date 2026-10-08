# SIGMA — Análisis funcional y definición de alcance del Centro de Planificación

Necesito que analices el sistema actual SIGMA, específicamente el módulo  **Mantenimiento** , su código, páginas, lógica, navegación, entidades y relaciones funcionales.

El objetivo es generar un documento Markdown que servirá posteriormente como  **fuente funcional oficial para Claude Design** , donde se diseñará el nuevo artefacto UI/UX del Centro de Planificación.

---

# 1. Estructura actual de Mantenimiento

Actualmente el módulo está organizado así:

```text
MANTENIMIENTO
│
├── Planificación
├── Programaciones
├── Procedimientos
│
├── INSPECCIÓN
│   ├── Pautas de inspección
│   └── Hallazgos de inspección
│
├── TAREAS
│   ├── Tareas recurrentes
│   └── Categorías de tarea
│
└── ÓRDENES DE TRABAJO
    ├── Listado de órdenes
    └── Fallas
```

Páginas actuales:

```text
Planificación
/View/Mantenimiento/Planificacion.aspx

Programaciones
/View/Mantenimiento/Programaciones/Programaciones.aspx

Procedimientos
/View/Mantenimiento/Procedimientos/Procedimientos.aspx

Pautas de inspección
/View/Mantenimiento/Checklist/ChecklistCentro.aspx

Hallazgos
/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx

Tareas recurrentes
/View/Mantenimiento/Tareas/Tareas.aspx

Categorías de tarea
/View/Mantenimiento/Tareas/TareaCategorias.aspx

Órdenes de trabajo
/View/Mantenimiento/Ordenes/OrdenTrabajos.aspx

Fallas
/View/Mantenimiento/Fallas/Fallas.aspx
```

---

# 2. Objetivo

Queremos transformar la experiencia actual de:

```text
Planificación
      +
Programaciones
      +
Procedimientos
```

en una experiencia integrada llamada:

# CENTRO DE PLANIFICACIÓN

IMPORTANTE:

No quiero que simplemente juntes las tres pantallas actuales.

Quiero que analices el sistema y determines **cómo debería funcionar conceptualmente el proceso de planificación de mantenimiento** para que el usuario necesite realizar la menor cantidad posible de pasos.

La premisa es:

> El usuario debe entender el mantenimiento como un proceso único, no como varios módulos técnicos separados.

---

# 3. Analiza el sistema real antes de proponer cambios

Debes revisar el código existente y determinar:

* Qué hace actualmente cada página.
* Qué entidades utiliza.
* Qué tablas intervienen.
* Qué Stored Procedures existen.
* Qué relaciones existen.
* Qué datos se crean.
* Qué datos se modifican.
* Qué datos se generan automáticamente.
* Qué dependencias existen entre Planificación, Programaciones y Procedimientos.
* Qué dependencias existen con Tareas.
* Qué dependencias existen con Pautas de inspección.
* Qué genera finalmente una Orden de Trabajo.

No inventes funcionalidades que no existan.

Cuando propongas algo nuevo, identifícalo claramente como:

**PROPUESTA**

y no como funcionalidad existente.

---

# 4. Analiza el flujo actual

Reconstruye el flujo real que debe realizar un usuario para crear mantenimiento.

Determina si actualmente ocurre algo parecido a:

```text
Crear planificación
        ↓
Guardar
        ↓
Crear programación
        ↓
Configurar frecuencia
        ↓
Asociar activo
        ↓
Crear procedimiento
        ↓
Crear tareas
        ↓
Asociar procedimiento
        ↓
Activar
        ↓
Generar ejecución
        ↓
Generar OT
```

Pero no asumas que este flujo es correcto.

Debes reconstruirlo desde el código y las funcionalidades existentes.

---

# 5. Detecta problemas

Identifica:

* pasos innecesarios;
* navegación entre páginas;
* formularios duplicados;
* información repetida;
* modales innecesarios;
* acciones que podrían hacerse inline;
* información que se solicita demasiado pronto;
* información que debería aparecer en contexto;
* dependencias difíciles de entender;
* funcionalidades duplicadas;
* conceptos que podrían unificarse;
* procesos que requieren demasiado conocimiento del sistema.

Para cada problema utiliza:

```text
Problema
Impacto
Propuesta
```

---

# 6. Diseña el concepto Centro de Planificación

Determina cómo debería funcionar una experiencia donde el usuario pueda:

### Definir qué mantener

* Activo.
* Equipo.
* Instalación.
* Ubicación.

### Definir qué hacer

* Tareas.
* Actividades.
* Procedimientos.
* Instrucciones.
* Pautas de inspección cuando corresponda.

### Definir cómo hacerlo

* Procedimiento.
* Pasos.
* Mediciones.
* Evidencias.
* Checklist.

### Definir cuándo hacerlo

* Frecuencia.
* Calendario.
* Días.
* Horarios.
* Repetición.
* Exclusiones.

### Definir quién lo ejecuta

* Técnico.
* Grupo de trabajo.
* Responsable.

### Revisar

Mostrar un resumen completo.

### Activar

Activar la planificación y comenzar el ciclo correspondiente.

---

# 7. No asumir que todo debe fusionarse

Analiza y determina:

* Qué debe unificarse visualmente.
* Qué debe mantenerse como entidad independiente.
* Qué debe seguir siendo un menú.
* Qué podría dejar de ser un menú.
* Qué debería convertirse en una funcionalidad interna del Centro de Planificación.
* Qué debería mantenerse como centro especializado.

Analiza específicamente:

* Planificación.
* Programaciones.
* Procedimientos.
* Tareas recurrentes.
* Categorías de tarea.
* Pautas de inspección.
* Hallazgos.
* Fallas.
* Órdenes de trabajo.

---

# 8. Analiza el ciclo completo

Determina las relaciones reales entre:

```text
Planificación
     ↓
Programación
     ↓
Procedimiento
     ↓
Tareas / Actividades
     ↓
Activo
     ↓
Frecuencia
     ↓
Ejecución
     ↓
Orden de Trabajo
     ↓
Resultado
     ↓
Historial
```

Y también:

```text
Pauta de inspección
     ↓
Ejecución
     ↓
Hallazgo
     ↓
Orden de Trabajo
```

Y:

```text
Falla
     ↓
Orden de Trabajo
```

Determina dónde debe comenzar y terminar el alcance del Centro de Planificación.

---

# 9. Diseña la experiencia ideal

La experiencia debería intentar evolucionar desde:

```text
Crear
↓
Guardar
↓
Salir
↓
Ir a otro menú
↓
Crear
↓
Guardar
↓
Volver
↓
Buscar
↓
Asociar
```

hacia:

```text
Crear planificación
        ↓
Configurar
        ↓
Revisar
        ↓
Activar
```

El sistema debe encargarse internamente de las relaciones necesarias.

---

# 10. UX

La propuesta debe priorizar:

1. Menos clicks.
2. Menos navegación.
3. Menos modales.
4. Menos formularios repetitivos.
5. Mayor contexto.
6. Edición inline.
7. Acciones rápidas.
8. Selección múltiple.
9. Reutilización.
10. Claridad.

NO convertirlo necesariamente en un wizard largo.

El Centro de Planificación debería sentirse como un  **workspace de mantenimiento** , no como un formulario gigante.

---

# 11. Casos de uso

Analiza como mínimo:

1. Crear mantenimiento preventivo.
2. Asociar activo.
3. Asociar varios activos.
4. Seleccionar procedimiento existente.
5. Crear procedimiento nuevo.
6. Agregar tareas.
7. Configurar frecuencia.
8. Asignar técnicos.
9. Agregar pauta de inspección.
10. Duplicar planificación.
11. Modificar planificación.
12. Desactivar planificación.
13. Revisar próximas ejecuciones.
14. Ver OT generadas desde una planificación.

---

# 12. Reglas de negocio

Identifica reglas existentes en el código.

Separarlas como:

### Regla existente

Regla que realmente está implementada.

### Regla propuesta

Regla recomendada para el nuevo diseño.

No inventes reglas existentes.

---

# 13. Decisión sobre los menús

Genera obligatoriamente esta tabla:

| Menú                 | Mantener | Transformar | Absorber | Eliminar | Justificación |
| --------------------- | -------- | ----------- | -------- | -------- | -------------- |
| Planificación        |          |             |          |          |                |
| Programaciones        |          |             |          |          |                |
| Procedimientos        |          |             |          |          |                |
| Tareas recurrentes    |          |             |          |          |                |
| Categorías de tarea  |          |             |          |          |                |
| Pautas de inspección |          |             |          |          |                |
| Hallazgos             |          |             |          |          |                |
| Fallas                |          |             |          |          |                |
| Órdenes de trabajo   |          |             |          |          |                |

Debe existir una decisión clara para cada menú.

---

# 14. Separar UX de arquitectura

IMPORTANTE:

No confundas:

### UX

Cómo lo ve el usuario.

### Arquitectura funcional

Cómo se relacionan los conceptos.

### Arquitectura técnica

Tablas, entidades, Stored Procedures, servicios, APIs, etc.

Puede existir un único Centro de Planificación en la interfaz y continuar existiendo diferentes entidades internamente.

---

# 15. MVP

Define:

## MVP

Lo indispensable para implementar el Centro de Planificación.

## Fase 2

Mejoras importantes.

## Futuro

Funcionalidades avanzadas.

El MVP debe ser realista.

---

# 16. Criterios de aceptación

Deben ser concretos y verificables.

Ejemplos:

* Crear una planificación sin abandonar el Centro de Planificación.
* Asociar activos desde la misma experiencia.
* Seleccionar o crear procedimientos.
* Configurar frecuencia.
* Asignar responsables.
* Revisar configuración.
* Activar planificación.
* Visualizar próximas ejecuciones.
* Acceder a OT generadas.
* Reducir navegación respecto al flujo actual.

---

# 17. Documento final

Genera exactamente:

```text
CENTRO_PLANIFICACION_ALCANCE.md
```

Con estas secciones:

1. Resumen ejecutivo
2. Estado actual
3. Arquitectura funcional actual
4. Flujo actual
5. Problemas detectados
6. Oportunidades
7. Visión del Centro de Planificación
8. Arquitectura funcional propuesta
9. Flujo UX propuesto
10. Pantalla principal
11. Ficha de planificación
12. Creación de planificación
13. Procedimientos
14. Tareas
15. Programación y frecuencia
16. Inspecciones
17. Integración con OT
18. Decisión sobre menús actuales
19. Entidades y relaciones
20. Casos de uso
21. Reglas de negocio
22. MVP
23. Fase 2
24. Fuera de alcance
25. Criterios de aceptación
26. Recomendaciones de implementación

---

# REGLA FINAL

Este documento será utilizado posteriormente por **Claude Design** para crear el artefacto UI/UX.

Por lo tanto:

* Sé específico.
* No seas genérico.
* No inventes funcionalidades existentes.
* Diferencia claramente existente vs propuesta.
* Toma decisiones.
* No te limites a describir.
* Explica qué debe cambiar y por qué.
* Define el comportamiento esperado.
* Define las relaciones funcionales.
* Define los casos de uso.
* Define el alcance.

El documento debe funcionar como:

> **Contrato funcional para el futuro diseño del Centro de Planificación de SIGMA.**
>
