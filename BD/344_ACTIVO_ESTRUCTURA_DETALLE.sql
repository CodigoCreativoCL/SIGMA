/* ============================================================================
   SIGMA - Bloque 344
   EL DIAGRAMA DEL ACTIVO MUESTRA TODO LO QUE CUELGA DE ÉL
   ----------------------------------------------------------------------------
   Rediseño del módulo de Activos (04-10-2026, maquetas «SIGMA · Rediseño
   módulo de Activos»). La pestaña Componentes del centro 360 queda como UN
   diagrama con su detalle al lado; para eso SEL_ACTIVO_ESTRUCTURA entrega dos
   cosas más, sin cambiar lo que ya entregaba (las columnas y el resultado
   nuevos van al final, así que quien lo lee hoy no se entera):

     1. Repuestos: PARA_ID y PARA, la parte a la que le sirve el repuesto
        cuando calza por un componente («Para: Burlete de la puerta»). NULL
        cuando le sirve a todo el equipo (por su tipo o su modelo).
     2. Resultado 5: las partes de cada SUBACTIVO, para dibujarlas debajo de
        él («Compresor Copeland ZB45 › Válvula de descarga»).
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- AUTHOR:          SIGMA
-- FECHA CREACION:  04-10-2026
-- MODIFICACION:    04-10-2026 (bloque 344) PARA_ID/PARA EN REPUESTOS Y
--                  RESULTADO 5 CON LAS PARTES DE LOS SUBACTIVOS
-- DESCRIPTION:     SELECT ESTRUCTURA DE UN ACTIVO: 1 PADRE, 2 SUBACTIVOS,
--                  3 COMPONENTES, 4 REPUESTOS COMPATIBLES CON SU STOCK,
--                  5 COMPONENTES DE SUS SUBACTIVOS
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEL_ACTIVO_ESTRUCTURA]
    @CLIENTE INT,
    @ACTIVO  INT
AS
SET NOCOUNT ON

    DECLARE @TIPO INT, @MODELO INT, @PADRE INT
    SELECT @TIPO = act_activo_tipo, @MODELO = act_activo_modelo, @PADRE = act_activo_padre
    FROM   [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE

    -- 1. su maquina principal (si es subactivo)
    SELECT p.act_id AS ID, p.act_codigo AS CODIGO, p.act_nombre AS NOMBRE
    FROM   [dbo].[Activo] p WHERE p.act_id = @PADRE AND p.act_cliente = @CLIENTE

    -- 2. subactivos
    SELECT s.act_id AS ID, s.act_codigo AS CODIGO, s.act_nombre AS NOMBRE,
           ISNULL(e.aes_nombre, '') AS ESTADO, ISNULL(e.aes_codigo, '') AS ESTADO_CODIGO,
           ISNULL(t.ati_nombre, '') AS TIPO, ISNULL(c.crn_nombre, '') AS CRITICIDAD,
           (SELECT COUNT(*) FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = s.act_id AND x.aco_habilitado = 1) AS COMPONENTES,
           (SELECT COUNT(*) FROM [dbo].[Activo] x WHERE x.act_activo_padre = s.act_id AND x.act_habilitado = 1) AS SUBACTIVOS
    FROM   [dbo].[Activo] s
    LEFT JOIN [dbo].[Activo_Estado] e ON e.aes_id = s.act_activo_estado
    LEFT JOIN [dbo].[Activo_Tipo] t ON t.ati_id = s.act_activo_tipo
    LEFT JOIN [dbo].[Criticidad_Nivel] c ON c.crn_id = s.act_criticidad_nivel
    WHERE  s.act_activo_padre = @ACTIVO AND s.act_cliente = @CLIENTE AND s.act_habilitado = 1 AND s.act_fusionado_en IS NULL
    ORDER BY s.act_nombre

    -- 3. componentes (con su padre, para armar el arbol)
    SELECT c.aco_id AS ID, c.aco_componente_padre AS PADRE, c.aco_codigo AS CODIGO, c.aco_nombre AS NOMBRE,
           ISNULL(t.cto_nombre, '') AS TIPO, ISNULL(p.cpn_nombre, '') AS LADO,
           ISNULL(e.ace_nombre, '') AS ESTADO, ISNULL(e.ace_codigo, '') AS ESTADO_CODIGO
    FROM   [dbo].[Activo_Componente] c
    LEFT JOIN [dbo].[Componente_Tipo] t ON t.cto_id = c.aco_componente_tipo
    LEFT JOIN [dbo].[Componente_Posicion] p ON p.cpn_id = c.aco_componente_posicion
    LEFT JOIN [dbo].[Activo_Componente_Estado] e ON e.ace_id = c.aco_activo_componente_estado
    WHERE  c.aco_activo = @ACTIVO AND c.aco_cliente = @CLIENTE AND c.aco_habilitado = 1 AND c.aco_fusionado_en IS NULL
    ORDER BY c.aco_componente_padre, c.aco_nombre

    -- 4. repuestos que le calzan: por su modelo, su tipo o alguno de sus componentes
    SELECT r.rep_id AS ID, r.rep_codigo AS CODIGO, r.rep_nombre AS NOMBRE,
           MIN(CASE WHEN rc.rco_activo_componente IS NOT NULL THEN 'COMPONENTE'
                    WHEN rc.rco_activo_modelo IS NOT NULL THEN 'MODELO' ELSE 'TIPO' END) AS ALCANCE,
           ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_repuesto = r.rep_id), 0) AS EXISTENCIA,
           ISNULL((SELECT SUM(u.rbs_stock_minimo) FROM [dbo].[Repuesto_Bodega_Stock] u WHERE u.rbs_repuesto = r.rep_id), 0) AS MINIMO,
           ISNULL(MAX(um.ume_simbolo), '') AS UNIDAD,
           MAX(pc.aco_id) AS PARA_ID,
           MAX(pc.aco_nombre) AS PARA
    FROM   [dbo].[Repuesto_Compatibilidad] rc
    JOIN   [dbo].[Repuesto] r ON r.rep_id = rc.rco_repuesto AND r.rep_cliente = @CLIENTE AND r.rep_habilitado = 1
    LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Activo_Componente] pc ON pc.aco_id = rc.rco_activo_componente AND pc.aco_activo = @ACTIVO
    WHERE  rc.rco_activo_tipo = @TIPO
       OR (@MODELO IS NOT NULL AND rc.rco_activo_modelo = @MODELO)
       OR  rc.rco_activo_componente IN (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = @ACTIVO)
    GROUP BY r.rep_id, r.rep_codigo, r.rep_nombre
    ORDER BY r.rep_nombre

    -- 5. las partes de sus subactivos, para dibujarlas debajo de cada uno
    SELECT c.aco_id AS ID, c.aco_activo AS ACTIVO, c.aco_codigo AS CODIGO, c.aco_nombre AS NOMBRE,
           ISNULL(t.cto_nombre, '') AS TIPO,
           ISNULL(e.ace_nombre, '') AS ESTADO, ISNULL(e.ace_codigo, '') AS ESTADO_CODIGO
    FROM   [dbo].[Activo_Componente] c
    JOIN   [dbo].[Activo] s ON s.act_id = c.aco_activo AND s.act_activo_padre = @ACTIVO AND s.act_cliente = @CLIENTE
                           AND s.act_habilitado = 1 AND s.act_fusionado_en IS NULL
    LEFT JOIN [dbo].[Componente_Tipo] t ON t.cto_id = c.aco_componente_tipo
    LEFT JOIN [dbo].[Activo_Componente_Estado] e ON e.ace_id = c.aco_activo_componente_estado
    WHERE  c.aco_cliente = @CLIENTE AND c.aco_habilitado = 1 AND c.aco_fusionado_en IS NULL
    ORDER BY c.aco_activo, c.aco_nombre
GO
