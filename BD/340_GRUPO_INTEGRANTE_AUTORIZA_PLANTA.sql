/* ============================================================================
   SIGMA - Bloque 340
   GRUPOS DE TRABAJO: SE PUEDE SUMAR A CUALQUIER PERSONA DEL CLIENTE
   ----------------------------------------------------------------------------
   INS_GRUPO_TRABAJO_USUARIO rechazaba a quien no estaba autorizado en la
   planta del grupo (regla 3). En Renca solo habia 2 autorizados y nadie mas
   podia entrar a un grupo. Decision de Emilio (04-10-2026): Root y el admin
   del cliente suman a quien quieran; ser responsable de la planta no es
   requisito. Al sumarlo, el SP lo autoriza en la planta del grupo.

   Ademas: el control de insercion usaba @@ROWCOUNT despues de un SET, que
   siempre vale 1; ahora se revisa @ID.
   ============================================================================ */
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ========================================================================
   INS_GRUPO_TRABAJO_USUARIO

   AQUI VIVE LA REGLA DEL LIDER UNICO.

   "Solo puede haber un lider vigente por grupo" es una condicion sobre
   VENTANAS DE TIEMPO, no sobre filas. Dos integrantes se solapan cuando
   cada uno empieza antes de que el otro termine; con fecha de fin vacia
   (sin vencimiento) el tramo se trata como abierto hasta el infinito.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_GRUPO_TRABAJO_USUARIO]
@ID              INT = NULL OUTPUT,
@GRUPO_TRABAJO   INT,
@USUARIO_DESTINO INT,
@ES_LIDER        BIT = 0,
@FECHA_INICIO    DATE = NULL,
@FECHA_FIN       DATE = NULL,
@USUARIO         INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME, @CLIENTE INT, @INSTALACION INT
DECLARE @FIN_INFINITO DATE = '9999-12-31'

SELECT  @CLIENTE = gtr_cliente, @INSTALACION = gtr_cliente_instalacion
FROM    [dbo].[Grupo_Trabajo] WHERE gtr_id = @GRUPO_TRABAJO

IF @CLIENTE IS NULL
BEGIN
    RAISERROR('1.- EL GRUPO DE TRABAJO NO EXISTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @FECHA_INICIO = ISNULL(@FECHA_INICIO, CAST(@DATE_NOW AS DATE))

BEGIN
    -- 2. El integrante debe pertenecer al cliente del grupo
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                    WHERE ucl_id_usuario = @USUARIO_DESTINO
                      AND ucl_id_cliente = @CLIENTE
                      AND ISNULL(ucl_habilitado, 0) = 1)
    BEGIN
        RAISERROR('2.- EL USUARIO NO ESTÁ AFILIADO Y VIGENTE EN ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* 3. (Bloque 340) Ya no se rechaza a quien no esta autorizado en la
          planta del grupo: Root y el administrador del cliente arman los
          grupos con quien quieran. Sumarlo a un grupo de una planta lo
          AUTORIZA en ella (mas abajo, en la misma transaccion), porque
          integrar una cuadrilla de esa planta es trabajar en ella. */

    -- 4. Fechas coherentes
    IF @FECHA_FIN IS NOT NULL AND @FECHA_FIN < @FECHA_INICIO
    BEGIN
        RAISERROR('4.- LA FECHA DE TÉRMINO NO PUEDE SER ANTERIOR A LA DE INICIO.', 16, 1)
        RETURN -1
    END

    -- 5. La misma persona no puede tener dos tramos solapados en el grupo
    IF EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo_Usuario]
                WHERE gtu_grupo_trabajo = @GRUPO_TRABAJO
                  AND gtu_usuario       = @USUARIO_DESTINO
                  AND gtu_fecha_inicio               <= ISNULL(@FECHA_FIN, @FIN_INFINITO)
                  AND ISNULL(gtu_fecha_fin, @FIN_INFINITO) >= @FECHA_INICIO)
    BEGIN
        RAISERROR('5.- EL USUARIO YA PERTENECE AL GRUPO EN ESE PERÍODO.', 16, 1)
        RETURN -1
    END

    -- 6. Un solo lider vigente a la vez
    IF @ES_LIDER = 1
       AND EXISTS (SELECT 1 FROM [dbo].[Grupo_Trabajo_Usuario]
                    WHERE gtu_grupo_trabajo = @GRUPO_TRABAJO
                      AND gtu_es_lider      = 1
                      AND gtu_fecha_inicio               <= ISNULL(@FECHA_FIN, @FIN_INFINITO)
                      AND ISNULL(gtu_fecha_fin, @FIN_INFINITO) >= @FECHA_INICIO)
    BEGIN
        RAISERROR('6.- EL GRUPO YA TIENE UN LÍDER VIGENTE EN ESE PERÍODO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Grupo_Trabajo_Usuario]
        (
            gtu_grupo_trabajo,
            gtu_usuario,
            gtu_es_lider,
            gtu_fecha_inicio,
            gtu_fecha_fin,
            gtu_usuario_creacion,
            gtu_fecha_creacion
        )
    VALUES
        (
            @GRUPO_TRABAJO,
            @USUARIO_DESTINO,
            @ES_LIDER,
            @FECHA_INICIO,
            @FECHA_FIN,
            @USUARIO,
            @DATE_NOW
        )

    SET @ID = SCOPE_IDENTITY()

    IF @INSTALACION IS NOT NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                    WHERE ciu_id_usuario = @USUARIO_DESTINO
                      AND ciu_id_instalacion = @INSTALACION)
            UPDATE [dbo].[Cliente_Instalacion_Usuario]
               SET ciu_habilitado = 1
             WHERE ciu_id_usuario = @USUARIO_DESTINO
               AND ciu_id_instalacion = @INSTALACION
               AND ciu_habilitado = 0
        ELSE
            INSERT INTO [dbo].[Cliente_Instalacion_Usuario]
                (ciu_id_instalacion, ciu_id_usuario, ciu_usuario_creacion, ciu_fecha_creacion,
                 ciu_habilitado, ciu_fecha_inicio, ciu_fecha_fin)
            VALUES
                (@INSTALACION, @USUARIO_DESTINO, @USUARIO, @DATE_NOW,
                 1, CAST(@DATE_NOW AS DATE), NULL)
    END

    IF @ID IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_GRUPO_TRABAJO_USUARIO @GRUPO_TRABAJO = ' +
              LTRIM(STR(@GRUPO_TRABAJO)) + ',@USUARIO_DESTINO = ' + LTRIM(STR(@USUARIO_DESTINO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '7.- NO FUE POSIBLE AGREGAR EL INTEGRANTE.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO
