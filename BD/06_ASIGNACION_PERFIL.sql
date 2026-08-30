USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     ACCESOS.ASPX ESCRIBE EN Perfil_Permiso, NO EN LAS TABLAS MUERTAS.
-- =============================================
-- Va DESPUES de 05_PAGINAS_RESTANTES.
--
-- EL HUECO QUE CIERRA
--   Los bloques 02 a 05 cambiaron el camino de LECTURA: Token resuelve
--   todo contra Perfil_Permiso. Pero Accesos.aspx -- la unica pantalla
--   que asigna accesos -- seguia ESCRIBIENDO en Menu_Perfil y
--   Menu_Funcion_Perfil, que ya no lee nadie.
--
--   Resultado: marcar un permiso en pantalla no hacia nada. Root entraba
--   igual porque SEL_USUARIO_PERMISOS le hace cortocircuito, asi que el
--   problema no se veia con el unico usuario que existe hoy.
--
-- QUE ES "VER"
--   En el modelo viejo "Ver" era el menu mismo: Paginas.menu_4.Ver = 4 era
--   el mnu_id, y el permiso vivia en Menu_Perfil(perfil, menu).
--   Ahora "Ver" es Menus.mnu_permiso, y otorgarlo es una fila en
--   Perfil_Permiso(perfil, permiso). Por eso no existe -- ni debe existir
--   -- una Menu_Funcion llamada "Ver": seria redundante con abrir la
--   pagina. Las funciones son solo lo que pasa DENTRO.
--
--   La grilla de Accesos.aspx conserva su forma: la columna Ver_0 es el
--   nivel de pagina y las columnas <nombre>_<mfu_id> son las funciones.
--   Cambia de donde salen los datos, no como se ven.
--
-- Menu_Perfil Y Menu_Funcion_Perfil QUEDAN SIN USO
--   No se eliminan en este bloque: estan vacias y no molestan. Se retiran
--   cuando el mantenedor lleve tiempo andando.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. LAS COLUMNAS DE FUNCIONES, AHORA CONTRA Perfil_Permiso
      @MENU es INT, asi que la concatenacion es segura.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_MENU_FUNCIONALIDAD] (@MENU INT)
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @COLUMNS VARCHAR(MAX) = ''

    SELECT @COLUMNS = @COLUMNS +
           ', CAST(CASE WHEN EXISTS (SELECT 1 FROM Perfil_Permiso
                                      WHERE ppe_perfil  = PER_ID
                                        AND ppe_permiso = ' + LTRIM(STR(f.mfu_permiso)) + ')
                        THEN 1 ELSE 0 END AS BIT)[' + f.mfu_nombre + '_' + LTRIM(STR(f.mfu_id)) + ']'
    FROM   [dbo].[Menu_Funcion] f
    WHERE  f.mfu_menu = @MENU
      AND  f.mfu_permiso IS NOT NULL
    ORDER BY f.mfu_id

    IF @COLUMNS = '' SET @COLUMNS = ' '

    RETURN @COLUMNS
END
GO


/* ========================================================================
   2. LA GRILLA DE ACCESOS
      Misma forma de salida: PER_ID, PERFIL, Ver_0 y una columna por funcion.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEGURIDAD_SEL_MENUS_PERMISOS]
    @MENU INT
AS
SET NOCOUNT ON

    DECLARE @PERMISO INT
    SELECT @PERMISO = mnu_permiso FROM [dbo].[Menus] WHERE mnu_id = @MENU

    DECLARE @CMD NVARCHAR(MAX)

    SET @CMD = N'SELECT PER_ID,
                        PER_NOMBRE [PERFIL],
                        CAST(CASE WHEN EXISTS (SELECT 1 FROM Perfil_Permiso
                                                WHERE ppe_perfil  = PER_ID
                                                  AND ppe_permiso = ' + LTRIM(STR(ISNULL(@PERMISO, 0))) + N')
                                  THEN 1 ELSE 0 END AS BIT)[Ver_0]'
             + [dbo].[FNC_MENU_FUNCIONALIDAD](@MENU) + N'
                 FROM   PERFILES
                 WHERE  PER_HABILITADO = 1
                 ORDER BY PER_NOMBRE'

    EXEC sp_executesql @CMD
GO


/* ========================================================================
   3. GUARDAR UNA MARCA DE LA GRILLA
      @FUNCION = 0 es el nivel de pagina ("Ver"); si no, es una funcion.
      Otorgar inserta, quitar borra. Perfil_Permiso no tiene bandera de
      habilitado: estar en la tabla ES tener el permiso.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_PERFIL_PERMISO]
    @PERFIL   INT,
    @MENU     INT = 0,
    @FUNCION  INT = 0,
    @OTORGADO BIT,
    @USUARIO  INT
AS
SET NOCOUNT ON

    DECLARE @PERMISO INT

    IF @FUNCION > 0
        SELECT @PERMISO = mfu_permiso FROM [dbo].[Menu_Funcion] WHERE mfu_id = @FUNCION
    ELSE
        SELECT @PERMISO = mnu_permiso FROM [dbo].[Menus] WHERE mnu_id = @MENU

    IF @PERMISO IS NULL
    BEGIN
        RAISERROR('1.- ESE MENU O FUNCION NO TIENE UN PERMISO ASOCIADO. Asignelo en el mantenedor de menus.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles] WHERE per_id = @PERFIL)
    BEGIN
        RAISERROR('2.- EL PERFIL NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @OTORGADO = 1
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                        WHERE ppe_perfil = @PERFIL AND ppe_permiso = @PERMISO)
            INSERT INTO [dbo].[Perfil_Permiso] ([ppe_perfil],[ppe_permiso],[ppe_usuario_creacion])
            VALUES (@PERFIL, @PERMISO, @USUARIO)
    END
    ELSE
    BEGIN
        -- Root no se puede quedar sin permisos: seria perder el acceso.
        IF @PERFIL = 1
        BEGIN
            RAISERROR('3.- NO SE PUEDEN QUITAR PERMISOS AL PERFIL ROOT.', 16, 1)
            RETURN -1
        END

        DELETE FROM [dbo].[Perfil_Permiso]
         WHERE ppe_perfil = @PERFIL AND ppe_permiso = @PERMISO
    END

RETURN 0
GO


/* ========================================================================
   4. EL SP DE CHEQUEO VIEJO YA NO LO USA NADIE
      SEGURIDAD_SEL_MENUS_PERMISO armaba la consulta concatenando @PERFIL:
          ... WHERE MPE_PERFIL IN (' + @PERFIL + ')
      SQL dinamico concatenado DENTRO del chequeo de autorizacion, que es
      el peor lugar posible para tenerlo. Token ya no lo llama: resuelve
      todo con el set en sesion. Se da de baja.
   ======================================================================== */

IF OBJECT_ID(N'[dbo].[SEGURIDAD_SEL_MENUS_PERMISO]', N'P') IS NOT NULL
    DROP PROCEDURE [dbo].[SEGURIDAD_SEL_MENUS_PERMISO]
GO


/* ========================================================================
   5. COMPROBACION
   ======================================================================== */

SELECT 'permisos por perfil' AS control, p.per_nombre AS detalle, COUNT(pp.ppe_id) AS valor
FROM   [dbo].[Perfiles] p
LEFT   JOIN [dbo].[Perfil_Permiso] pp ON pp.ppe_perfil = p.per_id
GROUP  BY p.per_nombre
GO

EXEC [dbo].[SEGURIDAD_SEL_MENUS_PERMISOS] @MENU = 27
GO
