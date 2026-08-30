/* ============================================================================
   SIGMA — Bloque 55
   LA FUNCION SPLIT QUE NUNCA EXISTIO · EL CATALOGO DE LA APP
   ----------------------------------------------------------------------------

   Dos cosas que aparecieron al probar el sitio en navegador. Las dos son del
   mismo tipo: codigo que llama a un objeto de base que no esta.

     1. dbo.SPLIT no existe, y tres procedimientos la invocan. Guardar un
        usuario reventaba con "Invalid object name DBO.SPLIT" y encima dejaba
        una transaccion abierta.

     2. La tabla APP no existe, y SEL_CLIENTE_APP_INSTALACION la consulta.
        Por eso la seccion "Configuracion de la app" de la ficha de planta
        salia vacia, con una nota y un boton Guardar que no guardaba nada.
   ============================================================================ */


/* ========================================================================
   1. dbo.SPLIT

      La usan INS_CLIENTE_USUARIO, UPD_CLIENTE_USUARIO y SEL_CLIENTE_USUARIO
      para partir el CSV de perfiles. Nunca se creo: viene del proyecto
      heredado, donde existia, y no se migro.

      No se noto antes porque las tres rutas que la tocan piden @PERFILES, y
      hasta ahora las pruebas o no lo pasaban o se cortaban antes -en
      INS_CLIENTE_USUARIO el tope del plan rechaza y retorna mucho antes de
      llegar aqui-. La primera vez que alguien guardo un usuario desde la
      pantalla, salto.

      SQL Server 2022 ya trae STRING_SPLIT, y de hecho API_SEL_USUARIO_LOGIN
      y UPS_CLIENTE_USUARIO_PLANTA lo usan directo. Esta funcion es una
      envoltura sobre ella, no una implementacion nueva: existe para que los
      procedimientos heredados encuentren el nombre que buscan, con la
      columna VALUE que esperan.

      CODIGO NUEVO: usar STRING_SPLIT directo. Esto es un puente, no el
      camino.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[SPLIT]
(
    @TEXTO     NVARCHAR(MAX),
    @SEPARADOR NVARCHAR(10)
)
RETURNS TABLE
AS
RETURN
(
    /* Inline y no multi-statement: se resuelve dentro del plan de la
       consulta que la llama, sin materializar una tabla intermedia.

       Se descartan los vacios porque un CSV real trae comas de sobra -"3,4,"
       o ",,5"- y una fila vacia se convierte rio abajo en un INSERT con id
       nulo o en un IN() que no filtra nada. */
    SELECT  LTRIM(RTRIM(s.value)) AS VALUE
    FROM    STRING_SPLIT(ISNULL(@TEXTO, N''), @SEPARADOR) s
    WHERE   LTRIM(RTRIM(s.value)) <> N''
)
GO


/* ========================================================================
   2. LA TRANSACCION QUE QUEDABA ABIERTA

      El segundo mensaje del error -"Transaction count after EXECUTE
      indicates a mismatching number of BEGIN and COMMIT"- no era otro
      problema: era la consecuencia. UPD_CLIENTE_USUARIO abre una
      transaccion, y cuando la llamada a SPLIT fallaba, el COMMIT del final
      nunca se ejecutaba. La transaccion quedaba viva, tomando bloqueos,
      hasta que la conexion se soltaba.

      SET XACT_ABORT ON hace que cualquier error aborte y revierta la
      transaccion entera. Es una linea, no cambia el comportamiento cuando
      todo sale bien, y convierte "fallo dejando todo a medias" en "fallo
      sin dejar rastro", que es lo unico aceptable en un procedimiento que
      toca cuatro tablas.

      Se aplica solo agregando la linea: el resto del procedimiento heredado
      no se toca, porque reescribirlo a ciegas es como se rompen las cosas
      que hoy funcionan.
   ======================================================================== */

DECLARE @SQL NVARCHAR(MAX) = (SELECT definition FROM sys.sql_modules
                               WHERE object_id = OBJECT_ID('UPD_CLIENTE_USUARIO'))

IF @SQL IS NOT NULL AND @SQL NOT LIKE '%XACT_ABORT%'
BEGIN
    -- CREATE PROCEDURE -> ALTER PROCEDURE, y se inyecta la linea tras el AS.
    SET @SQL = REPLACE(@SQL, 'CREATE PROCEDURE', 'ALTER PROCEDURE')
    SET @SQL = STUFF(@SQL,
                     CHARINDEX(CHAR(13) + CHAR(10), @SQL, CHARINDEX(CHAR(10) + 'AS', @SQL)) + 2,
                     0,
                     'SET XACT_ABORT ON' + CHAR(13) + CHAR(10))

    EXEC sys.sp_executesql @SQL
END
GO


/* ========================================================================
   3. EL CATALOGO DE FUNCIONALIDADES DE LA APP

      SEL_CLIENTE_APP_INSTALACION lee de una tabla APP que no existe, con
      SQL armado por concatenacion. La ficha de planta muestra la seccion,
      el repetidor sale vacio y queda un boton Guardar sobre una lista de
      cero elementos.

      Se crea el catalogo con la forma que el resto del sistema usa
      -id, codigo, nombre, orden, habilitado- y se registra en Catalogo para
      que se mantenga desde Cliente > Configuracion > Catalogos, como
      cualquier otro.

      SE CREA VACIO, A PROPOSITO. Cuales son las funcionalidades de la app
      movil es alcance de EP-15, que es del Sprint 2 y todavia no esta
      definido. Inventar aqui una lista de funciones seria decidir el
      producto desde la base de datos, y ademas quedaria mintiendo: el
      cliente veria interruptores para cosas que la app no hace.

      Cuando EP-15 defina las funciones, esto es un INSERT.
   ======================================================================== */

IF OBJECT_ID('[dbo].[App]') IS NULL
BEGIN
    CREATE TABLE [dbo].[App]
    (
        app_id         INT IDENTITY(1,1) NOT NULL,
        app_codigo     NVARCHAR(50)  NOT NULL,
        app_nombre     NVARCHAR(200) NOT NULL,
        app_tipo       NVARCHAR(50)      NULL,
        app_orden      INT           NOT NULL CONSTRAINT DF_App_Orden      DEFAULT (0),
        app_habilitado BIT           NOT NULL CONSTRAINT DF_App_Habilitado DEFAULT (1),
        CONSTRAINT PK_App PRIMARY KEY CLUSTERED (app_id),
        CONSTRAINT UQ_App_Codigo UNIQUE (app_codigo)
    )
END
GO

/* Las FK que a Cliente_App_Instalacion le faltaban. Sin ellas, la tabla
   puede guardar la configuracion de una planta que no existe para una
   funcionalidad que no existe, y nadie se entera. */
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CAI_APP')
    ALTER TABLE [dbo].[Cliente_App_Instalacion] WITH CHECK
    ADD CONSTRAINT FK_CAI_APP FOREIGN KEY (cai_id_app) REFERENCES [dbo].[App](app_id)
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CAI_INSTALACION')
    ALTER TABLE [dbo].[Cliente_App_Instalacion] WITH CHECK
    ADD CONSTRAINT FK_CAI_INSTALACION FOREIGN KEY (cai_id_instalacion) REFERENCES [dbo].[Cliente_Instalacion](cin_id)
GO

/* Se registra como catalogo mantenible desde la pantalla de Catalogos. */
INSERT INTO [dbo].[Catalogo]
    (ctl_codigo, ctl_nombre, ctl_descripcion, ctl_tabla, ctl_prefijo, ctl_modulo, ctl_ampliable, ctl_orden, ctl_habilitado)
SELECT  N'APP_FUNCIONALIDAD', N'Funcionalidades de la app',
        N'Que puede hacer la app movil. Se habilita por planta desde la ficha de la planta.',
        N'App', N'app', N'Movil',
        /* ampliable = 0: el cliente NO agrega funcionalidades. Que puede
           hacer la app lo define SIGMA al construirla; una fila inventada
           aqui seria un interruptor que no enciende nada. */
        0, 0, 1
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Catalogo] WHERE ctl_tabla = N'App')
GO


/* ---- El SP, sin SQL armado por concatenacion -------------------------- */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_APP_INSTALACION]
@ID_INSTALACION INT
AS
SET NOCOUNT ON

    /* Se listan TODAS las funcionalidades habilitadas y se trae, para cada
       una, si esta prendida en esta planta. Un LEFT JOIN y no un INNER:
       una funcionalidad que nunca se configuro tiene que aparecer igual, en
       NULL, para que se pueda prender por primera vez. */
    SELECT  a.app_id     AS APP_ID,
            a.app_nombre AS APP_NOMBRE,
            a.app_tipo   AS APP_TIPO,
            cai.cai_habilitado AS CAP_HABILITADO
    FROM    [dbo].[App] a
    LEFT JOIN [dbo].[Cliente_App_Instalacion] cai
           ON cai.cai_id_app = a.app_id
          AND cai.cai_id_instalacion = @ID_INSTALACION
    WHERE   a.app_habilitado = 1
    ORDER BY a.app_orden, a.app_nombre

RETURN(0)
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'dbo.SPLIT existe' AS OBJETO,
        (SELECT COUNT(*) FROM sys.objects WHERE name = 'SPLIT') AS HAY, 1 AS ESPERADO
UNION ALL
SELECT  'SPLIT parte bien y descarta vacios',
        (SELECT COUNT(*) FROM [dbo].[SPLIT](N'10,,5, 13 ,', N',')), 3
UNION ALL
SELECT  'UPD_CLIENTE_USUARIO aborta la transaccion ante un error',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('UPD_CLIENTE_USUARIO') AND definition LIKE '%XACT_ABORT%'), 1
UNION ALL
SELECT  'tabla App creada',
        (SELECT COUNT(*) FROM sys.tables WHERE name = 'App'), 1
UNION ALL
SELECT  'FKs de Cliente_App_Instalacion',
        (SELECT COUNT(*) FROM sys.foreign_keys WHERE name IN ('FK_CAI_APP','FK_CAI_INSTALACION')), 2
UNION ALL
SELECT  'App registrada como catalogo',
        (SELECT COUNT(*) FROM [dbo].[Catalogo] WHERE ctl_tabla = N'App'), 1
UNION ALL
SELECT  'SEL_CLIENTE_APP_INSTALACION sin SQL concatenado',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_CLIENTE_APP_INSTALACION')
            AND definition NOT LIKE '%EXEC(@SELECT%'), 1
GO

SELECT PRUEBA = 'la seccion de app ya no falla, devuelve vacio porque el catalogo esta vacio'
EXEC [dbo].[SEL_CLIENTE_APP_INSTALACION] @ID_INSTALACION = 1
GO
