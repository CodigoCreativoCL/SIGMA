USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  23-09-2026
-- DESCRIPTION:     UN SOLO MENU DE PROCEDIMIENTOS (HU-061 + HU-062).
--                  1. UPD_PROCEDIMIENTO_PASO_ORDEN: aplica el orden de todos
--                     los pasos de una receta en una sola pasada.
--                  2. Retira el menu "Pasos de procedimiento": los pasos se
--                     editan dentro de la ficha del procedimiento.
-- =============================================
-- Procedimientos y "Pasos de procedimiento" eran dos menus y cuatro pantallas.
-- Escribir una receta de ocho pasos costaba abrir el segundo menu, elegir el
-- procedimiento en un combo y repetir nueve veces nuevo-guardar-cerrar. Ahora
-- la receta y sus pasos son una pantalla: Procedimiento.aspx.
--
-- Las filas 2166 y 2167 se ELIMINAN, no se esconden: sus paginas se sacaron del
-- repositorio y una fila de Menus que apunta a una pagina inexistente es un
-- acceso roto -da 404 a quien tenga el enlace guardado- y ademas engaña al
-- inventario de pantallas. La funcion "Crear y editar" de la 2166 se va con
-- ella; la de la 2161, que es la que ahora manda, se queda.
-- TODO IDEMPOTENTE.
-- =============================================

SET NOCOUNT ON
GO

/* ========================================================================
   1. UPD_PROCEDIMIENTO_PASO_ORDEN

   POR QUE HACE FALTA UN SP APARTE
     El par (procedimiento, orden) tiene indice unico (UX_PPA_PROCEDIMIENTO_
     ORDEN). Renumerar de a uno con UPD_PROCEDIMIENTO_PASO choca con el paso
     que ya ocupa el numero destino en cuanto se escribe el primero: mover el
     quinto al segundo lugar falla contra el tercero a mitad de camino y deja
     media receta renumerada.

     Aca se pasan TODOS los pasos de la receta a orden negativo dentro de la
     misma transaccion -el espejo de 1..N nunca colisiona con 1..N- y recien
     despues se asigna la secuencia definitiva.

   LOS QUE NO VIENEN EN LA LISTA
     Un paso dado de baja, o uno que la pantalla no mostraba, queda despues
     del ultimo conservando su orden relativo. Dejarlos en negativo seria
     dejar la tabla en un estado que ningun SELECT sabe leer.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_PROCEDIMIENTO_PASO_ORDEN]
    @CLIENTE        INT,
    @PROCEDIMIENTO  INT,
    @IDS            VARCHAR(MAX),   -- ids separados por coma, EN ORDEN
    @USUARIO        INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @PRC_CLIENTE INT, @EXISTE BIT, @N INT

SELECT @PRC_CLIENTE = prc_cliente, @EXISTE = 1
FROM   [dbo].[Procedimiento]
WHERE  prc_id = @PROCEDIMIENTO

IF @EXISTE IS NULL
BEGIN RAISERROR('1.- EL PROCEDIMIENTO NO EXISTE.', 16, 1) RETURN -1 END

IF @PRC_CLIENTE IS NULL
BEGIN RAISERROR('2.- ES UN PROCEDIMIENTO GLOBAL DEL SISTEMA: NO SE REORDENAN SUS PASOS DESDE EL CLIENTE.', 16, 1) RETURN -1 END

IF @PRC_CLIENTE <> @CLIENTE
BEGIN RAISERROR('3.- EL PROCEDIMIENTO PERTENECE A OTRA EMPRESA.', 16, 1) RETURN -1 END

/* La lista tal como llego, con su posicion. STRING_SPLIT con ordinal necesita
   nivel de compatibilidad 160, que es el de esta base. */
DECLARE @LISTA TABLE (id INT PRIMARY KEY, n INT)

INSERT INTO @LISTA (id, n)
SELECT  TRY_CAST(LTRIM(RTRIM(value)) AS INT),
        ROW_NUMBER() OVER (ORDER BY ordinal)
FROM    STRING_SPLIT(@IDS, ',', 1)
WHERE   TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL

SELECT @N = COUNT(*) FROM @LISTA

IF @N = 0
BEGIN RAISERROR('4.- NO SE INDICO NINGUN PASO.', 16, 1) RETURN -1 END

/* Un id que no sea de esta receta es un error de quien llamo, no algo que se
   ignore en silencio: si se dejara pasar, la pantalla creeria que ordeno algo
   que no ordeno. */
IF EXISTS (SELECT 1 FROM @LISTA l
           LEFT JOIN [dbo].[Procedimiento_Paso] s ON s.ppa_id = l.id AND s.ppa_procedimiento = @PROCEDIMIENTO
           WHERE s.ppa_id IS NULL)
BEGIN RAISERROR('5.- LA LISTA TRAE PASOS QUE NO SON DE ESTE PROCEDIMIENTO.', 16, 1) RETURN -1 END

BEGIN TRAN

    /* Al espejo negativo. Asi 1..N queda libre para la secuencia nueva sin
       que el indice unico vea nunca dos pasos en el mismo numero. */
    UPDATE [dbo].[Procedimiento_Paso]
    SET    ppa_orden = -ppa_orden
    WHERE  ppa_procedimiento = @PROCEDIMIENTO
      AND  ppa_orden > 0

    -- La secuencia pedida.
    UPDATE s
    SET    s.ppa_orden = l.n
    FROM   [dbo].[Procedimiento_Paso] s
    JOIN   @LISTA l ON l.id = s.ppa_id
    WHERE  s.ppa_procedimiento = @PROCEDIMIENTO

    -- Los que no venian: detras del ultimo, en el mismo orden que tenian.
    ;WITH RESTO AS (
        SELECT ppa_id, ROW_NUMBER() OVER (ORDER BY -ppa_orden) AS rn
        FROM   [dbo].[Procedimiento_Paso]
        WHERE  ppa_procedimiento = @PROCEDIMIENTO
          AND  ppa_orden < 0
    )
    UPDATE s
    SET    s.ppa_orden = @N + r.rn
    FROM   [dbo].[Procedimiento_Paso] s
    JOIN   RESTO r ON r.ppa_id = s.ppa_id

COMMIT

SELECT 200 AS ID, 200 AS CODE, 'Orden de los pasos aplicado.' AS MENSAJE
GO
PRINT '--- UPD_PROCEDIMIENTO_PASO_ORDEN creado.'
GO


/* ========================================================================
   2. UN SOLO MENU

   2166 "Pasos de procedimiento" y 2167 "Paso de procedimiento (detalle)"
   dejan de existir: sus paginas se retiraron del repositorio. El texto de la
   2161 se actualiza para que diga lo que la pantalla hace ahora.
   ======================================================================== */

-- La funcion de la pantalla que se va (FK a Menus).
DELETE FROM [dbo].[Menu_Funcion] WHERE mfu_menu IN (2166, 2167)

-- Por si algun perfil la tuviera asignada explicitamente.
DELETE FROM [dbo].[Menu_Perfil]  WHERE mpe_menu IN (2166, 2167)

DELETE FROM [dbo].[Menus] WHERE mnu_id IN (2166, 2167)

UPDATE [dbo].[Menus]
SET    mnu_descripcion = 'Las recetas de trabajo reutilizables y sus pasos, en una sola pantalla.'
WHERE  mnu_id = 2161

PRINT '--- Menu de pasos de procedimiento retirado; queda solo Procedimientos.'
GO

/* Comprobacion: que no quede ninguna fila de Menus apuntando a las paginas
   retiradas. Una fila asi es un acceso roto en el arbol del menu. */
IF EXISTS (SELECT 1 FROM [dbo].[Menus] WHERE mnu_link LIKE '%ProcedimientoPaso%')
    PRINT '*** ATENCION: quedan filas de Menus apuntando a ProcedimientoPaso(s).aspx'
ELSE
    PRINT '--- Sin accesos rotos: ninguna fila apunta a las paginas retiradas.'
GO

PRINT '260_PROCEDIMIENTO_UNIFICADO aplicado.'
GO
