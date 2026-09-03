/* ============================================================================
   SIGMA — Bloque 111
   LOS PROCEDIMIENTOS DEL CENTRO DE ACCION OPERACIONAL
   ----------------------------------------------------------------------------

   EL ORDEN NO ES POR FECHA NI POR GRAVEDAD SOLA

     Una critica que ya tiene a alguien encima es menos urgente que una
     critica que no tiene a nadie: la primera ya se esta resolviendo, la
     segunda no la ha visto nadie. Por eso el orden combina las dos cosas:

       1. Criticas SIN responsable
       2. Criticas en gestion
       3. Altas
       4. Advertencias
       5. Informativas

     Se calcula en el SP y no en la pantalla porque la web y la app tienen
     que priorizar igual. Si cada una lo ordenara por su cuenta, dos personas
     mirando lo mismo verian arriba cosas distintas.

   LEER NO ES RECONOCER, Y NINGUNA DE LAS DOS ES RESOLVER

     Son tres cosas y viven en tres lugares:

       - Leer      -> `Alerta_Lectura`, una fila por persona. Abrir la alerta
                      la marca leida y NO le cambia el estado.
       - Reconocer -> `ale_alerta_estado` = RECONOCIDA. Es explicito: alguien
                      dice "me hago cargo". La alerta SIGUE ABIERTA.
       - Resolver  -> `ale_alerta_estado` = RESUELTA, con fecha, usuario y
                      observacion.

     UPD_ALERTA_ESTADO nunca toca `Alerta_Lectura`, y UPD_ALERTA_LEER nunca
     toca el estado. Esa separacion es la razon de que exista este bloque.

   LOS ESTADOS TERMINALES NO SE PISAN

     Resolver algo ya resuelto, o descartar algo ya cerrado, se rechaza con un
     mensaje en vez de sobrescribir en silencio la fecha y el usuario del
     cierre original. Dos personas apretando el mismo boton a la vez es un
     caso normal, no un caso raro.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. SEL_ALERTA — la cola de la bandeja

      Reemplaza la version del bloque 83 conservando TODAS sus columnas: la
      app movil y el panel de la campana ya las leen por nombre. Lo que se
      agrega va al final.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ALERTA]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA]
    @CLIENTE            INT,
    @USUARIO            INT,
    @SOLO_ABIERTAS      BIT = 1,
    @TOPE               INT = 50,
    @GRUPO              VARCHAR(20) = NULL,   /* ACTIVAS · GESTION · RESUELTAS */
    @SEVERIDAD          VARCHAR(50) = NULL,
    @TIPO               VARCHAR(100) = NULL,
    @SIN_RESPONSABLE    BIT = NULL,
    @FILTRO             VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT  TOP (@TOPE)
            a.ale_id,
            a.ale_titulo,
            ISNULL(a.ale_descripcion, '')      AS ale_descripcion,
            a.ale_fecha_deteccion_utc,
            t.alt_codigo,
            t.alt_nombre,
            ISNULL(t.alt_icono, 'mdi mdi-bell-outline')  AS alt_icono,
            ISNULL(t.alt_menu_link, '')        AS alt_menu_link,
            ISNULL(t.alt_ficha_link, '')       AS FICHA_LINK,

            CASE t.alt_ficha_id_columna
                 WHEN 'ale_repuesto'       THEN a.ale_repuesto
                 WHEN 'ale_bodega'         THEN a.ale_bodega
                 WHEN 'ale_repuesto_lote'  THEN a.ale_repuesto_lote
                 WHEN 'ale_activo'         THEN a.ale_activo
                 WHEN 'ale_orden_trabajo'  THEN a.ale_orden_trabajo
                 ELSE NULL
            END                                AS FICHA_ID,

            e.aet_codigo,
            e.aet_nombre,
            ISNULL(s.sev_codigo, 'NORMAL')     AS sev_codigo,
            ISNULL(s.sev_nombre, 'Normal')     AS sev_nombre,
            a.ale_repuesto, a.ale_bodega, a.ale_repuesto_lote,
            a.ale_valor_observado, a.ale_valor_umbral,

            CASE WHEN l.alr_id IS NULL THEN 0 ELSE 1 END AS LEIDA,
            DATEDIFF(MINUTE, a.ale_fecha_deteccion_utc, GETUTCDATE()) AS MINUTOS,

            /* ---- lo que agrega el Centro de Accion Operacional ---- */

            a.ale_usuario_responsable,
            ISNULL(ur.usu_nombre + ' ' + ur.usu_apellido_paterno, '') AS RESPONSABLE_NOMBRE,
            a.ale_cliente_instalacion,
            ISNULL(ci.cin_nombre, '')          AS INSTALACION_NOMBRE,
            a.ale_activo,
            ISNULL(ac.act_codigo, '')          AS ACTIVO_CODIGO,
            ISNULL(ac.act_nombre, '')          AS ACTIVO_NOMBRE,
            ISNULL(rp.rep_codigo, '')          AS REPUESTO_CODIGO,
            ISNULL(bo.bod_nombre, '')          AS BODEGA_NOMBRE,
            a.ale_ocurrencias,
            a.ale_fecha_primera_ocurrencia_utc,
            a.ale_fecha_ultima_ocurrencia_utc,

            /* Alerta nacida del modelo predictivo. La pantalla la marca con
               el distintivo de SIGMA AI y solo a ella: rotular como IA una
               alerta de stock bajo el minimo -que es una resta- seria
               atribuirle al modelo un trabajo que no hizo. */
            CAST(CASE WHEN t.alt_codigo = 'PREDICCION RIESGO' AND a.ale_prediccion IS NOT NULL
                      THEN 1 ELSE 0 END AS BIT) AS ES_PREDICCION,
            a.ale_prediccion,

            /* El grupo con el que la pantalla arma sus pestañas. */
            CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 'RESUELTAS'
                 WHEN e.aet_codigo = 'EN GESTION' THEN 'GESTION'
                 ELSE 'ACTIVAS' END            AS GRUPO,

            /* La prioridad de la cola. Una critica sin responsable va antes
               que una critica que ya tiene a alguien encima: la segunda se
               esta resolviendo, la primera no la ha visto nadie. */
            CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 9
                 WHEN ISNULL(s.sev_id, 1) = 5 AND a.ale_usuario_responsable IS NULL THEN 1
                 WHEN ISNULL(s.sev_id, 1) = 5 THEN 2
                 WHEN ISNULL(s.sev_id, 1) = 4 THEN 3
                 WHEN ISNULL(s.sev_id, 1) = 3 THEN 4
                 ELSE 5 END                    AS ORDEN_PRIORIDAD

    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    LEFT JOIN [dbo].[Severidad] s   ON s.sev_id = a.ale_severidad
    LEFT JOIN [dbo].[Alerta_Lectura] l ON l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO
    LEFT JOIN [dbo].[Usuario] ur    ON ur.usu_id = a.ale_usuario_responsable
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = a.ale_cliente_instalacion
    LEFT JOIN [dbo].[Activo] ac     ON ac.act_id = a.ale_activo
    LEFT JOIN [dbo].[Repuesto] rp   ON rp.rep_id = a.ale_repuesto
    LEFT JOIN [dbo].[Bodega] bo     ON bo.bod_id = a.ale_bodega
    WHERE   a.ale_cliente = @CLIENTE
      AND   a.ale_habilitado = 1
      AND   (@SOLO_ABIERTAS = 0 OR e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA'))
      /* El permiso del TIPO decide quien ve la alerta. Se valida aca y no en
         la pantalla: la app consume el mismo SP. */
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
      AND   (@GRUPO IS NULL
             OR (@GRUPO = 'ACTIVAS'   AND e.aet_codigo IN ('NUEVA', 'RECONOCIDA', 'EN GESTION'))
             OR (@GRUPO = 'GESTION'   AND e.aet_codigo = 'EN GESTION')
             OR (@GRUPO = 'RESUELTAS' AND e.aet_codigo IN ('RESUELTA', 'DESCARTADA')))
      AND   (@SEVERIDAD IS NULL OR s.sev_codigo = @SEVERIDAD)
      AND   (@TIPO IS NULL OR t.alt_codigo = @TIPO)
      AND   (@SIN_RESPONSABLE IS NULL
             OR (@SIN_RESPONSABLE = 1 AND a.ale_usuario_responsable IS NULL)
             OR (@SIN_RESPONSABLE = 0 AND a.ale_usuario_responsable IS NOT NULL))
      AND   (@FILTRO IS NULL
             OR a.ale_titulo      LIKE '%' + @FILTRO + '%'
             OR a.ale_descripcion LIKE '%' + @FILTRO + '%'
             OR ac.act_codigo     LIKE '%' + @FILTRO + '%'
             OR ac.act_nombre     LIKE '%' + @FILTRO + '%'
             OR rp.rep_codigo     LIKE '%' + @FILTRO + '%')

    ORDER BY CASE WHEN e.aet_codigo IN ('RESUELTA', 'DESCARTADA') THEN 9
                  WHEN ISNULL(s.sev_id, 1) = 5 AND a.ale_usuario_responsable IS NULL THEN 1
                  WHEN ISNULL(s.sev_id, 1) = 5 THEN 2
                  WHEN ISNULL(s.sev_id, 1) = 4 THEN 3
                  WHEN ISNULL(s.sev_id, 1) = 3 THEN 4
                  ELSE 5 END,
             a.ale_fecha_deteccion_utc DESC,
             a.ale_id DESC
GO

PRINT '--- SEL_ALERTA actualizado.'
GO


/* ========================================================================
   2. SEL_ALERTA_RESUMEN — los cinco indicadores y la campana

      La campana cuenta ALERTAS ACTIVAS -nueva, reconocida, en gestion-, no
      las no leidas. Un jefe que abrio las doce alertas de la mañana y no
      resolvio ninguna tenia la campana en cero con la planta igual de mal.
      NO_LEIDAS se sigue devolviendo, como indicador secundario.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA_RESUMEN') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ALERTA_RESUMEN]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA_RESUMEN]
    @CLIENTE    INT,
    @USUARIO    INT
AS
SET NOCOUNT ON

/* Variable de tabla y no un CTE: un CTE solo alcanza a la sentencia que va
   inmediatamente despues, y aca hacen falta DOS resultados -los indicadores y
   el desglose por menu- sobre el mismo conjunto. Con un CTE el segundo
   SELECT no lo encuentra. */
DECLARE @VISIBLES TABLE (
    ale_id                  INT,
    ale_usuario_responsable INT,
    ale_prediccion          INT,
    aet_codigo              NVARCHAR(100),
    alt_codigo              NVARCHAR(100),
    alt_menu_link           NVARCHAR(800),
    sev_codigo              NVARCHAR(50),
    LEIDA                   BIT)

INSERT INTO @VISIBLES
    SELECT  a.ale_id,
            a.ale_usuario_responsable,
            a.ale_prediccion,
            e.aet_codigo,
            t.alt_codigo,
            t.alt_menu_link,
            ISNULL(s.sev_codigo, 'NORMAL'),
            CASE WHEN l.alr_id IS NULL THEN 0 ELSE 1 END
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    LEFT JOIN [dbo].[Severidad] s   ON s.sev_id = a.ale_severidad
    LEFT JOIN [dbo].[Alerta_Lectura] l ON l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO
    WHERE   a.ale_cliente = @CLIENTE
      AND   a.ale_habilitado = 1
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)

    SELECT
        ABIERTAS      = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION') THEN 1 ELSE 0 END),
        NO_LEIDAS     = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION') AND LEIDA = 0 THEN 1 ELSE 0 END),
        CRITICAS      = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION') AND sev_codigo = 'CRITICA' THEN 1 ELSE 0 END),
        EN_GESTION    = SUM(CASE WHEN aet_codigo = 'EN GESTION' THEN 1 ELSE 0 END),
        SIN_RESPONSABLE = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION')
                                    AND ale_usuario_responsable IS NULL THEN 1 ELSE 0 END),
        /* Solo las que REALMENTE salieron del modelo: tipo PREDICCION RIESGO
           y con su fila en Prediccion. Contar aca cualquier alerta seria
           atribuirle a SIGMA AI trabajo que no hizo. */
        PREDICCIONES  = SUM(CASE WHEN aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION')
                                  AND alt_codigo = 'PREDICCION RIESGO'
                                  AND ale_prediccion IS NOT NULL THEN 1 ELSE 0 END)
    FROM @VISIBLES

    /* Segundo resultado: cuantas por pantalla, para el punto del menu
       lateral.

       LOS NOMBRES DE COLUMNA SE CONSERVAN -MENU_LINK y ABIERTAS-. El
       AlertaController los lee asi, y su catch se traga cualquier fallo para
       que un contador no tumbe la cabecera: renombrarlos no habria dado
       error, habria dejado los badges del menu en blanco sin decir nada. */
    SELECT  MENU_LINK = alt_menu_link,
            ABIERTAS  = COUNT(*)
    FROM    @VISIBLES
    WHERE   aet_codigo IN ('NUEVA','RECONOCIDA','EN GESTION')
      AND   alt_menu_link IS NOT NULL
    GROUP BY alt_menu_link
GO

PRINT '--- SEL_ALERTA_RESUMEN actualizado.'
GO


/* ========================================================================
   3. UPD_ALERTA_ESTADO — reconocer, gestionar, resolver, descartar

      NUNCA toca Alerta_Lectura. Leer y reconocer son cosas distintas y esa
      separacion es lo que impide que abrir la bandeja resuelva la planta.
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_ALERTA_ESTADO') IS NOT NULL DROP PROCEDURE [dbo].[UPD_ALERTA_ESTADO]
GO

CREATE PROCEDURE [dbo].[UPD_ALERTA_ESTADO]
    @ALERTA         INT,
    @CLIENTE        INT,
    @USUARIO        INT,
    @ESTADO         VARCHAR(50),          /* RECONOCIDA · EN GESTION · RESUELTA · DESCARTADA */
    @MOTIVO         NVARCHAR(1000) = NULL,
    @RESPONSABLE    INT = NULL
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @DESDE INT, @DESDE_COD VARCHAR(50), @HASTA INT, @PERMISO VARCHAR(100)

SELECT  @DESDE = a.ale_alerta_estado,
        @DESDE_COD = e.aet_codigo,
        @PERMISO = pm.prm_codigo
  FROM  [dbo].[Alerta] a
  JOIN  [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
  JOIN  [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
  LEFT JOIN [dbo].[Permiso] pm  ON pm.prm_id = t.alt_permiso
 WHERE  a.ale_id = @ALERTA AND a.ale_cliente = @CLIENTE AND a.ale_habilitado = 1

IF (@DESDE IS NULL)
BEGIN
    RAISERROR('1.- LA ALERTA NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* El permiso se valida en el SERVIDOR. Esconder el boton no es seguridad:
   quien manda el postback a mano se lo salta. */
IF (@PERMISO IS NOT NULL
    AND [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, @PERMISO) = 0)
BEGIN
    RAISERROR('2.- NO TIENE PERMISO SOBRE ESTE TIPO DE ALERTA.', 16, 1)
    RETURN -1
END

SELECT @HASTA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = @ESTADO

IF (@HASTA IS NULL)
BEGIN
    RAISERROR('3.- EL ESTADO "%s" NO EXISTE.', 16, 1, @ESTADO)
    RETURN -1
END

/* Un estado terminal no se pisa. Resolver algo ya resuelto sobrescribiria en
   silencio la fecha y el usuario del cierre original, y dos personas
   apretando el mismo boton a la vez es un caso normal. */
IF (@DESDE_COD IN ('RESUELTA', 'DESCARTADA'))
BEGIN
    RAISERROR('4.- LA ALERTA YA ESTA CERRADA COMO "%s".', 16, 1, @DESDE_COD)
    RETURN -1
END

IF (@DESDE_COD = @ESTADO)
BEGIN
    RAISERROR('5.- LA ALERTA YA ESTA EN ESE ESTADO.', 16, 1)
    RETURN -1
END

/* Descartar sin decir por que deja una alerta cerrada que nadie puede
   explicar despues. El motivo es obligatorio y con contenido. */
IF (@ESTADO = 'DESCARTADA' AND (@MOTIVO IS NULL OR LEN(LTRIM(RTRIM(@MOTIVO))) < 5))
BEGIN
    RAISERROR('6.- INDIQUE EL MOTIVO DEL DESCARTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Alerta]
       SET ale_alerta_estado = @HASTA,

           /* Reconocer deja constancia de QUIEN se hizo cargo y cuando. Si
              no venia responsable, se asume que quien reconoce la toma: es
              lo que significa el boton. */
           ale_fecha_reconocimiento_utc =
               CASE WHEN @ESTADO = 'RECONOCIDA' AND ale_fecha_reconocimiento_utc IS NULL
                    THEN @AHORA ELSE ale_fecha_reconocimiento_utc END,
           ale_usuario_reconocimiento =
               CASE WHEN @ESTADO = 'RECONOCIDA' AND ale_usuario_reconocimiento IS NULL
                    THEN @USUARIO ELSE ale_usuario_reconocimiento END,

           ale_fecha_gestion_utc =
               CASE WHEN @ESTADO = 'EN GESTION' AND ale_fecha_gestion_utc IS NULL
                    THEN @AHORA ELSE ale_fecha_gestion_utc END,

           /* El cierre. ale_usuario_atencion / ale_fecha_atencion_utc ya
              existian con ese significado desde el bloque 19, y hay un CHECK
              que impide poner la fecha sin el usuario. */
           ale_usuario_atencion =
               CASE WHEN @ESTADO IN ('RESUELTA', 'DESCARTADA') THEN @USUARIO
                    ELSE ale_usuario_atencion END,
           ale_fecha_atencion_utc =
               CASE WHEN @ESTADO IN ('RESUELTA', 'DESCARTADA') THEN @AHORA
                    ELSE ale_fecha_atencion_utc END,

           ale_motivo_resolucion =
               CASE WHEN @ESTADO = 'RESUELTA' THEN @MOTIVO ELSE ale_motivo_resolucion END,
           ale_motivo_descarte =
               CASE WHEN @ESTADO = 'DESCARTADA' THEN @MOTIVO ELSE ale_motivo_descarte END,

           ale_usuario_responsable =
               CASE WHEN @RESPONSABLE IS NOT NULL THEN @RESPONSABLE
                    WHEN @ESTADO IN ('RECONOCIDA', 'EN GESTION') AND ale_usuario_responsable IS NULL
                    THEN @USUARIO
                    ELSE ale_usuario_responsable END,

           ale_usuario_actualizacion = @USUARIO,
           ale_fecha_actualizacion   = @AHORA
     WHERE ale_id = @ALERTA AND ale_cliente = @CLIENTE

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('7.- NO FUE POSIBLE ACTUALIZAR LA ALERTA.', 16, 1)
        RETURN -1
    END

    INSERT INTO [dbo].[Alerta_Historial]
        (ahi_alerta, ahi_estado_desde, ahi_estado_hasta, ahi_usuario,
         ahi_fecha_utc, ahi_motivo, ahi_usuario_responsable)
    SELECT @ALERTA, @DESDE, @HASTA, @USUARIO, @AHORA, @MOTIVO, ale_usuario_responsable
      FROM [dbo].[Alerta] WHERE ale_id = @ALERTA

COMMIT TRANSACTION

SELECT @ALERTA AS ID, 200 AS CODE,
       CASE @ESTADO
            WHEN 'RECONOCIDA' THEN 'Alerta tomada.'
            WHEN 'EN GESTION' THEN 'Alerta en gestión.'
            WHEN 'RESUELTA'   THEN 'Alerta resuelta.'
            WHEN 'DESCARTADA' THEN 'Alerta descartada.'
            ELSE 'Alerta actualizada.' END AS MENSAJE
GO

PRINT '--- UPD_ALERTA_ESTADO creado.'
GO


/* ========================================================================
   4. UPD_ALERTA_RESPONSABLE — asignar sin cambiar el estado
   ======================================================================== */
IF OBJECT_ID('dbo.UPD_ALERTA_RESPONSABLE') IS NOT NULL DROP PROCEDURE [dbo].[UPD_ALERTA_RESPONSABLE]
GO

CREATE PROCEDURE [dbo].[UPD_ALERTA_RESPONSABLE]
    @ALERTA         INT,
    @CLIENTE        INT,
    @USUARIO        INT,
    @RESPONSABLE    INT
AS
SET NOCOUNT ON
SET XACT_ABORT ON

DECLARE @AHORA DATETIME = GETUTCDATE(), @ESTADO INT

SELECT @ESTADO = ale_alerta_estado FROM [dbo].[Alerta]
 WHERE ale_id = @ALERTA AND ale_cliente = @CLIENTE AND ale_habilitado = 1

IF (@ESTADO IS NULL)
BEGIN
    RAISERROR('1.- LA ALERTA NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* El responsable tiene que pertenecer al cliente. Sin esto se puede asignar
   una alerta a alguien de otra empresa, que ademas no la veria nunca. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario]
                WHERE ucl_id_cliente = @CLIENTE
                  AND ucl_id_usuario = @RESPONSABLE
                  AND ucl_habilitado = 1)
BEGIN
    RAISERROR('2.- EL RESPONSABLE NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE [dbo].[Alerta]
       SET ale_usuario_responsable   = @RESPONSABLE,
           ale_usuario_actualizacion = @USUARIO,
           ale_fecha_actualizacion   = @AHORA
     WHERE ale_id = @ALERTA AND ale_cliente = @CLIENTE

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('3.- NO FUE POSIBLE ASIGNAR EL RESPONSABLE.', 16, 1)
        RETURN -1
    END

    /* Asignar es un hecho del ciclo de vida aunque el estado no cambie: sin
       esta fila no se puede responder "¿desde cuando es de Marcela?". */
    INSERT INTO [dbo].[Alerta_Historial]
        (ahi_alerta, ahi_estado_desde, ahi_estado_hasta, ahi_usuario,
         ahi_fecha_utc, ahi_motivo, ahi_usuario_responsable)
    VALUES (@ALERTA, @ESTADO, @ESTADO, @USUARIO, @AHORA,
            'Responsable asignado', @RESPONSABLE)

COMMIT TRANSACTION

SELECT @ALERTA AS ID, 200 AS CODE, 'Responsable asignado.' AS MENSAJE
GO

PRINT '--- UPD_ALERTA_RESPONSABLE creado.'
GO


/* ========================================================================
   5. SEL_ALERTA_HISTORIAL — la linea de tiempo del detalle
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA_HISTORIAL') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ALERTA_HISTORIAL]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA_HISTORIAL]
    @ALERTA     INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] WHERE ale_id = @ALERTA AND ale_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA ALERTA NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

    /* La deteccion no esta en el historial -no la hizo una persona- pero es
       el primer punto de la linea de tiempo. Se antepone aca para que la
       pantalla no tenga que armar el primer hito por su cuenta. */
    SELECT  ORDEN = 0,
            FECHA = a.ale_fecha_primera_ocurrencia_utc,
            ESTADO_DESDE = '',
            ESTADO_HASTA = 'Detectada',
            USUARIO = 'SIGMA',
            MOTIVO = CASE WHEN a.ale_ocurrencias > 1
                          THEN 'La condición se repitió ' + CAST(a.ale_ocurrencias AS VARCHAR(10)) + ' veces'
                          ELSE '' END,
            RESPONSABLE = ''
    FROM    [dbo].[Alerta] a
    WHERE   a.ale_id = @ALERTA

    UNION ALL

    SELECT  ORDEN = h.ahi_id,
            FECHA = h.ahi_fecha_utc,
            ESTADO_DESDE = ISNULL(ed.aet_nombre, ''),
            ESTADO_HASTA = eh.aet_nombre,
            USUARIO = ISNULL(u.usu_nombre + ' ' + u.usu_apellido_paterno, ''),
            MOTIVO = ISNULL(h.ahi_motivo, ''),
            RESPONSABLE = ISNULL(ur.usu_nombre + ' ' + ur.usu_apellido_paterno, '')
    FROM    [dbo].[Alerta_Historial] h
    JOIN    [dbo].[Alerta_Estado] eh ON eh.aet_id = h.ahi_estado_hasta
    LEFT JOIN [dbo].[Alerta_Estado] ed ON ed.aet_id = h.ahi_estado_desde
    LEFT JOIN [dbo].[Usuario] u  ON u.usu_id = h.ahi_usuario
    LEFT JOIN [dbo].[Usuario] ur ON ur.usu_id = h.ahi_usuario_responsable
    WHERE   h.ahi_alerta = @ALERTA

    ORDER BY ORDEN
GO

PRINT '--- SEL_ALERTA_HISTORIAL creado.'
GO


/* ========================================================================
   6. SEL_ALERTA_PREDICCION — el panel de SIGMA AI

      Devuelve NADA cuando la alerta no nacio del modelo. La pantalla esconde
      el panel entero en ese caso: mostrar "probabilidad de falla: no
      disponible" en una alerta de stock es ruido que ademas sugiere que el
      modelo opino y no lo hizo.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_ALERTA_PREDICCION') IS NOT NULL DROP PROCEDURE [dbo].[SEL_ALERTA_PREDICCION]
GO

CREATE PROCEDURE [dbo].[SEL_ALERTA_PREDICCION]
    @ALERTA     INT,
    @CLIENTE    INT
AS
SET NOCOUNT ON

    SELECT  p.pre_id,
            p.pre_probabilidad,
            p.pre_dia_restante,
            p.pre_confianza,
            p.pre_valor,
            p.pre_intervalo_inferior,
            p.pre_intervalo_superior,
            p.pre_fecha_calculo_utc,
            p.pre_fecha_evento_estimada_utc,
            ISNULL(mp.mpr_nombre, '')          AS MODELO_NOMBRE,
            ISNULL(CAST(mv.mpv_numero AS VARCHAR(10)), '') AS MODELO_VERSION,
            ISNULL(s.sev_codigo, '')           AS sev_codigo,
            ISNULL(ac.act_codigo, '')          AS ACTIVO_CODIGO,
            ISNULL(ac.act_nombre, '')          AS ACTIVO_NOMBRE
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Prediccion] p ON p.pre_id = a.ale_prediccion
    LEFT JOIN [dbo].[Modelo_Predictivo_Version] mv ON mv.mpv_id = p.pre_modelo_predictivo_version
    LEFT JOIN [dbo].[Modelo_Predictivo] mp ON mp.mpr_id = mv.mpv_modelo_predictivo
    LEFT JOIN [dbo].[Severidad] s ON s.sev_id = p.pre_severidad
    LEFT JOIN [dbo].[Activo] ac ON ac.act_id = p.pre_activo
    WHERE   a.ale_id = @ALERTA AND a.ale_cliente = @CLIENTE

    /* Los factores principales: que empujo la prediccion y cuanto. */
    SELECT  ex.pex_orden,
            ex.pex_texto,
            ex.pex_contribucion,
            ex.pex_direccion,
            ex.pex_valor_observado,
            ex.pex_valor_referencia
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Prediccion_Explicacion] ex ON ex.pex_prediccion = a.ale_prediccion
    WHERE   a.ale_id = @ALERTA AND a.ale_cliente = @CLIENTE
    ORDER BY ISNULL(ex.pex_orden, 999), ex.pex_id
GO

PRINT '--- SEL_ALERTA_PREDICCION creado.'
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */
EXEC [dbo].[SEL_ALERTA_RESUMEN] @CLIENTE = 1, @USUARIO = 1
GO

EXEC [dbo].[SEL_ALERTA] @CLIENTE = 1, @USUARIO = 1, @TOPE = 5
GO

PRINT '111_ALERTA_BANDEJA_SP aplicado.'
GO
