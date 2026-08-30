USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  20-08-2026
-- DESCRIPTION:     ORQUESTADOR: EJECUTA TODOS LOS BLOQUES EN ORDEN.
-- =============================================
--
-- COMO SE EJECUTA
--   1. Abrir este archivo en SSMS
--   2. Menu Query -> SQLCMD Mode  (SIN esto, los :r fallan)
--   3. Ajustar la ruta de $(RUTA) mas abajo
--   4. Ejecutar
--
--   Si el modo SQLCMD no esta disponible -- por ejemplo desde el panel web
--   de SmarterASP -- ejecutar los archivos a mano en el orden de la lista.
--
-- EL NUMERO DEL ARCHIVO ES UN NOMBRE, NO UN ORDEN
--   El orden real es ESTA LISTA. Los numeros se conservan porque los
--   documentos y anexos ya los referencian. Dos ejemplos de por que no
--   coinciden:
--     21_FUNDACIONES va TERCERO, no ultimo, porque Activo tiene FK a
--       Instalacion_Area y a Centro_Costo, que se crean ahi.
--     10_REFINAMIENTOS va casi al final porque son ALTER TABLE sobre
--       tablas que crean los bloques 13, 17 y 19.
--
-- EL ORDEN NO ES NEGOCIABLE
--   Cada bloque solo referencia tablas de los bloques anteriores. La
--   unica excepcion son los ciclos reales del modelo -- una medicion
--   puede nacer de una OT y una OT puede registrar mediciones -- y esos
--   se cierran al final, en 22_FK_DIFERIDAS.
--
-- TODOS LOS BLOQUES SON IDEMPOTENTES
--   Se pueden correr dos veces seguidas y la segunda no rompe nada. Eso
--   no es un lujo: es lo que permite reejecutar despues de arreglar un
--   error a mitad de camino, sin borrar la base.
--   La forma de comprobarlo es correrlo dos veces. Hacerlo.
--
-- ANTES DE EMPEZAR: 00_SANEAMIENTO Y 01_REPARACION_NUCLEO
--   Ya no son un aviso: son los dos primeros bloques de la lista.
--   El 00 da de baja 36 objetos legados de SGF que apuntan a tablas
--   inexistentes: 12 triggers TRG_LOG_*, 3 SP SEL_LOG_*, 4 SP de Archivo
--   y 17 SP de Checklist. Los triggers son el bloqueador real: mientras
--   esten vivos, cualquier INSERT sobre Cliente o Usuario falla.
--   El 01 repara DEL_CLIENTE, que queda roto tras el 00.
--   NO SON OPCIONALES NI AUNQUE LA BASE ESTE VACIA.
--
-- EL MODELO SON 232 TABLAS
--   Eran 235 hasta el 28-08-2026. Se restaron Log, Log_Estado y
--   Log_Tabla: nunca existieron en esta base, y el bloque 00 da de baja
--   los 12 triggers que escribian en ellas. La auditoria de SIGMA es el
--   dominio D10 Bitacora, no el log de SGF.
--   210 las crean estos scripts; 22 ya existian en la base legada de SGF
--   (Usuario, Perfiles, Menus, Cliente, Paises...). Al terminar,
--   99_VERIFICACION dice exactamente cuantas hay y cuales faltan.
-- =============================================

:setvar RUTA "C:\Capstone\BD"

PRINT '========================================================'
PRINT ' SIGMA : carga completa del modelo de datos (232 tablas)'
PRINT '========================================================'
GO

-- ── 0. SANEAMIENTO Y REPARACION ────────────────────────────────────
--    Van PRIMERO. El 00 debe correr antes del 18: el bloque 18 crea un
--    [dbo].[Archivo] nuevo y los SP legados de Archivo colisionan con el.
PRINT ''
PRINT '--- 00 SANEAMIENTO (baja de 36 objetos legados) ---'
GO
:r $(RUTA)\00_SANEAMIENTO.sql
GO

PRINT ''
PRINT '--- 01 REPARACION DEL NUCLEO (DEL_CLIENTE) ---'
GO
:r $(RUTA)\01_REPARACION_NUCLEO.sql
GO

-- ── 1. CATALOGOS ────────────────────────────────────────────────────────
--    73 tablas de ids fijos con su carga. Van primero SIEMPRE: todo lo
--    demas les hace FK.
PRINT ''
PRINT '--- 04 CATALOGOS (73 tablas) ---'
GO
:r $(RUTA)\04_CATALOGOS_SIGMA.sql
GO

-- ── 2. FUNDACIONES ──────────────────────────────────────────────────────
--    D1 + D14. Zona horaria, permisos finos, areas, centros de costo.
--    Va TERCERO y no ultimo: Activo tiene FK a Instalacion_Area.
PRINT ''
PRINT '--- 21 FUNDACIONES (12 tablas) ---'
GO
:r $(RUTA)\21_FUNDACIONES_RESTO.sql
GO

-- ── 3. ARCHIVOS ─────────────────────────────────────────────────────────
--    D11 sin Archivo_Vinculo. Temprano porque Dictado_Voz y
--    Suscripcion_Pago tienen FK a Archivo.
PRINT ''
PRINT '--- 18 ARCHIVOS Y ANALISIS VISUAL (5 tablas) ---'
GO
:r $(RUTA)\18_ARCHIVOS.sql
GO

-- ── 4. PERMISOS, VOZ Y MODELO COMERCIAL ─────────────────────────────────
PRINT ''
PRINT '--- 06 PERMISOS POR USUARIO (1 tabla) ---'
GO
:r $(RUTA)\06_PERMISOS_USUARIO.sql
GO

PRINT ''
PRINT '--- 07 VOZ E INCLUSION (2 tablas; los enganches van en el 24) ---'
GO
:r $(RUTA)\07_VOZ_INCLUSION.sql
GO

PRINT ''
PRINT '--- 08 SUSCRIPCION Y MODELO COMERCIAL (10 tablas) ---'
GO
:r $(RUTA)\08_SUSCRIPCION.sql
GO

-- ── 5. NUCLEO TECNICO ───────────────────────────────────────────────────
--    D2 + D3. Todo el resto del modelo cuelga de Activo.
PRINT ''
PRINT '--- 11 ACTIVOS Y MEDICIONES (15 tablas) ---'
GO
:r $(RUTA)\11_ACTIVOS_MEDICIONES.sql
GO

PRINT ''
PRINT '--- 12 REPUESTOS E INVENTARIO (8 tablas) ---'
GO
:r $(RUTA)\12_REPUESTOS_INVENTARIO.sql
GO

PRINT ''
PRINT '--- 13 MOTOR DE PROGRAMACION (9 tablas) ---'
GO
:r $(RUTA)\13_PROGRAMACION.sql
GO

-- ── 6. TERCEROS Y ALERTAS ───────────────────────────────────────────────
--    Antes de los planes: Plan_Mantenimiento_Actividad -> Procedimiento.
PRINT ''
PRINT '--- 19 TERCEROS, PROCEDIMIENTOS Y ALERTAS (5 tablas) ---'
GO
:r $(RUTA)\19_TERCEROS_ALERTAS.sql
GO

-- ── 7. EL TRABAJO ───────────────────────────────────────────────────────
--    Checklist va ANTES que planes: Plan_Actividad_Checklist tiene FK a
--    Checklist_Plantilla_Version. El checklist no depende de los planes.
PRINT ''
PRINT '--- 15 CHECKLIST DINAMICO (15 tablas) ---'
GO
:r $(RUTA)\15_CHECKLIST.sql
GO

PRINT ''
PRINT '--- 14 PLANES DE MANTENIMIENTO (10 tablas) ---'
GO
:r $(RUTA)\14_PLANES.sql
GO

PRINT ''
PRINT '--- 16 TAREAS (9 tablas) ---'
GO
:r $(RUTA)\16_TAREAS.sql
GO

PRINT ''
PRINT '--- 17 ORDENES DE TRABAJO Y FALLAS (17 tablas) ---'
GO
:r $(RUTA)\17_ORDEN_TRABAJO.sql
GO

PRINT ''
PRINT '--- 23 BITACORA (3 tablas) ---'
GO
:r $(RUTA)\23_BITACORA.sql
GO

-- ── 8. INTELIGENCIA ─────────────────────────────────────────────────────
--    D12. El motor de SIGMA Intelligence.
PRINT ''
PRINT '--- 20 MACHINE LEARNING (10 tablas) ---'
GO
:r $(RUTA)\20_MACHINE_LEARNING.sql
GO

-- ── 9. TERRENO ──────────────────────────────────────────────────────────
--    05 necesita Bitacora, OT, Checklist_Ejecucion y Tarea_Ocurrencia.
PRINT ''
PRINT '--- 05 DESCUBRIMIENTO EN TERRENO (4 tablas) ---'
GO
:r $(RUTA)\05_DESCUBRIMIENTO_TERRENO.sql
GO

--    10 son ALTER TABLE sobre tablas de los bloques 13, 17 y 19.
--    Por eso va aqui y no en su numero.
PRINT ''
PRINT '--- 10 REFINAMIENTOS DE TERRENO (1 tabla + ALTERs) ---'
GO
:r $(RUTA)\10_REFINAMIENTOS_TERRENO.sql
GO

--    24 agrega las columnas de voz y modo de entrada a Activo_Medicion,
--    Orden_Trabajo, Checklist_Ejecucion_Respuesta, Bitacora y Falla.
PRINT ''
PRINT '--- 24 ENGANCHES DE VOZ (solo ALTERs) ---'
GO
:r $(RUTA)\24_VOZ_ENGANCHES.sql
GO

-- ── 10. CIERRE DEL GRAFO ────────────────────────────────────────────────
--    Las FK que cruzan dominios hacia atras, mas Archivo_Vinculo.
PRINT ''
PRINT '--- 22 FK DIFERIDAS Y ARCHIVO_VINCULO (1 tabla + 22 FK) ---'
GO
:r $(RUTA)\22_FK_DIFERIDAS.sql
GO

-- ── 10b. MENUS Y PERMISOS DINAMICOS ──────────────────────────────
--    Retiran Paginas.cs: el permiso de cada pagina pasa a resolverse
--    por su propia URL contra Menus.mnu_link. Van al final porque
--    dependen de Permiso y Perfil_Permiso, que crea el bloque 21.
PRINT ''
PRINT '--- 02 MENUS Y PERMISOS (ALTER + catalogo + SP) ---'
GO
:r $(RUTA)\02_MENUS_PERMISOS.sql
GO

PRINT ''
PRINT '--- 03 MANTENEDOR DE MENUS ---'
GO
:r $(RUTA)\03_MANTENEDOR_MENUS.sql
GO

PRINT ''
PRINT '--- 04 EL PERMISO SE RESUELVE POR LA URL ---'
GO
:r $(RUTA)\04_PERMISOS_POR_URL.sql
GO

PRINT ''
PRINT '--- 05 PAGINAS RESTANTES ---'
GO
:r $(RUTA)\05_PAGINAS_RESTANTES.sql
GO

PRINT ''
PRINT '--- 06 ASIGNACION A PERFILES (Accesos.aspx) ---'
GO
:r $(RUTA)\06_ASIGNACION_PERFIL.sql
GO

PRINT ''
PRINT '--- 07 LOS ICONOS DEL MENU PASAN A MDI ---'
GO
:r $(RUTA)\07_ICONOS_MDI.sql
GO

-- ── 10.5. SPRINT 1 Y MODELO COMERCIAL (bloques 25 a 48) ──────────────
--
--   Todo lo que se construyo despues del modelo base. Van en orden
--   numerico porque se apoyan unos en otros: 26 necesita las columnas de
--   25, 36 necesita los permisos de 32, y 48 necesita la suscripcion de 41.
--
--   Los dos bloques de datos demo van al final y aparte. Son los unicos
--   que insertan informacion inventada -el cliente Hamburgo y sus siete
--   usuarios-; para levantar un ambiente limpio, se comentan esas dos
--   lineas y el resto sigue funcionando igual.

PRINT ''
PRINT '--- 25 MODELO DEL SPRINT 1 (columnas nuevas, historial, recuperacion, catalogos) ---'
GO
:r $(RUTA)\25_SPRINT1_MODELO.sql
GO

PRINT ''
PRINT '--- 26 SEGURIDAD: hash con sal, login, recuperacion, permisos ---'
GO
:r $(RUTA)\26_SPRINT1_SEGURIDAD.sql
GO

PRINT ''
PRINT '--- 27 ORGANIZACION: areas y centros de costo ---'
GO
:r $(RUTA)\27_SPRINT1_ORGANIZACION.sql
GO

PRINT ''
PRINT '--- 28 EQUIPOS: especialidades y grupos de trabajo ---'
GO
:r $(RUTA)\28_SPRINT1_EQUIPOS.sql
GO

PRINT ''
PRINT '--- 29 CLIENTE Y PLANTA ---'
GO
:r $(RUTA)\29_SPRINT1_CLIENTE_PLANTA.sql
GO

PRINT ''
PRINT '--- 30 USUARIOS Y PERFILES ---'
GO
:r $(RUTA)\30_SPRINT1_USUARIOS_PERFILES.sql
GO

PRINT ''
PRINT '--- 31 MANTENEDOR GENERICO DE CATALOGOS ---'
GO
:r $(RUTA)\31_SPRINT1_CATALOGOS.sql
GO

PRINT ''
PRINT '--- 32 MENUS Y PERMISOS DEL SPRINT 1 ---'
GO
:r $(RUTA)\32_SPRINT1_MENUS_PERMISOS.sql
GO

PRINT ''
PRINT '--- 33 AJUSTES DE APOYO ---'
GO
:r $(RUTA)\33_SPRINT1_AJUSTES.sql
GO

PRINT ''
PRINT '--- 34 FICHAS DESCUBIERTAS EN LA WEB ---'
GO
:r $(RUTA)\34_SPRINT1_MENUS_WEB.sql
GO

PRINT ''
PRINT '--- 35 ICONOS QUE EXISTEN EN EL MDI INSTALADO ---'
GO
:r $(RUTA)\35_SPRINT1_ICONOS_VALIDOS.sql
GO

PRINT ''
PRINT '--- 36 PERFILES BASE Y SU MATRIZ DE PERMISOS ---'
GO
:r $(RUTA)\36_SPRINT1_PERFILES_BASE.sql
GO

PRINT ''
PRINT '--- 39 IDENTIFICADOR TRIBUTARIO POR PAIS (RUT, RUC, NIT, CUIT) ---'
GO
:r $(RUTA)\39_SPRINT1_IDENTIFICADOR_PAIS.sql
GO

PRINT ''
PRINT '--- 40 UF: carga diaria y arrastre ---'
GO
:r $(RUTA)\40_SUSCRIPCION_UF.sql
GO

PRINT ''
PRINT '--- 41 SUSCRIPCION: planes, periodos y pagos ---'
GO
:r $(RUTA)\41_SUSCRIPCION_SPS.sql
GO

PRINT ''
PRINT '--- 42 ARCHIVOS Y COMPROBANTES ---'
GO
:r $(RUTA)\42_SUSCRIPCION_ARCHIVOS.sql
GO

PRINT ''
PRINT '--- 43 MENUS Y PERMISOS DE COMERCIAL ---'
GO
:r $(RUTA)\43_SUSCRIPCION_MENUS.sql
GO

PRINT ''
PRINT '--- 44 MANTENEDOR DE PLANES CON PRECIO VERSIONADO ---'
GO
:r $(RUTA)\44_PLANES_MANTENEDOR.sql
GO

PRINT ''
PRINT '--- 45 REEMISION DE LA CLAVE DE INTEGRACION ---'
GO
:r $(RUTA)\45_SUSCRIPCION_KEY.sql
GO

PRINT ''
PRINT '--- 46 QUE INCLUYE CADA PLAN ---'
GO
:r $(RUTA)\46_PLAN_FUNCIONALIDADES.sql
GO

PRINT ''
PRINT '--- 47 TOPES DEL PLAN Y ESTADO DE LA SUSCRIPCION ---'
GO
:r $(RUTA)\47_BLOQUE_D_LIMITES.sql
GO

PRINT ''
PRINT '--- 48 QUIEN RENUEVA Y QUIEN NO ENTRA ---'
GO
:r $(RUTA)\48_SUSCRIPCION_ACCESO_PERFIL.sql
GO

PRINT ''
PRINT '--- 49 EL ACCESO DEL USUARIO DE CLIENTE ---'
GO
:r $(RUTA)\49_ACCESO_Y_ARBOL_CLIENTE.sql
GO

PRINT ''
PRINT '--- 50 PLANTA Y ARBOL DE TERCER NIVEL ---'
GO
:r $(RUTA)\50_PLANTA_Y_ARBOL_TERCER_NIVEL.sql
GO

PRINT ''
PRINT '--- 51 UNA SOLA FICHA DE PLANTA ---'
GO
:r $(RUTA)\51_PLANTA_FICHA_UNICA.sql
GO

PRINT ''
PRINT '--- 52 DECISIONES ABIERTAS (perfiles, baja logica, DV por pais) ---'
GO
:r $(RUTA)\52_DECISIONES_ABIERTAS.sql
GO

PRINT ''
PRINT '--- 53 EL ARBOL DEL CLIENTE, POR TEMA ---'
GO
:r $(RUTA)\53_ARBOL_USUARIOS_CONFIGURACION.sql
GO

PRINT ''
PRINT '--- 54 NOMBRES DE MENU MAS CORTOS ---'
GO
:r $(RUTA)\54_MENUS_NOMBRES_CORTOS.sql
GO

PRINT ''
PRINT '--- 55 dbo.SPLIT Y EL CATALOGO DE LA APP ---'
GO
:r $(RUTA)\55_SPLIT_Y_APP.sql
GO

PRINT ''
PRINT '--- 56 GUARDAR UN USUARIO, BIEN ---'
GO
:r $(RUTA)\56_USUARIO_GUARDAR.sql
GO

PRINT ''
PRINT '--- 57 QUE PUEDE HACER LA APP EN CADA PLANTA ---'
GO
:r $(RUTA)\57_APP_FUNCIONALIDADES.sql
GO

-- ── 10.6. DATOS DEMO (opcional: comentar para un ambiente limpio) ────

PRINT ''
PRINT '--- 37 DATOS DEMO: cliente Hamburgo, plantas, areas, grupos ---'
GO
:r $(RUTA)\37_SPRINT1_DATOS_DEMO.sql
GO

PRINT ''
PRINT '--- 38 DATOS DEMO: usuarios ficticios, uno por perfil ---'
GO
:r $(RUTA)\38_SPRINT1_USUARIOS_DEMO.sql
GO
-- ── 11. VERIFICACION ────────────────────────────────────────────────────
PRINT ''
PRINT '--- 99 VERIFICACION DEL ESTADO ---'
GO
:r $(RUTA)\99_VERIFICACION.sql
GO

PRINT ''
PRINT '========================================================'
PRINT ' Fin. Revisar la salida de 99_VERIFICACION:'
PRINT '   - cuadro 2: debe decir 232 de 232'
PRINT '   - cuadro 3: que falta, y que bloque lo crea'
PRINT '   - cuadro 4: catalogos creados pero VACIOS (rompen FK)'
PRINT '   - cuadro 6: FK, CHECK y PK creadas'
PRINT '========================================================'
GO
