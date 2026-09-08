USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     CREA LA TABLA Usuario_Favorito Y SU UPS.
-- =============================================
-- QUE RESUELVE
--
--   Un tecnico con veinte ordenes en la bandeja vuelve una y otra vez a las
--   mismas tres: la que dejo a medias, la del equipo critico, la que tiene que
--   retomar despues del almuerzo. Hoy las busca desplazando la lista cada vez.
--
-- POR QUE NO ES UN MENU APARTE
--
--   Una pantalla de «Favoritos» seria una lista mas que mantener y un sitio
--   mas donde mirar. Marcar algo como favorito no cambia lo que es: cambia
--   DONDE aparece. Por eso el favorito se fija arriba de la misma bandeja y se
--   filtra con un chip, junto a «Mias» y «Disponibles».
--
-- POR QUE UNA COLUMNA POR ENTIDAD Y NO (entidad, entidad_id)
--
--   Es el mismo mecanismo polimorfico que ya usa `Archivo_Vinculo` en esta
--   base, y por la misma razon: con una columna por entidad hay FK de verdad.
--   Con un par (entidad, entidad_id) generico, borrar una orden deja un
--   favorito apuntando al vacio y nadie se entera hasta que algo falla al
--   leerlo.
--
-- ES RELACION PURA: la baja es fisica.
--
--   Quitar un favorito es quitarlo, no marcarlo como deshabilitado. Guardar el
--   historial de lo que alguien dejo de marcar no le sirve a nadie y obligaria
--   a filtrar por `habilitado` en cada consulta.
-- =============================================

SET NOCOUNT ON
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[Usuario_Favorito]') AND type = 'U'
)
BEGIN
    CREATE TABLE [dbo].[Usuario_Favorito]
    (
        [ufv_id]                INT      NOT NULL IDENTITY(1,1),
        [ufv_usuario]           INT      NOT NULL,

        /* El favorito es POR CLIENTE. La misma persona puede trabajar para dos
           empresas, y lo que fijo arriba en una no tiene por que aparecerle en
           la otra. */
        [ufv_cliente]           INT      NOT NULL,

        /* Exactamente una de las tres, garantizado por el CHECK de abajo. */
        [ufv_orden_trabajo]     INT      NULL,
        [ufv_tarea_ocurrencia]  INT      NULL,
        [ufv_activo]            INT      NULL,

        [ufv_usuario_creacion]  INT      NOT NULL,
        [ufv_fecha_creacion]    DATETIME NOT NULL
            CONSTRAINT DF_UFV_FECHA_CREACION DEFAULT GETDATE(),

        CONSTRAINT PK_USUARIO_FAVORITO PRIMARY KEY CLUSTERED ([ufv_id] ASC),

        CONSTRAINT FK_UFV_USUARIO FOREIGN KEY ([ufv_usuario])
            REFERENCES [dbo].[Usuario] ([usu_id]),
        CONSTRAINT FK_UFV_CLIENTE FOREIGN KEY ([ufv_cliente])
            REFERENCES [dbo].[Cliente] ([cli_id]),
        CONSTRAINT FK_UFV_ORDEN_TRABAJO FOREIGN KEY ([ufv_orden_trabajo])
            REFERENCES [dbo].[Orden_Trabajo] ([otr_id]),
        CONSTRAINT FK_UFV_TAREA_OCURRENCIA FOREIGN KEY ([ufv_tarea_ocurrencia])
            REFERENCES [dbo].[Tarea_Ocurrencia] ([toc_id]),
        CONSTRAINT FK_UFV_ACTIVO FOREIGN KEY ([ufv_activo])
            REFERENCES [dbo].[Activo] ([act_id]),

        /* UNA y solo una entidad. Sin esto, una fila con las tres en NULL es
           un favorito de nada, y una con dos es un favorito ambiguo: las dos
           se leen como datos validos y ninguna lo es. */
        CONSTRAINT CK_UFV_UNA_ENTIDAD CHECK (
            (CASE WHEN [ufv_orden_trabajo]    IS NULL THEN 0 ELSE 1 END +
             CASE WHEN [ufv_tarea_ocurrencia] IS NULL THEN 0 ELSE 1 END +
             CASE WHEN [ufv_activo]           IS NULL THEN 0 ELSE 1 END) = 1
        )
    )

    /* Se consulta siempre «los favoritos de esta persona en este cliente». */
    CREATE NONCLUSTERED INDEX IX_UFV_USUARIO_CLIENTE
        ON [dbo].[Usuario_Favorito] ([ufv_usuario], [ufv_cliente])

    /* Marcar dos veces lo mismo no puede crear dos filas: el UPS ya lo evita,
       pero dos toques rapidos son dos peticiones y la base es el ultimo
       arbitro. Los indices son FILTRADOS porque un UNIQUE normal sobre
       columnas que admiten NULL trataria todos los NULL como iguales. */
    CREATE UNIQUE NONCLUSTERED INDEX UX_UFV_ORDEN
        ON [dbo].[Usuario_Favorito] ([ufv_usuario], [ufv_orden_trabajo])
        WHERE [ufv_orden_trabajo] IS NOT NULL

    CREATE UNIQUE NONCLUSTERED INDEX UX_UFV_TAREA
        ON [dbo].[Usuario_Favorito] ([ufv_usuario], [ufv_tarea_ocurrencia])
        WHERE [ufv_tarea_ocurrencia] IS NOT NULL

    CREATE UNIQUE NONCLUSTERED INDEX UX_UFV_ACTIVO
        ON [dbo].[Usuario_Favorito] ([ufv_usuario], [ufv_activo])
        WHERE [ufv_activo] IS NOT NULL

    PRINT 'Tabla Usuario_Favorito creada correctamente.'
END
ELSE
    PRINT 'Tabla Usuario_Favorito ya existe.'
GO


/* ========================================================================
   API_UPS_FAVORITO - marca o desmarca, y devuelve como quedo

   POR QUE UN SOLO SP Y NO UN INS + UN DEL

     La estrella es un interruptor: la app no sabe —ni tiene por que saber— si
     el favorito ya estaba antes de tocarla. Con dos endpoints, dos toques
     rapidos pueden cruzarse y dejar el estado invertido respecto de lo que
     muestra la pantalla. Un UPS que devuelve ES_FAVORITO deja que la pantalla
     se pinte con lo que dijo la base, no con lo que supone.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_FAVORITO]
@USUARIO    INT,
@CLIENTE    INT,
@ENTIDAD    VARCHAR(20),
@ENTIDAD_ID INT
AS
SET NOCOUNT ON

    IF (@ENTIDAD NOT IN ('ORDEN', 'TAREA', 'ACTIVO'))
    BEGIN
        RAISERROR('1.- ESE TIPO DE FAVORITO NO EXISTE.', 16, 1)
        RETURN -1
    END

    DECLARE @ID INT

    SELECT  @ID = ufv_id
    FROM    [dbo].[Usuario_Favorito]
    WHERE   ufv_usuario = @USUARIO
      AND   ((@ENTIDAD = 'ORDEN'  AND ufv_orden_trabajo    = @ENTIDAD_ID)
          OR (@ENTIDAD = 'TAREA'  AND ufv_tarea_ocurrencia = @ENTIDAD_ID)
          OR (@ENTIDAD = 'ACTIVO' AND ufv_activo           = @ENTIDAD_ID))

    IF (@ID IS NOT NULL)
    BEGIN
        DELETE FROM [dbo].[Usuario_Favorito] WHERE ufv_id = @ID
        SELECT CAST(0 AS BIT) AS ES_FAVORITO
        RETURN 0
    END

    INSERT INTO [dbo].[Usuario_Favorito]
        (ufv_usuario, ufv_cliente,
         ufv_orden_trabajo, ufv_tarea_ocurrencia, ufv_activo,
         ufv_usuario_creacion, ufv_fecha_creacion)
    VALUES
        (@USUARIO, @CLIENTE,
         CASE WHEN @ENTIDAD = 'ORDEN'  THEN @ENTIDAD_ID END,
         CASE WHEN @ENTIDAD = 'TAREA'  THEN @ENTIDAD_ID END,
         CASE WHEN @ENTIDAD = 'ACTIVO' THEN @ENTIDAD_ID END,
         @USUARIO, GETDATE())

    SELECT CAST(1 AS BIT) AS ES_FAVORITO
GO
