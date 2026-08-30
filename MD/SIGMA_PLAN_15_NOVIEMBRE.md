# SIGMA — Plan al 15 de noviembre de 2026

Qué cabe en 88 días con 2 o 3 personas a medio tiempo, qué no, y en qué orden.

Supuestos declarados: la meta es **la defensa del capstone con demo funcionando**; el equipo aporta entre 30 y 60 horas semanales sumadas; **hoy no hay nada construido** salvo los scripts, que aún no se ejecutan; y la app **debe estar publicada en producción** en Google Play.

---

## 1. La respuesta corta

**Sí, se alcanza la defensa. No se alcanza a construir el modelo completo, y no hace falta que se alcance.**

| | |
|---|---|
| Días disponibles | **88** (12,6 semanas) |
| Presupuesto de horas del equipo | 380 – 750 h · punto medio **≈ 566 h** |
| Estimación del alcance recortado | **≈ 620 h** |
| Veredicto | **Alcanzable, sin holgura.** Solo funciona con el recorte de la sección 3 |
| Infraestructura | **SmarterASP .NET Premium**, USD 12,50/mes · 3 meses cubren hasta el 19 de noviembre |

Las 250 tablas del modelo **no se construyen**: se construye el hilo completo de una, y las demás quedan modeladas y con script. Para una defensa eso es lo correcto — un sistema angosto y profundo se demuestra; uno ancho y a medias, no.

**Y hay una fecha que ya está corriendo, que no depende de programar y que puede hundir el proyecto entero.**

> **Antes de nada, confirmar la fecha.** El 15 de noviembre de 2026 **cae domingo**. Si la defensa es el viernes 13 hay dos días menos, y si es la entrega del informe la fecha puede ser incluso anterior. Todo el plan de abajo se corre hacia atrás lo que corresponda, y lo que primero se aprieta es el margen de revisión de Google. Averiguarlo esta semana cuesta un correo.

---

## 2. La restricción que manda: Google Play

Publicar en producción exige, para cuentas personales creadas después del 13-11-2023, **12 testers activos durante 14 días seguidos** antes de siquiera poder solicitar el acceso a producción. Esos 14 días no se compran, no se aceleran y no se negocian.

Retroplanificando desde el 15 de noviembre:

| Fecha límite | Hito | Por qué esa fecha |
|---|---|---|
| **esta semana** | **Crear la cuenta de desarrollador y verificar identidad** | Requiere documento y tarjeta; la verificación tarda días y bloquea todo lo demás |
| **esta semana** | **Tener la lista de 12 testers con su correo Google** | Personas reales que instalen y **no se salgan** en 14 días. Es coordinación, no programación |
| **15 de octubre** | **APK firmado subido a Play** | Deja una semana para ficha de tienda, política de privacidad y formulario de seguridad de datos |
| **22 de octubre** | **Arranca la prueba cerrada** | 14 días continuos → termina el 5 de noviembre |
| **5 de noviembre** | **Solicitar acceso a producción** | Deja 10 días de margen |
| 15 de noviembre | Defensa | La revisión suele tardar horas o pocos días, pero **puede llegar a 7** |

> **La consecuencia:** la app no tiene 12,6 semanas. **Tiene 8.** Todo lo que la app deba hacer en la demo tiene que estar funcionando el **15 de octubre**, no el 15 de noviembre.

Tres cosas que conviene saber antes de comprometerse:

- **Un rechazo reinicia la revisión.** Si Google devuelve el build el 6 de noviembre, se sube otro y empieza un nuevo período de revisión. Por eso el margen de 10 días no es exceso de precaución.
- **Los testers que se salen no cuentan.** Quien entra, prueba 5 días y se va, no suma. Hay que elegir 12 personas que no se vayan a desinstalar — compañeros, gente de Hamburgo, familia — y avisarles explícitamente que no borren la app hasta el 5 de noviembre.
- **Conviene reclutar 15, no 12.** Sale gratis y cubre las bajas.

### 2.1 El plan B, por si el calendario se rompe

Si el 15 de octubre la app no está lista para subir, **publicar en producción deja de ser posible** y hay que decidirlo ese día, no en noviembre. La alternativa es demostrar con un APK instalado a mano o con el canal de prueba interna, que no exige los 12 testers.

Eso hay que conversarlo **ahora** con quien evalúa: si la publicación en la tienda es un requisito de la rúbrica, es un riesgo de proyecto; si no lo es, es un lujo que se puede soltar sin costo.

---

## 3. Qué se construye y qué se documenta

El criterio de corte es uno solo: **¿aparece en la demo?** Lo que no aparece, queda modelado, con script de tablas y explicado en los anexos — que es exactamente lo que se está entregando como trabajo de modelado.

### 3.1 El hilo de la demo

Todo el recorte se ordena alrededor de esta secuencia. Si algo no sirve para contarla, no se construye:

1. Ingresa el planificador de Hamburgo — se ve que el sistema es multicliente
2. Abre la ficha de un blower: posición funcional, componentes, criticidad
3. Crea un plan de mantenimiento con recurrencia — el motor genera la OT
4. El técnico abre la app **sin señal** y ejecuta el checklist
5. **Dicta la observación por voz** — con el motor del teléfono, sin señal — porque tiene las manos con aceite
6. Saca una foto, que queda en Blob
7. **Descubre un componente no registrado y lo crea en terreno**
8. Recupera señal y **sincroniza**
9. El planificador ve la OT cerrada, el historial del componente y un indicador
10. El modelo predictivo estima vida útil restante
11. Se vence la suscripción, **el sistema bloquea** y ofrece renovar con comprobante

Once pasos. Cada uno es una decisión de diseño que ya está documentada y defendida en los anexos, lo cual es la mitad del trabajo de una defensa.

### 3.2 El corte, bloque por bloque

Sobre los 14 bloques del orden de construcción del documento de reunión:

| Bloque | Decisión | Qué se hace |
|---|:--:|---|
| 0 · Saneamiento | **construir** | Completo. Es la base de todo |
| 1 · Fundaciones | **construir** | Login, multicliente, perfiles, permisos por usuario |
| 2 · Activos | **construir** | Completo — es el corazón de la demo |
| 3 · Medición | **recortar** | Solo horómetro y una variable de condición. Sin el catálogo completo de variables |
| 4 · Repuestos | **recortar fuerte** | Solo consumo de repuesto dentro de la OT. **Sin bodega, lote, saldo ni movimiento** |
| 5 · Programación | **construir** | Completo. Es el motor y es lo más demostrable del modelo |
| 6 · Terceros | **no construir** | Modelado y documentado. No aparece en la demo |
| 7 · Checklist | **construir** | Completo, incluida la versión publicada inmutable |
| 8 · Tareas | **no construir** | La OT cuenta el mismo relato. Se explica el modelo |
| 9 · Bitácora | **recortar** | Solo el registro de texto y voz dentro de la OT |
| **Voz** | **construir** | Dictado y lectura con el motor del teléfono. **Se simplificó**: sin nube, sin cuotas, sin función que elija motor |
| 10 · Planes | **construir** | Completo — plan, hito, actividad |
| 11 · Órdenes de trabajo | **recortar** | Todo menos permisos de trabajo |
| 12 · Evidencias | **recortar** | Blob y fotos sí. **Análisis visual no** |
| 13 · Inteligencia artificial | **recortar** | El pipeline completo, entrenado con datos sintéticos. Ver 3.3 |
| 14 · Importación | **no construir** | La carga de la demo se hace por script |
| **78 catálogos** | **recortar** | Se cargan con `04_CATALOGOS_SIGMA.sql`. Mantenedor solo para los **10 ampliables** |

Lo que ese corte ahorra es sobre todo interfaz: **no construir 68 mantenedores de catálogo** es la diferencia entre llegar y no llegar.

### 3.3 El problema del predictivo, dicho antes de que lo pregunten

**No hay datos históricos con qué entrenar.** El modelo predictivo necesita series de mediciones a lo largo del tiempo terminadas en fallas confirmadas, y esos datos no existen todavía — la razón misma de construir SIGMA es empezar a capturarlos.

Es una limitación real y hay dos maneras de tratarla. Una es esconderla y esperar que nadie pregunte. La otra, que recomiendo:

> Entrenar con **datos sintéticos generados a propósito** — curvas de degradación de vibración y temperatura que terminan en falla — y **decirlo explícitamente en la defensa**. Lo que se demuestra es que el *pipeline* funciona de extremo a extremo: dataset, entrenamiento, versión ONNX, inferencia dentro de la API, predicción, explicación y registro del resultado real para reentrenar.

Eso es defendible y además es la verdad del ciclo de vida de cualquier sistema predictivo: **el primer año se recolecta, el segundo se predice.** Ya está escrito así en el modelo comercial, donde el plan FULL con predictivo se vende a partir del mes 12. La coherencia entre el modelo de negocio y la limitación técnica juega a favor, no en contra.

Los 7.043 registros de la matriz de OT de Hamburgo sí sirven, y conviene usarlos: dan un historial de OT realista para poblar la demo.

---

## 4. El plan semana a semana

Dos pistas en paralelo. Con 3 personas: una en la pista A, una en la B, y la tercera se reparte. **Con solo 2 personas el riesgo sube mucho** — ver sección 5.

| Semana | Fechas | Pista A · Base y web | Pista B · API y app |
|:--:|---|---|---|
| **S0** | 19 – 23 ago | Contratar Premium. Ejecutar los scripts 00-09, **dos veces**. Crear la base de pruebas aparte | **Cuenta Google Play + verificación**. Reclutar 15 testers. Desplegar web y API como **dos sitios** |
| **S1** | 24 – 30 ago | Bloque 0 y 1: saneamiento, login, multicliente, perfiles | Esqueleto de la API con validación de KEY. Esqueleto Flutter: login y base local |
| **S2** | 31 ago – 6 sep | Bloque 2: activos, posiciones, componentes | Endpoints de catálogos y activos. Sincronización descendente |
| **S3** | 7 – 13 sep | Bloque 2 (cierre) y bloque 3 recortado | Flutter: lista de activos **funcionando sin señal** |
| **S4** | 14 – 20 sep | Bloque 5: motor de programación completo | Endpoints de OT. Flutter: bandeja de trabajo |
| **S5** | 21 – 27 sep | Bloque 7: checklist con versión publicada | Flutter: ejecutar checklist y capturar respuestas |
| **S6** | 28 sep – 4 oct | Bloque 10 y 11: planes y OT en la web | **Voz**: dictado y lectura, todo en el dispositivo. Sin nube, sin cuotas, sin API de voz |
| **S7** | 5 – 11 oct | Cierre de OT, historial, registro en terreno en la web | **Fotos a Blob. Sincronización bidireccional completa** |
| **S8** | 12 – 18 oct | Suscripción, bloqueo y pantalla de renovación | ⚠️ **15 oct: APK a Play.** Ficha, privacidad, seguridad de datos |
| **S9** | 19 – 25 oct | Indicadores y reportes | ⚠️ **22 oct: arranca la prueba cerrada.** Corregir solo lo crítico |
| **S10** | 26 oct – 1 nov | Carga de los datos de demo de Hamburgo | Pipeline ML con datos sintéticos, ONNX dentro de la API |
| **S11** | 2 – 8 nov | Ensayo cronometrado de la demo. Documento de defensa | ⚠️ **5 nov: solicitar acceso a producción** |
| **S12** | 9 – 15 nov | **Margen.** Ensayos finales | Revisión de Google. Margen para un rechazo |

**La única holgura real del plan es la semana 12**, y está comprometida con la revisión de Google. Cualquier atraso de más de una semana en la pista B se come el margen completo.

### 4.1 Los tres hitos que no se mueven

Si uno de estos se pasa, hay que **cambiar el plan ese mismo día**, no esperar:

1. **15 de octubre — APK a Play.** Si no está, se cae la publicación en producción.
2. **22 de octubre — arranca la prueba cerrada.** Es la última fecha compatible con los 14 días.
3. **5 de noviembre — solicitud de producción.** Con menos margen, un rechazo mata la fecha.

---

## 5. Los cinco riesgos, con fecha de chequeo

Un riesgo sin fecha de verificación es una preocupación. Éstos tienen fecha:

| Riesgo | Probabilidad | **Se verifica** | Qué se hace si se confirma |
|---|:--:|:--:|---|
| ~~ONNX Runtime no cabe en los 256 MB del app pool~~ | **Resuelto** | S0, igual | **Se compró el plan Premium: 3 GB de app pool.** Se mide de todos modos en S0, pero como verificación, no como riesgo abierto |
| **La app no está lista el 15 de octubre** | **Alta** | S6, no S8 | Soltar la publicación en producción y demostrar con prueba interna o APK. **Decidirlo en S6** |
| **Los 12 testers no se sostienen 14 días** | Media | S9 semanal | Por eso se reclutan 15. Revisar la cuenta de activos cada semana |
| **Solo hay 2 personas efectivas** | Media | S1 | Recortar más: sacar el registro en terreno y la lectura por voz de la demo. Avisar en la reunión, no en octubre |
| **Desplegar la web y la API en SmarterASP falla** | Media | **S0** | Es configuración de IIS: barata en agosto y carísima en noviembre. Con Premium van como **dos sitios separados**, cada uno con su app pool |

El riesgo de despliegue se verifica en **S0** deliberadamente: es barato de comprobar ahora y devastador de descubrir tarde. **Desplegar un «hola mundo» a SmarterASP esta semana vale más que cualquier avance funcional.**

El riesgo que encabezaba esta tabla — si el predictivo cabía en memoria — **se resolvió comprando el plan Premium**, que da 3 GB de app pool en vez de 256 MB, 10 GB por base en vez de 1 GB y sitios ilimitados en vez de uno. Por USD 12,50 al mes se cerraron de una vez los dos mayores riesgos técnicos del proyecto y se ganó, de paso, una base separada para pruebas.

---

## 6. Qué hacer esta semana

En orden, y lo primero no es programar:

1. **Crear la cuenta de Google Play y hacer la verificación de identidad.** Es el único trabajo cuyo retraso no se puede recuperar con horas extra.
2. **Armar la lista de 15 testers** con nombre y correo Google, y avisarles el compromiso: instalar cuando se les pida y **no desinstalar hasta el 5 de noviembre**.
3. **Ejecutar los scripts 00 a 09** en la base de SmarterASP, dos veces, verificando que la segunda no rompe nada.
4. **Desplegar un proyecto ASP.NET vacío**, con la web y la API como **dos sitios separados** — ahora que el Premium lo permite — y comprobar que la configuración funciona.
5. **Crear la base de pruebas aparte de la de producción.** El plan trae 20 bases; usar una sola para desarrollar y demostrar es pedir un accidente la semana de la defensa.
6. **Llevar este plan a la reunión** y acordar el recorte de la sección 3. El recorte funciona si el equipo lo comparte; si cada uno construye lo que le parece, no alcanza.

---

## 7. Lo que hay que decir en la defensa

El recorte no es una deuda que esconder, es una decisión que se explica:

> El modelo de datos cubre **250 tablas en 15 dominios**, verificadas sin colisiones de prefijo, con catálogos relacionales, multicliente por clave foránea compuesta, y decisiones documentadas sobre estados derivables, congelamiento de versiones y trazabilidad. La implementación construye **el hilo completo de un caso de uso de punta a punta** — del plan de mantenimiento a la orden de trabajo ejecutada por voz sin señal y sincronizada — porque un sistema angosto y profundo demuestra que el modelo funciona, y uno ancho y a medias no demuestra nada.

Eso es más fuerte que mostrar sesenta mantenedores de catálogo, y además es verdad.

---

*Plan construido sobre datos verificados en agosto de 2026: [requisitos de prueba cerrada de Google Play](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) · [registro de desarrollador](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en) · [planes de SmarterASP.NET](https://www.smarterasp.net/hosting_plans). Las estimaciones de esfuerzo son estimaciones, no mediciones: revisar el avance real contra este plan al cierre de la semana 3 y ajustar el recorte si la velocidad no es la supuesta.*
