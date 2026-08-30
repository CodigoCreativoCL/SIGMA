USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  29-08-2026
-- DESCRIPTION:     BLOQUE A. EL VALOR DE LA UF.
-- =============================================
-- Va DESPUES de 39_SPRINT1_IDENTIFICADOR_PAIS.
--
-- POR QUE ESTO VA PRIMERO
--   Sin UF no se puede emitir ni cobrar nada: Suscripcion_Periodo congela
--   el monto en pesos y ese monto sale de multiplicar las UF del plan por
--   el valor de la UF del dia. Con Valor_Uf vacia, FNC_VALOR_UF devuelve
--   NULL y toda emision queda en cero.
--
-- DONDE CORRE EL ALIMENTADOR
--   El ANEXO F §4 dice "job del servidor". Este hosting NO da acceso a
--   msdb, asi que no hay SQL Agent: el alimentador corre en la aplicacion
--   web (UfController) y escribe por INS_VALOR_UF.
--
--   Lo que el anexo prohibe -y se respeta- es que el VALOR llegue desde el
--   navegador de quien paga. Aqui el que consulta la fuente es el servidor
--   de la aplicacion, no el cliente, y queda registrado con que origen y a
--   que hora se obtuvo.
--
-- LA REGLA DE ARRASTRE
--   Si la fuente se cae, no se bloquea nada: se escribe el ultimo valor
--   conocido marcado como ARRASTRE. Queda visible que es un arrastre y se
--   corrige despues. Nadie se queda sin poder renovar porque un servicio
--   externo estaba caido (§4.2).
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. INS_VALOR_UF

      Una fila por dia. Si el dia ya esta cargado NO se duplica.

      La unica actualizacion permitida es reemplazar un ARRASTRE por el
      valor real: eso no es reescribir historia, es corregir un marcador de
      posicion que se escribio justamente porque la fuente no respondio.
      Un valor real jamas se pisa con otro.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_VALOR_UF]
@FECHA          DATE,
@VALOR          DECIMAL(18,4),
@ORIGEN_CODIGO  NVARCHAR(100) = N'API EXTERNA',
@RESPUESTA      NVARCHAR(500) = NULL,
@USUARIO        INT = 1,
@ESCRITO        BIT = 0 OUTPUT

AS
SET NOCOUNT ON

SET @ESCRITO = 0

DECLARE @ORIGEN INT, @ORIGEN_ARRASTRE INT, @ORIGEN_ACTUAL INT

SELECT @ORIGEN = ufo_id FROM [dbo].[Uf_Origen]
 WHERE ufo_codigo COLLATE DATABASE_DEFAULT = @ORIGEN_CODIGO COLLATE DATABASE_DEFAULT

SELECT @ORIGEN_ARRASTRE = ufo_id FROM [dbo].[Uf_Origen] WHERE ufo_codigo = N'ARRASTRE'

BEGIN
    IF @ORIGEN IS NULL
    BEGIN
        RAISERROR('1.- EL ORIGEN "%s" NO ESTÁ EN EL CATÁLOGO Uf_Origen.', 16, 1, @ORIGEN_CODIGO)
        RETURN -1
    END

    IF @VALOR IS NULL OR @VALOR <= 0
    BEGIN
        RAISERROR('2.- EL VALOR DE LA UF DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
END

SELECT @ORIGEN_ACTUAL = vuf_uf_origen FROM [dbo].[Valor_Uf] WHERE vuf_fecha = @FECHA

IF @ORIGEN_ACTUAL IS NULL
BEGIN
    INSERT [dbo].[Valor_Uf]
        (vuf_fecha, vuf_valor, vuf_uf_origen, vuf_fecha_obtencion_utc,
         vuf_respuesta_cruda, vuf_usuario_creacion, vuf_fecha_creacion)
    VALUES
        (@FECHA, @VALOR, @ORIGEN, GETUTCDATE(), @RESPUESTA, @USUARIO, GETDATE())

    SET @ESCRITO = 1
    RETURN(0)
END

-- Solo se corrige un arrastre con un valor de verdad.
IF @ORIGEN_ACTUAL = @ORIGEN_ARRASTRE AND @ORIGEN <> @ORIGEN_ARRASTRE
BEGIN
    UPDATE [dbo].[Valor_Uf]
       SET vuf_valor               = @VALOR,
           vuf_uf_origen           = @ORIGEN,
           vuf_fecha_obtencion_utc = GETUTCDATE(),
           vuf_respuesta_cruda     = @RESPUESTA
     WHERE vuf_fecha = @FECHA

    SET @ESCRITO = 1
END

RETURN(0)
GO


/* ========================================================================
   2. INS_VALOR_UF_ARRASTRE

      Lo llama el alimentador cuando la fuente no responde. Copia el ultimo
      valor conocido al dia pedido y lo marca.

      Si no hay NINGUN valor previo no inventa nada: devuelve -1 y el
      llamador avisa. Un arrastre sin nada que arrastrar seria un numero
      inventado, y con numeros inventados se emiten cobros.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_VALOR_UF_ARRASTRE]
@FECHA    DATE = NULL,
@USUARIO  INT = 1,
@ESCRITO  BIT = 0 OUTPUT

AS
SET NOCOUNT ON

SET @ESCRITO = 0
SET @FECHA = ISNULL(@FECHA, CAST(GETDATE() AS DATE))

DECLARE @ULTIMO DECIMAL(18,4), @FECHA_ULTIMO DATE

SELECT TOP 1 @ULTIMO = vuf_valor, @FECHA_ULTIMO = vuf_fecha
FROM   [dbo].[Valor_Uf]
WHERE  vuf_fecha < @FECHA
ORDER BY vuf_fecha DESC

IF @ULTIMO IS NULL
BEGIN
    RAISERROR('1.- NO HAY NINGÚN VALOR DE UF ANTERIOR QUE ARRASTRAR.', 16, 1)
    RETURN -1
END

DECLARE @NOTA NVARCHAR(500) =
    N'Arrastre del valor del ' + CONVERT(NVARCHAR(10), @FECHA_ULTIMO, 103) +
    N' porque la fuente no respondió.'

EXEC [dbo].[INS_VALOR_UF]
     @FECHA         = @FECHA,
     @VALOR         = @ULTIMO,
     @ORIGEN_CODIGO = N'ARRASTRE',
     @RESPUESTA     = @NOTA,
     @USUARIO       = @USUARIO,
     @ESCRITO       = @ESCRITO OUTPUT

RETURN(0)
GO


/* ========================================================================
   3. SEL_VALOR_UF

      Consulta y control. ES_ARRASTRE deja a la vista los dias que quedaron
      con un valor heredado: son los que hay que revisar.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_VALOR_UF]
@FECHA        DATE = NULL,
@DESDE        DATE = NULL,
@HASTA        DATE = NULL,
@SOLO_ARRASTRE BIT = NULL,
@TOPE         INT = 60

AS
SET NOCOUNT ON

    SELECT  TOP (@TOPE)
            v.vuf_id                    AS VUF_ID,
            v.vuf_fecha                 AS VUF_FECHA,
            v.vuf_valor                 AS VUF_VALOR,
            v.vuf_uf_origen             AS VUF_UF_ORIGEN,
            o.ufo_nombre                AS UFO_NOMBRE,
            o.ufo_codigo                AS UFO_CODIGO,
            v.vuf_fecha_obtencion_utc   AS VUF_FECHA_OBTENCION_UTC,
            v.vuf_respuesta_cruda       AS VUF_RESPUESTA_CRUDA,
            CASE WHEN o.ufo_codigo = N'ARRASTRE' THEN 1 ELSE 0 END AS ES_ARRASTRE
    FROM    [dbo].[Valor_Uf] v
    INNER JOIN [dbo].[Uf_Origen] o ON o.ufo_id = v.vuf_uf_origen
    WHERE   (@FECHA IS NULL OR v.vuf_fecha = @FECHA)
      AND   (@DESDE IS NULL OR v.vuf_fecha >= @DESDE)
      AND   (@HASTA IS NULL OR v.vuf_fecha <= @HASTA)
      AND   (@SOLO_ARRASTRE IS NULL OR @SOLO_ARRASTRE = 0
             OR o.ufo_codigo = N'ARRASTRE')
    ORDER BY v.vuf_fecha DESC

RETURN(0)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'SPs de UF' AS control, COUNT(*) AS valor, 3 AS esperado
FROM   sys.procedures
WHERE  name IN ('INS_VALOR_UF','INS_VALOR_UF_ARRASTRE','SEL_VALOR_UF')
UNION ALL
SELECT 'días de UF cargados', COUNT(*), NULL FROM [dbo].[Valor_Uf]
GO
