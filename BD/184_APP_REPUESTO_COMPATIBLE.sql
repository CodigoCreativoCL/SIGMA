USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LOS REPUESTOS CON SALDO, MARCANDO CUALES SIRVEN AL ACTIVO.
-- =============================================
-- QUE RESUELVE
--
--   Al consumir un repuesto contra una orden, la app ofrecia TODO lo que
--   tuviera saldo en la planta. Un rodamiento 6205 y uno 6310 se ven casi
--   iguales en una lista, y el que se equivoca lo descubre abajo, con el
--   equipo abierto y la pieza que no calza en la mano.
--
--   `Repuesto_Compatibilidad` ya existe y relaciona un repuesto con el TIPO,
--   el MODELO o el COMPONENTE de activo al que sirve. Nadie la estaba
--   consultando.
--
-- POR QUE SE MARCA Y NO SE FILTRA
--
--   La tabla esta vacia hoy (0 filas al 08-09-2026): filtrar por ella dejaria
--   la lista en blanco y la funcion inservible hasta que alguien cargue las
--   compatibilidades. Y aun con la tabla llena, filtrar seria peor: una
--   compatibilidad que nadie declaro no significa que la pieza no sirva,
--   significa que no se anoto — y en terreno, a las tres de la mañana, hay que
--   poder usar lo que hay.
--
--   Asi que se ORDENA: lo compatible primero y marcado, el resto despues. La
--   app avisa; la persona decide.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_REPUESTO_ORDEN]
@OTR_ID  INT,
@CLIENTE INT,
@FILTRO  VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    DECLARE @ACTIVO INT, @TIPO INT, @MODELO INT, @INSTALACION INT

    SELECT  @ACTIVO      = OTR.otr_activo,
            @INSTALACION = OTR.otr_cliente_instalacion
      FROM  [dbo].[Orden_Trabajo] OTR
     WHERE  OTR.otr_id = @OTR_ID AND OTR.otr_cliente = @CLIENTE

    IF (@INSTALACION IS NULL)
    BEGIN
        RAISERROR('1.- ESA ORDEN NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* El tipo y el modelo del equipo: son las dos formas en que una
       compatibilidad se declara para todo un parque, en vez de activo por
       activo. */
    SELECT  @TIPO   = ACT.act_activo_tipo,
            @MODELO = ACT.act_activo_modelo
      FROM  [dbo].[Activo] ACT
     WHERE  ACT.act_id = @ACTIVO

    SELECT      ISA.isa_id                  AS isa_id,
                ISA.isa_repuesto            AS isa_repuesto,
                ISA.isa_bodega              AS isa_bodega,
                REP.rep_codigo              AS REPUESTO_CODIGO,
                REP.rep_nombre              AS REPUESTO_NOMBRE,
                UME.ume_simbolo             AS UNIDAD_SIMBOLO,
                BOD.bod_nombre              AS BODEGA_NOMBRE,
                ISA.isa_cantidad            AS CANTIDAD_DISPONIBLE,

                /* Sirve para ESTE equipo: por su tipo, por su modelo, o por
                   uno de sus componentes. */
                CAST(CASE WHEN EXISTS (
                    SELECT 1
                      FROM [dbo].[Repuesto_Compatibilidad] RCO
                     WHERE RCO.rco_repuesto = ISA.isa_repuesto
                       AND (RCO.rco_activo_tipo   = @TIPO
                         OR RCO.rco_activo_modelo = @MODELO
                         OR RCO.rco_activo_componente IN (
                                SELECT ACO.aco_id
                                  FROM [dbo].[Activo_Componente] ACO
                                 WHERE ACO.aco_activo = @ACTIVO))
                ) THEN 1 ELSE 0 END AS BIT)     AS ES_COMPATIBLE

    FROM        [dbo].[Inventario_Saldo]    ISA
    INNER JOIN  [dbo].[Repuesto]            REP ON REP.rep_id = ISA.isa_repuesto
    INNER JOIN  [dbo].[Bodega]              BOD ON BOD.bod_id = ISA.isa_bodega
    /* La unidad sale de `Unidad_Medida`, igual que en
       SEL_INVENTARIO_SALDO: dos caminos al mismo simbolo terminan
       mostrando «un» en una pantalla y «UN» en la otra. */
    LEFT  JOIN  [dbo].[Unidad_Medida]       UME ON UME.ume_id = REP.rep_unidad_medida
    WHERE       BOD.bod_cliente_instalacion = @INSTALACION
      AND       ISA.isa_cantidad > 0
      AND       ISNULL(REP.rep_habilitado, 0) = 1
      AND       (@FILTRO IS NULL OR @FILTRO = ''
                 OR REP.rep_codigo LIKE '%' + @FILTRO + '%'
                 OR REP.rep_nombre LIKE '%' + @FILTRO + '%')
    /* Lo que sirve primero. Dentro de cada grupo, por codigo: en una bodega
       de trescientas piezas el orden alfabetico es el unico que se puede
       seguir con la vista. */
    ORDER BY    ES_COMPATIBLE DESC, REP.rep_codigo
GO
