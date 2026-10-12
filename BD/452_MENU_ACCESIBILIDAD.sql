/* ============================================================================
   SIGMA — Bloque 452
   PERMISO Y MENÚ DE ACCESIBILIDAD (HU-162, T-5338)
   ----------------------------------------------------------------------------

   La pantalla de accesibilidad es de autoservicio: cada persona configura SUS
   opciones. Por eso el permiso «CONFIGURAR ACCESIBILIDAD» se concede a TODOS los
   perfiles —nadie debería quedar sin poder ajustar cómo ve y escucha SIGMA—, y
   la fila en Menus cuelga de «Utilidades», junto a las otras herramientas
   personales (escanear, etiquetas, carga de datos).

   SIN FILA EN MENUS LA PANTALLA NO SE ABRE
     Token.ExigirPagina() resuelve la URL contra Menus.mnu_link; sin esta fila,
     Accesibilidad.aspx daría acceso denegado aunque exista el archivo.

   Idempotente (MERGE del permiso, grant con NOT EXISTS, menú con NOT EXISTS).
   ============================================================================ */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

/* ---- 1. el permiso ---- */
MERGE [dbo].[Permiso] AS D
USING (VALUES
      ('CONFIGURAR ACCESIBILIDAD', 'Configurar la accesibilidad propia',
       'SISTEMA', 2,
       'Permite a la persona ajustar sus propias opciones de accesibilidad: tamaño del texto, alto contraste, iconos grandes, voz y sonido. Cada quien configura la suya.')
) AS O (codigo, nombre, modulo, ambito, descripcion)
   ON D.prm_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito,
            prm_descripcion, prm_usuario_creacion, prm_fecha_creacion)
    VALUES (O.codigo, O.nombre, O.modulo, O.ambito, O.descripcion, @ROOT, @AHORA)
WHEN MATCHED THEN
    UPDATE SET D.prm_nombre = O.nombre, D.prm_modulo = O.modulo, D.prm_descripcion = O.descripcion;
GO

/* ---- 2. a TODOS los perfiles ---- */
DECLARE @ROOT INT = 1, @AHORA DATETIME = GETDATE()

INSERT  [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  PER.per_id, PRM.prm_id, @ROOT, @AHORA
FROM    [dbo].[Perfiles] PER
CROSS JOIN [dbo].[Permiso] PRM
WHERE   PRM.prm_codigo = N'CONFIGURAR ACCESIBILIDAD'
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] PP
                     WHERE PP.ppe_perfil = PER.per_id AND PP.ppe_permiso = PRM.prm_id)

PRINT '  Permiso CONFIGURAR ACCESIBILIDAD asignado a todos los perfiles.'
GO

/* ---- 3. la pantalla en el menú, bajo «Utilidades» ---- */
DECLARE @UTIL INT = (SELECT mnu_id FROM [dbo].[Menus] WHERE mnu_nombre COLLATE DATABASE_DEFAULT = N'Utilidades' AND mnu_nivel = 2)

INSERT INTO [dbo].[Menus]
    ([mnu_nombre], [mnu_descripcion], [mnu_nivel], [mnu_padre], [mnu_orden]
    ,[mnu_link], [mnu_visible], [mnu_icon], [mnu_permiso], [mnu_ambito])
SELECT
     N'Accesibilidad', N'Ajusta cómo ves y escuchas SIGMA (texto, contraste, voz y sonido)', 3, @UTIL, 20
    ,N'~/View/Comun/Accesibilidad/Accesibilidad.aspx', 1, N'mdi mdi-human-wheelchair', p.[prm_id], 1
  FROM [dbo].[Permiso] p
 WHERE p.[prm_codigo] = N'CONFIGURAR ACCESIBILIDAD'
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Menus] m WHERE m.[mnu_link] = N'~/View/Comun/Accesibilidad/Accesibilidad.aspx')

PRINT '--- Menu de Accesibilidad registrado bajo Utilidades (bloque 452).'
GO
