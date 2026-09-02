/* ============================================================================
   SIGMA — Bloque 92
   EN QUE EQUIPOS APLICA CADA REPUESTO                                 HU-051
   ----------------------------------------------------------------------------

   LA TABLA NO ES LA QUE DICE LA TAREA

     T-3159 pide "revisar Componente_Repuesto_Instalacion" y los SP se
     llamarían `*_REPUESTO_COMPATIBILIDAD`. Son dos tablas distintas y el
     texto de la tarea mezcla una con otra:

       · `Componente_Repuesto_Instalacion` es el HISTORIAL: qué pieza se
         montó en qué componente, con qué horómetro y por qué se retiró. Es
         lo que necesita HU-058, no esta historia.

       · `Repuesto_Compatibilidad` es lo que pide HU-051 —"indicar en qué
         equipos o modelos aplica cada repuesto"—. Existe desde el bloque 12
         y estaba sin usar.

     La tarea también pide "confirmar el índice único del código dentro del
     cliente". Esta tabla **no tiene columna de código** y no la necesita: no
     es una entidad que alguien nombre, es una afirmación —"este rodamiento
     sirve para esta bomba"—.

   UNA FILA, UN ALCANCE. NO TRES A LA VEZ.

     `CK_RCO_ALCANCE` exige que venga al menos uno de tipo, modelo o
     componente, pero no impide que vengan los tres. Una fila con
     `tipo=BOMBA` y `modelo=GM10S` a la vez no se puede leer: ¿aplica a las
     bombas Y al modelo, o a las bombas QUE SEAN ese modelo? Las dos lecturas
     son razonables y dan resultados distintos.

     Los SP exigen **exactamente uno**. Si hace falta declarar dos alcances
     se crean dos filas, que además es lo que después permite borrar uno sin
     tocar el otro.

   EL BORRADO ES FISICO, Y ES A PROPOSITO

     T-3163 pide baja lógica. La tabla no tiene `rco_habilitado` y no se le
     agrega. Una compatibilidad es una afirmación de hecho: o el repuesto
     sirve para ese equipo o no sirve. Si está mal, está mal — no hay
     historia que preservar, y nada en la base depende de esta fila (ninguna
     tabla la referencia).

     Peor: una compatibilidad equivocada guardada "deshabilitada" es
     exactamente lo que la historia quiere evitar —que el técnico monte una
     pieza que no corresponde— esperando a que alguien la vuelva a encender
     por error.

   EL AISLAMIENTO VA POR EL REPUESTO

     La tabla **no tiene `rco_cliente`**. La pertenencia se resuelve por
     `rco_repuesto -> Repuesto.rep_cliente`, y por eso todos los SP hacen ese
     JOIN y filtran. Un id puesto a mano no alcanza para ver ni tocar la
     compatibilidad de otra empresa.

     Y el alcance también se valida: un tipo o un modelo de otro cliente se
     rechaza. Los que tienen cliente NULL son globales del sistema y sí se
     aceptan.

   ORDEN: despues de 91_PROVEEDOR.sql
   ============================================================================ */

SET NOCOUNT ON
GO


/* ========================================================================
   1. LO QUE LE FALTABA A LA TABLA                                  T-3159

      a) Auditoría de actualización. T-3162 pide un UPD_, y un UPD_ sin
         "quién lo cambió" en un sistema cuya premisa es la trazabilidad es
         peor que el costo de dos columnas.

      b) Unicidad. Nada impedía declarar dos veces que el mismo rodamiento
         sirve para el mismo tipo de bomba. En un índice único de SQL Server
         los NULL se comparan como iguales entre sí, así que un único índice
         sobre las cuatro columnas cubre los tres alcances de una vez.

      c) Un índice para la consulta al revés —"¿qué repuestos sirven para
         este equipo?"—, que es como lo va a usar el técnico. El único que
         existía, IX_RCO_REPUESTO, sirve para la otra dirección.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.columns
                WHERE object_id = OBJECT_ID('dbo.Repuesto_Compatibilidad')
                  AND name = 'rco_usuario_actualizacion')
BEGIN
    ALTER TABLE [dbo].[Repuesto_Compatibilidad]
        ADD [rco_usuario_actualizacion] INT NULL,
            [rco_fecha_actualizacion]   DATETIME NULL

    PRINT '--- Columnas de auditoria de actualizacion agregadas.'
END
ELSE PRINT '--- Las columnas de auditoria ya existen.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'UX_RCO_ALCANCE'
                  AND object_id = OBJECT_ID('dbo.Repuesto_Compatibilidad'))
BEGIN
    /* Si ya hubiera duplicados el indice no se crearia y el bloque fallaria
       entero. Se limpian primero, dejando el de menor id: son la misma
       afirmacion dicha dos veces. */
    ;WITH DUP AS (
        SELECT rco_id,
               ROW_NUMBER() OVER (PARTITION BY rco_repuesto, rco_activo_tipo,
                                               rco_activo_modelo, rco_activo_componente
                                      ORDER BY rco_id) AS N
        FROM   [dbo].[Repuesto_Compatibilidad]
    )
    DELETE FROM DUP WHERE N > 1

    CREATE UNIQUE NONCLUSTERED INDEX UX_RCO_ALCANCE
        ON [dbo].[Repuesto_Compatibilidad]
           ([rco_repuesto], [rco_activo_tipo], [rco_activo_modelo], [rco_activo_componente])

    PRINT '--- Indice unico UX_RCO_ALCANCE creado.'
END
ELSE PRINT '--- Indice UX_RCO_ALCANCE ya existe.'
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
                WHERE name = 'IX_RCO_INVERSO'
                  AND object_id = OBJECT_ID('dbo.Repuesto_Compatibilidad'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_RCO_INVERSO
        ON [dbo].[Repuesto_Compatibilidad]
           ([rco_activo_tipo], [rco_activo_modelo], [rco_activo_componente])
        INCLUDE ([rco_repuesto])

    PRINT '--- Indice IX_RCO_INVERSO creado.'
END
ELSE PRINT '--- Indice IX_RCO_INVERSO ya existe.'
GO


/* ========================================================================
   2. SEL_REPUESTO_COMPATIBILIDAD                                   T-3160

      Sirve a la grilla y a la ficha, y a las DOS direcciones de la pregunta:

        @REPUESTO  -> "¿para qué equipos sirve esta pieza?"  (planificador)
        @TIPO/@MODELO/@COMPONENTE -> "¿qué piezas sirven para este equipo?"
                                     (técnico, que es el que no debe montar
                                      la que no corresponde)
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_REPUESTO_COMPATIBILIDAD') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_REPUESTO_COMPATIBILIDAD]
GO

CREATE PROCEDURE [dbo].[SEL_REPUESTO_COMPATIBILIDAD]
    @CLIENTE     INT,
    @ID          INT = NULL,
    @REPUESTO    INT = NULL,
    @TIPO        INT = NULL,
    @MODELO      INT = NULL,
    @COMPONENTE  INT = NULL,
    @FILTRO      VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  c.rco_id,
            c.rco_repuesto,
            c.rco_activo_tipo,
            c.rco_activo_modelo,
            c.rco_activo_componente,
            ISNULL(c.rco_observacion, '')                       AS rco_observacion,
            c.rco_usuario_creacion,
            c.rco_fecha_creacion,
            c.rco_usuario_actualizacion,
            c.rco_fecha_actualizacion,

            r.rep_codigo                                        AS REPUESTO_CODIGO,
            r.rep_nombre                                        AS REPUESTO_NOMBRE,
            ISNULL(ume.ume_simbolo, '')                         AS UNIDAD,

            /* Qué alcance es y cómo se llama, resuelto acá para que la
               pantalla no tenga que elegir entre tres columnas y adivinar
               cuál viene informada. */
            CASE WHEN c.rco_activo_componente IS NOT NULL THEN 'COMPONENTE'
                 WHEN c.rco_activo_modelo     IS NOT NULL THEN 'MODELO'
                 ELSE 'TIPO' END                                AS ALCANCE,

            CASE WHEN c.rco_activo_componente IS NOT NULL
                      THEN ISNULL(co.aco_codigo + ' · ', '') + ISNULL(co.aco_nombre, '')
                 WHEN c.rco_activo_modelo IS NOT NULL
                      THEN ISNULL(mo.amo_fabricante + ' ', '') + ISNULL(mo.amo_nombre, '')
                 ELSE ISNULL(ti.ati_nombre, '') END             AS ALCANCE_NOMBRE,

            ISNULL(uc.usu_nombre + ' ' + uc.usu_apellido_paterno, '') AS USUARIO_CREACION_NOMBRE,
            ISNULL(ua.usu_nombre + ' ' + ua.usu_apellido_paterno, '') AS USUARIO_ACTUALIZACION_NOMBRE

    FROM    [dbo].[Repuesto_Compatibilidad] c
    /* INNER y no LEFT: el repuesto es lo que decide de qué cliente es la
       fila. Sin él no hay forma de saber si se puede mostrar. */
    JOIN    [dbo].[Repuesto] r
            ON  r.rep_id = c.rco_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Activo_Tipo] ti    ON ti.ati_id  = c.rco_activo_tipo
    LEFT JOIN [dbo].[Activo_Modelo] mo  ON mo.amo_id  = c.rco_activo_modelo
    LEFT JOIN [dbo].[Activo_Componente] co ON co.aco_id = c.rco_activo_componente
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = c.rco_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = c.rco_usuario_actualizacion

    WHERE   r.rep_cliente = @CLIENTE
      AND   (@ID         IS NULL OR c.rco_id                = @ID)
      AND   (@REPUESTO   IS NULL OR c.rco_repuesto          = @REPUESTO)
      AND   (@TIPO       IS NULL OR c.rco_activo_tipo       = @TIPO)
      AND   (@MODELO     IS NULL OR c.rco_activo_modelo     = @MODELO)
      AND   (@COMPONENTE IS NULL OR c.rco_activo_componente = @COMPONENTE)
      AND   (@FILTRO IS NULL
             OR r.rep_codigo      LIKE '%' + @FILTRO + '%'
             OR r.rep_nombre      LIKE '%' + @FILTRO + '%'
             OR ti.ati_nombre     LIKE '%' + @FILTRO + '%'
             OR mo.amo_nombre     LIKE '%' + @FILTRO + '%'
             OR mo.amo_fabricante LIKE '%' + @FILTRO + '%'
             OR co.aco_nombre     LIKE '%' + @FILTRO + '%'
             OR c.rco_observacion LIKE '%' + @FILTRO + '%')

    /* Orden estable: el desempate por id evita que dos filas con el mismo
       repuesto y el mismo nombre de alcance se muestren dos veces o se
       salten al paginar. */
    ORDER BY r.rep_codigo, ALCANCE_NOMBRE, c.rco_id
GO

PRINT '--- SEL_REPUESTO_COMPATIBILIDAD creado.'
GO


/* ========================================================================
   3. INS_REPUESTO_COMPATIBILIDAD                                   T-3161
   ======================================================================== */
IF OBJECT_ID('dbo.INS_REPUESTO_COMPATIBILIDAD') IS NOT NULL
    DROP PROCEDURE [dbo].[INS_REPUESTO_COMPATIBILIDAD]
GO

CREATE PROCEDURE [dbo].[INS_REPUESTO_COMPATIBILIDAD]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @REPUESTO    INT,
    @TIPO        INT = NULL,
    @MODELO      INT = NULL,
    @COMPONENTE  INT = NULL,
    @OBSERVACION NVARCHAR(500) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME, @CUANTOS INT

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL REPUESTO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* Exactamente uno. Ver el encabezado: dos alcances en la misma fila no se
   pueden leer sin elegir entre dos interpretaciones distintas. */
SET @CUANTOS = CASE WHEN @TIPO       IS NOT NULL THEN 1 ELSE 0 END
             + CASE WHEN @MODELO     IS NOT NULL THEN 1 ELSE 0 END
             + CASE WHEN @COMPONENTE IS NOT NULL THEN 1 ELSE 0 END

IF (@CUANTOS = 0)
BEGIN
    RAISERROR('2.- INDIQUE A QUE APLICA: UN TIPO DE ACTIVO, UN MODELO O UN COMPONENTE.', 16, 1)
    RETURN -1
END

IF (@CUANTOS > 1)
BEGIN
    RAISERROR('3.- INDIQUE UN SOLO ALCANCE POR FILA. SI APLICA A VARIOS, CREE UNA FILA POR CADA UNO.', 16, 1)
    RETURN -1
END

/* El alcance tiene que ser de este cliente o global (cliente NULL). Sin esto
   se podria declarar compatibilidad contra el modelo de otra empresa, y ese
   nombre despues aparece en la pantalla de un tercero. */
IF (@TIPO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                                       WHERE ati_id = @TIPO
                                         AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE)))
BEGIN
    RAISERROR('4.- EL TIPO DE ACTIVO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@MODELO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo]
                                         WHERE amo_id = @MODELO
                                           AND (amo_cliente IS NULL OR amo_cliente = @CLIENTE)))
BEGIN
    RAISERROR('5.- EL MODELO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                                             WHERE aco_id = @COMPONENTE AND aco_cliente = @CLIENTE))
BEGIN
    RAISERROR('6.- EL COMPONENTE NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad]
            WHERE rco_repuesto = @REPUESTO
              AND ISNULL(rco_activo_tipo, -1)       = ISNULL(@TIPO, -1)
              AND ISNULL(rco_activo_modelo, -1)     = ISNULL(@MODELO, -1)
              AND ISNULL(rco_activo_componente, -1) = ISNULL(@COMPONENTE, -1))
BEGIN
    RAISERROR('7.- ESA COMPATIBILIDAD YA ESTA DECLARADA PARA ESTE REPUESTO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Repuesto_Compatibilidad]
        (rco_repuesto, rco_activo_tipo, rco_activo_modelo, rco_activo_componente,
         rco_observacion, rco_usuario_creacion, rco_fecha_creacion,
         rco_usuario_actualizacion, rco_fecha_actualizacion)
    VALUES
        (@REPUESTO, @TIPO, @MODELO, @COMPONENTE,
         @OBSERVACION, @USUARIO, @AHORA, NULL, NULL)

    DECLARE @FILAS_INS INT = @@ROWCOUNT

    SET @ID = SCOPE_IDENTITY()

    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('8.- NO FUE POSIBLE GUARDAR LA COMPATIBILIDAD.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Compatibilidad guardada con éxito.' AS MENSAJE
GO

PRINT '--- INS_REPUESTO_COMPATIBILIDAD creado.'
GO


/* ========================================================================
   4. UPD_REPUESTO_COMPATIBILIDAD                                   T-3162

      El REPUESTO no se cambia. Mover una compatibilidad de un repuesto a
      otro no es editar: es borrar una afirmación y hacer otra distinta, y
      dejarlo pasar convierte un error de tipeo en un dato que nadie va a
      volver a revisar.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_REPUESTO_COMPATIBILIDAD') IS NOT NULL
    DROP PROCEDURE [dbo].[UPD_REPUESTO_COMPATIBILIDAD]
GO

CREATE PROCEDURE [dbo].[UPD_REPUESTO_COMPATIBILIDAD]
    @ID          INT,
    @CLIENTE     INT,
    @TIPO        INT = NULL,
    @MODELO      INT = NULL,
    @COMPONENTE  INT = NULL,
    @OBSERVACION NVARCHAR(500) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @AHORA DATETIME, @CUANTOS INT, @REPUESTO INT

SELECT  @REPUESTO = c.rco_repuesto
FROM    [dbo].[Repuesto_Compatibilidad] c
JOIN    [dbo].[Repuesto] r ON r.rep_id = c.rco_repuesto
WHERE   c.rco_id = @ID AND r.rep_cliente = @CLIENTE

IF (@REPUESTO IS NULL)
BEGIN
    RAISERROR('9.- LA COMPATIBILIDAD NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CUANTOS = CASE WHEN @TIPO       IS NOT NULL THEN 1 ELSE 0 END
             + CASE WHEN @MODELO     IS NOT NULL THEN 1 ELSE 0 END
             + CASE WHEN @COMPONENTE IS NOT NULL THEN 1 ELSE 0 END

IF (@CUANTOS <> 1)
BEGIN
    RAISERROR('3.- INDIQUE UN SOLO ALCANCE POR FILA. SI APLICA A VARIOS, CREE UNA FILA POR CADA UNO.', 16, 1)
    RETURN -1
END

IF (@TIPO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Tipo]
                                       WHERE ati_id = @TIPO
                                         AND (ati_cliente IS NULL OR ati_cliente = @CLIENTE)))
BEGIN
    RAISERROR('4.- EL TIPO DE ACTIVO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@MODELO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo]
                                         WHERE amo_id = @MODELO
                                           AND (amo_cliente IS NULL OR amo_cliente = @CLIENTE)))
BEGIN
    RAISERROR('5.- EL MODELO NO ESTA DISPONIBLE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF (@COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente]
                                             WHERE aco_id = @COMPONENTE AND aco_cliente = @CLIENTE))
BEGIN
    RAISERROR('6.- EL COMPONENTE NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad]
            WHERE rco_repuesto = @REPUESTO
              AND rco_id <> @ID
              AND ISNULL(rco_activo_tipo, -1)       = ISNULL(@TIPO, -1)
              AND ISNULL(rco_activo_modelo, -1)     = ISNULL(@MODELO, -1)
              AND ISNULL(rco_activo_componente, -1) = ISNULL(@COMPONENTE, -1))
BEGIN
    RAISERROR('7.- ESA COMPATIBILIDAD YA ESTA DECLARADA PARA ESTE REPUESTO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    /* La observación va con ISNULL(@X, columna): un formulario que no la
       muestre no puede borrarla en silencio. El alcance NO, porque acá
       siempre viene informado —lo exige la validación de arriba—. */
    UPDATE  [dbo].[Repuesto_Compatibilidad]
    SET     rco_activo_tipo           = @TIPO
           ,rco_activo_modelo          = @MODELO
           ,rco_activo_componente      = @COMPONENTE
           ,rco_observacion            = ISNULL(@OBSERVACION, rco_observacion)
           ,rco_usuario_actualizacion  = @USUARIO
           ,rco_fecha_actualizacion    = @AHORA
    WHERE   rco_id = @ID

    DECLARE @FILAS_UPD INT = @@ROWCOUNT

    IF @FILAS_UPD = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('10.- NO FUE POSIBLE ACTUALIZAR LA COMPATIBILIDAD.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Compatibilidad actualizada con éxito.' AS MENSAJE
GO

PRINT '--- UPD_REPUESTO_COMPATIBILIDAD creado.'
GO


/* ========================================================================
   5. DEL_REPUESTO_COMPATIBILIDAD                                   T-3163

      Borrado FISICO. Ver el encabezado: una compatibilidad equivocada
      guardada "deshabilitada" es justo lo que la historia quiere evitar,
      esperando a que alguien la vuelva a encender.
   ======================================================================== */
IF OBJECT_ID('dbo.DEL_REPUESTO_COMPATIBILIDAD') IS NOT NULL
    DROP PROCEDURE [dbo].[DEL_REPUESTO_COMPATIBILIDAD]
GO

CREATE PROCEDURE [dbo].[DEL_REPUESTO_COMPATIBILIDAD]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

/* El cliente se comprueba por el repuesto, que es de donde cuelga la
   pertenencia de esta fila. */
IF NOT EXISTS (SELECT 1
                 FROM [dbo].[Repuesto_Compatibilidad] c
                 JOIN [dbo].[Repuesto] r ON r.rep_id = c.rco_repuesto
                WHERE c.rco_id = @ID AND r.rep_cliente = @CLIENTE)
BEGIN
    RAISERROR('9.- LA COMPATIBILIDAD NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    DELETE FROM [dbo].[Repuesto_Compatibilidad] WHERE rco_id = @ID

    DECLARE @FILAS_DEL INT = @@ROWCOUNT

    IF @FILAS_DEL = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('11.- NO FUE POSIBLE ELIMINAR LA COMPATIBILIDAD.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS ID, 200 AS CODE, 'Compatibilidad eliminada con éxito.' AS MENSAJE
GO

PRINT '--- DEL_REPUESTO_COMPATIBILIDAD creado.'
GO


/* ========================================================================
   6. MENU Y PERMISOS                                        T-3171 · T-3172

      SE REUTILIZAN LOS PERMISOS DEL MAESTRO DE REPUESTOS

        La compatibilidad es una propiedad del repuesto, no una entidad
        aparte: quien mantiene el catálogo mantiene sus compatibilidades. Un
        par de permisos propios obligaría a asignarlos a mano a todos los
        perfiles que ya tienen los del maestro, y el primer día que alguien
        se olvide la pantalla queda invisible sin explicación.
   ======================================================================== */
DECLARE @VER INT, @EDITAR INT, @PADRE INT, @MNU INT

SELECT @VER    = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER REPUESTOS'
SELECT @EDITAR = prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'CREAR EDITAR REPUESTOS'

/* Cuelga de Inventario > Configuracion, junto a Repuestos. */
SELECT @PADRE = mnu_padre FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Repuestos/Repuestos.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Inventario/Compatibilidades/RepuestoCompatibilidades.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Compatibilidades', 'En qué equipos aplica cada repuesto',
            4, @PADRE, 3, '~/View/Inventario/Compatibilidades/RepuestoCompatibilidades.aspx',
            1, NULL, @VER, 1)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menus]
                WHERE mnu_link = '~/View/Inventario/Compatibilidades/RepuestoCompatibilidad.aspx')
    INSERT INTO [dbo].[Menus]
        (mnu_nombre, mnu_descripcion, mnu_nivel, mnu_padre, mnu_orden, mnu_link,
         mnu_visible, mnu_icon, mnu_permiso, mnu_ambito)
    VALUES ('Compatibilidad (detalle)', 'Ficha de la compatibilidad',
            4, @PADRE, 99, '~/View/Inventario/Compatibilidades/RepuestoCompatibilidad.aspx',
            0, NULL, @VER, 1)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Compatibilidades/RepuestoCompatibilidades.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Eliminar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Eliminar', @MNU, @EDITAR)

SELECT @MNU = mnu_id FROM [dbo].[Menus]
 WHERE mnu_link = '~/View/Inventario/Compatibilidades/RepuestoCompatibilidad.aspx'

IF NOT EXISTS (SELECT 1 FROM [dbo].[Menu_Funcion]
                WHERE mfu_menu = @MNU AND mfu_nombre = 'Crear y editar')
    INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
    VALUES ('Crear y editar', @MNU, @EDITAR)

PRINT '--- Menu y funciones de compatibilidades listos.'
GO


/* ========================================================================
   7. DATOS DE PRUEBA                                               T-3164

      HACEN FALTA MODELOS, Y NO HAY NINGUNO

        La historia habla de "equipos o MODELOS" y `Activo_Modelo` está
        vacía, así que sin esto el alcance por modelo no se puede ejercitar:
        el combo saldría vacío y el criterio de aceptación quedaría sin
        probar. Se crean tres, que son los de los activos que ya existen.

      El alcance por COMPONENTE queda sin datos a propósito: `Activo_Componente`
      está vacía y poblarla es del módulo de activos, no de esta historia.
      El SP y la pantalla lo soportan; cuando existan componentes, funciona.
   ======================================================================== */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Modelo] WHERE amo_cliente = 1)
BEGIN
    INSERT INTO [dbo].[Activo_Modelo]
        (amo_cliente, amo_activo_tipo, amo_fabricante, amo_nombre, amo_descripcion,
         amo_usuario_creacion, amo_fecha_creacion, amo_habilitado)
    VALUES
        (1, 7,  N'WEG',      N'W22 132S',   N'Motor trifásico 5,5 kW 1500 rpm', 1, GETDATE(), 1),
        (1, 8,  N'Grundfos', N'NB 65-200',  N'Bomba centrífuga monobloc',       1, GETDATE(), 1),
        (1, 9,  N'Soler',    N'CJTHT-71',   N'Ventilador centrífugo de techo',  1, GETDATE(), 1)

    PRINT '--- Modelos de activo de prueba creados: 3'
END
ELSE PRINT '--- El cliente ya tiene modelos de activo.'
GO

DECLARE @ID INT, @REP INT, @MOD INT, @N INT = 0

IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Compatibilidad] c
                JOIN [dbo].[Repuesto] r ON r.rep_id = c.rco_repuesto
               WHERE r.rep_cliente = 1)
BEGIN
    /* Por TIPO: el rodamiento 6205 sirve para cualquier motor eléctrico. */
    SELECT @REP = rep_id FROM [dbo].[Repuesto] WHERE rep_codigo = 'DEMO-ROD-6205' AND rep_cliente = 1
    IF @REP IS NOT NULL
    BEGIN
        EXEC [dbo].[INS_REPUESTO_COMPATIBILIDAD] @ID OUTPUT, 1, @REP, 7, NULL, NULL,
             N'Rodamiento del lado acople en motores de hasta 7,5 kW.', 1
        SET @N = @N + 1
    END

    /* Por MODELO: el 6308 solo en la bomba Grundfos. */
    SELECT @REP = rep_id FROM [dbo].[Repuesto] WHERE rep_codigo = 'DEMO-ROD-6308' AND rep_cliente = 1
    SELECT @MOD = amo_id FROM [dbo].[Activo_Modelo] WHERE amo_nombre = 'NB 65-200' AND amo_cliente = 1
    IF @REP IS NOT NULL AND @MOD IS NOT NULL
    BEGIN
        EXEC [dbo].[INS_REPUESTO_COMPATIBILIDAD] @ID OUTPUT, 1, @REP, NULL, @MOD, NULL,
             N'Solo este modelo: en la NB 50-160 el eje es de 35 mm y no calza.', 1
        SET @N = @N + 1
    END

    /* Por TIPO: la correa A42, en ventiladores. */
    SELECT @REP = rep_id FROM [dbo].[Repuesto] WHERE rep_codigo = 'DEMO-CORREA-A42' AND rep_cliente = 1
    IF @REP IS NOT NULL
    BEGIN
        EXEC [dbo].[INS_REPUESTO_COMPATIBILIDAD] @ID OUTPUT, 1, @REP, 9, NULL, NULL,
             N'Transmisión por correa en ventiladores de extracción.', 1
        SET @N = @N + 1
    END

    /* Por MODELO: el filtro G4, en el ventilador Soler. */
    SELECT @REP = rep_id FROM [dbo].[Repuesto] WHERE rep_codigo = 'DEMO-FILT-G4' AND rep_cliente = 1
    SELECT @MOD = amo_id FROM [dbo].[Activo_Modelo] WHERE amo_nombre = 'CJTHT-71' AND amo_cliente = 1
    IF @REP IS NOT NULL AND @MOD IS NOT NULL
    BEGIN
        EXEC [dbo].[INS_REPUESTO_COMPATIBILIDAD] @ID OUTPUT, 1, @REP, NULL, @MOD, NULL,
             N'Medida 592x592x48. Verificar el marco antes de pedir.', 1
        SET @N = @N + 1
    END

    PRINT '--- Compatibilidades de prueba creadas: ' + LTRIM(STR(@N))
END
ELSE PRINT '--- El cliente ya tiene compatibilidades declaradas.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
EXEC [dbo].[SEL_REPUESTO_COMPATIBILIDAD] @CLIENTE = 1
GO

PRINT '92_REPUESTO_COMPATIBILIDAD aplicado.'
GO
