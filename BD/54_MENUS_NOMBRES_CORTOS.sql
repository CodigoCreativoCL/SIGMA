/* ============================================================================
   SIGMA — Bloque 54
   NOMBRES DE MENU MAS CORTOS
   ----------------------------------------------------------------------------

   El menu lateral tiene poco mas de 200px de ancho. Un nombre de 26
   caracteres -"Especialidades del usuario"- se parte en tres lineas y empuja
   al resto; se lee peor, no mejor.

   La regla es que **el nombre no repite lo que ya dice el padre**. Colgando
   de "Usuarios", el item no necesita decir "del usuario": el arbol ya lo
   dijo. Antes esos nombres colgaban de "Organizacion" y ahi la coletilla si
   hacia falta para distinguir "Especialidades del usuario" de una
   especialidad como catalogo. Agrupado por tema, sobra.

   Se aprovecha para poner las tildes que faltaban: Menus, Paises, Modulos,
   Geografica. No es cosmetica menor, es la lista que el usuario lee todo el
   dia.
   ============================================================================ */


/* ---- Cliente > Usuarios ------------------------------------------------
   El padre ya dice "Usuarios", asi que la coletilla es ruido.
   "Usuarios > Usuarios" se conserva a proposito: es el listado principal, y
   nombrarlo "Listado" o "Personas" seria mas corto pero menos claro.
   ---------------------------------------------------------------------- */
UPDATE [dbo].[Menus] SET mnu_nombre = N'Permisos'       WHERE mnu_id = 2090
UPDATE [dbo].[Menus] SET mnu_nombre = N'Especialidades' WHERE mnu_id = 2088
UPDATE [dbo].[Menus] SET mnu_nombre = N'Grupos'         WHERE mnu_id = 2083
GO

/* ---- Cliente > Organizacion --------------------------------------------
   "Centros de costo" no se acorta a "Centros": es el termino contable y
   partirlo lo vuelve ambiguo. Solo se corrige la mayuscula de mas.
   ---------------------------------------------------------------------- */
UPDATE [dbo].[Menus] SET mnu_nombre = N'Centros de costo' WHERE mnu_id = 2082
GO

/* ---- Comercial --------------------------------------------------------- */
UPDATE [dbo].[Menus] SET mnu_nombre = N'Reasignaciones' WHERE mnu_id = 31
UPDATE [dbo].[Menus] SET mnu_nombre = N'Clientes'       WHERE mnu_id = 27   -- abre el LISTADO, decia "Cliente"
GO

/* ---- Sistema ----------------------------------------------------------- */
UPDATE [dbo].[Menus] SET mnu_nombre = N'Geografía'  WHERE mnu_id = 7
UPDATE [dbo].[Menus] SET mnu_nombre = N'Países'     WHERE mnu_id = 8
UPDATE [dbo].[Menus] SET mnu_nombre = N'Menús'      WHERE mnu_id = 6
UPDATE [dbo].[Menus] SET mnu_nombre = N'Mantenedor' WHERE mnu_id = 2061      -- cuelga de Acceso, junto a "Menús"
UPDATE [dbo].[Menus] SET mnu_nombre = N'Módulos'    WHERE mnu_id = 1062
GO


/* ========================================================================
   VERIFICACION

      Se mide el nombre mas largo del arbol visible: es el que decide si la
      lista se parte en dos lineas.
   ======================================================================== */

SELECT  'nombres visibles de mas de 18 caracteres' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Menus]
          WHERE mnu_visible = 1 AND LEN(mnu_nombre) > 18) AS HAY,
        0 AS ESPERADO
UNION ALL
SELECT  'el mas largo mide',
        (SELECT MAX(LEN(mnu_nombre)) FROM [dbo].[Menus] WHERE mnu_visible = 1),
        16   -- "Centros de costo"
GO

SELECT  mnu_id, LARGO = LEN(mnu_nombre), mnu_nombre
FROM    [dbo].[Menus]
WHERE   mnu_visible = 1
ORDER BY LEN(mnu_nombre) DESC, mnu_nombre
GO
