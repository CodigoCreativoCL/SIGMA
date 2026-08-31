/* ============================================================================
   SIGMA — Bloque 62
   EL BOTON QUE NO APARECIA · LAS DOS RESPUESTAS QUE NO COINCIDEN
   ----------------------------------------------------------------------------

   1. EL SINTOMA

     Root entra a Bodegas y a Repuestos y no ve el boton "Nuevo". Tampoco lo
     ve nadie. No hay error en pantalla ni en el log.

   2. LA CAUSA

     El bloque 60 creo las 8 filas de Menus del modulo y **ninguna de
     Menu_Funcion**.

     Token.PuedeFuncion("Crear y editar") busca la funcion DE LA PAGINA
     ACTUAL en el mapa que arma SEL_MENUS_PERMISOS_MAPA, y ese mapa sale de
     Menu_Funcion. Sin fila, devuelve false para todos —Root incluido— y el
     boton no se pinta.

     El propio comentario de Token.PuedeFuncion lo advierte:

        "aqui no redirige a nadie, simplemente el boton de Crear o de Emitir
         no aparece y quien mira concluye que le falta un permiso que en
         realidad tiene."

     Ya habia pasado con las fichas del modulo de suscripcion. Queda escrito
     en PATRONES/ASP/CHECKLIST_ENTIDAD_NUEVA.md §5 para que no pase una
     tercera vez: **cada menu nuevo lleva su Menu_Funcion**.

   3. LO QUE APARECIO BUSCANDO ESO

     Hay DOS implementaciones de "este usuario tiene este permiso" y no
     responden lo mismo:

        SEL_USUARIO_PERMISOS       -> Root ve todo, por regla explicita
        FNC_USUARIO_TIENE_PERMISO  -> no tiene esa regla

     Y hay algo peor: la funcion exige una fila en Cliente_Usuario y sale con
     RETURN 0 si no la hay. Root, Soporte y Gerente Comercial son cuentas de
     plataforma y **no tienen afiliacion a ningun cliente**, asi que para la
     funcion no tienen NINGUN permiso, nunca.

     Se nota poco porque la web usa Token.Puede, que va por el SP. Pero
     SEL_MENU_APP (bloque 58) usa la funcion: el arbol de la app le habria
     salido vacio a Root en cuanto hubiera menus con permiso. Y tambien la
     usa INS_CLIENTE_USUARIO_PERMISO para validar quien puede otorgar.

     Se agrega la regla de Root a la funcion, igual que la del SP.

   4. LO QUE NO SE TOCA, Y POR QUE

     El SP tambien cuenta los perfiles de Usuario_Perfil, y la funcion no.
     Parece la misma omision, pero **no se corrige aca**: Usuario_Perfil esta
     poblado EN ESPEJO de Cliente_Usuario_Perfil desde el bloque 49, asi que
     cada usuario de cliente tiene ahi su perfil. Contarlo en la funcion le
     daria sus permisos en CUALQUIER cliente, no solo en el suyo.

     O sea que la diferencia entre las dos implementaciones sigue existiendo
     y hay que decidirla: o el SP deja de contar los perfiles globales para
     los usuarios afiliados, o el espejo deja de poblarse para ellos. Queda
     anotado en el MD de estado como decision abierta; adivinar cual es la
     buena y aplicarla en silencio es como se abren agujeros.
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. Menu_Funcion DEL MODULO DE INVENTARIO

      Solo los listados: Menu_Funcion cuelga del listado y desde la ficha no
      resuelve. Las fichas usan Token.Puede("CODIGO") directo, que es lo que
      ya hacen.

      Existencias no lleva ninguna: es de solo lectura y no tiene boton.
      Movimientos tampoco: su boton se resuelve con Token.Puede sobre los
      tres permisos de operacion, porque cual mostrar depende de cual de los
      tres tenga la persona.
   ======================================================================== */
DECLARE @F TABLE (link NVARCHAR(500) COLLATE DATABASE_DEFAULT,
                  funcion NVARCHAR(200) COLLATE DATABASE_DEFAULT,
                  permiso NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @F VALUES
    (N'~/View/Inventario/Bodegas/Bodegas.aspx',     N'Crear y editar',   N'CREAR EDITAR BODEGAS'),
    (N'~/View/Inventario/Repuestos/Repuestos.aspx', N'Crear y editar',   N'CREAR EDITAR REPUESTOS'),
    (N'~/View/Inventario/Repuestos/Repuestos.aspx', N'Gestionar stock',  N'GESTIONAR STOCK')

INSERT INTO [dbo].[Menu_Funcion] (mfu_menu, mfu_nombre, mfu_permiso)
SELECT  m.mnu_id, f.funcion, p.prm_id
FROM    @F f
JOIN    [dbo].[Menus]   m ON m.mnu_link COLLATE DATABASE_DEFAULT = f.link
JOIN    [dbo].[Permiso] p ON p.prm_codigo = f.permiso
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion] x
                     WHERE x.mfu_menu = m.mnu_id
                       AND x.mfu_nombre COLLATE DATABASE_DEFAULT = f.funcion)

DECLARE @N_FUN INT
SELECT  @N_FUN = COUNT(*)
FROM    [dbo].[Menu_Funcion] f
JOIN    [dbo].[Menus] m ON m.mnu_id = f.mfu_menu
WHERE   m.mnu_link LIKE '%/Inventario/%'

PRINT '--- Menu_Funcion del inventario: ' + LTRIM(STR(@N_FUN))
GO


/* ========================================================================
   2. Perfil_Permiso PARA ROOT Y SOPORTE

      ROOT
        SEL_USUARIO_PERMISOS ya le devuelve todo por regla, asi que estas
        filas no le cambian lo que puede. Se agregan igual para que la
        matriz de permisos se pueda LEER: un Root con dos filas en una
        pantalla que muestra diez por perfil se lee como si le faltaran
        ocho.

      SOPORTE
        "Ve todo y no toca nada" (bloque 52). Solo los VER. Darle
        CREAR EDITAR seria convertir a la cuenta de soporte en una cuenta
        de operacion, que es justo lo que esa decision descarto.
   ======================================================================== */
DECLARE @PP TABLE (perfil INT, codigo NVARCHAR(100) COLLATE DATABASE_DEFAULT)

INSERT INTO @PP
-- Root (1): el modulo completo
SELECT 1, prm_codigo FROM [dbo].[Permiso]
 WHERE prm_modulo IN ('INVENTARIO', 'REPUESTOS') AND prm_habilitado = 1
UNION ALL
-- Soporte (2): solo mirar
SELECT 2, codigo FROM (VALUES
    (N'VER BODEGAS'), (N'VER REPUESTOS'), (N'VER EXISTENCIAS')) v(codigo)

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  pp.perfil, p.prm_id, 1, GETDATE()
FROM    @PP pp
JOIN    [dbo].[Permiso] p ON p.prm_codigo = pp.codigo
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] x
                     WHERE x.ppe_perfil = pp.perfil AND x.ppe_permiso = p.prm_id)
GO


/* ========================================================================
   3. FNC_USUARIO_TIENE_PERMISO — LA REGLA DE ROOT

      Se agrega ARRIBA DE TODO, antes del chequeo de afiliacion: Root no
      tiene fila en Cliente_Usuario y ese RETURN 0 es el que lo dejaba sin
      nada.

      Es la misma regla que ya tenia SEL_USUARIO_PERMISOS. Lo unico que se
      hace es que las dos implementaciones respondan igual para Root.
   ======================================================================== */
IF OBJECT_ID('dbo.FNC_USUARIO_TIENE_PERMISO') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO]
GO

CREATE FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO         INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY             DATE = CAST(GETDATE() AS DATE)
    DECLARE @POR_PERFIL      BIT  = 0
    DECLARE @OTORGADO        BIT
    DECLARE @RESULTADO       BIT  = 0

    SELECT @PERMISO = prm_id
      FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    /* ---- Root ve todo (bloque 62) ----
       Va antes del chequeo de afiliacion a proposito: Root es una cuenta de
       plataforma y no tiene fila en Cliente_Usuario. Sin esto, la funcion le
       devolvia 0 para TODO permiso, y SEL_MENU_APP le habria dejado el arbol
       de la app vacio.

       Es la misma regla que SEL_USUARIO_PERMISOS ya tenia. */
    IF EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil]
                WHERE upe_usuario = @USUARIO AND upe_perfil = 1)
        RETURN 1

    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO
       AND ucl_id_cliente = @CLIENTE
       AND ISNULL(ucl_habilitado, 0) = 1
    IF @CLIENTE_USUARIO IS NULL RETURN 0

    -- 1. Lo que entrega el perfil dentro de ese cliente
    IF EXISTS (SELECT 1
                 FROM [dbo].[Cliente_Usuario_Perfil] cup
                 JOIN [dbo].[Perfil_Permiso]         ppe ON ppe.ppe_perfil = cup.cup_id_perfil
                WHERE cup.cup_id_cliente_usuario = @CLIENTE_USUARIO
                  AND ppe.ppe_permiso            = @PERMISO)
        SET @POR_PERFIL = 1

    -- 2. La regla de usuario mas especifica: la de la planta gana sobre la global
    SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
      FROM [dbo].[Cliente_Usuario_Permiso] cpm
     WHERE cpm.cpm_cliente_usuario = @CLIENTE_USUARIO
       AND cpm.cpm_permiso         = @PERMISO
       AND cpm.cpm_habilitado      = 1
       AND cpm.cpm_instalacion_area IS NULL
       AND (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
       AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
       AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
     ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END

    -- 3. La regla de usuario manda sobre el perfil, exista o no
    SET @RESULTADO = CASE WHEN @OTORGADO IS NOT NULL THEN @OTORGADO ELSE @POR_PERFIL END

    -- 4. Sin autorizacion vigente en la planta no hay permiso que valga
    IF @RESULTADO = 1 AND @INSTALACION IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        WHERE ciu.ciu_id_usuario     = @USUARIO
                          AND ciu.ciu_id_instalacion = @INSTALACION
                          AND ciu.ciu_habilitado     = 1
                          AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                          AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            SET @RESULTADO = 0
    END

    RETURN @RESULTADO
END
GO


/* ========================================================================
   4. VERIFICACION
   ======================================================================== */
PRINT '--- Las funciones que hacen aparecer el boton ---'
SELECT  m.mnu_nombre, m.mnu_link, f.mfu_nombre, p.prm_codigo
FROM    [dbo].[Menu_Funcion] f
JOIN    [dbo].[Menus]   m ON m.mnu_id = f.mfu_menu
JOIN    [dbo].[Permiso] p ON p.prm_id = f.mfu_permiso
WHERE   m.mnu_link LIKE '%/Inventario/%'
ORDER BY m.mnu_nombre, f.mfu_nombre

PRINT '--- Permisos del modulo por perfil ---'
SELECT  pr.per_id, pr.per_nombre, COUNT(*) AS permisos
FROM    [dbo].[Perfil_Permiso] pp
JOIN    [dbo].[Perfiles] pr ON pr.per_id = pp.ppe_perfil
JOIN    [dbo].[Permiso]  p  ON p.prm_id  = pp.ppe_permiso
WHERE   p.prm_modulo IN ('INVENTARIO', 'REPUESTOS')
GROUP BY pr.per_id, pr.per_nombre
ORDER BY pr.per_id

PRINT '--- Las dos implementaciones, comparadas para Root ---'
SELECT  'CREAR EDITAR BODEGAS' AS permiso,
        [dbo].[FNC_USUARIO_TIENE_PERMISO](1, 1, NULL, 'CREAR EDITAR BODEGAS') AS por_funcion,
        CAST(1 AS BIT) AS por_sp_regla_root
GO
