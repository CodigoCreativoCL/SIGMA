USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     COMPANEROS FILTRADOS POR PERFIL, CON FOTO Y ESPECIALIDAD.
-- =============================================
-- TRES COSAS, Y UNA DE ELLAS ES UN DEFECTO
--
-- 1) EL FILTRO POR PERFIL
--
--    El SP devolvia a TODOS los usuarios habilitados de la instalacion. Al
--    sumar a alguien a un trabajo aparecian el gerente comercial y el
--    administrador, que no van a estar delante de la maquina.
--
--    Va como parametro y no escrito adentro porque las dos hojas de la app
--    -sumar compañero y compartir- pueden pedir conjuntos distintos, y el dia
--    que uno cambie no hay que tocar SQL. Nulo devuelve todo, como antes: la
--    web sigue llamando igual.
--
-- 2) EL SEPARADOR ESTABA ROTO, Y POR ESO NO SE VEIAN LAS ESPECIALIDADES
--
--    El SP concatenaba con N' Â· ' -mojibake: el punto medio guardado como si
--    fuera Latin-1- y la app parte por ' · '. NUNCA calzaban, asi que los
--    chips de oficio no habrian aparecido ni con datos cargados. Es la misma
--    familia del sqlcmd-lee-ANSI: por eso este script SE APLICA CON -f 65001,
--    y sin eso vuelve a entrar roto sin que nada avise.
--
-- 3) LA FOTO
--
--    Viaja como RUTA DE BLOB, igual que la del activo en API_SEL_ACTIVO_FOTO:
--    la app la pide a /archivo/ver, la deduplica y la cachea. No se manda el
--    binario: una lista de veinte personas serian veinte fotos dentro del
--    mismo JSON, en una red de planta.
--
--    HOY NINGUN USUARIO TIENE FOTO -0 filas con usu_archivo_foto- asi que la
--    columna llega nula y la app pinta las iniciales. Eso no es un fallo: es
--    el respaldo, y es el que se va a ver hasta que alguien cargue fotos desde
--    la web.
--
-- Y UN AVISO QUE NO ES DE CODIGO
--
--    Usuario_Especialidad tiene 0 filas. Hay 9 especialidades definidas y
--    ninguna asignada, asi que agrupar por especialidad va a mostrar un solo
--    grupo -«Sin especialidad»- hasta que se carguen desde la web. El SP y la
--    app quedan listos; el dato no esta.
-- =============================================
SET NOCOUNT ON
GO

CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_COMPANERO]
@CLIENTE     INT,
@USUARIO     INT,
@INSTALACION INT,
@FILTRO      VARCHAR(200) = NULL,
/* Lista de ids de perfil separados por coma: '13,4,11,12'. Nulo = todos, que
   es como se comportaba antes de existir este parametro. */
@PERFILES    VARCHAR(100) = NULL
AS
SET NOCOUNT ON

    SELECT      USU.usu_id      AS usu_id,
                LTRIM(RTRIM(ISNULL(USU.usu_nombre, N'') + N' ' +
                            ISNULL(USU.usu_apellido_paterno, N''))) AS NOMBRE,
                USU.usu_login   AS LOGIN,
                MAX(PER.per_nombre) AS PERFIL_NOMBRE,

                /* El id, no solo el nombre: la app agrupa por perfil y agrupar
                   por texto se rompe con un acento o una mayuscula. */
                MAX(PER.per_id)     AS PERFIL_ID,

                /* La ruta del blob. MAX porque el GROUP BY es por usuario y
                   la foto es una sola. */
                MAX(ARC.arc_ruta)   AS FOTO_RUTA,

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
    /* La foto, si la hay. LEFT porque hoy no la hay para nadie. */
    LEFT  JOIN  [dbo].[Archivo]                     ARC ON ARC.arc_id = USU.usu_archivo_foto
                                                       AND ARC.arc_cliente = @CLIENTE
    WHERE       CIU.ciu_id_instalacion = @INSTALACION
      AND       ISNULL(CIU.ciu_habilitado, 0) = 1
      AND       CIN.cin_cliente        = @CLIENTE
      AND       USU.usu_id            <> @USUARIO
      AND       ISNULL(USU.usu_habilitado, 0) = 1
      AND       (@FILTRO IS NULL OR @FILTRO = ''
                 OR USU.usu_nombre            LIKE '%' + @FILTRO + '%'
                 OR USU.usu_apellido_paterno  LIKE '%' + @FILTRO + '%'
                 OR USU.usu_login             LIKE '%' + @FILTRO + '%')
      /* El filtro por perfil. Se compara contra la lista con separadores a los
         dos lados para que '1' no calce dentro de '11' ni de '13'. */
      AND       (@PERFILES IS NULL OR @PERFILES = ''
                 OR EXISTS (SELECT 1
                              FROM [dbo].[Usuario_Perfil] UP2
                             WHERE UP2.upe_usuario = USU.usu_id
                               AND ',' + @PERFILES + ',' LIKE
                                   '%,' + CAST(UP2.upe_perfil AS VARCHAR(10)) + ',%'))
    GROUP BY    USU.usu_id, USU.usu_nombre, USU.usu_apellido_paterno, USU.usu_login
    ORDER BY    NOMBRE
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
PRINT '--- sin filtro de perfil (como antes) ---'
EXEC [dbo].[API_SEL_APP_COMPANERO] @CLIENTE = 1, @USUARIO = 8, @INSTALACION = 3
GO
PRINT '--- solo los cuatro perfiles de terreno ---'
EXEC [dbo].[API_SEL_APP_COMPANERO] @CLIENTE = 1, @USUARIO = 8, @INSTALACION = 3, @PERFILES = '13,4,11,12'
GO
