USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LA ESPECIALIDAD DE CADA COMPAÑERO, PARA SUMARLO AL TRABAJO.
-- =============================================
-- POR QUE
--
--   Un trabajo lo hacen dos personas de oficios distintos: el mecanico
--   desmonta y el electrico desconecta. Al sumar a alguien a la orden hay que
--   poder buscarlo POR LO QUE SABE HACER, no por su nombre — sobre todo en una
--   planta donde no se conoce a todos.
--
--   `Usuario_Especialidad` y `Especialidad` ya existen (9 especialidades
--   cargadas). Nadie las estaba consultando desde la app.
--
-- POR QUE VIENEN CONCATENADAS Y TAMBIEN LOS IDS
--
--   El nombre —«Mecanico · Electrico»— es lo que se lee en la fila. Los ids
--   son lo que la app usa para filtrar y para mandar `@ESPECIALIDAD` al
--   registrar el tramo: filtrar por texto se rompe con un acento o una
--   mayuscula, y la especialidad del tramo tiene que ser un id de verdad.
--
--   Una persona puede tener varias —un electromecanico las tiene dos— asi que
--   no cabe una sola columna.
--
-- OJO: `Usuario_Especialidad` esta VACIA al 08-09-2026
--
--   La app tiene que verse bien sin ese dato: la fila muestra el perfil como
--   hasta ahora y los chips de filtro NO aparecen. Cuando se carguen, aparecen
--   solos sin tocar la app.
--
-- ES IDEMPOTENTE: CREATE OR ALTER.
-- =============================================

SET NOCOUNT ON
GO

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
                MAX(PER.per_nombre) AS PERFIL_NOMBRE,

                /* Lo que sabe hacer, para leer y para filtrar.

                   `STUFF(... FOR XML PATH(''))` es como se concatena en este
                   servidor: `STRING_AGG` existe desde SQL Server 2017 y esta
                   base convive con instalaciones anteriores. */
                STUFF((SELECT N' · ' + ESP.esp_nombre
                         FROM [dbo].[Usuario_Especialidad] UES
                         JOIN [dbo].[Especialidad]         ESP
                              ON ESP.esp_id = UES.ues_especialidad
                        WHERE UES.ues_usuario = USU.usu_id
                          AND UES.ues_cliente = @CLIENTE
                          AND ISNULL(UES.ues_habilitado, 0) = 1
                        ORDER BY ESP.esp_nombre
                          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'),
                      1, 3, N'')                AS ESPECIALIDADES,

                STUFF((SELECT ',' + CAST(UES.ues_especialidad AS VARCHAR(10))
                         FROM [dbo].[Usuario_Especialidad] UES
                        WHERE UES.ues_usuario = USU.usu_id
                          AND UES.ues_cliente = @CLIENTE
                          AND ISNULL(UES.ues_habilitado, 0) = 1
                          FOR XML PATH(''), TYPE).value('.', 'VARCHAR(200)'),
                      1, 1, '')                 AS ESPECIALIDAD_IDS

    FROM        [dbo].[Cliente_Instalacion_Usuario] CIU
    INNER JOIN  [dbo].[Cliente_Instalacion]         CIN ON CIN.cin_id = CIU.ciu_id_instalacion
    INNER JOIN  [dbo].[Usuario]                     USU ON USU.usu_id = CIU.ciu_id_usuario
    LEFT  JOIN  [dbo].[Usuario_Perfil]              UPE ON UPE.upe_usuario = USU.usu_id
    /* La tabla heredada se llama `Perfiles`, en plural: es de las que el
       patron dice NO renombrar, se referencian tal cual existen. */
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
