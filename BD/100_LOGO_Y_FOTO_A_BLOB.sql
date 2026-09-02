/* ============================================================================
   SIGMA — Bloque 100
   EL LOGO Y LA FOTO SE VAN A BLOB STORAGE
   ----------------------------------------------------------------------------

   LO QUE HABIA

     `Cliente.cli_logo` y `Usuario.usu_foto` son `varbinary(max)`: el binario
     guardado DENTRO de SQL Server. Contradice la decision del 29-08 —"todo
     archivo se almacena en Blob Storage"— que ya cumplen el comprobante de
     pago y el permiso de trabajo.

     Y se servian como `data:image/jpeg;base64,...` incrustado en el HTML: la
     imagen viaja entera en CADA carga de pagina y ningun navegador la puede
     cachear. Un logo de 200 KB se transmite otra vez en cada pantalla.

   NO HAY NADA QUE MIGRAR

     Cero clientes con logo, cero usuarios con foto, cero filas en
     `Cliente_Binario`. Se comprobo antes de escribir este bloque. Por eso el
     cambio es puramente aditivo y no lleva script de traspaso: no hay dato
     que traspasar.

   DOS SP CHICOS EN VEZ DE TOCAR NUEVE

     Poner un logo NO es "editar el cliente": es una operacion propia, con un
     solo dato. Meterla en `UPD_CLIENTE` obligaria a tocar tambien
     `INS_CLIENTE`, `SEL_CLIENTE`, y las tres equivalentes de Usuario, mas
     `UPD_USUARIO_MI_PERFIL` — nueve procedimientos, entre ellos los del
     camino de autenticacion.

     `UPD_CLIENTE_LOGO` y `UPD_USUARIO_FOTO` hacen una cosa cada uno. Los
     nueve grandes quedan intactos.

   LAS COLUMNAS VIEJAS NO SE BORRAN TODAVIA

     Estan vacias y ya nadie va a escribirlas, pero dropear una columna es
     irreversible y `SEL_CLIENTE_USUARIO` todavia la nombra con su parametro
     @DEVUELVE_FOTO. Se dejan muertas y anotadas: el dia que se confirme que
     ninguna consulta las toca, se van en un bloque propio.

   ORDEN: despues de 98_MENU_PERMISO_VIGENTE.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LAS DOS CATEGORIAS DE ARCHIVO

      Un logo entre los "documentos" no se vuelve a encontrar. Las
      categorias son con lo que despues se filtran los archivos de un
      cliente.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria] WHERE aca_codigo = 'LOGO CLIENTE')
BEGIN
    SET IDENTITY_INSERT [dbo].[Archivo_Categoria] ON

    INSERT INTO [dbo].[Archivo_Categoria]
        (aca_id, aca_cliente, aca_codigo, aca_nombre, aca_icono, aca_archivo,
         aca_orden, aca_usuario_creacion, aca_fecha_creacion, aca_habilitado)
    VALUES (14, NULL, 'LOGO CLIENTE', 'Logo del cliente',
            'mdi mdi-domain', 1, 14, 1, GETDATE(), 1),
           (15, NULL, 'FOTO USUARIO', 'Foto de la persona',
            'mdi mdi-account-circle-outline', 1, 15, 1, GETDATE(), 1)

    SET IDENTITY_INSERT [dbo].[Archivo_Categoria] OFF

    PRINT '--- Categorias LOGO CLIENTE (14) y FOTO USUARIO (15) creadas.'
END
ELSE PRINT '--- Las categorias de logo y foto ya existen.'
GO


/* ========================================================================
   2. LAS DOS COLUMNAS
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Cliente') AND name = 'cli_archivo_logo')
BEGIN
    ALTER TABLE [dbo].[Cliente] ADD [cli_archivo_logo] INT NULL

    PRINT '--- Columna cli_archivo_logo agregada.'
END
ELSE PRINT '--- cli_archivo_logo ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CLI_ARCHIVO_LOGO')
BEGIN
    ALTER TABLE [dbo].[Cliente] WITH CHECK
        ADD CONSTRAINT FK_CLI_ARCHIVO_LOGO
        FOREIGN KEY ([cli_archivo_logo]) REFERENCES [dbo].[Archivo] ([arc_id])

    PRINT '--- FK_CLI_ARCHIVO_LOGO creada.'
END
ELSE PRINT '--- FK_CLI_ARCHIVO_LOGO ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Usuario') AND name = 'usu_archivo_foto')
BEGIN
    ALTER TABLE [dbo].[Usuario] ADD [usu_archivo_foto] INT NULL

    PRINT '--- Columna usu_archivo_foto agregada.'
END
ELSE PRINT '--- usu_archivo_foto ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_USU_ARCHIVO_FOTO')
BEGIN
    ALTER TABLE [dbo].[Usuario] WITH CHECK
        ADD CONSTRAINT FK_USU_ARCHIVO_FOTO
        FOREIGN KEY ([usu_archivo_foto]) REFERENCES [dbo].[Archivo] ([arc_id])

    PRINT '--- FK_USU_ARCHIVO_FOTO creada.'
END
ELSE PRINT '--- FK_USU_ARCHIVO_FOTO ya existe.'
GO


/* ========================================================================
   3. UPD_CLIENTE_LOGO

      @ARCHIVO NULL con @QUITAR = 1 borra el logo; @ARCHIVO NULL con
      @QUITAR = 0 no lo toca. Sin la bandera no habria forma de distinguir
      "no me toques el logo" de "sacale el logo", y quedaria un logo que no
      se puede quitar nunca.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_CLIENTE_LOGO') IS NOT NULL DROP PROCEDURE [dbo].[UPD_CLIENTE_LOGO]
GO

CREATE PROCEDURE [dbo].[UPD_CLIENTE_LOGO]
    @CLIENTE INT,
    @ARCHIVO INT = NULL,
    @QUITAR  BIT = 0,
    @USUARIO INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
BEGIN
    RAISERROR('1.- EL CLIENTE NO EXISTE.', 16, 1)
    RETURN -1
END

/* El archivo tiene que ser de ESTE cliente. Sin esta comprobacion se podria
   apuntar el logo al archivo de otra empresa poniendo un id a mano. */
IF (@ARCHIVO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                     WHERE arc_id = @ARCHIVO AND arc_cliente = @CLIENTE))
BEGIN
    RAISERROR('2.- EL ARCHIVO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

UPDATE  [dbo].[Cliente]
SET     cli_archivo_logo = CASE WHEN @QUITAR = 1 THEN NULL
                                ELSE ISNULL(@ARCHIVO, cli_archivo_logo) END
WHERE   cli_id = @CLIENTE

SELECT @CLIENTE AS ID, 200 AS CODE, 'Logo actualizado.' AS MENSAJE
GO

PRINT '--- UPD_CLIENTE_LOGO creado.'
GO


/* ========================================================================
   4. UPD_USUARIO_FOTO

      @CLIENTE se recibe para comprobar que el archivo es de esa empresa. La
      persona puede pertenecer a varias, pero el archivo que sube pertenece
      a aquella con la que esta trabajando.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_USUARIO_FOTO') IS NOT NULL DROP PROCEDURE [dbo].[UPD_USUARIO_FOTO]
GO

CREATE PROCEDURE [dbo].[UPD_USUARIO_FOTO]
    @USUARIO_DESTINO INT,
    @CLIENTE         INT = NULL,
    @ARCHIVO         INT = NULL,
    @QUITAR          BIT = 0,
    @USUARIO         INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario] WHERE usu_id = @USUARIO_DESTINO)
BEGIN
    RAISERROR('3.- EL USUARIO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@ARCHIVO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                     WHERE arc_id = @ARCHIVO
                       AND (@CLIENTE IS NULL OR arc_cliente = @CLIENTE)))
BEGIN
    RAISERROR('2.- EL ARCHIVO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

UPDATE  [dbo].[Usuario]
SET     usu_archivo_foto = CASE WHEN @QUITAR = 1 THEN NULL
                                ELSE ISNULL(@ARCHIVO, usu_archivo_foto) END
WHERE   usu_id = @USUARIO_DESTINO

SELECT @USUARIO_DESTINO AS ID, 200 AS CODE, 'Foto actualizada.' AS MENSAJE
GO

PRINT '--- UPD_USUARIO_FOTO creado.'
GO


/* ========================================================================
   5. LOS TRES SEL_ DEVUELVEN LA COLUMNA NUEVA

   ESTA PARTE SE APLICO CON UN SCRIPT, Y HAY UNA RAZON

     Los tres arman su SELECT como texto y hay que agregarles una columna.
     Los dos primeros intentos desde SQL fallaron, y el segundo hizo dano:

     1) CREATE -> ALTER con STUFF sobre la primera aparicion de 'CREATE'.
        La cabecera de SEL_USUARIO trae el comentario estandar de SSMS
        "-- Create date: ...", asi que CHARINDEX cayo DENTRO del comentario
        y destrozo el encabezado. Error: "Incorrect syntax near 'date:'".

     2) DROP y despues CREATE. El CREATE de SEL_CLIENTE_USUARIO fallo
        —"Invalid column name 'usu_archivo_foto'"— porque ese SP arma un CTE
        llamado BASE y hay que agregar la columna en DOS sitios: dentro del
        CTE y en el SELECT final. Como el DROP ya se habia ejecutado,
        **SEL_CLIENTE_USUARIO quedo borrado**, y es el procedimiento del
        LOGIN. Hubo que restaurarlo del bloque 49.

     La leccion: NO se borra un objeto antes de saber que el reemplazo
     compila. El script `scratchpad/parchar_sel.ps1` crea primero una copia
     con nombre temporal; solo si esa compila toca el procedimiento real, y
     si el original dice CREATE OR ALTER ni siquiera necesita borrarlo.

   LO QUE QUEDO APLICADO

     SEL_CLIENTE          -> CLI_LOGO, CLI_ARCHIVO_LOGO
     SEL_USUARIO          -> ,USU_FOTO, USU_ARCHIVO_FOTO
     SEL_CLIENTE_USUARIO  -> u.usu_archivo_foto dentro del CTE BASE
                             b.usu_archivo_foto AS USU_ARCHIVO_FOTO al final

     Para rehacerlo en otro ambiente, correr parchar_sel.ps1 con esos
     anclajes. No se deja aqui como sp_executesql a proposito: es
     exactamente la forma que fallo dos veces.
   ======================================================================== */


/* ========================================================================
   VERIFICACION

   Las columnas nuevas tienen que aparecer en los tres SEL_.
   ======================================================================== */
SELECT  o.name AS SP,
        CASE WHEN m.definition LIKE '%CLI_ARCHIVO_LOGO%'
               OR m.definition LIKE '%USU_ARCHIVO_FOTO%'
             THEN 'OK' ELSE '*** FALTA' END AS ESTADO
FROM    sys.sql_modules m
JOIN    sys.objects o ON o.object_id = m.object_id
WHERE   o.name IN ('SEL_CLIENTE', 'SEL_USUARIO', 'SEL_CLIENTE_USUARIO')
ORDER BY o.name
GO

SELECT  'Cliente.cli_archivo_logo' AS COLUMNA,
        CASE WHEN COL_LENGTH('dbo.Cliente', 'cli_archivo_logo') IS NULL
             THEN '*** FALTA' ELSE 'OK' END AS ESTADO
UNION ALL
SELECT  'Usuario.usu_archivo_foto',
        CASE WHEN COL_LENGTH('dbo.Usuario', 'usu_archivo_foto') IS NULL
             THEN '*** FALTA' ELSE 'OK' END
GO

PRINT '100_LOGO_Y_FOTO_A_BLOB aplicado.'
GO
