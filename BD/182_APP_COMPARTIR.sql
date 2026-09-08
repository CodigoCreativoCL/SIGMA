USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     COMPARTIR UN TRABAJO CON UN COMPAÑERO DE LA INSTALACION.
-- =============================================
-- QUE RESUELVE
--
--   Un tecnico abre un motor y ve que no lo saca solo: necesita al electrico,
--   o a alguien que sostenga mientras el desmonta. Hoy eso se resuelve por
--   telefono o gritando en la planta, y no queda registrado: la orden termina
--   firmada por uno solo aunque la hicieron dos.
--
-- POR QUE ENTRA POR LA BANDEJA DE ALERTAS Y NO POR UNA PANTALLA NUEVA
--
--   `Alerta` ya es la bandeja de la app: tiene badge, no-leidas, pantalla y
--   push previsto. Una bandeja aparte para «lo que me compartieron» seria un
--   segundo sitio donde mirar, y lo que no se mira no sirve de aviso.
--
-- EL DESTINATARIO ES NUEVO, Y ES OPCIONAL
--
--   Hasta hoy una alerta era para «quien tenga el permiso»: la detecta el
--   sistema y la ve quien corresponda. Compartir es lo contrario —va dirigida
--   a UNA persona—, y sin destinatario el aviso le llegaria a toda la planta.
--
--   `ale_usuario_destinatario` admite NULL, que es como se comportan TODAS las
--   alertas existentes: sin destinatario, manda el permiso como siempre. Es
--   aditivo, ninguna alerta actual cambia.
-- =============================================

SET NOCOUNT ON
GO

/* ---- 1) El destinatario ---- */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID(N'[dbo].[Alerta]')
                  AND name = 'ale_usuario_destinatario')
BEGIN
    ALTER TABLE [dbo].[Alerta]
        ADD [ale_usuario_destinatario] INT NULL

    PRINT 'Alerta.ale_usuario_destinatario agregada.'
END
ELSE
    PRINT 'Alerta.ale_usuario_destinatario ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ALE_USUARIO_DESTINATARIO')
    ALTER TABLE [dbo].[Alerta]
        ADD CONSTRAINT FK_ALE_USUARIO_DESTINATARIO
            FOREIGN KEY ([ale_usuario_destinatario]) REFERENCES [dbo].[Usuario] ([usu_id])
GO

/* ---- 2) El tipo. SIN permiso asociado: quien recibe algo dirigido lo ve,
          tenga el permiso que tenga sobre el modulo. ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'COMPARTIDO')
BEGIN
    /* `Alerta_Tipo` es un catalogo pequeño y sin auditoria: solo codigo,
       nombre, orden, permiso y los enlaces con que la web abre la ficha. */
    INSERT INTO [dbo].[Alerta_Tipo]
        (alt_codigo, alt_nombre, alt_orden, alt_permiso, alt_icono, alt_habilitado)
    VALUES
        ('COMPARTIDO', 'Trabajo compartido',
         (SELECT ISNULL(MAX(alt_orden), 0) + 1 FROM [dbo].[Alerta_Tipo]),
         NULL, 'account-multiple-outline', 1)

    PRINT 'Alerta_Tipo COMPARTIDO creado.'
END
ELSE
    PRINT 'Alerta_Tipo COMPARTIDO ya existe.'
GO


/* ========================================================================
   API_SEL_APP_COMPANERO - con quien se puede compartir

   La lista sale de `Cliente_Instalacion_Usuario`, la MISMA regla que ya usan
   la sabana, las plantas (BD/175) y el contexto (BD/176). Compartir con
   alguien que no trabaja en esa planta es mandarle un aviso sobre un equipo
   que no puede tocar.

   Se excluye a quien comparte: ofrecerse a uno mismo es una fila que nadie va
   a tocar nunca.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_COMPANERO]
@CLIENTE     INT,
@USUARIO     INT,
@INSTALACION INT,
@FILTRO      VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT      USU.usu_id      AS usu_id,
                LTRIM(RTRIM(ISNULL(USU.usu_nombre, N'') + N' ' +
                            ISNULL(USU.usu_apellido_paterno, N''))) AS NOMBRE,
                USU.usu_login   AS LOGIN,
                MAX(PER.per_nombre) AS PERFIL_NOMBRE
    FROM        [dbo].[Cliente_Instalacion_Usuario] CIU
    INNER JOIN  [dbo].[Cliente_Instalacion]         CIN ON CIN.cin_id = CIU.ciu_id_instalacion
    INNER JOIN  [dbo].[Usuario]                     USU ON USU.usu_id = CIU.ciu_id_usuario
    LEFT  JOIN  [dbo].[Usuario_Perfil]              UPE ON UPE.upe_usuario = USU.usu_id
    /* La tabla heredada se llama `Perfiles`, en plural y en mayusculas de
       origen: es de las que el patron dice NO renombrar, se referencian tal
       cual existen. */
    LEFT  JOIN  [dbo].[Perfiles]                    PER ON PER.per_id = UPE.upe_perfil
    WHERE       CIU.ciu_id_instalacion = @INSTALACION
      AND       ISNULL(CIU.ciu_habilitado, 0) = 1
      AND       CIN.cin_cliente        = @CLIENTE
      AND       USU.usu_id            <> @USUARIO
      AND       ISNULL(USU.usu_habilitado, 0) = 1
      AND       (@FILTRO IS NULL OR @FILTRO = ''
                 OR USU.usu_nombre            LIKE '%' + @FILTRO + '%'
                 OR USU.usu_apellido_paterno  LIKE '%' + @FILTRO + '%'
                 OR USU.usu_login             LIKE '%' + @FILTRO + '%')
    GROUP BY    USU.usu_id, USU.usu_nombre, USU.usu_apellido_paterno, USU.usu_login
    ORDER BY    NOMBRE
GO


/* ========================================================================
   API_INS_COMPARTIR - deja el aviso en la bandeja del compañero

   POR QUE EL TITULO LO ARMA EL SP Y NO LA APP

     «Ramiro Perez te compartio OT-1» tiene que decir lo mismo venga del
     telefono de quien sea. Si lo armara la app, dos versiones distintas
     escribirian dos textos para el mismo hecho, y el que quede guardado
     dependeria de quien tenga la app mas vieja.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_COMPARTIR]
@ID           INT = NULL OUTPUT,
@CLIENTE      INT,
@USUARIO      INT,
@DESTINATARIO INT,
@ENTIDAD      VARCHAR(20),
@ENTIDAD_ID   INT,
@MENSAJE      NVARCHAR(500) = NULL,
@UUID         UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

/* Idempotencia, igual que el resto de las escrituras de la app: sin señal se
   reintenta, y sin esto el compañero recibiria el mismo aviso cuatro veces. */
IF (@UUID IS NOT NULL)
BEGIN
    SET @ID = NULL
    SELECT @ID = ale_id FROM [dbo].[Alerta] WHERE ale_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID AS [ID], '200' AS [CODE], 'Ya estaba compartido.' AS [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

IF (@ENTIDAD NOT IN ('ORDEN', 'TAREA', 'ACTIVO'))
BEGIN
    RAISERROR('1.- ESE TIPO DE TRABAJO NO SE PUEDE COMPARTIR.', 16, 1)
    RETURN -1
END

IF (@DESTINATARIO = @USUARIO)
BEGIN
    RAISERROR('2.- NO PUEDES COMPARTIRTE UN TRABAJO A TI MISMO.', 16, 1)
    RETURN -1
END

DECLARE @TIPO INT, @ESTADO INT, @QUIEN NVARCHAR(200), @QUE NVARCHAR(300)
DECLARE @INSTALACION INT, @ACTIVO INT, @ORDEN INT

SELECT @TIPO = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'COMPARTIDO'
/* NUEVA, no ABIERTA: los estados de este catalogo son NUEVA, RECONOCIDA,
   EN GESTION, RESUELTA y DESCARTADA. Un trabajo recien compartido esta sin
   mirar, que es exactamente NUEVA. */
SELECT TOP 1 @ESTADO = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'

SELECT @QUIEN = LTRIM(RTRIM(ISNULL(usu_nombre, N'') + N' ' + ISNULL(usu_apellido_paterno, N'')))
  FROM [dbo].[Usuario] WHERE usu_id = @USUARIO

/* Que se comparte, y de donde cuelga. El vinculo importa: es lo que deja que
   la pantalla de la alerta ABRA el trabajo en vez de solo describirlo. */
IF (@ENTIDAD = 'ORDEN')
BEGIN
    SELECT  @QUE = N'OT-' + CAST(otr_correlativo AS NVARCHAR(20)) + N' - ' + otr_titulo,
            @INSTALACION = otr_cliente_instalacion,
            @ACTIVO = otr_activo,
            @ORDEN = otr_id
      FROM  [dbo].[Orden_Trabajo]
     WHERE  otr_id = @ENTIDAD_ID AND otr_cliente = @CLIENTE
END
ELSE IF (@ENTIDAD = 'TAREA')
BEGIN
    SELECT  @QUE = TAR.tar_titulo,
            @INSTALACION = TAR.tar_cliente_instalacion,
            @ACTIVO = TAR.tar_activo
      FROM  [dbo].[Tarea_Ocurrencia] TOC
      JOIN  [dbo].[Tarea] TAR ON TAR.tar_id = TOC.toc_tarea
     WHERE  TOC.toc_id = @ENTIDAD_ID AND TAR.tar_cliente = @CLIENTE
END
ELSE
BEGIN
    SELECT  @QUE = act_codigo + N' - ' + act_nombre,
            @INSTALACION = act_cliente_instalacion,
            @ACTIVO = act_id
      FROM  [dbo].[Activo]
     WHERE  act_id = @ENTIDAD_ID AND act_cliente = @CLIENTE
END

IF (@QUE IS NULL)
BEGIN
    RAISERROR('3.- ESE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* El destinatario tiene que trabajar en ESA instalacion. Compartir con quien
   no puede pisar la planta es mandarle un aviso que no puede atender. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                WHERE ciu_id_usuario     = @DESTINATARIO
                  AND ciu_id_instalacion = @INSTALACION
                  AND ISNULL(ciu_habilitado, 0) = 1)
BEGIN
    RAISERROR('4.- ESA PERSONA NO ESTA ASIGNADA A LA INSTALACION DEL TRABAJO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Alerta]
        (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo,
         ale_alerta_estado, ale_severidad, ale_titulo, ale_descripcion,
         ale_fecha_deteccion_utc, ale_activo, ale_orden_trabajo,
         ale_usuario_destinatario,
         ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
    VALUES
        (@UUID, @CLIENTE, @INSTALACION, @TIPO,
         @ESTADO, 2, @QUIEN + N' te compartió ' + @QUE,
         ISNULL(@MENSAJE, N'Puede que necesite una mano. Ábrelo para ver de qué se trata.'),
         GETUTCDATE(), @ACTIVO, @ORDEN,
         @DESTINATARIO,
         @USUARIO, GETDATE(), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('5.- NO FUE POSIBLE COMPARTIR EL TRABAJO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS [ID], '201' AS [CODE], 'Compartido.' AS [MENSAJE]
RETURN 0
GO
