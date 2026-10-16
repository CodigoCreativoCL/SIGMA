/* ============================================================================
   SIGMA — Bloque 468
   CENTRO COMERCIAL V2 · CLIENTE EN DRAWER: MONEDA DE COBRO AUDITADA
   ----------------------------------------------------------------------------
   La moneda de cobro (UF o USD) se fija al crear el cliente, según su país, y
   no cambia sola. Cambiarla exige la facultad CAMBIAR MONEDA COBRO CLIENTE y
   un motivo, y queda en Cliente_Moneda_Historial. Un período ya emitido
   conserva su moneda (Suscripcion_Periodo.spe_moneda).

   UPS_CLIENTE_MONEDA_COBRO   inicial (sin motivo) o cambio (con motivo).
   SEL_CLIENTE_COMERCIAL      la ficha comercial: identidad, país, moneda,
                              suscripción y ejecutivo a cargo.
   SEL_CLIENTE_COMERCIAL_LISTA  moneda y país de cada cliente (para la lista).
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Cliente_Moneda_Historial]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Cliente_Moneda_Historial]
    (
        [cmh_id]              INT            NOT NULL IDENTITY(1,1),
        [cmh_cliente]         INT            NOT NULL,
        [cmh_moneda_anterior] VARCHAR(3)     NULL,
        [cmh_moneda_nueva]    VARCHAR(3)     NOT NULL,
        [cmh_motivo]          NVARCHAR(500)  NULL,
        [cmh_usuario]         INT            NOT NULL,
        [cmh_fecha]           DATETIME       NOT NULL CONSTRAINT DF_CMH_FECHA DEFAULT GETDATE(),
        CONSTRAINT PK_CLIENTE_MONEDA_HISTORIAL PRIMARY KEY CLUSTERED ([cmh_id] ASC),
        CONSTRAINT FK_CMH_CLIENTE FOREIGN KEY ([cmh_cliente]) REFERENCES [dbo].[Cliente] ([cli_id])
    )
    CREATE NONCLUSTERED INDEX IX_CMH_CLIENTE ON [dbo].[Cliente_Moneda_Historial] ([cmh_cliente], [cmh_fecha] DESC)
END
GO

/* Facultad para cambiar la moneda de cobro: Root y Gerente Comercial. */
INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT  N'CAMBIAR MONEDA COBRO CLIENTE', N'Cambiar la moneda en que se cobra a un cliente', N'COMERCIAL',
        (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'WEB'),
        NULL, 1, GETDATE(), 1, GETDATE(), 1, 0
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'CAMBIAR MONEDA COBRO CLIENTE')
GO

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_codigo = N'CAMBIAR MONEDA COBRO CLIENTE'
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  pf.per_id, pm.prm_id, 1
FROM    [dbo].[Perfiles] pf
CROSS JOIN [dbo].[Permiso] pm
WHERE   pf.per_nombre = N'2. Gerente Comercial' COLLATE DATABASE_DEFAULT
  AND   pm.prm_codigo = N'CAMBIAR MONEDA COBRO CLIENTE' COLLATE DATABASE_DEFAULT
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp WHERE pp.ppe_perfil = pf.per_id AND pp.ppe_permiso = pm.prm_id)
GO

CREATE OR ALTER PROCEDURE [dbo].[UPS_CLIENTE_MONEDA_COBRO]
@ID INT, @MONEDA VARCHAR(3), @MOTIVO NVARCHAR(500) = NULL, @USUARIO INT
AS
SET NOCOUNT ON
DECLARE @ACTUAL VARCHAR(3)
SELECT @ACTUAL = cli_moneda_cobro FROM [dbo].[Cliente] WHERE cli_id = @ID
IF @ACTUAL IS NULL BEGIN RAISERROR('1.- EL CLIENTE NO EXISTE.', 16, 1) RETURN -1 END
IF @MONEDA NOT IN ('UF', 'USD') BEGIN RAISERROR('2.- LA MONEDA DE COBRO DEBE SER UF O USD.', 16, 1) RETURN -1 END
IF @ACTUAL = @MONEDA RETURN 0
-- Con motivo es un CAMBIO (auditado); sin motivo solo vale para fijar la moneda de un cliente recién creado.
IF @MOTIVO IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Cliente_Moneda_Historial] WHERE cmh_cliente = @ID)
       OR EXISTS (SELECT 1 FROM [dbo].[Suscripcion] S JOIN [dbo].[Suscripcion_Periodo] P ON P.spe_suscripcion = S.sus_id WHERE S.sus_cliente = @ID)
    BEGIN RAISERROR('3.- CAMBIAR LA MONEDA DE COBRO EXIGE UN MOTIVO.', 16, 1) RETURN -1 END
END
ELSE IF LEN(LTRIM(RTRIM(@MOTIVO))) < 5
BEGIN RAISERROR('4.- INDICA EL MOTIVO DEL CAMBIO DE MONEDA (AL MENOS 5 LETRAS).', 16, 1) RETURN -1 END
BEGIN TRANSACTION
    UPDATE [dbo].[Cliente] SET cli_moneda_cobro = @MONEDA, cli_usuario_actualizacion = @USUARIO, cli_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE cli_id = @ID
    INSERT [dbo].[Cliente_Moneda_Historial] (cmh_cliente, cmh_moneda_anterior, cmh_moneda_nueva, cmh_motivo, cmh_usuario, cmh_fecha)
    VALUES (@ID, @ACTUAL, @MONEDA, LTRIM(RTRIM(@MOTIVO)), @USUARIO, [dbo].[FNC_AHORA]())
COMMIT TRANSACTION
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_COMERCIAL]
@ID INT
AS
SET NOCOUNT ON
-- 0 · identidad
SELECT  C.cli_id AS ID, C.cli_nombre AS NOMBRE, C.cli_razon_social AS RAZON_SOCIAL, C.cli_nombre_fantasia AS FANTASIA,
        C.cli_pais AS PAIS_ID, PA.pai_nombre AS PAIS, PA.pai_identificador_nombre AS IDENT_ETIQUETA, C.cli_identificador AS IDENTIFICADOR,
        C.cli_zona_horaria AS ZONA_HORARIA, C.cli_idioma AS IDIOMA, C.cli_moneda AS MONEDA_ID, C.cli_moneda_cobro AS MONEDA_COBRO,
        C.cli_habilitado AS HABILITADO, C.cli_archivo_logo AS LOGO, CONVERT(VARCHAR(10), C.cli_fecha_creacion, 120) AS DESDE
FROM    [dbo].[Cliente] C
LEFT JOIN [dbo].[Paises] PA ON PA.pai_id = C.cli_pais
WHERE   C.cli_id = @ID
-- 1 · suscripción, plan y ejecutivo a cargo
SELECT  S.sus_id AS SUSCRIPCION, PC.plc_nombre AS PLAN_NOMBRE, SE.sue_nombre AS ESTADO,
        CONVERT(VARCHAR(10), S.sus_fecha_fin, 120) AS HASTA,
        LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS EJECUTIVO, L.lea_codigo AS LEAD_CODIGO
FROM    [dbo].[Cliente] C
LEFT JOIN [dbo].[Suscripcion] S ON S.sus_cliente = C.cli_id AND S.sus_habilitado = 1
LEFT JOIN [dbo].[Plan_Comercial] PC ON PC.plc_id = S.sus_plan_comercial
LEFT JOIN [dbo].[Suscripcion_Estado] SE ON SE.sue_id = S.sus_suscripcion_estado
LEFT JOIN [dbo].[Lead] L ON L.lea_cliente = C.cli_id
LEFT JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo
WHERE   C.cli_id = @ID
-- 2 · contactos
EXEC [dbo].[SEL_CLIENTE_CONTACTO] @CLIENTE = @ID
RETURN 0
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_COMERCIAL_LISTA]
AS
SET NOCOUNT ON
SELECT C.cli_id AS ID, C.cli_pais AS PAIS_ID, PA.pai_nombre AS PAIS, C.cli_moneda_cobro AS MONEDA_COBRO
FROM [dbo].[Cliente] C LEFT JOIN [dbo].[Paises] PA ON PA.pai_id = C.cli_pais
RETURN 0
GO

/* Países habilitados con la etiqueta de su identificador tributario y la moneda en que se cobra
   (Chile: UF; el resto: USD). Lo usan el drawer Cliente, el Nuevo lead y el formulario público. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_COBRO_PAISES]
AS
SET NOCOUNT ON
SELECT pai_id AS ID, pai_nombre AS NOMBRE, ISNULL(pai_identificador_nombre, N'Identificador tributario') AS ETIQUETA,
       pai_identificador_validacion AS VALIDACION, pai_identificador_largo AS LARGO,
       CASE WHEN pai_id = 1 THEN 'UF' ELSE 'USD' END AS MONEDA
  FROM [dbo].[Paises] WHERE pai_habilItado = 1 ORDER BY CASE WHEN pai_id = 1 THEN 0 ELSE 1 END, pai_nombre
RETURN 0
GO

PRINT '468_CLIENTE_COBRO_DRAWER aplicado.'
GO
