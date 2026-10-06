/* ============================================================================
   SIGMA - Bloque 351
   UN REPUESTO COMPATIBLE CON UN ACTIVO O SUBACTIVO CONCRETO
   ----------------------------------------------------------------------------
   Repuesto_Compatibilidad declaraba el alcance por tipo de activo, por modelo
   o por componente. Desde el explorador de la planta y el asistente del
   centro se vincula «este repuesto le sirve a ESTE activo» (o subactivo), sin
   pasar por su tipo ni su modelo:
     - columna rco_activo (FK Activo), el cuarto alcance posible;
     - CK_RCO_ALCANCE y el indice unico UX_RCO_ALCANCE lo incluyen;
     - INS_ACTIVO_REPUESTO_COMPATIBLE / DEL_ACTIVO_REPUESTO_COMPATIBLE:
       vinculan y quitan SOLO los alcances directos (activo o componente);
       los de tipo y modelo se siguen manejando en la ficha del repuesto
       (INS_REPUESTO_COMPATIBILIDAD no cambia);
     - SEL_REPUESTO_ELEGIR: los repuestos del cliente con su stock y su foto,
       para el combo que busca mientras se escribe;
     - las lecturas de compatibles (SEL_ACTIVO_PLANTA, SEL_ACTIVO_REPUESTO_
       COMPATIBLE, SEL_BODEGA_MAPA_COMPATIBLES) reconocen el alcance directo.
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

IF COL_LENGTH('dbo.Repuesto_Compatibilidad', 'rco_activo') IS NULL
    ALTER TABLE [dbo].[Repuesto_Compatibilidad] ADD [rco_activo] INT NULL
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_RCO_ACTIVO')
    ALTER TABLE [dbo].[Repuesto_Compatibilidad] WITH CHECK
        ADD CONSTRAINT [FK_RCO_ACTIVO] FOREIGN KEY ([rco_activo]) REFERENCES [dbo].[Activo] ([act_id])
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_RCO_ALCANCE'
            AND definition NOT LIKE '%rco_activo]%IS NOT NULL%')
    ALTER TABLE [dbo].[Repuesto_Compatibilidad] DROP CONSTRAINT [CK_RCO_ALCANCE]
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_RCO_ALCANCE')
    ALTER TABLE [dbo].[Repuesto_Compatibilidad] WITH CHECK ADD CONSTRAINT [CK_RCO_ALCANCE]
        CHECK ([rco_activo_tipo] IS NOT NULL OR [rco_activo_modelo] IS NOT NULL
            OR [rco_activo_componente] IS NOT NULL OR [rco_activo] IS NOT NULL)
GO

-- El indice unico incluye el activo: el mismo repuesto no se declara dos veces para el mismo activo.
IF EXISTS (SELECT 1 FROM sys.indexes i WHERE i.name = 'UX_RCO_ALCANCE' AND i.object_id = OBJECT_ID('dbo.Repuesto_Compatibilidad')
            AND NOT EXISTS (SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                             WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND c.name = 'rco_activo'))
    DROP INDEX [UX_RCO_ALCANCE] ON [dbo].[Repuesto_Compatibilidad]
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_RCO_ALCANCE' AND object_id = OBJECT_ID('dbo.Repuesto_Compatibilidad'))
    CREATE UNIQUE NONCLUSTERED INDEX [UX_RCO_ALCANCE] ON [dbo].[Repuesto_Compatibilidad]
        ([rco_repuesto], [rco_activo_tipo], [rco_activo_modelo], [rco_activo_componente], [rco_activo])
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RCO_ACTIVO' AND object_id = OBJECT_ID('dbo.Repuesto_Compatibilidad'))
    CREATE NONCLUSTERED INDEX [IX_RCO_ACTIVO] ON [dbo].[Repuesto_Compatibilidad] ([rco_activo]) INCLUDE ([rco_repuesto])
GO

/* ---- vincular: al activo (o subactivo) o a uno de sus componentes ---- */
CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO_REPUESTO_COMPATIBLE]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @REPUESTO    INT,
    @ACTIVO      INT = NULL,
    @COMPONENTE  INT = NULL,
    @OBSERVACION NVARCHAR(500) = NULL,
    @USUARIO     INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PAIS INT, @AHORA DATETIME;
    SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE;
    SET @AHORA = [dbo].[FNC_PAIS_HORA](@PAIS);

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE AND ISNULL(rep_habilitado, 1) = 1)
    BEGIN RAISERROR('El repuesto no existe.', 16, 1); RETURN -1; END

    IF ((CASE WHEN @ACTIVO IS NULL THEN 0 ELSE 1 END) + (CASE WHEN @COMPONENTE IS NULL THEN 0 ELSE 1 END)) <> 1
    BEGIN RAISERROR('Elige si le sirve al activo o a uno de sus componentes.', 16, 1); RETURN -1; END

    IF (@ACTIVO IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo] WHERE act_id = @ACTIVO AND act_cliente = @CLIENTE))
    BEGIN RAISERROR('El activo no existe.', 16, 1); RETURN -1; END

    IF (@COMPONENTE IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_id = @COMPONENTE AND aco_cliente = @CLIENTE))
    BEGIN RAISERROR('El componente no existe.', 16, 1); RETURN -1; END

    -- Si ya estaba vinculado, no es un error: se devuelve el mismo.
    SELECT @ID = rco_id FROM [dbo].[Repuesto_Compatibilidad]
    WHERE  rco_repuesto = @REPUESTO AND rco_activo_tipo IS NULL AND rco_activo_modelo IS NULL
      AND  ((@ACTIVO IS NOT NULL AND rco_activo = @ACTIVO AND rco_activo_componente IS NULL)
        OR  (@COMPONENTE IS NOT NULL AND rco_activo_componente = @COMPONENTE AND rco_activo IS NULL));
    IF (@ID IS NOT NULL) RETURN 0;

    INSERT INTO [dbo].[Repuesto_Compatibilidad]
           (rco_repuesto, rco_activo_tipo, rco_activo_modelo, rco_activo_componente, rco_activo,
            rco_observacion, rco_usuario_creacion, rco_fecha_creacion)
    VALUES (@REPUESTO, NULL, NULL, @COMPONENTE, @ACTIVO,
            NULLIF(LTRIM(RTRIM(@OBSERVACION)), N''), @USUARIO, @AHORA);
    SET @ID = SCOPE_IDENTITY();
    RETURN 0;
END
GO

/* ---- quitar: solo un vinculo directo (activo o componente) del cliente ---- */
CREATE OR ALTER PROCEDURE [dbo].[DEL_ACTIVO_REPUESTO_COMPATIBLE]
    @ID      INT,
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM [dbo].[Repuesto_Compatibilidad] rc
        JOIN   [dbo].[Repuesto] r ON r.rep_id = rc.rco_repuesto AND r.rep_cliente = @CLIENTE
        WHERE  rc.rco_id = @ID AND (rc.rco_activo IS NOT NULL OR rc.rco_activo_componente IS NOT NULL))
    BEGIN RAISERROR('Ese vínculo no existe o se maneja desde la ficha del repuesto.', 16, 1); RETURN -1; END

    DELETE FROM [dbo].[Repuesto_Compatibilidad] WHERE rco_id = @ID;
    RETURN 0;
END
GO

/* ---- el combo: repuestos del cliente con su stock y su foto de portada ---- */
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_ELEGIR]
    @CLIENTE INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.rep_id AS ID, r.rep_codigo AS CODIGO, r.rep_nombre AS NOMBRE,
           ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s WHERE s.isa_repuesto = r.rep_id AND s.isa_cliente = @CLIENTE), 0) AS EXISTENCIA,
           ISNULL(um.ume_simbolo, N'') AS UNIDAD
    FROM   [dbo].[Repuesto] r
    LEFT JOIN [dbo].[Unidad_Medida] um ON um.ume_id = r.rep_unidad_medida
    WHERE  r.rep_cliente = @CLIENTE AND ISNULL(r.rep_habilitado, 1) = 1
    ORDER BY r.rep_nombre;
END
GO

/* ---- las lecturas reconocen el alcance directo ---- */
DECLARE @sql NVARCHAR(MAX)

-- planta: el join suma el activo y el resultado trae el id del vinculo directo (para quitarlo)
SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA'))
IF @sql NOT LIKE N'%rc.rco_activo = a.act_id%'
BEGIN
    SET @sql = REPLACE(@sql,
        N'SELECT DISTINCT a.act_id AS ACTIVO, rc.rco_repuesto AS REP, k.aco_id AS PARA_ID, k.aco_nombre AS PARA',
        N'SELECT DISTINCT a.act_id AS ACTIVO, rc.rco_repuesto AS REP, k.aco_id AS PARA_ID, k.aco_nombre AS PARA,
               CASE WHEN rc.rco_activo = a.act_id OR k.aco_id IS NOT NULL THEN rc.rco_id END AS VINCULO')
    SET @sql = REPLACE(@sql,
        N'OR rc.rco_activo_componente IN (SELECT x.aco_id FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = a.act_id)',
        N'OR rc.rco_activo_componente IN (SELECT x.aco_id FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = a.act_id)
               OR rc.rco_activo = a.act_id')
    SET @sql = REPLACE(@sql,
        N'MAX(c.PARA_ID) AS PARA_ID, MAX(c.PARA) AS PARA',
        N'MAX(c.PARA_ID) AS PARA_ID, MAX(c.PARA) AS PARA, MAX(c.VINCULO) AS VINCULO')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END

-- centro del activo (Repuestos y costos): tambien lo vinculado al activo o a sus componentes
SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_REPUESTO_COMPATIBLE'))
IF @sql NOT LIKE N'%cmp.rco_activo = act.act_id%'
BEGIN
    SET @sql = REPLACE(@sql,
        N'OR (cmp.rco_activo_modelo IS NOT NULL AND cmp.rco_activo_modelo = act.act_activo_modelo))',
        N'OR (cmp.rco_activo_modelo IS NOT NULL AND cmp.rco_activo_modelo = act.act_activo_modelo)
             OR cmp.rco_activo = act.act_id
             OR cmp.rco_activo_componente IN (SELECT x.aco_id FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = act.act_id))
      /* un repuesto vinculado por mas de un camino sale una vez */
      AND   cmp.rco_id = (SELECT MIN(c2.rco_id) FROM [dbo].[Repuesto_Compatibilidad] c2
                           WHERE c2.rco_repuesto = cmp.rco_repuesto
                             AND (c2.rco_activo_tipo = act.act_activo_tipo
                                  OR (c2.rco_activo_modelo IS NOT NULL AND c2.rco_activo_modelo = act.act_activo_modelo)
                                  OR c2.rco_activo = act.act_id
                                  OR c2.rco_activo_componente IN (SELECT x.aco_id FROM [dbo].[Activo_Componente] x WHERE x.aco_activo = act.act_id)))')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END

-- mapa de bodega: la regla «Activo»; y «Tipo de activo» en vez de «Tipo de equipo»
SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_BODEGA_MAPA_COMPATIBLES'))
IF @sql NOT LIKE N'%c.rco_activo = @ACTIVO%'
BEGIN
    SET @sql = REPLACE(@sql,
        N'MIN(CASE WHEN c.rco_activo_componente IS NOT NULL THEN ''Componente''',
        N'MIN(CASE WHEN c.rco_activo IS NOT NULL THEN ''Activo'' WHEN c.rco_activo_componente IS NOT NULL THEN ''Componente''')
    SET @sql = REPLACE(@sql, N'ELSE ''Tipo de equipo'' END', N'ELSE ''Tipo de activo'' END')
    SET @sql = REPLACE(@sql,
        N'OR   (c.rco_activo_modelo IS NULL AND c.rco_activo_componente IS NULL AND c.rco_activo_tipo IS NOT NULL AND c.rco_activo_tipo = @TIPO)',
        N'OR   (c.rco_activo_modelo IS NULL AND c.rco_activo_componente IS NULL AND c.rco_activo_tipo IS NOT NULL AND c.rco_activo_tipo = @TIPO)
       OR   (c.rco_activo IS NOT NULL AND c.rco_activo = @ACTIVO)')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

-- estructura del centro («¿De qué está hecho?»): tambien lo vinculado al activo
DECLARE @sql NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ESTRUCTURA'))
IF @sql NOT LIKE N'%rc.rco_activo = @ACTIVO%'
BEGIN
    SET @sql = REPLACE(@sql,
        N'MIN(CASE WHEN rc.rco_activo_componente IS NOT NULL THEN ''COMPONENTE''',
        N'MIN(CASE WHEN rc.rco_activo IS NOT NULL THEN ''ACTIVO'' WHEN rc.rco_activo_componente IS NOT NULL THEN ''COMPONENTE''')
    SET @sql = REPLACE(@sql,
        N'OR  rc.rco_activo_componente IN (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = @ACTIVO)',
        N'OR  rc.rco_activo_componente IN (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_activo = @ACTIVO)
       OR  rc.rco_activo = @ACTIVO')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END

-- la lista de la ficha del repuesto: el alcance «ACTIVO» con el nombre del activo
SET @sql = OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_REPUESTO_COMPATIBILIDAD'))
IF @sql NOT LIKE N'%''ACTIVO''%'
BEGIN
    SET @sql = REPLACE(@sql,
        N'CASE WHEN c.rco_activo_componente IS NOT NULL THEN ''COMPONENTE''',
        N'CASE WHEN c.rco_activo IS NOT NULL THEN ''ACTIVO''
                 WHEN c.rco_activo_componente IS NOT NULL THEN ''COMPONENTE''')
    SET @sql = REPLACE(@sql,
        N'CASE WHEN c.rco_activo_componente IS NOT NULL
                      THEN ISNULL(co.aco_codigo + '' · '', '''') + ISNULL(co.aco_nombre, '''')',
        N'CASE WHEN c.rco_activo IS NOT NULL
                      THEN ISNULL(ac.act_codigo + '' · '', '''') + ISNULL(ac.act_nombre, '''')
                 WHEN c.rco_activo_componente IS NOT NULL
                      THEN ISNULL(co.aco_codigo + '' · '', '''') + ISNULL(co.aco_nombre, '''')')
    SET @sql = REPLACE(@sql,
        N'LEFT JOIN [dbo].[Activo_Componente] co ON co.aco_id = c.rco_activo_componente',
        N'LEFT JOIN [dbo].[Activo_Componente] co ON co.aco_id = c.rco_activo_componente
    LEFT JOIN [dbo].[Activo] ac ON ac.act_id = c.rco_activo')
    SET @sql = REPLACE(REPLACE(@sql, N'CREATE PROCEDURE', N'CREATE OR ALTER PROCEDURE'), N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE')
    EXEC (@sql)
END
GO

SELECT
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_ESTRUCTURA')) LIKE N'%rc.rco_activo = @ACTIVO%' THEN 'OK' ELSE 'FALTA' END AS ESTRUCTURA,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_REPUESTO_COMPATIBILIDAD')) LIKE N'%ac.act_id = c.rco_activo%' THEN 'OK' ELSE 'FALTA' END AS FICHA_REPUESTO,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_PLANTA')) LIKE N'%rc.rco_activo = a.act_id%' THEN 'OK' ELSE 'FALTA' END AS PLANTA,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_ACTIVO_REPUESTO_COMPATIBLE')) LIKE N'%cmp.rco_activo = act.act_id%' THEN 'OK' ELSE 'FALTA' END AS CENTRO,
    CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.SEL_BODEGA_MAPA_COMPATIBLES')) LIKE N'%c.rco_activo = @ACTIVO%' THEN 'OK' ELSE 'FALTA' END AS BODEGA
GO
