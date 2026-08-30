USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     REPARA LOS SP DEL NUCLEO QUE QUEDAN ROTOS TRAS EL 00.
-- =============================================
-- Va DESPUES de 00_SANEAMIENTO y ANTES del 04.
--
-- DEL_CLIENTE
--
--   QUE LE PASABA
--     Su primer statement era un guard contra la tabla [CHECKLIST], que
--     no existe en esta base. Por resolucion diferida de nombres el SP se
--     creaba bien, pero al ejecutarlo lanzaba error 208 "Invalid object
--     name" antes de llegar al BEGIN TRANSACTION. Resultado: eliminar un
--     cliente fallaba SIEMPRE, para cualquier cliente. Afecta a HU-010.
--     No habia riesgo de borrado parcial: fallaba antes de la transaccion.
--
--   POR QUE SE QUITA EL GUARD Y NO SE REEMPLAZA
--     El checklist de SIGMA es el dominio D7 (bloque 15) y no cuelga del
--     cliente: cuelga de la instalacion y del activo. El guard contra
--     CLIENTE_INSTALACION, que se conserva, ya cubre ese caso y todos los
--     demas: activos, bodegas, ordenes y checklists cuelgan de la
--     instalacion. El guard de CHECKLIST era redundante incluso en el
--     modelo legado.
--
--   SE ELIMINAN TAMBIEN LOS DOS BLOQUES "UPDATE ... PARA LOG"
--     Existian solo para que los triggers TRG_LOG_* capturaran el usuario
--     responsable: estampaban la fila justo antes de borrarla. El bloque
--     00 da de baja esos triggers, asi que los dos UPDATE quedan sin
--     ningun proposito.
--
--     Ademas uno de ellos tenia un BUG REAL:
--         UPDATE CLIENTE_USUARIO ... WHERE UCL_ID = @ID
--     @ID es un id de CLIENTE, pero UCL_ID es la PK de Cliente_Usuario.
--     El filtro correcto es UCL_ID_CLIENTE, como usan los DELETE de mas
--     abajo en el mismo SP. Tal como estaba, pisaba una fila arbitraria
--     de OTRO cliente. Hoy el error del checklist lo tapaba; al quitar el
--     guard se habria activado. Al borrar el bloque, desaparece.
--
--     Con ellos se va tambien el bloque de FNC_PAIS_HORA: su @DATE_NOW no
--     alimentaba nada mas.
--
--   LO QUE NO CAMBIA
--     El guard de CLIENTE_INSTALACION, el orden de borrado
--     (Cliente_Usuario_Perfil -> Cliente_Usuario -> Cliente), la
--     transaccion, el manejo de error con INS_EXCEPCION y los codigos de
--     retorno 0 / -1. La firma es identica, asi que ClienteController.cs
--     no necesita ningun cambio.
--
-- PENDIENTE DE PRODUCTO (no se decide aqui)
--   Bajo SIGMA un cliente acumula suscripcion, activos, historial y
--   bitacora. Habria que definir si HU-010 "eliminar" significa borrado
--   fisico o deshabilitar (cli_habilitado). Este script solo deja el
--   comportamiento actual funcionando; no cambia la semantica.
--
-- ES IDEMPOTENTE
--   Usa CREATE OR ALTER. Se puede correr dos veces.
-- =============================================
GO

CREATE OR ALTER PROCEDURE [dbo].[DEL_CLIENTE]
 @ID      INT
,@USUARIO INT
AS
SET NOCOUNT ON

    -- Unico guard: si el cliente tiene instalaciones, no se borra.
    -- Todo lo demas del modelo cuelga de la instalacion.
    IF (EXISTS(SELECT TOP 1 1 FROM CLIENTE_INSTALACION WHERE CIN_CLIENTE = @ID))
    BEGIN
        RAISERROR('1. No es posible eliminar, el cliente posee Instalaciones', 16, 1);
        RETURN -1;
    END

    BEGIN TRANSACTION

        DELETE  CLIENTE_USUARIO_PERFIL
        WHERE   CUP_ID_CLIENTE_USUARIO IN (SELECT UCL_ID
                                           FROM   CLIENTE_USUARIO
                                           WHERE  UCL_ID_CLIENTE = @ID)

        DELETE  CLIENTE_USUARIO
        WHERE   UCL_ID_CLIENTE = @ID

        DELETE  CLIENTE
        WHERE   CLI_ID = @ID

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX)
            SET @VARIABLES = 'DEL_CLIENTE ' + LTRIM(STR(@ID))
            EXEC INS_EXCEPCION
                 @MSG       = '1.- No fue posible Eliminar el Cliente.',
                 @VARIABLES = @VARIABLES
            RETURN -1
        END

    COMMIT TRANSACTION

RETURN(0)
GO

-- ── Comprobacion ────────────────────────────────────────────────────────
-- Debe devolver CERO filas: ningun SP del nucleo puede seguir citando
-- tablas que no existen.
SELECT OBJECT_NAME(d.referencing_id) AS sp,
       d.referenced_entity_name      AS tabla_inexistente
FROM   sys.sql_expression_dependencies d
WHERE  d.referenced_id IS NULL
  AND  d.referenced_entity_name NOT LIKE '#%'
  AND  d.referenced_entity_name NOT IN ('INSERTED','DELETED','SPLIT','INS_EXCEPCION')
ORDER BY 1, 2
GO
