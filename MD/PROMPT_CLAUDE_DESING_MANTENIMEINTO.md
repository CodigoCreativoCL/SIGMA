# SIGMA — Diseño del Centro de Planificación

Quiero que construyas el  **artefacto UI/UX completo del nuevo Centro de Planificación de SIGMA** .

Te adjunto:

```text
CENTRO_PLANIFICACION_ALCANCE.md
```

Este documento es la **fuente funcional principal y contrato de alcance** para este diseño.

Debes leerlo y utilizarlo como base antes de diseñar cualquier pantalla.

---

# 1. OBJETIVO

Transformar la experiencia actual de:

```text
Planificación
Programaciones
Procedimientos
```

en una experiencia integrada:

# Centro de Planificación

El usuario debe poder configurar y administrar mantenimiento desde un único espacio de trabajo.

La interfaz debe hacer que el usuario piense en:

> "Quiero configurar el mantenimiento de este activo."

y NO en:

> "Tengo que entrar a Planificación, después Programaciones y después Procedimientos."

---

# 2. REGLA FUNDAMENTAL

El archivo:

```text
CENTRO_PLANIFICACION_ALCANCE.md
```

define el alcance funcional.

NO inventes funcionalidades fuera de ese alcance.

Si el documento dice que algo debe mantenerse separado, respétalo.

Si existe una decisión funcional en el documento, respétala.

Si existe una funcionalidad marcada como propuesta, puedes representarla visualmente, pero no agregar funcionalidades adicionales sin justificarlo.

---

# 3. NO HAGAS UN SIMPLE REDISEÑO

No quiero que tomes las tres pantallas existentes y las pongas juntas.

Quiero una experiencia completamente coherente.

Debe sentirse como un producto único:

```text
Centro de Planificación
        ↓
Configurar
        ↓
Revisar
        ↓
Activar
```

---

# 4. PRINCIPIOS UX

Prioriza:

### Menos clicks

El usuario debe realizar la menor cantidad posible de acciones.

### Menos modales

Evita modales para procesos principales.

Preferir:

* edición inline;
* panel lateral;
* secciones expandibles;
* tabs internas;
* formularios integrados;
* acciones contextuales.

### Contexto

El usuario debe saber siempre:

* qué está configurando;
* sobre qué activo;
* qué tareas existen;
* qué procedimiento utiliza;
* cuándo se ejecutará;
* quién lo ejecutará.

### Visibilidad

La información importante debe estar disponible sin navegar innecesariamente.

### Rapidez

El usuario debe poder crear o modificar una planificación rápidamente.

---

# 5. EXPERIENCIA PRINCIPAL

Diseña como mínimo:

## A. Dashboard / listado del Centro de Planificación

Debe permitir:

* Buscar.
* Filtrar.
* Crear.
* Editar.
* Duplicar.
* Activar/desactivar.
* Ver estado.
* Ver próxima ejecución.
* Ver activo.
* Ver frecuencia.
* Ver responsable.
* Acceder al detalle.

Determina la mejor representación:

* Tabla.
* Cards.
* Vista híbrida.

No utilices una tabla si visualmente existe una alternativa claramente mejor.

---

# 6. B. CREAR PLANIFICACIÓN

Diseña la experiencia completa.

Debe permitir configurar, según el alcance funcional:

### Qué mantener

Activo/equipo/instalación/ubicación.

### Qué hacer

Tareas/actividades.

### Cómo hacerlo

Procedimiento/instrucciones/inspecciones/mediciones cuando corresponda.

### Cuándo

Frecuencia/calendario/repetición/exclusiones.

### Quién

Técnicos/responsables.

### Revisión

Resumen antes de activar.

---

# 7. EVITAR WIZARDS EXCESIVOS

No diseñes automáticamente:

```text
Paso 1
Paso 2
Paso 3
Paso 4
Paso 5
Paso 6
```

si puede resolverse mejor mediante un workspace.

Quiero evaluar una experiencia donde el usuario pueda ver diferentes bloques de configuración en un mismo contexto.

Por ejemplo:

```text
┌─────────────────────────────────────────────┐
│ Nueva planificación                         │
│                                             │
│ Información general                         │
│                                             │
│ Activos                                     │
│ ┌─────────────────────────────────────────┐ │
│ │ Compresor Línea 1                  ✓    │ │
│ │ Compresor Línea 2                  ✓    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Actividades                                 │
│ ┌─────────────────────────────────────────┐ │
│ │ Cambio de aceite                        │ │
│ │ Inspección de temperatura               │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Procedimiento                               │
│ [ Procedimiento mantenimiento motor    ]    │
│                                             │
│ Frecuencia                                  │
│ [ Cada 30 días ]                            │
│                                             │
│ Responsable                                 │
│ [ Equipo mantenimiento ]                    │
│                                             │
│                              [Activar]      │
└─────────────────────────────────────────────┘
```

Esto es solo una referencia conceptual.

Diseña la solución que consideres mejor según el MD.

---

# 8. FICHA DE PLANIFICACIÓN

Diseña una vista de detalle que permita comprender rápidamente:

```text
Qué
Dónde
Sobre qué
Cómo
Cuándo
Quién
```

Debe mostrar:

* estado;
* activo;
* procedimiento;
* tareas;
* frecuencia;
* próxima ejecución;
* responsables;
* historial relevante;
* acciones disponibles.

Debe ser posible editar información importante sin abandonar la ficha.

---

# 9. PROCEDIMIENTOS

El usuario debe poder:

* seleccionar un procedimiento existente;
* visualizar su información;
* asociarlo;
* cuando el alcance lo permita, crear uno nuevo desde el contexto de planificación.

Evita enviar al usuario a otra página sin necesidad.

Si se requiere una edición más profunda, utiliza una experiencia apropiada como:

* panel lateral;
* sección expandible;
* vista integrada;

según lo definido en el MD.

---

# 10. TAREAS

Las tareas deben ser fáciles de:

* agregar;
* eliminar;
* ordenar;
* editar;
* asociar.

Si existe información relevante como:

* duración;
* responsable;
* evidencia;
* medición;
* procedimiento;

debe mostrarse de forma contextual.

No sobrecargar la interfaz.

---

# 11. PROGRAMACIÓN

La frecuencia debe ser extremadamente fácil de configurar.

Ejemplos:

```text
Cada día
Cada semana
Cada 15 días
Cada mes
Cada X horas
Según calendario
```

La interfaz debe mostrar inmediatamente una representación comprensible de:

> Próxima ejecución: lunes 12 de octubre.

No obligar al usuario a interpretar configuraciones técnicas.

---

# 12. ESTADOS

Diseña estados claros para:

* Borrador.
* Activa.
* Inactiva.
* Próxima ejecución.
* Vencida.
* Con problemas/configuración incompleta.

Utiliza jerarquía visual clara.

No abusar de colores ni badges.

---

# 13. VALIDACIONES

Las validaciones deben aparecer:

* cerca del campo;
* en contexto;
* de manera comprensible.

Evitar mensajes genéricos como:

> "Error al guardar."

Preferir:

> "La planificación necesita al menos un activo."

---

# 14. DISEÑO VISUAL SIGMA

Mantén la identidad visual existente de SIGMA.

El resultado debe sentirse:

* moderno;
* corporativo;
* tecnológico;
* limpio;
* profesional;
* comercial;
* práctico.

No quiero un dashboard genérico de SaaS.

No quiero exceso de:

* gradientes;
* glassmorphism;
* sombras;
* bordes;
* tarjetas innecesarias;
* elementos "AI-looking";
* decoraciones que no aporten funcionalidad.

La prioridad es:

**claridad + productividad + jerarquía visual.**

---

# 15. COMPONENTES

Utiliza componentes consistentes y reutilizables.

Define visualmente:

* botones;
* inputs;
* selects;
* tablas;
* filtros;
* badges;
* estados;
* tabs;
* dropdowns;
* paneles;
* listas;
* empty states;
* loading;
* errores;
* confirmaciones.

---

# 16. RESPONSIVE

Aunque el foco principal sea escritorio, el diseño debe considerar:

* desktop;
* tablet;
* resoluciones menores.

No sacrificar la experiencia desktop para intentar convertir todo en mobile.

---

# 17. DATOS REALISTAS

Utiliza datos realistas de mantenimiento industrial.

Ejemplo:

```text
Compresor Atlas Copco GA75
Horno Línea 2
Bomba Hidráulica PH-204
Transportador Principal TP-01
```

No utilices:

```text
Lorem ipsum
Item 1
Test
Demo
Example
```

---

# 18. CASOS DE USO A REPRESENTAR

El artefacto debe permitir visualizar como mínimo:

1. Listado de planificaciones.
2. Crear planificación.
3. Asociar activo.
4. Agregar tareas.
5. Seleccionar procedimiento.
6. Configurar frecuencia.
7. Asignar responsable.
8. Revisar configuración.
9. Activar.
10. Editar planificación.
11. Duplicar.
12. Desactivar.
13. Ver próximas ejecuciones.
14. Acceder a las OT generadas.

---

# 19. NO DISEÑAR FUNCIONALIDADES FUERA DE ALCANCE

Si el MD no define algo:

No lo agregues automáticamente.

Si consideras que algo es necesario para UX, puedes incorporarlo únicamente si:

1. Es estrictamente necesario para representar una funcionalidad definida.
2. No cambia el alcance funcional.
3. Es una decisión de presentación/interacción.

---

# 20. ENTREGA

Quiero un  **artefacto funcional de alta fidelidad** , no solamente wireframes.

Debe poder utilizarse para:

* validar la propuesta con usuarios;
* presentar la nueva experiencia;
* discutirla con el equipo;
* posteriormente llevarla a implementación.

El artefacto debe representar:

* navegación;
* estados;
* interacciones;
* formularios;
* tablas;
* filtros;
* creación;
* edición;
* detalle;
* validaciones;
* estados vacíos;
* confirmaciones;
* acciones.

---

# 21. CRITERIO DE ÉXITO

El resultado será exitoso si un usuario que nunca ha visto la arquitectura interna de SIGMA puede entender intuitivamente:

> "Aquí configuro todo el mantenimiento planificado de mis activos."

y puede completar el flujo:

```text
Crear
 ↓
Configurar qué
 ↓
Configurar qué hacer
 ↓
Configurar cómo
 ↓
Configurar cuándo
 ↓
Configurar quién
 ↓
Revisar
 ↓
Activar
```

sin tener que comprender la separación técnica entre:

**Planificación + Programaciones + Procedimientos.**

---

# 22. RESULTADO FINAL

No quiero solamente una pantalla bonita.

Quiero un  **producto UI/UX coherente** , donde todas las vistas formen parte del mismo Centro de Planificación.

El diseño debe responder visualmente:

> ¿Dónde estoy?

> ¿Qué estoy configurando?

> ¿Qué me falta?

> ¿Qué va a ocurrir?

> ¿Cuándo ocurrirá?

> ¿Quién lo ejecutará?

> ¿Puedo activarlo?

> ¿Qué mantenimiento generará?

Utiliza el archivo `CENTRO_PLANIFICACION_ALCANCE.md` como fuente funcional y construye sobre él el artefacto completo.
