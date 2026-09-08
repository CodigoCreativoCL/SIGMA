USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     CADA PERFIL VE LO SUYO: ALERTAS Y MENUS POR AMBITO.
-- =============================================
-- EL PROBLEMA ERA DE DATOS, NO DE CODIGO
--
--   SEL_ALERTA ya filtraba por el permiso del TIPO de alerta -alt_permiso- y
--   los menus ya se muestran segun mnu_permiso. El mecanismo estaba bien; lo
--   que estaba mal era el mapeo:
--
--     * Las alertas de stock exigian VER EXISTENCIAS y las de lote VER
--       REPUESTOS. El tecnico tiene los dos -y debe tenerlos, mira el saldo
--       antes de bajar a bodega-, asi que le llegaba cada aviso de stock
--       minimo de la planta.
--
--     * Las alertas de activos, OT y permisos exigian VER ACTIVOS. El
--       bodeguero lo tiene -imprime etiquetas de equipos-, asi que le llegaban
--       las de mantenimiento.
--
--   Subir el liston de VER EXISTENCIAS a algo mas restrictivo habria roto la
--   consulta de saldo, que es legitima para todos. Lo que hacia falta no era
--   endurecer un permiso existente, sino separar VER de RECIBIR: son dos
--   preguntas distintas y estaban compartiendo respuesta.
--
-- POR ESO NACEN DOS PERMISOS DE AMBITO
--
--   VER ALERTAS MANTENIMIENTO y VER ALERTAS INVENTARIO. Explicitos, editables
--   desde la web sin tocar codigo, y con un nombre que dice para que son. La
--   alternativa era reusar permisos existentes -«permisos de trabajo» ->
--   VER PERMISOS TRABAJO, que el bodeguero no tiene- pero para activos y
--   mediciones no habia ninguno limpio y habria quedado forzado: el dia que
--   alguien mueva ese permiso por otra razon, las alertas cambian de dueño sin
--   que nadie relacione una cosa con la otra.
--
-- QUIEN RECIBE QUE (decidido con Bryan el 08-09-2026)
--
--   MANTENIMIENTO -> Jefe, Planificador, Supervisor y Tecnico.
--   INVENTARIO    -> Bodeguero, Jefe y Planificador. El tecnico y el
--                    supervisor dejan de recibirlas; un stock minimo si frena
--                    el trabajo del planificador, asi que enterarse le sirve.
--
--   COMPARTIDO se queda SIN permiso a proposito: va dirigida a una persona
--   concreta, y filtrarla por ambito la haria desaparecer para su destinatario.
--
-- Y EL JEFE DEJA DE MOVER INVENTARIO
--
--   «un CRUD de repuestos no puede hacerlo, movimientos tampoco, solo el
--   bodeguero». Pierde CREAR EDITAR REPUESTOS, AJUSTAR INVENTARIO, GESTIONAR
--   STOCK, REGISTRAR INGRESO REPUESTO y ENTREGAR REPUESTO. Lo mismo el
--   Planificador, que tenia CREAR EDITAR REPUESTOS y ENTREGAR REPUESTO.
--
--   CONSERVA VER EXISTENCIAS y VER REPUESTOS: ve pero no toca. Planificar sin
--   saber si hay repuestos es planificar a ciegas.
--
--   NO se toca CREAR REPUESTO TERRENO, que tienen los cinco perfiles: es el
--   alta rapida de la pieza que aparece delante del equipo, no el mantenedor.
--
--   Las pantallas de la web ya comprueban estos permisos una por una
--   -Repuesto.aspx.cs linea 277, Movimientos.aspx.cs linea 106-, asi que
--   quitarlos basta: los botones desaparecen solos.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) Los dos permisos de ambito
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS MANTENIMIENTO')
BEGIN
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES
        ('VER ALERTAS MANTENIMIENTO', 'Recibir alertas de mantenimiento', 'ACTIVOS', 3,
         'Recibe los avisos de activos, ordenes de trabajo, mediciones y permisos. Separado de VER ACTIVOS a proposito: mirar la ficha de un equipo y recibir sus alertas son dos cosas distintas.',
         1, GETDATE(), 1, 0)
END
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS INVENTARIO')
BEGIN
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES
        ('VER ALERTAS INVENTARIO', 'Recibir alertas de inventario', 'INVENTARIO', 3,
         'Recibe los avisos de stock minimo, stock maximo y lotes vencidos. Separado de VER EXISTENCIAS a proposito: consultar el saldo lo hace todo el mundo, recibir el aviso no.',
         1, GETDATE(), 1, 0)
END
GO

-- ---------------------------------------------------------------------------
-- 2) A quien se le asignan
-- ---------------------------------------------------------------------------
DECLARE @MANT INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS MANTENIMIENTO')
DECLARE @INV  INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS INVENTARIO')

/* Perfiles: 4 Bodeguero, 5 Jefe de Mantenimiento, 11 Planificador,
   12 Supervisor, 13 Tecnico. El 1 (Root) entra en los dos: si no, quien
   administra deja de ver lo que administra. */
DECLARE @DESTINO TABLE (perfil INT, permiso INT)

INSERT INTO @DESTINO (perfil, permiso)
SELECT p, @MANT FROM (VALUES (1),(5),(11),(12),(13)) v(p)
UNION ALL
SELECT p, @INV  FROM (VALUES (1),(4),(5),(11)) v(p)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT d.perfil, d.permiso, 1, GETDATE()
FROM @DESTINO d
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                   WHERE ppe_perfil = d.perfil AND ppe_permiso = d.permiso)
GO

-- ---------------------------------------------------------------------------
-- 3) Cada tipo de alerta apunta a su ambito
-- ---------------------------------------------------------------------------
DECLARE @MANT INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS MANTENIMIENTO')
DECLARE @INV  INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS INVENTARIO')

UPDATE [dbo].[Alerta_Tipo]
   SET alt_permiso = @MANT
 WHERE alt_codigo IN ('MEDICION FUERA RANGO', 'HALLAZGO CRITICO', 'OCURRENCIA VENCIDA',
                      'PREDICCION RIESGO', 'PERMISO VENCIDO', 'MEDIDOR SIN LECTURA',
                      'DESCUBRIMIENTO TERRENO', 'MEDIDOR PROXIMO MANTENIMIENTO')

UPDATE [dbo].[Alerta_Tipo]
   SET alt_permiso = @INV
 WHERE alt_codigo IN ('STOCK MINIMO', 'STOCK MAXIMO', 'LOTE VENCIDO', 'LOTE POR VENCER')

/* COMPARTIDO no se toca: va dirigida a una persona. */
GO

-- ---------------------------------------------------------------------------
-- 4) El jefe y el planificador dejan de mover inventario
-- ---------------------------------------------------------------------------
DELETE pp
FROM [dbo].[Perfil_Permiso] pp
JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
WHERE pp.ppe_perfil IN (5, 11)
  AND p.prm_codigo IN ('CREAR EDITAR REPUESTOS', 'AJUSTAR INVENTARIO', 'GESTIONAR STOCK',
                       'REGISTRAR INGRESO REPUESTO', 'ENTREGAR REPUESTO')
GO

-- ---------------------------------------------------------------------------
-- 5) El menu de movimientos deja de asomar donde no lleva a nada
-- ---------------------------------------------------------------------------
/* Exigian VER EXISTENCIAS, que tiene todo el mundo, pero Movimientos.aspx
   rechaza a quien no pueda ingresar, entregar o ajustar. Era un menu que
   llevaba a una pared. */
DECLARE @STOCK INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'GESTIONAR STOCK')

UPDATE [dbo].[Menus]
   SET mnu_permiso = @STOCK
 WHERE mnu_id IN (2116, 2120)
   AND mnu_nombre IN ('Movimientos', 'Movimiento (detalle)')
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'ALERTA ' + t.alt_codigo COLLATE DATABASE_DEFAULT + ' -> ' +
       ISNULL(p.prm_codigo COLLATE DATABASE_DEFAULT, '(sin permiso)') AS RESULTADO
FROM [dbo].[Alerta_Tipo] t
LEFT JOIN [dbo].[Permiso] p ON p.prm_id = t.alt_permiso
WHERE t.alt_habilitado = 1
ORDER BY t.alt_id
GO
