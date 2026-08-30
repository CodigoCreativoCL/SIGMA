/* ============================================================================
   SIGMA — Bloque 57
   QUE PUEDE HACER LA APP EN CADA PLANTA
   ----------------------------------------------------------------------------

   El bloque 55 creo la tabla App vacia. Aqui se llena, y se define que
   significa exactamente ese interruptor.

   DOS CAPAS QUE NO SON LO MISMO

   Ya existe Plan_Funcionalidad: es lo que el cliente COMPRO. Si su plan no
   incluye "Evidencia fotografica", no hay fotos y punto.

   Lo de esta pantalla es otra cosa: aunque el plan las incluya, hay plantas
   donde no se puede. En una sala electrica clasificada no entra un telefono
   sacando fotos, y en una planta de alimentos la camara puede estar prohibida
   por politica del cliente. La misma empresa, una planta si y otra no.

     Plan   -> "esto se vende"           FNC_CLIENTE_TIENE_FUNCIONALIDAD
     Planta -> "aqui ademas se permite"  Cliente_App_Instalacion

   Por eso cada funcionalidad de la app apunta a la funcionalidad de plan que
   la habilita comercialmente: **el interruptor solo aparece si el plan la
   incluye**. Mostrar un interruptor para algo que el cliente no compro lo
   deja creyendo que lo activo.

   DE DONDE SALE LA LISTA

   No se invento: cada fila corresponde a una historia del backlog, y la
   columna app_origen la deja anotada. Si manana alguien pregunta por que
   existe "Dictado por voz", la respuesta es US-080, no "a alguien le
   parecio".

   QUE NO ENTRO, Y POR QUE

     · Bandeja del dia (US-074) y trabajo sin senal (US-071) son el nucleo de
       la app. Apagarlos por planta seria apagar la app. El backlog llama al
       trabajo sin senal "el diferenciador del producto y no negociable"; un
       interruptor que nadie deberia mover no es una opcion, es una trampa.

     · Accesibilidad (US-082) es preferencia DE LA PERSONA, no de la planta.
       Si alguien necesita texto grande o mas contraste, lo necesita en las
       cinco plantas donde trabaja. Ponerlo aqui obligaria a pedirle permiso
       a cada planta para poder ver.
   ============================================================================ */


/* ========================================================================
   1. LA TABLA APRENDE DE DONDE VIENE CADA FILA
   ======================================================================== */

IF COL_LENGTH('dbo.App', 'app_funcionalidad') IS NULL
    ALTER TABLE [dbo].[App] ADD app_funcionalidad INT NULL
GO

IF COL_LENGTH('dbo.App', 'app_por_defecto') IS NULL
    ALTER TABLE [dbo].[App] ADD app_por_defecto BIT NOT NULL
        CONSTRAINT DF_App_PorDefecto DEFAULT (1)
GO

IF COL_LENGTH('dbo.App', 'app_origen') IS NULL
    ALTER TABLE [dbo].[App] ADD app_origen NVARCHAR(200) NULL
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_App_Funcionalidad')
    ALTER TABLE [dbo].[App] WITH CHECK
    ADD CONSTRAINT FK_App_Funcionalidad FOREIGN KEY (app_funcionalidad)
        REFERENCES [dbo].[Funcionalidad](fun_id)
GO


/* ========================================================================
   2. LAS SEIS FUNCIONALIDADES

      Van todas habilitadas por defecto: lo normal es que la app haga lo que
      el plan permite, y el cliente APAGA lo que en esa planta no aplica. Al
      reves -todo apagado hasta que alguien lo prenda- una planta recien
      creada tendria una app que no hace nada y nadie sabria por que.
   ======================================================================== */

;WITH F AS (
    SELECT * FROM (VALUES
        (N'FOTOS',          N'Fotos desde terreno',
         N'TERRENO',  1, 1, N'US-085 · Sacar y subir fotos desde terreno',
         N'EVIDENCIA FOTOGRAFICA'),

        (N'DESCUBRIMIENTO', N'Registrar lo que se encuentra en terreno',
         N'TERRENO',  2, 1, N'US-073 · Registrar un componente descubierto en terreno',
         N'REGISTRO TERRENO'),

        (N'VOZ_DICTADO',    N'Dictar observaciones por voz',
         N'VOZ',      3, 1, N'US-080 · Dictar una observación',
         N'CREACION POR VOZ'),

        (N'VOZ_LECTURA',    N'Escuchar el checklist en voz alta',
         N'VOZ',      4, 1, N'US-081 · Escuchar el checklist en voz alta',
         N'LECTURA POR VOZ'),

        (N'BITACORA_VOZ',   N'Bitácora por voz',
         N'VOZ',      5, 1, N'US-130 · Registrar una entrada de bitácora con voz',
         N'BITACORA'),

        (N'REPUESTOS',      N'Consultar stock de repuestos',
         N'CONSULTA', 6, 1, N'US-092 · Consultar el stock de un repuesto',
         N'INVENTARIO REPUESTOS')
    ) v (codigo, nombre, tipo, orden, defecto, origen, funcionalidad)
)
MERGE [dbo].[App] AS destino
USING (SELECT f.codigo, f.nombre, f.tipo, f.orden, f.defecto, f.origen,
              fun.fun_id
         FROM F f
         LEFT JOIN [dbo].[Funcionalidad] fun
                ON fun.fun_codigo COLLATE DATABASE_DEFAULT = f.funcionalidad COLLATE DATABASE_DEFAULT
      ) AS origen
   ON destino.app_codigo COLLATE DATABASE_DEFAULT = origen.codigo COLLATE DATABASE_DEFAULT

WHEN MATCHED THEN
    UPDATE SET destino.app_nombre        = origen.nombre,
               destino.app_tipo          = origen.tipo,
               destino.app_orden         = origen.orden,
               destino.app_por_defecto   = origen.defecto,
               destino.app_origen        = origen.origen,
               destino.app_funcionalidad = origen.fun_id

WHEN NOT MATCHED BY TARGET THEN
    INSERT (app_codigo, app_nombre, app_tipo, app_orden, app_por_defecto,
            app_origen, app_funcionalidad, app_habilitado)
    VALUES (origen.codigo, origen.nombre, origen.tipo, origen.orden, origen.defecto,
            origen.origen, origen.fun_id, 1);
GO


/* ========================================================================
   3. EL SP: SOLO LO QUE EL PLAN INCLUYE

      Se agrega @CLIENTE para poder preguntarle al plan. Es opcional: si no
      viene, se deduce de la planta, para no romper a quien ya llama con un
      solo parametro.

      CAP_HABILITADO deja de poder venir en NULL. Antes, una planta sin
      configurar devolvia NULL y la pantalla mostraba ni SI ni NO -dos radios
      apagados, sin decir cual estaba vigente-. Ahora cae al valor por
      defecto de la funcionalidad, que es lo que la app va a hacer realmente.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_APP_INSTALACION]
@ID_INSTALACION INT,
@CLIENTE        INT = NULL
AS
SET NOCOUNT ON

    IF @CLIENTE IS NULL
        SELECT @CLIENTE = cin_cliente
          FROM [dbo].[Cliente_Instalacion]
         WHERE cin_id = @ID_INSTALACION

    SELECT  a.app_id     AS APP_ID,
            a.app_nombre AS APP_NOMBRE,
            a.app_tipo   AS APP_TIPO,
            a.app_origen AS APP_ORIGEN,

            /* Sin fila para esta planta rige el valor por defecto: es lo que
               la app hace hoy, y es lo que el interruptor tiene que mostrar. */
            CAP_HABILITADO = ISNULL(cai.cai_habilitado, a.app_por_defecto)

    FROM    [dbo].[App] a
    LEFT JOIN [dbo].[Cliente_App_Instalacion] cai
           ON cai.cai_id_app = a.app_id
          AND cai.cai_id_instalacion = @ID_INSTALACION

    WHERE   a.app_habilitado = 1

      /* El plan manda. Una funcionalidad que el cliente no compro no se
         ofrece: el interruptor daria a entender que basta prenderlo.
         app_funcionalidad en NULL significa "no depende del plan".

         PERO: sin suscripcion no se filtra nada. Es la misma regla del
         bloque 47 -"sin plan no hay tope que hacer cumplir"-. Un cliente que
         se esta configurando todavia no compro; no es que haya comprado
         cero. Tratarlo al reves deja la pantalla en blanco justo cuando
         alguien la esta armando, y sin ninguna pista de por que. */
      AND   ( a.app_funcionalidad IS NULL
              OR @CLIENTE IS NULL
              OR NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion]
                              WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1)
              OR [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD](
                     @CLIENTE,
                     (SELECT fun_codigo FROM [dbo].[Funcionalidad] WHERE fun_id = a.app_funcionalidad)
                 ) = 1 )

    ORDER BY a.app_tipo, a.app_orden

RETURN(0)
GO


/* ========================================================================
   4. UNA SOLA FILA POR PLANTA Y FUNCIONALIDAD

      INS_CLIENTE_APP_INSTALACION ya hace upsert -busca la fila antes de
      decidir-, asi que hoy no duplica. La restriccion es para que tampoco
      pueda duplicar manana desde otra ruta: dos filas para la misma planta y
      la misma funcionalidad dejarian el interruptor dependiendo de cual lea
      primero el LEFT JOIN, que es la clase de error que aparece en
      produccion y no se reproduce nunca.
   ======================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CAI_Instalacion_App')
    ALTER TABLE [dbo].[Cliente_App_Instalacion]
    ADD CONSTRAINT UQ_CAI_Instalacion_App UNIQUE (cai_id_instalacion, cai_id_app)
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'funcionalidades de app cargadas' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[App]) AS HAY, 6 AS ESPERADO
UNION ALL
SELECT  'todas apuntan a una funcionalidad de plan',
        (SELECT COUNT(*) FROM [dbo].[App] WHERE app_funcionalidad IS NOT NULL), 6
UNION ALL
SELECT  'todas dicen de que historia salen',
        (SELECT COUNT(*) FROM [dbo].[App] WHERE app_origen IS NOT NULL), 6
UNION ALL
SELECT  'FK contra Funcionalidad',
        (SELECT COUNT(*) FROM sys.foreign_keys WHERE name = 'FK_App_Funcionalidad'), 1
UNION ALL
SELECT  'una fila por planta y funcionalidad',
        (SELECT COUNT(*) FROM sys.indexes WHERE name = 'UQ_CAI_Instalacion_App'), 1
GO

SELECT PRUEBA = 'lo que ve la planta 1 (Hamburgo no tiene plan: se ofrece todo)'
EXEC [dbo].[SEL_CLIENTE_APP_INSTALACION] @ID_INSTALACION = 1
GO
