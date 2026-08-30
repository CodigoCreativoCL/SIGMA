USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  30-08-2026
-- DESCRIPTION:     BLOQUE C.4 REEMISION DE LA CLAVE DE SUSCRIPCION.
-- =============================================
-- Va DESPUES de 44_PLANES_MANTENEDOR.
--
-- LA PREGUNTA QUE ORIGINA ESTE BLOQUE
--   "Como le reenvio la key al cliente?"
--
--   No se puede. Y eso NO es una carencia que haya que tapar: es la
--   consecuencia buscada de guardar solo el hash. La clave se muestra una
--   vez, al crear la suscripcion, y de ahi en adelante la base tiene el
--   prefijo visible y HASHBYTES del resto. No hay forma de recuperarla, del
--   mismo modo que no hay forma de recuperar la contrasena de nadie desde
--   el bloque 26.
--
--   Lo unico honesto que se puede ofrecer es REEMITIR: generar una clave
--   nueva, guardar su hash, y mostrarla una vez.
--
-- LO QUE HAY QUE ENTENDER ANTES DE APRETAR EL BOTON
--   Reemitir INVALIDA la clave anterior. Si el cliente ya la tiene
--   configurada en su instalacion o en la app, esa integracion deja de
--   funcionar hasta que le carguen la nueva. No es una operacion de
--   consulta disfrazada: es un corte.
--
--   Por eso el SP exige @MOTIVO. No por burocracia: la reemision es de las
--   pocas operaciones que rompen algo que estaba funcionando, y dentro de
--   seis meses alguien va a querer saber por que se corto.
--
-- POR QUE LA CLAVE SE GENERA EN LA APLICACION Y NO AQUI
--   Mismo criterio que INS_SUSCRIPCION: la clave llega partida en prefijo y
--   texto, y el SP solo guarda el prefijo y el hash. Generarla en T-SQL
--   obligaria a usar NEWID() como fuente de aleatoriedad y a que el texto
--   en claro viajara de vuelta en un SELECT, quedando en el plan de
--   ejecucion y en cualquier traza que este activa.
--
-- ES IDEMPOTENTE
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. UPD_SUSCRIPCION_KEY

      Reemite la clave. Devuelve el prefijo nuevo para que la pantalla lo
      muestre; el texto en claro NUNCA vuelve desde aqui, porque quien lo
      genero es la aplicacion y ya lo tiene.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SUSCRIPCION_KEY]
@ID          INT,
@KEY_PREFIJO NVARCHAR(20),
@KEY_TEXTO   VARCHAR(200),
@MOTIVO      NVARCHAR(500),
@USUARIO     INT

AS
SET NOCOUNT ON

DECLARE @PREFIJO_ANTERIOR NVARCHAR(20)

BEGIN
    SELECT @PREFIJO_ANTERIOR = sus_key_prefijo
      FROM [dbo].[Suscripcion]
     WHERE sus_id = @ID

    IF @PREFIJO_ANTERIOR IS NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion] WHERE sus_id = @ID)
    BEGIN
        RAISERROR('1.- LA SUSCRIPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @KEY_TEXTO IS NULL OR LEN(@KEY_TEXTO) < 16
    BEGIN
        RAISERROR('2.- LA CLAVE DE SUSCRIPCIÓN NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END

    /* El motivo es obligatorio: reemitir corta una integracion que estaba
       funcionando, y sin registro nadie va a poder explicar despues por que
       la app del cliente dejo de conectarse un martes. */
    IF @MOTIVO IS NULL OR LEN(LTRIM(@MOTIVO)) < 5
    BEGIN
        RAISERROR('3.- INDIQUE EL MOTIVO DE LA REEMISIÓN.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Suscripcion]
    SET     sus_key_prefijo           = @KEY_PREFIJO,
            sus_key_hash              = HASHBYTES('SHA2_256', @KEY_TEXTO),
            sus_fecha_emision_key_utc = GETUTCDATE(),
            /* Queda en la observacion y no en una tabla aparte: son eventos
               raros -si se vuelven frecuentes, ahi si merecen su tabla- y
               dejarlos a la vista de quien abre la ficha es mas util que
               esconderlos en una bitacora que nadie consulta. */
            sus_observacion           = ISNULL(sus_observacion + NCHAR(13) + NCHAR(10), N'') +
                                        N'[' + CONVERT(NVARCHAR(10), GETDATE(), 103) + N'] ' +
                                        N'Clave reemitida (' + ISNULL(@PREFIJO_ANTERIOR, N'sin prefijo') +
                                        N' → ' + @KEY_PREFIJO + N'). Motivo: ' + @MOTIVO,
            sus_usuario_actualizacion = @USUARIO,
            sus_fecha_actualizacion   = GETDATE()
    WHERE   sus_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION_KEY @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE REEMITIR LA CLAVE.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   2. PERMISO

      Separado de CREAR EDITAR SUSCRIPCIONES a proposito. Corregir un
      telefono de contacto y cortarle la conexion a un cliente no son la
      misma facultad, y quien hace lo primero todo el dia no tiene por que
      poder hacer lo segundo por accidente.
   ======================================================================== */

INSERT INTO [dbo].[Permiso]
    (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
     prm_usuario_creacion, prm_fecha_creacion, prm_usuario_actualizacion, prm_fecha_actualizacion,
     prm_habilitado, prm_asignable_usuario)
SELECT  N'REEMITIR KEY SUSCRIPCION', N'Reemitir la clave de suscripción', N'COMERCIAL',
        (SELECT pam_id FROM [dbo].[Permiso_Ambito] WHERE pam_codigo = N'WEB'),
        NULL, 1, GETDATE(), 1, GETDATE(), 1, 0
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = N'REEMITIR KEY SUSCRIPCION')
GO

INSERT INTO [dbo].[Menu_Funcion] (mfu_nombre, mfu_menu, mfu_permiso)
SELECT  N'Reemitir clave',
        (SELECT mnu_id FROM [dbo].[Menus]
          WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/suscripciones.aspx' COLLATE DATABASE_DEFAULT),
        (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'REEMITIR KEY SUSCRIPCION')
WHERE   EXISTS (SELECT 1 FROM [dbo].[Menus]
                 WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/suscripciones.aspx' COLLATE DATABASE_DEFAULT)
  AND   NOT EXISTS (
            SELECT 1 FROM [dbo].[Menu_Funcion] mf
            WHERE mf.mfu_menu = (SELECT mnu_id FROM [dbo].[Menus]
                                  WHERE LOWER(mnu_link) = N'~/view/comercial/suscripciones/suscripciones.aspx' COLLATE DATABASE_DEFAULT)
              AND mf.mfu_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'REEMITIR KEY SUSCRIPCION'))
GO


/* ========================================================================
   3. QUIEN PUEDE

      Root y Gerente Comercial. El Administrador del Cliente NO: la clave
      identifica a su instalacion ante SIGMA, y dejar que la reemita por su
      cuenta es dejar que se desconecte solo sin que nadie del lado de
      SIGMA se entere.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  1, p.prm_id, 1
FROM    [dbo].[Permiso] p
WHERE   p.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = 1 AND pp.ppe_permiso = p.prm_id)
GO

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion)
SELECT  pf.per_id, pm.prm_id, 1
FROM    [dbo].[Perfiles] pf
CROSS JOIN [dbo].[Permiso] pm
WHERE   pf.per_nombre = N'2. Gerente Comercial' COLLATE DATABASE_DEFAULT
  AND   pm.prm_codigo = N'REEMITIR KEY SUSCRIPCION' COLLATE DATABASE_DEFAULT
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = pf.per_id AND pp.ppe_permiso = pm.prm_id)
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */

SELECT 'UPD_SUSCRIPCION_KEY' AS control, COUNT(*) AS valor, 1 AS esperado
FROM   sys.procedures WHERE name = 'UPD_SUSCRIPCION_KEY'
UNION ALL
SELECT 'permiso de reemisión', COUNT(*), 1
FROM   [dbo].[Permiso] WHERE prm_codigo = N'REEMITIR KEY SUSCRIPCION'
UNION ALL
SELECT 'función en Suscripción', COUNT(*), 1
FROM   [dbo].[Menu_Funcion] mf
INNER JOIN [dbo].[Menus] m ON m.mnu_id = mf.mfu_menu
WHERE  LOWER(m.mnu_link) = N'~/view/comercial/suscripciones/suscripciones.aspx' COLLATE DATABASE_DEFAULT
  AND  mf.mfu_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'REEMITIR KEY SUSCRIPCION')
GO
