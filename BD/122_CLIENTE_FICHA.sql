/* ============================================================================
   SIGMA — Bloque 122
   LA FICHA CORPORATIVA DEL CLIENTE
   ----------------------------------------------------------------------------

   QUE RESUELVE

     La pantalla de identidad mostraba los campos crudos: `cli_pais` es un
     numero, `cli_zona_horaria` otro. Para escribir "Chile" y "Hora de Chile
     continental" habia que ir a buscar cuatro catalogos por separado desde
     el C#.

     Este SP entrega la ficha completa —los datos, los nombres resueltos, los
     conteos y quien la creo y la modifico— en una sola consulta. Es la misma
     razon de siempre: la web y la app tienen que decir lo mismo, y si cada
     una arma la frase por su cuenta terminan discrepando.

   LO QUE NO INVENTA

     `Cliente` no tiene contacto ni datos comerciales: esas columnas no
     existen en el modelo. La ficha lo dice asi —"sin contacto configurado"—
     en vez de dejar el espacio en blanco o, peor, inventar un campo.

     Tampoco hay historial de cambios: no existe `Cliente_Historial`. Lo que
     si existe es quien creo el registro y quien lo toco por ultima vez, y eso
     es lo que se entrega. Llamarlo "historial" seria prometer un registro de
     cambios que nadie esta guardando.

   LA CONFIGURACION "COMPLETA" SE CALCULA

     Zona horaria, idioma y moneda son las tres que hacen que las fechas, los
     formatos y los montos se muestren bien. Con las tres puestas la
     configuracion esta completa; si falta alguna, se dice CUAL. Un "completa"
     que no se puede verificar no sirve de nada.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.SEL_CLIENTE_FICHA') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_CLIENTE_FICHA]
GO

CREATE PROCEDURE [dbo].[SEL_CLIENTE_FICHA]
    @CLIENTE    INT
AS
SET NOCOUNT ON

    SELECT  c.cli_id,
            ISNULL(c.cli_nombre, '')            AS cli_nombre,
            ISNULL(c.cli_razon_social, '')      AS cli_razon_social,
            ISNULL(c.cli_nombre_fantasia, '')   AS cli_nombre_fantasia,
            ISNULL(c.cli_identificador, '')     AS cli_identificador,
            c.cli_habilitado,
            c.cli_archivo_logo,

            c.cli_pais,
            ISNULL(p.pai_nombre, '')            AS PAIS_NOMBRE,
            /* Como se llama el identificador EN ESE PAIS: RUT en Chile, CUIT
               en Argentina. Rotular todo como "RUT" es correcto en una sola
               parte del mapa. */
            ISNULL(p.pai_identificador_nombre, 'Identificador') AS IDENTIFICADOR_ROTULO,

            c.cli_zona_horaria,
            ISNULL(z.zho_nombre, '')            AS ZONA_HORARIA_NOMBRE,
            c.cli_idioma,
            ISNULL(i.idi_nombre, '')            AS IDIOMA_NOMBRE,
            c.cli_moneda,
            ISNULL(m.mon_nombre, '')            AS MONEDA_NOMBRE,

            /* Cuantas personas y cuantas instalaciones tiene. Son los dos
               numeros que dicen el tamano real de la operacion. */
            USUARIOS = (SELECT COUNT(*) FROM [dbo].[Cliente_Usuario] cu
                         WHERE cu.ucl_id_cliente = c.cli_id AND cu.ucl_habilitado = 1),

            INSTALACIONES = (SELECT COUNT(*) FROM [dbo].[Cliente_Instalacion] ci
                              WHERE ci.cin_cliente = c.cli_id AND ci.cin_habilitado = 1),

            /* Completa = las tres puestas. Si falta alguna se nombra, porque
               "incompleta" sin decir que falta obliga a revisar las tres. */
            CONFIGURACION_COMPLETA = CAST(CASE WHEN c.cli_zona_horaria IS NOT NULL
                                                AND c.cli_idioma IS NOT NULL
                                                AND c.cli_moneda IS NOT NULL
                                               THEN 1 ELSE 0 END AS BIT),

            CONFIGURACION_FALTA =
                LTRIM(RTRIM(
                    CASE WHEN c.cli_zona_horaria IS NULL THEN 'zona horaria, ' ELSE '' END +
                    CASE WHEN c.cli_idioma IS NULL       THEN 'idioma, '       ELSE '' END +
                    CASE WHEN c.cli_moneda IS NULL       THEN 'moneda, '       ELSE '' END)),

            /* Quien lo creo y quien lo toco por ultima vez. NO es un
               historial de cambios: eso no se esta guardando en ninguna
               parte, y llamarlo asi prometeria un registro que no existe. */
            c.cli_usuario_creacion,
            c.cli_fecha_creacion,
            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            c.cli_usuario_actualizacion,
            c.cli_fecha_actualizacion,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE

    FROM    [dbo].[Cliente] c
    LEFT JOIN [dbo].[Paises] p       ON p.pai_id = c.cli_pais
    LEFT JOIN [dbo].[Zona_Horaria] z ON z.zho_id = c.cli_zona_horaria
    LEFT JOIN [dbo].[Idioma] i       ON i.idi_id = c.cli_idioma
    LEFT JOIN [dbo].[Moneda] m       ON m.mon_id = c.cli_moneda
    LEFT JOIN [dbo].[Usuario] uc     ON uc.usu_id = c.cli_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua     ON ua.usu_id = c.cli_usuario_actualizacion
    WHERE   c.cli_id = @CLIENTE
GO

PRINT '--- SEL_CLIENTE_FICHA creado.'
GO

EXEC [dbo].[SEL_CLIENTE_FICHA] @CLIENTE = 1
GO

PRINT '122_CLIENTE_FICHA aplicado.'
GO
