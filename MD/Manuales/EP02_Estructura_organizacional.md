# EP-02 - Estructura organizacional

> Representar la organización real del cliente: sus plantas, sus áreas, sus centros de costo y su gente.

**Manual de operacion.** Como se usa este modulo, paso a paso. Se genera desde el Product Backlog y desde la tabla `Menus` de la base, asi que dice lo mismo que hace el sistema.

## 1. Donde esta en el menu

| Pantalla | Ruta en el menu | Pestanas | Permiso que exige |
|---|---|---|---|
| Identidad | Cliente > Identidad | - | Ver la identidad del cliente |
| Plantas | Cliente > Organización > Plantas | - | Ver las plantas del cliente |
| Áreas | Cliente > Organización > Áreas | - | Ver las áreas de una planta |
| Centros de costo | Cliente > Organización > Centros de costo | - | Ver los centros de costo |
| Especialidades | Cliente > Usuarios > Especialidades | - | Ver las especialidades de un usuario |
| Grupos | Cliente > Usuarios > Grupos | - | Ver los grupos de trabajo |
| Planta (detalle) *(se abre desde otra pantalla)* | Cliente > Organización > Planta (detalle) | - | Ver las plantas del cliente |
| Área (detalle) *(se abre desde otra pantalla)* | Cliente > Organización > Área (detalle) | - | Ver las áreas de una planta |
| Centro de costo (detalle) *(se abre desde otra pantalla)* | Cliente > Organización > Centro de costo (detalle) | - | Ver los centros de costo |
| Grupo de trabajo (detalle) *(se abre desde otra pantalla)* | Cliente > Usuarios > Grupo de trabajo (detalle) | Datos / Integrantes | Ver los grupos de trabajo |
| Especialidad de usuario (detalle) *(se abre desde otra pantalla)* | Cliente > Usuarios > Especialidad de usuario (detalle) | - | Ver las especialidades de un usuario |

## 2. Que permisos hacen falta

Sin estos permisos el modulo no se ve, y la accion se rechaza en el servidor aunque se intente por otra via:

- **Ver la identidad del cliente**
- **Ver las especialidades de un usuario**
- **Ver las plantas del cliente**
- **Ver las áreas de una planta**
- **Ver los centros de costo**
- **Ver los grupos de trabajo**

## 3. Que tiene que existir antes

Este modulo se apoya en lo que construyeron otros. Si falta algo de esto, las pantallas se abren pero no se puede completar la operacion:

- [ ] `HU-006` - Aplicar mis permisos en la interfaz y en el servidor
- [ ] `HU-010` - Administrar clientes de SIGMA
- [ ] `HU-011` - Administrar las plantas del cliente
- [ ] `HU-014` - Administrar usuarios del cliente

## 4. Paso a paso

### HU-014 - Administrar usuarios del cliente

**Para que.** Como administrador del cliente, crear usuarios y asignarles perfil, plantas y especialidades, que cada persona ingrese con lo que le corresponde.

*Web - Sprint 1*

**Donde se hace:** Nuevo usuario del cliente

**Como se llega:** Cliente > Usuarios > Usuarios > se abre Nuevo usuario del cliente

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| RUT | Texto con máscara | Si | Dígito verificador válido. Único por cliente |
| Nombres | Texto | Si | Máximo 100 caracteres |
| Apellidos | Texto | Si | Máximo 100 caracteres |
| Correo electrónico | Texto (email) | Si | Único en la plataforma |
| Teléfono | Texto con máscara | No | Formato +56 9 XXXX XXXX |
| Perfil | Lista desplegable | Si | Del catálogo de perfiles del cliente |
| Plantas asignadas | Casillas múltiples | Si | Al menos una planta |
| Vigente desde | Selector de fecha | No | Por defecto la fecha actual |
| Vigente hasta | Selector de fecha | No | Vacío indica sin vencimiento |
| Habilitado | Interruptor | Si | Activo por defecto |

**Como saber que quedo bien:**

1. **Alta de usuario** - Cuando registro un usuario con correo, perfil y al menos una planta Entonces queda habilitado para iniciar sesión Y su correo es único en toda la plataforma
2. **Usuario sin planta** - Cuando intento guardar un usuario sin ninguna planta asignada Entonces la operación es rechazada con "Debe asignar al menos una planta"
3. **Vigencia en la planta** - Cuando asigno una planta con fecha de término Entonces el usuario deja de ver esa planta al vencer la fecha


### HU-015 - Administrar perfiles y sus permisos

**Para que.** Como administrador del cliente, definir qué puede hacer cada perfil, reflejar en el sistema cómo se reparten las responsabilidades en la planta.

*Web - Sprint 1*

**Donde se hace:** Perfil (detalle)

**Como se llega:** Sistema > Acceso > Perfiles > se abre Perfil (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Nombre del perfil | Texto | Si | Único por cliente |
| Tipo de perfil | Lista desplegable | Si | Del catálogo de tipos de perfil |
| Descripción | Texto multilinea | No | Máximo 500 caracteres |
| Permisos | Árbol de casillas agrupado por módulo | No | Del catálogo de permisos |

**Como saber que quedo bien:**

1. **Asignar permisos a un perfil** - Cuando marco los permisos de un perfil y guardo Entonces todos los usuarios con ese perfil los reciben en su siguiente ingreso
2. **Perfil en uso** - Cuando intento eliminar un perfil con usuarios asignados Entonces la operación es rechazada e indica cuántos usuarios lo tienen
3. **Facultad de cierre** - Dado el perfil Técnico de mantenimiento Entonces el permiso de cerrar órdenes de trabajo no puede activarse Y el sistema explica que esa facultad corresponde a jefatura, supervisión o planificación


### HU-011 - Administrar las plantas del cliente

**Para que.** Como administrador del cliente, registrar las plantas o instalaciones de la empresa, poder separar la operación por ubicación física.

*Web - Sprint 1*

**Donde se hace:** Planta (detalle)

**Como se llega:** Cliente > Organización > Plantas > se abre Planta (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Mayúsculas sin espacios. Único por cliente |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Dirección | Texto | No | Máximo 300 caracteres |
| Zona horaria | Lista desplegable | No | Vacío hereda la del cliente |
| Latitud | Numérico decimal | No | Entre -90 y 90 |
| Longitud | Numérico decimal | No | Entre -180 y 180 |

**Como saber que quedo bien:**

1. **Alta de planta** - Cuando registro una planta con su código y dirección Entonces queda disponible para asociarle áreas, activos y usuarios Y su código es único dentro del cliente
2. **Zona horaria propia** - Dado que una planta está en una zona horaria distinta a la del cliente Cuando le asigno su propia zona horaria Entonces las programaciones de esa planta se calculan con esa zona


### HU-012 - Administrar las áreas de una planta

**Para que.** Como administrador del cliente, organizar la planta en áreas y subareas, agrupar activos e indicadores por zona productiva.

*Web - Sprint 1*

**Donde se hace:** Área (detalle)

**Como se llega:** Cliente > Organización > Áreas > se abre Área (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Planta | Lista desplegable | Si | Plantas del cliente |
| Área superior | Selector de árbol | No | Vacío indica área de primer nivel |
| Código | Texto | Si | Mayúsculas sin espacios. Único por planta |
| Nombre | Texto | Si | Máximo 200 caracteres |
| Tipo de área | Lista desplegable | No | Del catálogo de tipos de área |
| Descripción | Texto multilinea | No | Máximo 500 caracteres |

**Como saber que quedo bien:**

1. **Jerarquía de áreas** - Cuando creo el área Línea 1 dentro del área Producción Entonces Línea 1 aparece anidada bajo Producción en el árbol Y los indicadores de Producción suman los de sus áreas hijas
2. **Ciclo prohibido** - Cuando intento asignar como área superior a una de sus propias descendientes Entonces la operación es rechazada con "Un área no puede depender de si misma"


### HU-010 - Administrar clientes de SIGMA

**Para que.** Como administrador de SIGMA, dar de alta y mantener los clientes de la plataforma, incorporar una empresa nueva sin intervenir la base de datos.

*Web - Sprint 1*

**Donde se hace:** Cliente (detalle)

**Como se llega:** Comercial > Clientes > se abre Cliente (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| RUT | Texto con máscara | Si | Dígito verificador válido. Único en la plataforma |
| Razón social | Texto | Si | Máximo 200 caracteres |
| Nombre de fantasía | Texto | No | Máximo 200 caracteres |
| País | Lista desplegable | Si | Del catálogo de países |
| Zona horaria | Lista desplegable | Si | Del catálogo de zonas horarias |
| Idioma | Lista desplegable | Si | Del catálogo de idiomas |
| Moneda | Lista desplegable | Si | Del catálogo de monedas |
| Logotipo | Carga de imagen | No | PNG o JPG, máximo 1 MB |
| Habilitado | Interruptor | Si | Activo por defecto |

**Como saber que quedo bien:**

1. **Alta de cliente** - Cuando registro un cliente con su RUT y razón social Entonces queda disponible para asignarle usuarios, plantas y suscripción Y su RUT no puede repetirse en la plataforma
2. **Baja lógica** - Cuando deshabilito un cliente Entonces sus usuarios no pueden iniciar sesión Y su información se conserva integra


### HU-017 - Registrar especialidades y certificaciones de un usuario

**Para que.** Como administrador del cliente, registrar que sabe hacer cada técnico y hasta cuando está certificado, no asignar un trabajo a alguien cuya certificación venció.

*Web - Sprint 1*

**Donde se hace:** Especialidad de usuario (detalle)

**Como se llega:** Cliente > Usuarios > Especialidades > se abre Especialidad de usuario (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Especialidad | Lista desplegable | Si | Del catálogo de especialidades |
| Nivel | Lista desplegable | No | Del catálogo de niveles de especialidad |
| Certificación | Texto | No | Máximo 200 caracteres |
| Vence el | Selector de fecha | No | Vacío indica sin vencimiento |
| Documento del certificado | Carga de archivo | No | PDF o imagen, máximo 5 MB |

**Como saber que quedo bien:**

1. **Alta de especialidad** - Cuando asigno una especialidad a un técnico Entonces esa persona aparece como candidata cuando una orden requiere esa especialidad
2. **Certificación vencida** - Dado que un técnico tiene una especialidad con certificación vencida Cuando se le selecciona para una orden que exige esa especialidad Entonces se muestra la advertencia "Certificación vencida el {fecha}" Y la asignación se permite y la advertencia queda registrada en la orden
3. **Aviso anticipado** - Dado que una certificación vence en menos de 30 días Entonces aparece en el panel de alertas del administrador


### HU-016 - Administrar grupos de trabajo

**Para que.** Como administrador del cliente, agrupar técnicos en cuadrillas o turnos, poder asignar trabajo al turno completo y no a una persona en particular.

*Web - Sprint 1*

**Donde se hace:** Grupo de trabajo (detalle)

**Como se llega:** Cliente > Usuarios > Grupos > se abre Grupo de trabajo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Código | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Ejemplo: Turno noche mecanicos |
| Planta | Lista desplegable | No | Vacío indica grupo transversal al cliente |
| Especialidad predominante | Lista desplegable | No | Del catálogo de especialidades |
| Integrantes | Grilla editable | Si | Al menos un integrante |
| Es líder | Casilla por fila | No | Un único líder vigente por grupo |

**Como saber que quedo bien:**

1. **Alta de grupo** - Cuando creo el grupo Turno noche mecanicos y le asigno integrantes Entonces puedo asignarle órdenes, tareas y checklists
2. **Líder del grupo** - Cuando marco a un integrante como líder Entonces las notificaciones del grupo se dirigen a él Y solo puede haber un líder vigente por grupo
3. **Integrante con vigencia** - Cuando agrego un integrante con fecha de término Entonces deja de pertenecer al grupo al vencer esa fecha


### HU-013 - Administrar centros de costo

**Para que.** Como administrador del cliente, mantener el árbol de centros de costo, poder imputar el gasto de mantenimiento a quien corresponde.

*Web - Sprint 1*

**Donde se hace:** Centro de costo (detalle)

**Como se llega:** Cliente > Organización > Centros de costo > se abre Centro de costo (detalle)

**Que se completa:**

| Campo | Control | Obligatorio | Que valida |
|---|---|---|---|
| Centro de costo superior | Selector de árbol | No | Vacío indica primer nivel |
| Código | Texto | Si | Único por cliente |
| Nombre | Texto | Si | Máximo 200 caracteres |

**Como saber que quedo bien:**

1. **Alta jerárquica** - Cuando creo un centro de costo dependiente de otro Entonces el costo del hijo suma al del padre en los reportes
2. **Código único** - Cuando intento crear un centro de costo con un código ya existente en el cliente Entonces la operación es rechazada


## 5. Lo que el sistema no deja hacer

Estas reglas viven en el servidor, no en la pantalla: se aplican aunque la accion se intente desde la API o desde la app.

- **HU-014 - Usuario sin planta** - Cuando intento guardar un usuario sin ninguna planta asignada Entonces la operación es rechazada con "Debe asignar al menos una planta"
- **HU-015 - Perfil en uso** - Cuando intento eliminar un perfil con usuarios asignados Entonces la operación es rechazada e indica cuántos usuarios lo tienen
- **HU-015 - Facultad de cierre** - Dado el perfil Técnico de mantenimiento Entonces el permiso de cerrar órdenes de trabajo no puede activarse Y el sistema explica que esa facultad corresponde a jefatura, supervisión o planificación
- **HU-012 - Ciclo prohibido** - Cuando intento asignar como área superior a una de sus propias descendientes Entonces la operación es rechazada con "Un área no puede depender de si misma"
- **HU-010 - Alta de cliente** - Cuando registro un cliente con su RUT y razón social Entonces queda disponible para asignarle usuarios, plantas y suscripción Y su RUT no puede repetirse en la plataforma
- **HU-010 - Baja lógica** - Cuando deshabilito un cliente Entonces sus usuarios no pueden iniciar sesión Y su información se conserva integra
- **HU-013 - Código único** - Cuando intento crear un centro de costo con un código ya existente en el cliente Entonces la operación es rechazada

## 6. Si algo no funciona

| Sintoma | Causa mas probable |
|---|---|
| No aparece la opcion en el menu | Falta el permiso de la seccion 2, o la pantalla no tiene su fila en `Menus` |
| La pantalla abre pero el boton no hace nada | Falta el permiso de la funcion: ver no es lo mismo que crear y editar |
| Dice que no se puede guardar, sin mas detalle | Alguna regla de la seccion 5; el mensaje viene del procedimiento almacenado |
| Los combos salen vacios | Falta construir lo de la seccion 3 |
| Estoy en la pantalla correcta y no veo el formulario | Falta pulsar la pestana que indica cada operacion en la seccion 4 |

---

*Generado desde `Fase 2/SIGMA_Product_Backlog_por_Sprint.xlsx`, la tabla `Menus` y las pestanas declaradas en los .aspx. Para actualizarlo: `python _scratch/gen_manuales.py`.*
