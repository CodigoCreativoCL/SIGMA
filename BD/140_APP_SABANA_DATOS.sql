USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  04-09-2026
-- DESCRIPTION:     LA SABANA DE DATOS DE LA APP MOVIL (HU-150).
-- =============================================
-- POR QUE EXISTE ESTE BLOQUE
--
--   La app tiene que poder trabajar SIN SEÑAL. Para eso baja una vez todo lo
--   que necesita y lo guarda en su SQLite. Hoy la API es por recurso y
--   paginada: armar el paquete con GET /repuestos?pagina=1..N son decenas de
--   viajes, y la app queda sincronizando cinco minutos en la puerta de la
--   planta.
--
--   Este SP entrega el paquete completo, bloque por bloque.
--
-- EL PATRON ES EL DE FacilityGes
--
--   `API_2_SEL_USUARIO_SABANA_DATOS` resuelve lo mismo alla con un @TIPO por
--   bloque. Se conserva la forma —un SELECT por tipo, los JOIN de seguridad
--   adentro, ORDER BY explicito— porque esta probada en produccion.
--
--   Lo que cambia: @DESDE. Las tablas de SIGMA tienen auditoria, asi que la
--   app puede pedir solo lo que cambio desde su ultima sincronizacion. Bajar
--   tres mil activos cada vez que se abre la app es gastar el plan de datos
--   del tecnico.
--
-- LA SEGURIDAD VA ADENTRO, NO EN LA API
--
--   Todo bloque se acota por el cliente y por las plantas que la persona
--   tiene autorizadas en Cliente_Instalacion_Usuario. Un filtro puesto en el
--   controller es un filtro que se puede saltar cambiando un parametro; uno
--   puesto aca, no.
--
-- ORDER BY EXPLICITO EN TODO LO QUE SE LISTA
--
--   SQLite no conserva el orden de insercion. En FacilityGes esto se
--   descubrio en produccion (27-10-2025) y se arreglo agregando el ORDER BY
--   al SP. El orden se define donde se define el dato.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_SABANA_DATOS]
     @USUARIO      INT
    ,@CLIENTE      INT
    ,@TIPO         INT      = 0
    ,@DESDE        DATETIME = NULL   -- NULL = carga completa
    ,@INSTALACION  INT      = NULL   -- NULL = todas las autorizadas
AS
SET NOCOUNT ON

BEGIN

    /* Las plantas que esta persona puede ver. Se resuelve UNA vez y los
       bloques la usan: repetir el encadenado en cada uno es repetir la regla
       de seguridad siete veces, y la septima es la que sale mal. */
    DECLARE @PLANTAS TABLE (CIN_ID INT PRIMARY KEY)

    INSERT  @PLANTAS (CIN_ID)
    SELECT  DISTINCT CIN.cin_id
    FROM    [dbo].[Cliente_Instalacion] CIN
    JOIN    [dbo].[Cliente_Instalacion_Usuario] CIU
            ON  CIU.ciu_id_instalacion = CIN.cin_id
            AND CIU.ciu_id_usuario     = @USUARIO
            AND ISNULL(CIU.ciu_habilitado, 0) = 1
    WHERE   CIN.cin_cliente    = @CLIENTE
    AND     CIN.cin_habilitado = 1
    AND     (@INSTALACION IS NULL OR CIN.cin_id = @INSTALACION)


    -- =========================================================
    -- 0 · MANIFIESTO
    --
    -- Cuantas filas tiene cada bloque, para que la app dibuje una barra de
    -- progreso REAL en vez de una animacion indefinida, y sepa que pedir.
    -- =========================================================
    IF (@TIPO = 0)
    BEGIN
        SELECT  1 AS BLOQUE, 'ORGANIZACION' AS CODIGO, 'Organizacion y plantas' AS NOMBRE,
                (SELECT COUNT(*) FROM @PLANTAS) AS FILAS
        UNION ALL
        SELECT  2, 'AREAS', 'Areas de planta',
                (SELECT COUNT(*) FROM [dbo].[Instalacion_Area] IAR
                  JOIN @PLANTAS P ON P.CIN_ID = IAR.iar_cliente_instalacion
                 WHERE IAR.iar_habilitado = 1)
        UNION ALL
        SELECT  3, 'CATALOGOS', 'Catalogos del sistema',
                (SELECT COUNT(*) FROM [dbo].[Catalogo] WHERE ctl_habilitado = 1)
        UNION ALL
        SELECT  4, 'ACTIVOS', 'Activos de planta',
                (SELECT COUNT(*) FROM [dbo].[Activo] ACT
                  JOIN @PLANTAS P ON P.CIN_ID = ACT.act_cliente_instalacion
                 WHERE ACT.act_habilitado = 1)
        UNION ALL
        SELECT  5, 'MEDICION', 'Medidores y variables',
                (SELECT COUNT(*) FROM [dbo].[Activo_Medidor] AME
                  JOIN [dbo].[Activo] ACT ON ACT.act_id = AME.ame_activo
                  JOIN @PLANTAS P ON P.CIN_ID = ACT.act_cliente_instalacion
                 WHERE AME.ame_habilitado = 1)
        UNION ALL
        SELECT  6, 'INVENTARIO', 'Repuestos y bodegas',
                (SELECT COUNT(*) FROM [dbo].[Repuesto]
                  WHERE rep_cliente = @CLIENTE AND rep_habilitado = 1)
        UNION ALL
        SELECT  7, 'EXISTENCIAS', 'Existencias',
                (SELECT COUNT(*) FROM [dbo].[Inventario_Saldo] ISA
                  JOIN [dbo].[Bodega] BOD ON BOD.bod_id = ISA.isa_bodega
                  JOIN @PLANTAS P ON P.CIN_ID = BOD.bod_cliente_instalacion)
        UNION ALL
        SELECT  8, 'PERMISOS_TRABAJO', 'Tipos y estados de permiso',
                (SELECT COUNT(*) FROM [dbo].[Permiso_Trabajo_Tipo] WHERE ptt_habilitado = 1)

        ORDER BY BLOQUE

        /* La hora del servidor. La app la guarda como @DESDE de la proxima
           vez: usar su propio reloj haria que un telefono desajustado se
           saltara registros para siempre. */
        SELECT GETUTCDATE() AS SERVIDOR_FECHA_UTC
    END


    -- =========================================================
    -- 1 · ORGANIZACION: cliente y sus plantas
    -- =========================================================
    IF (@TIPO = 1)
    BEGIN
        SELECT  CLI.cli_id            AS CLI_ID
               ,CLI.cli_nombre        AS CLI_NOMBRE
               ,CIN.cin_id            AS CIN_ID
               ,CIN.cin_codigo        AS CIN_CODIGO
               ,CIN.cin_nombre        AS CIN_NOMBRE
               ,CIN.cin_direccion     AS CIN_DIRECCION
               ,CIN.cin_zona_horaria  AS CIN_ZONA_HORARIA
        FROM    [dbo].[Cliente_Instalacion] CIN
        JOIN    @PLANTAS P ON P.CIN_ID = CIN.cin_id
        JOIN    [dbo].[Cliente] CLI ON CLI.cli_id = CIN.cin_cliente
        ORDER BY CIN.cin_nombre
    END


    -- =========================================================
    -- 2 · AREAS de cada planta
    -- =========================================================
    IF (@TIPO = 2)
    BEGIN
        SELECT  IAR.iar_id                  AS IAR_ID
               ,IAR.iar_cliente_instalacion AS IAR_CLIENTE_INSTALACION
               ,IAR.iar_area_padre          AS IAR_AREA_PADRE
               ,IAR.iar_codigo              AS IAR_CODIGO
               ,IAR.iar_nombre              AS IAR_NOMBRE
        FROM    [dbo].[Instalacion_Area] IAR
        JOIN    @PLANTAS P ON P.CIN_ID = IAR.iar_cliente_instalacion
        WHERE   IAR.iar_habilitado = 1
        ORDER BY IAR.iar_cliente_instalacion, IAR.iar_nombre
    END


    -- =========================================================
    -- 3 · CATALOGOS y sus valores
    --
    -- Van juntos en un solo resultado: son el combo de media app y pedirlos
    -- por separado obliga a la app a cruzar dos listas.
    -- =========================================================
    IF (@TIPO = 3)
    BEGIN
        SELECT  CTL.ctl_id      AS CTL_ID
               ,CTL.ctl_codigo  AS CTL_CODIGO
               ,CTL.ctl_nombre  AS CTL_NOMBRE
               ,CTL.ctl_modulo  AS CTL_MODULO
        FROM    [dbo].[Catalogo] CTL
        WHERE   CTL.ctl_habilitado = 1
        ORDER BY CTL.ctl_codigo
    END


    -- =========================================================
    -- 4 · ACTIVOS
    --
    -- El bloque grande. Con @DESDE la app pide solo lo que cambio: la
    -- auditoria de la tabla es lo que lo hace posible.
    -- =========================================================
    IF (@TIPO = 4)
    BEGIN
        SELECT  ACT.act_id                  AS ACT_ID
               ,ACT.act_codigo              AS ACT_CODIGO
               ,ACT.act_nombre              AS ACT_NOMBRE
               ,ACT.act_cliente_instalacion AS ACT_CLIENTE_INSTALACION
               ,ACT.act_instalacion_area    AS ACT_INSTALACION_AREA
               ,ACT.act_activo_posicion     AS ACT_ACTIVO_POSICION
               ,ACT.act_activo_tipo         AS ACT_ACTIVO_TIPO
               ,ACT.act_activo_modelo       AS ACT_ACTIVO_MODELO
               ,ACT.act_activo_estado       AS ACT_ACTIVO_ESTADO
               ,ACT.act_criticidad_nivel    AS ACT_CRITICIDAD_NIVEL
               ,ACT.act_numero_serie        AS ACT_NUMERO_SERIE
               ,ACT.act_fabricante          AS ACT_FABRICANTE

               /* Resueltos aca y no en la app: son los que se muestran en la
                  ficha, y hacer que el telefono cruce cinco catalogos para
                  pintar una pantalla es trabajo que el servidor ya hizo. */
               ,ATI.ati_nombre              AS TIPO_NOMBRE
               ,AMO.amo_nombre              AS MODELO_NOMBRE
               ,AES.aes_nombre              AS ESTADO_NOMBRE
               ,AES.aes_codigo              AS ESTADO_CODIGO
               ,CRN.crn_nombre              AS CRITICIDAD_NOMBRE
               ,IAR.iar_nombre              AS AREA_NOMBRE
               ,APO.apo_codigo              AS POSICION_CODIGO
               ,CIN.cin_nombre              AS PLANTA_NOMBRE

               ,ACT.act_fecha_actualizacion AS ACT_FECHA_ACTUALIZACION
        FROM    [dbo].[Activo] ACT
        JOIN    @PLANTAS P ON P.CIN_ID = ACT.act_cliente_instalacion
        JOIN    [dbo].[Cliente_Instalacion] CIN ON CIN.cin_id = ACT.act_cliente_instalacion
        LEFT JOIN [dbo].[Activo_Tipo]        ATI ON ATI.ati_id = ACT.act_activo_tipo
        LEFT JOIN [dbo].[Activo_Modelo]      AMO ON AMO.amo_id = ACT.act_activo_modelo
        LEFT JOIN [dbo].[Activo_Estado]      AES ON AES.aes_id = ACT.act_activo_estado
        LEFT JOIN [dbo].[Criticidad_Nivel]   CRN ON CRN.crn_id = ACT.act_criticidad_nivel
        LEFT JOIN [dbo].[Instalacion_Area]   IAR ON IAR.iar_id = ACT.act_instalacion_area
        LEFT JOIN [dbo].[Activo_Posicion]    APO ON APO.apo_id = ACT.act_activo_posicion
        WHERE   ACT.act_habilitado = 1
        AND     (@DESDE IS NULL
                 OR ISNULL(ACT.act_fecha_actualizacion, ACT.act_fecha_creacion) > @DESDE)
        ORDER BY ACT.act_codigo
    END


    -- =========================================================
    -- 5 · MEDIDORES Y VARIABLES
    --
    -- Lo que la app necesita para capturar en terreno: que medidor tiene cada
    -- activo, en que unidad, y cual fue su ultimo valor.
    --
    -- NO HAY SENSORES. Todo valor lo escribe una persona en su ronda, asi que
    -- `ame_valor_actual` es la ULTIMA LECTURA REGISTRADA, no una señal en
    -- vivo. La app lo muestra con su fecha y con quien la tomo.
    -- =========================================================
    IF (@TIPO = 5)
    BEGIN
        -- Medidores
        SELECT  AME.ame_id                      AS AME_ID
               ,AME.ame_activo                  AS AME_ACTIVO
               ,AME.ame_codigo                  AS AME_CODIGO
               ,AME.ame_nombre                  AS AME_NOMBRE
               ,AME.ame_unidad_medida           AS AME_UNIDAD_MEDIDA
               ,UME.ume_simbolo                 AS UNIDAD_SIMBOLO
               ,AME.ame_valor_actual            AS AME_VALOR_ACTUAL
               ,AME.ame_fecha_valor_actual_utc  AS AME_FECHA_VALOR_ACTUAL_UTC
               ,AME.ame_permite_reinicio        AS AME_PERMITE_REINICIO
               ,ACT.act_codigo                  AS ACTIVO_CODIGO
               ,ACT.act_nombre                  AS ACTIVO_NOMBRE
        FROM    [dbo].[Activo_Medidor] AME
        JOIN    [dbo].[Activo] ACT ON ACT.act_id = AME.ame_activo AND ACT.act_habilitado = 1
        JOIN    @PLANTAS P ON P.CIN_ID = ACT.act_cliente_instalacion
        LEFT JOIN [dbo].[Unidad_Medida] UME ON UME.ume_id = AME.ame_unidad_medida
        WHERE   AME.ame_habilitado = 1
        ORDER BY ACT.act_codigo, AME.ame_codigo

        -- Variables de condicion, con sus umbrales
        SELECT  AVA.ava_id                AS AVA_ID
               ,AVA.ava_activo            AS AVA_ACTIVO
               ,AVA.ava_variable_medicion AS AVA_VARIABLE_MEDICION
               ,VME.vme_codigo            AS VARIABLE_CODIGO
               ,VME.vme_nombre            AS VARIABLE_NOMBRE
               ,AVA.ava_unidad_medida     AS AVA_UNIDAD_MEDIDA
               ,UME.ume_simbolo           AS UNIDAD_SIMBOLO
               ,AVA.ava_valor_minimo      AS AVA_VALOR_MINIMO
               ,AVA.ava_valor_maximo      AS AVA_VALOR_MAXIMO
               ,AVA.ava_valor_advertencia AS AVA_VALOR_ADVERTENCIA
               ,AVA.ava_valor_critico     AS AVA_VALOR_CRITICO
        FROM    [dbo].[Activo_Variable] AVA
        JOIN    [dbo].[Activo] ACT ON ACT.act_id = AVA.ava_activo AND ACT.act_habilitado = 1
        JOIN    @PLANTAS P ON P.CIN_ID = ACT.act_cliente_instalacion
        LEFT JOIN [dbo].[Variable_Medicion] VME ON VME.vme_id = AVA.ava_variable_medicion
        LEFT JOIN [dbo].[Unidad_Medida] UME ON UME.ume_id = AVA.ava_unidad_medida
        WHERE   AVA.ava_habilitado = 1
        ORDER BY ACT.act_codigo, VME.vme_nombre
    END


    -- =========================================================
    -- 6 · INVENTARIO: repuestos, bodegas y ubicaciones
    -- =========================================================
    IF (@TIPO = 6)
    BEGIN
        -- Repuestos
        SELECT  REP.rep_id             AS REP_ID
               ,REP.rep_codigo         AS REP_CODIGO
               ,REP.rep_nombre         AS REP_NOMBRE
               ,REP.rep_fabricante     AS REP_FABRICANTE
               ,REP.rep_modelo         AS REP_MODELO
               ,REP.rep_unidad_medida  AS REP_UNIDAD_MEDIDA
               ,UME.ume_simbolo        AS UNIDAD_SIMBOLO
               ,REP.rep_controla_lote  AS REP_CONTROLA_LOTE
        FROM    [dbo].[Repuesto] REP
        LEFT JOIN [dbo].[Unidad_Medida] UME ON UME.ume_id = REP.rep_unidad_medida
        WHERE   REP.rep_cliente    = @CLIENTE
        AND     REP.rep_habilitado = 1
        ORDER BY REP.rep_codigo

        -- Bodegas
        SELECT  BOD.bod_id                  AS BOD_ID
               ,BOD.bod_codigo              AS BOD_CODIGO
               ,BOD.bod_nombre              AS BOD_NOMBRE
               ,BOD.bod_cliente_instalacion AS BOD_CLIENTE_INSTALACION
        FROM    [dbo].[Bodega] BOD
        JOIN    @PLANTAS P ON P.CIN_ID = BOD.bod_cliente_instalacion
        WHERE   BOD.bod_habilitado = 1
        ORDER BY BOD.bod_nombre

        -- Ubicaciones
        SELECT  BUB.bub_id     AS BUB_ID
               ,BUB.bub_bodega AS BUB_BODEGA
               ,BUB.bub_codigo AS BUB_CODIGO
               ,BUB.bub_nombre AS BUB_NOMBRE
        FROM    [dbo].[Bodega_Ubicacion] BUB
        JOIN    [dbo].[Bodega] BOD ON BOD.bod_id = BUB.bub_bodega
        JOIN    @PLANTAS P ON P.CIN_ID = BOD.bod_cliente_instalacion
        WHERE   BUB.bub_habilitado = 1
        ORDER BY BUB.bub_bodega, BUB.bub_codigo

        -- Tipos de movimiento: sin esto la app no sabe que puede hacer
        /* El signo NO esta en esta tabla: `imo_cantidad` siempre es
           positiva y el sentido lo resuelve el SP de movimientos segun el
           tipo. La app solo necesita saber que tipos existen. */
        SELECT  IMT.imt_id     AS IMT_ID
               ,IMT.imt_codigo AS IMT_CODIGO
               ,IMT.imt_nombre AS IMT_NOMBRE
               ,IMT.imt_orden  AS IMT_ORDEN
        FROM    [dbo].[Inventario_Movimiento_Tipo] IMT
        WHERE   IMT.imt_habilitado = 1
        ORDER BY IMT.imt_orden, IMT.imt_id
    END


    -- =========================================================
    -- 7 · EXISTENCIAS
    --
    -- El bloque que NO conviene cachear como los demas: es el dato que no
    -- puede estar viejo. Baja igual —sin señal es mejor un saldo de hace una
    -- hora que ninguno— pero viaja `isa_fecha_ultimo_movimiento` para que la
    -- app pueda decir DE CUANDO es lo que muestra (HU-056 CA2).
    -- =========================================================
    IF (@TIPO = 7)
    BEGIN
        SELECT  ISA.isa_id                       AS ISA_ID
               ,ISA.isa_repuesto                 AS ISA_REPUESTO
               ,ISA.isa_bodega                   AS ISA_BODEGA
               ,ISA.isa_cantidad                 AS ISA_CANTIDAD
               ,ISA.isa_cantidad_reservada       AS ISA_CANTIDAD_RESERVADA
               ,ISA.isa_cantidad - ISNULL(ISA.isa_cantidad_reservada, 0) AS CANTIDAD_DISPONIBLE
               ,ISA.isa_fecha_ultimo_movimiento  AS ISA_FECHA_ULTIMO_MOVIMIENTO
               ,REP.rep_codigo                   AS REPUESTO_CODIGO
               ,REP.rep_nombre                   AS REPUESTO_NOMBRE
               ,UME.ume_simbolo                  AS UNIDAD_SIMBOLO
               ,BOD.bod_nombre                   AS BODEGA_NOMBRE
               ,CIN.cin_nombre                   AS PLANTA_NOMBRE
               ,RBS.rbs_stock_minimo             AS RBS_STOCK_MINIMO
               ,RBS.rbs_stock_maximo             AS RBS_STOCK_MAXIMO

               /* Bajo minimo lo decide el SP, no la pantalla: asi la web y el
                  telefono no pueden discrepar sobre que es "critico". */
               ,CASE WHEN RBS.rbs_stock_minimo IS NOT NULL
                      AND ISA.isa_cantidad < RBS.rbs_stock_minimo
                     THEN 1 ELSE 0 END           AS BAJO_MINIMO
               ,CASE WHEN RBS.rbs_stock_maximo IS NOT NULL
                      AND ISA.isa_cantidad > RBS.rbs_stock_maximo
                     THEN 1 ELSE 0 END           AS SOBRE_MAXIMO
        FROM    [dbo].[Inventario_Saldo] ISA
        JOIN    [dbo].[Bodega] BOD ON BOD.bod_id = ISA.isa_bodega
        JOIN    @PLANTAS P ON P.CIN_ID = BOD.bod_cliente_instalacion
        JOIN    [dbo].[Cliente_Instalacion] CIN ON CIN.cin_id = BOD.bod_cliente_instalacion
        JOIN    [dbo].[Repuesto] REP ON REP.rep_id = ISA.isa_repuesto
        LEFT JOIN [dbo].[Unidad_Medida] UME ON UME.ume_id = REP.rep_unidad_medida
        LEFT JOIN [dbo].[Repuesto_Bodega_Stock] RBS
               ON RBS.rbs_repuesto = ISA.isa_repuesto
              AND RBS.rbs_bodega   = ISA.isa_bodega
        ORDER BY REP.rep_codigo, BOD.bod_nombre
    END


    -- =========================================================
    -- 8 · PERMISOS DE TRABAJO: tipos y estados
    -- =========================================================
    IF (@TIPO = 8)
    BEGIN
        SELECT  PTT.ptt_id     AS PTT_ID
               ,PTT.ptt_codigo AS PTT_CODIGO
               ,PTT.ptt_nombre AS PTT_NOMBRE
        FROM    [dbo].[Permiso_Trabajo_Tipo] PTT
        WHERE   PTT.ptt_habilitado = 1
        AND     (PTT.ptt_cliente IS NULL OR PTT.ptt_cliente = @CLIENTE)
        ORDER BY PTT.ptt_orden, PTT.ptt_id

        SELECT  PTE.pte_id     AS PTE_ID
               ,PTE.pte_codigo AS PTE_CODIGO
               ,PTE.pte_nombre AS PTE_NOMBRE
        FROM    [dbo].[Permiso_Trabajo_Estado] PTE
        WHERE   PTE.pte_habilitado = 1
        ORDER BY PTE.pte_orden, PTE.pte_id
    END

END
GO

PRINT 'API_SEL_APP_SABANA_DATOS creado.'
GO
