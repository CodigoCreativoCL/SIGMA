USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  06-10-2026
-- DESCRIPTION:     MODULO SOPORTE: audiencia, tickets, trazabilidad,
--                  encuesta, problemas recurrentes y analitica de la mesa.
-- =============================================
-- Va DESPUES de 359_SOPORTE_ESQUEMA. El cupo de tickets lo define el bloque
-- 365 (funcionalidad SOPORTE TICKETS); sin ella nadie fuera de soporte crea.
--
-- LA AUTORIZACION VIVE ACA, NO EN LA PANTALLA
--   Cada SP recibe @USUARIO y decide: el agente (SOPORTE GESTIONAR) ve todo;
--   quien reporto ve SU ticket y nunca las notas internas. La pantalla solo
--   esconde botones.
-- =============================================

SET NOCOUNT ON
GO


/* ========================================================================
   1. FUNCIONES
   ======================================================================== */

/* ¿Es del equipo de soporte? Root o un perfil de plataforma con SOPORTE
   GESTIONAR. Se pasa cliente 0: lo que viene del cliente no cuenta. */
CREATE OR ALTER FUNCTION [dbo].[FNC_SOPORTE_ES_AGENTE] (@USUARIO INT)
RETURNS BIT
AS
BEGIN
    RETURN [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, 0, NULL, N'SOPORTE GESTIONAR')
END
GO

CREATE OR ALTER FUNCTION [dbo].[FNC_SOPORTE_PUEDE] (@USUARIO INT, @PERMISO NVARCHAR(50))
RETURNS BIT
AS
BEGIN
    RETURN [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, 0, NULL, @PERMISO)
END
GO

CREATE OR ALTER FUNCTION [dbo].[FNC_SOPORTE_NOMBRE] (@USUARIO INT)
RETURNS NVARCHAR(200)
AS
BEGIN
    RETURN (SELECT LTRIM(RTRIM(ISNULL(usu_nombre, '') + ' ' + ISNULL(usu_apellido_paterno, ''))) COLLATE DATABASE_DEFAULT
              FROM [dbo].[Usuario] WHERE usu_id = @USUARIO)
END
GO

/* Duracion legible: «2 h 15 min», «3 d 4 h», «12 min». */
CREATE OR ALTER FUNCTION [dbo].[FNC_SOPORTE_DURACION] (@MIN INT)
RETURNS NVARCHAR(40)
AS
BEGIN
    IF @MIN IS NULL RETURN NULL
    IF @MIN < 0 SET @MIN = -@MIN
    IF @MIN >= 2880 RETURN CAST(@MIN / 1440 AS NVARCHAR(10)) + N' d ' + CAST((@MIN % 1440) / 60 AS NVARCHAR(10)) + N' h'
    IF @MIN >= 60   RETURN CAST(@MIN / 60 AS NVARCHAR(10)) + N' h ' + RIGHT('0' + CAST(@MIN % 60 AS NVARCHAR(10)), 2) + N' min'
    RETURN CAST(@MIN AS NVARCHAR(10)) + N' min'
END
GO

/* LA AUDIENCIA: quienes cumplen las condiciones.
   Condiciones en JSON: [{"campo":"perfil","op":"=","valor":"Bodeguero"}, ...]
   Union AND (todas) u OR (cualquiera). @USUARIO acota a una persona: es lo
   que usa la entrega de campanas en cada pagina, para no recorrer a todos.
   Campos: estado (Activo/Inactivo), cliente, planta, perfil, usuario (id). */
CREATE OR ALTER FUNCTION [dbo].[FNC_CAMPANA_AUDIENCIA]
(
    @CONDICIONES NVARCHAR(MAX),
    @UNION       VARCHAR(3),
    @USUARIO     INT
)
RETURNS @R TABLE (usuario INT NOT NULL, cliente INT NOT NULL, PRIMARY KEY (usuario, cliente))
AS
BEGIN
    DECLARE @B TABLE (usuario INT NOT NULL, cliente INT NOT NULL, ucl INT NOT NULL, activo BIT NOT NULL,
                      PRIMARY KEY (usuario, cliente))

    INSERT INTO @B (usuario, cliente, ucl, activo)
    SELECT  u.usu_id, cu.ucl_id_cliente, MIN(cu.ucl_id),
            CAST(MAX(CASE WHEN ISNULL(u.usu_habilitado, 0) = 1 AND ISNULL(cu.ucl_habilitado, 0) = 1 THEN 1 ELSE 0 END) AS BIT)
    FROM    [dbo].[Cliente_Usuario] cu
    JOIN    [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
    WHERE   (@USUARIO IS NULL OR u.usu_id = @USUARIO)
    GROUP BY u.usu_id, cu.ucl_id_cliente

    DECLARE @C TABLE (i INT NOT NULL, campo VARCHAR(20), op VARCHAR(2), valor NVARCHAR(200))

    IF ISJSON(@CONDICIONES) = 1
        INSERT INTO @C (i, campo, op, valor)
        SELECT  CAST([key] AS INT),
                JSON_VALUE(value, '$.campo'),
                ISNULL(JSON_VALUE(value, '$.op'), '='),
                JSON_VALUE(value, '$.valor')
        FROM    OPENJSON(@CONDICIONES)

    DECLARE @N INT = (SELECT COUNT(*) FROM @C)

    IF @N = 0
    BEGIN
        INSERT INTO @R SELECT usuario, cliente FROM @B
        RETURN
    END

    DECLARE @H TABLE (i INT, usuario INT, cliente INT)

    INSERT INTO @H (i, usuario, cliente)
    SELECT  c.i, b.usuario, b.cliente
    FROM    @C c
    CROSS JOIN @B b
    WHERE   (CASE c.campo
                WHEN 'estado'  THEN CASE WHEN (c.valor = N'Activo' AND b.activo = 1) OR (c.valor = N'Inactivo' AND b.activo = 0) THEN 1 ELSE 0 END
                WHEN 'cliente' THEN CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Cliente] cl
                                                       WHERE cl.cli_id = b.cliente
                                                         AND cl.cli_nombre COLLATE DATABASE_DEFAULT = c.valor COLLATE DATABASE_DEFAULT) THEN 1 ELSE 0 END
                WHEN 'perfil'  THEN CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario_Perfil] cup
                                                        JOIN [dbo].[Perfiles] pe ON pe.per_id = cup.cup_id_perfil
                                                       WHERE cup.cup_id_cliente_usuario = b.ucl
                                                         AND pe.per_nombre COLLATE DATABASE_DEFAULT = c.valor COLLATE DATABASE_DEFAULT) THEN 1 ELSE 0 END
                WHEN 'planta'  THEN CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                                                        JOIN [dbo].[Cliente_Instalacion] cin ON cin.cin_id = ciu.ciu_id_instalacion
                                                       WHERE ciu.ciu_id_usuario = b.usuario
                                                         AND cin.cin_cliente = b.cliente
                                                         AND ISNULL(ciu.ciu_habilitado, 0) = 1
                                                         AND cin.cin_nombre COLLATE DATABASE_DEFAULT = c.valor COLLATE DATABASE_DEFAULT) THEN 1 ELSE 0 END
                WHEN 'usuario' THEN CASE WHEN b.usuario = TRY_CAST(c.valor AS INT) THEN 1 ELSE 0 END
                ELSE 0 END)
          = CASE WHEN c.op = '!=' THEN 0 ELSE 1 END

    INSERT INTO @R (usuario, cliente)
    SELECT  usuario, cliente
    FROM    @H
    GROUP BY usuario, cliente
    HAVING  COUNT(DISTINCT i) >= CASE WHEN @UNION = 'OR' THEN 1 ELSE @N END

    RETURN
END
GO


/* ========================================================================
   2. LA VISTA DEL TICKET (con el SLA ya calculado)
   ======================================================================== */

CREATE OR ALTER VIEW [dbo].[V_SOPORTE_TICKET]
AS
SELECT  t.stk_id, t.stk_folio, t.stk_cliente, t.stk_cliente_instalacion, t.stk_usuario, t.stk_titulo,
        t.stk_categoria, t.stk_prioridad, t.stk_estado, t.stk_responsable, t.stk_area,
        t.stk_modulo, t.stk_submodulo, t.stk_pantalla, t.stk_seccion, t.stk_ruta, t.stk_registro, t.stk_perfil,
        t.stk_recurrente, t.stk_fecha_creacion, t.stk_fecha_actualizacion, t.stk_fecha_resolucion, t.stk_fecha_cierre,
        t.stk_fecha_primera_respuesta, t.stk_fecha_pausa,
        es.ses_nombre, es.ses_tono, es.ses_abierto,
        pr.spr_nombre, pr.spr_horas_sla, pr.spr_barras,
        ca.sca_nombre, ca.sca_icono,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) COLLATE DATABASE_DEFAULT AS USUARIO_NOMBRE,
        LTRIM(RTRIM(ISNULL(r.usu_nombre, '') + ' ' + ISNULL(r.usu_apellido_paterno, ''))) COLLATE DATABASE_DEFAULT AS RESPONSABLE_NOMBRE,
        ISNULL(ar.sar_nombre, N'Mesa de Ayuda') AS AREA_NOMBRE,
        cl.cli_nombre COLLATE DATABASE_DEFAULT AS CLIENTE_NOMBRE,
        ISNULL(ci.cin_nombre, N'') COLLATE DATABASE_DEFAULT AS PLANTA_NOMBRE,
        pr.spr_horas_sla * 60 AS SLA_TOTAL_MIN,
        /* El reloj corre desde que se creo, se detiene al resolver o mientras
           espera al usuario, y descuenta lo que ya estuvo en pausa. */
        DATEDIFF(MINUTE, t.stk_fecha_creacion,
                 COALESCE(t.stk_fecha_resolucion, t.stk_fecha_pausa, [dbo].[FNC_AHORA]())) - t.stk_sla_pausa_min AS SLA_USADO_MIN
FROM    [dbo].[Soporte_Ticket] t
JOIN    [dbo].[Soporte_Estado]    es ON es.ses_codigo = t.stk_estado
JOIN    [dbo].[Soporte_Prioridad] pr ON pr.spr_codigo = t.stk_prioridad
JOIN    [dbo].[Soporte_Categoria] ca ON ca.sca_codigo = t.stk_categoria
JOIN    [dbo].[Usuario]           u  ON u.usu_id = t.stk_usuario
JOIN    [dbo].[Cliente]           cl ON cl.cli_id = t.stk_cliente
LEFT JOIN [dbo].[Usuario]         r  ON r.usu_id = t.stk_responsable
LEFT JOIN [dbo].[Soporte_Area]    ar ON ar.sar_id = t.stk_area
LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = t.stk_cliente_instalacion
WHERE   t.stk_habilitado = 1
GO


/* ========================================================================
   3. AVISOS POR LA CAMPANA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SOPORTE_AVISO]
    @TICKET       INT,
    @DESTINATARIO INT,
    @TIPO         NVARCHAR(100),
    @TITULO       NVARCHAR(400),
    @DESCRIPCION  NVARCHAR(1000),
    @USUARIO      INT
AS
SET NOCOUNT ON
    IF @DESTINATARIO IS NULL OR @DESTINATARIO = @USUARIO RETURN

    DECLARE @TIPO_ID INT = (SELECT alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = @TIPO)
    IF @TIPO_ID IS NULL RETURN

    INSERT INTO [dbo].[Alerta] (ale_cliente, ale_cliente_instalacion, ale_alerta_tipo, ale_alerta_estado, ale_titulo,
                                ale_descripcion, ale_usuario_destinatario, ale_soporte_ticket, ale_usuario_creacion,
                                ale_fecha_primera_ocurrencia_utc, ale_fecha_ultima_ocurrencia_utc)
    SELECT  t.stk_cliente, t.stk_cliente_instalacion, @TIPO_ID,
            (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'),
            LEFT(@TITULO, 400), @DESCRIPCION, @DESTINATARIO, @TICKET, ISNULL(@USUARIO, 1),
            GETUTCDATE(), GETUTCDATE()
    FROM    [dbo].[Soporte_Ticket] t
    WHERE   t.stk_id = @TICKET
GO


/* ========================================================================
   4. CAMBIO DE ESTADO (lo usan todos los SP que mueven el ticket)
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOPORTE_TICKET_MOVER]
    @TICKET     INT,
    @HASTA      VARCHAR(5),
    @USUARIO    INT,          -- NULL = lo hizo SIGMA
    @ES_SOPORTE BIT
AS
SET NOCOUNT ON
    DECLARE @DESDE VARCHAR(5), @AHORA DATETIME = [dbo].[FNC_AHORA]()
    SELECT @DESDE = stk_estado FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET
    IF @DESDE IS NULL OR @DESDE = @HASTA RETURN

    UPDATE [dbo].[Soporte_Ticket]
       SET stk_estado = @HASTA,
           /* Sale de la espera: lo que estuvo pausado se descuenta. */
           stk_sla_pausa_min = stk_sla_pausa_min
                             + CASE WHEN @DESDE = 'esp' AND stk_fecha_pausa IS NOT NULL THEN DATEDIFF(MINUTE, stk_fecha_pausa, @AHORA) ELSE 0 END
                             /* Se reabre: el tiempo que estuvo resuelto tampoco cuenta. */
                             + CASE WHEN @DESDE IN ('res','cer') AND @HASTA NOT IN ('res','cer') AND stk_fecha_resolucion IS NOT NULL
                                    THEN DATEDIFF(MINUTE, stk_fecha_resolucion, @AHORA) ELSE 0 END,
           stk_fecha_pausa = CASE WHEN @HASTA = 'esp' THEN @AHORA ELSE NULL END,
           stk_fecha_resolucion = CASE WHEN @HASTA = 'res' THEN @AHORA
                                       WHEN @HASTA = 'cer' THEN ISNULL(stk_fecha_resolucion, @AHORA)
                                       ELSE NULL END,
           stk_fecha_cierre = CASE WHEN @HASTA = 'cer' THEN @AHORA ELSE NULL END,
           stk_usuario_actualizacion = @USUARIO,
           stk_fecha_actualizacion = @AHORA
     WHERE stk_id = @TICKET

    INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_estado_desde, ste_estado_hasta, ste_fecha)
    VALUES (@TICKET, 'st', @USUARIO, ISNULL(@ES_SOPORTE, 0), @DESDE, @HASTA, @AHORA)
GO


/* ========================================================================
   5. PROBLEMAS RECURRENTES
   ======================================================================== */

/* Cinco o mas tickets en 30 dias de la misma pantalla y categoria forman un
   problema recurrente. Si ya existe, el ticket nuevo se suma. */
CREATE OR ALTER PROCEDURE [dbo].[UPS_SOPORTE_RECURRENTE]
    @TICKET INT
AS
SET NOCOUNT ON
    DECLARE @MOD NVARCHAR(150), @PANT NVARCHAR(150), @CAT VARCHAR(10), @SUB NVARCHAR(150), @SEC NVARCHAR(150), @R INT
    SELECT @MOD = stk_modulo, @SUB = stk_submodulo, @PANT = stk_pantalla, @SEC = stk_seccion, @CAT = stk_categoria
      FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET
    IF @PANT IS NULL OR @MOD IS NULL RETURN

    SELECT @R = sre_id FROM [dbo].[Soporte_Recurrente]
     WHERE sre_habilitado = 1 AND sre_modulo = @MOD AND sre_pantalla = @PANT AND sre_categoria = @CAT

    IF @R IS NULL
    BEGIN
        DECLARE @DESDE DATETIME = DATEADD(DAY, -30, [dbo].[FNC_AHORA]())
        IF (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket]
             WHERE stk_habilitado = 1 AND stk_modulo = @MOD AND stk_pantalla = @PANT AND stk_categoria = @CAT
               AND stk_fecha_creacion >= @DESDE) < 5
            RETURN

        /* El titulo es el que mas se repite entre ellos. */
        INSERT INTO [dbo].[Soporte_Recurrente] (sre_titulo, sre_modulo, sre_submodulo, sre_pantalla, sre_seccion, sre_categoria)
        SELECT TOP 1 stk_titulo, @MOD, @SUB, @PANT, @SEC, @CAT
          FROM [dbo].[Soporte_Ticket]
         WHERE stk_habilitado = 1 AND stk_modulo = @MOD AND stk_pantalla = @PANT AND stk_categoria = @CAT
         GROUP BY stk_titulo
         ORDER BY COUNT(*) DESC, MIN(stk_id)
        SET @R = SCOPE_IDENTITY()

        UPDATE [dbo].[Soporte_Ticket] SET stk_recurrente = @R
         WHERE stk_habilitado = 1 AND stk_recurrente IS NULL
           AND stk_modulo = @MOD AND stk_pantalla = @PANT AND stk_categoria = @CAT
           AND stk_fecha_creacion >= @DESDE
    END
    ELSE
        UPDATE [dbo].[Soporte_Ticket] SET stk_recurrente = @R WHERE stk_id = @TICKET AND stk_recurrente IS NULL
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_RECURRENTES]
    @USUARIO INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0 AND [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'SOPORTE ANALITICA') = 0
    BEGIN RAISERROR(N'No tienes acceso a la mesa de ayuda.', 16, 1) RETURN END

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    SELECT  r.sre_id, r.sre_titulo, r.sre_modulo, r.sre_submodulo, r.sre_pantalla, r.sre_seccion, r.sre_categoria,
            r.sre_causa, r.sre_contenido, c.ayc_titulo AS CONTENIDO_TITULO, c.ayc_tipo AS CONTENIDO_TIPO,
            N30 = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id AND t.stk_fecha_creacion >= DATEADD(DAY, -30, @AHORA)),
            NPREV = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id
                       AND t.stk_fecha_creacion >= DATEADD(DAY, -60, @AHORA) AND t.stk_fecha_creacion < DATEADD(DAY, -30, @AHORA)),
            NTOTAL = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id),
            /* Reportes por semana, las ultimas 12, separados por coma. */
            SERIE = (SELECT STRING_AGG(CAST(x.n AS VARCHAR(10)), ',') WITHIN GROUP (ORDER BY x.s DESC)
                       FROM (SELECT s.s, n = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t
                                              WHERE t.stk_recurrente = r.sre_id
                                                AND t.stk_fecha_creacion >= DATEADD(WEEK, -(s.s + 1), @AHORA)
                                                AND t.stk_fecha_creacion <  DATEADD(WEEK, -s.s, @AHORA))
                               FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11)) s (s)) x)
    FROM    [dbo].[Soporte_Recurrente] r
    LEFT JOIN [dbo].[Ayuda_Contenido] c ON c.ayc_id = r.sre_contenido AND c.ayc_habilitado = 1
    WHERE   r.sre_habilitado = 1
    ORDER BY N30 DESC, NTOTAL DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_RECURRENTE]
    @ID      INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0 AND [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'SOPORTE ANALITICA') = 0
    BEGIN RAISERROR(N'No tienes acceso a la mesa de ayuda.', 16, 1) RETURN END

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    SELECT  r.*, c.ayc_titulo AS CONTENIDO_TITULO,
            N30   = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id AND t.stk_fecha_creacion >= DATEADD(DAY, -30, @AHORA)),
            NPREV = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id
                       AND t.stk_fecha_creacion >= DATEADD(DAY, -60, @AHORA) AND t.stk_fecha_creacion < DATEADD(DAY, -30, @AHORA)),
            USUARIOS = (SELECT COUNT(DISTINCT t.stk_usuario) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id),
            CLIENTES = (SELECT COUNT(DISTINCT t.stk_cliente) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id),
            HORAS = (SELECT ISNULL(SUM(DATEDIFF(MINUTE, t.stk_fecha_creacion, ISNULL(t.stk_fecha_resolucion, @AHORA))), 0) / 60
                       FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id)
    FROM    [dbo].[Soporte_Recurrente] r
    LEFT JOIN [dbo].[Ayuda_Contenido] c ON c.ayc_id = r.sre_contenido
    WHERE   r.sre_id = @ID

    SELECT  s.s AS SEMANA,
            N = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t
                  WHERE t.stk_recurrente = @ID
                    AND t.stk_fecha_creacion >= DATEADD(WEEK, -(s.s + 1), @AHORA)
                    AND t.stk_fecha_creacion <  DATEADD(WEEK, -s.s, @AHORA))
    FROM    (VALUES (11),(10),(9),(8),(7),(6),(5),(4),(3),(2),(1),(0)) s (s)

    SELECT TOP 5 v.CLIENTE_NOMBRE + CASE WHEN v.PLANTA_NOMBRE <> '' THEN N' · ' + v.PLANTA_NOMBRE ELSE N'' END AS ETIQUETA, COUNT(*) AS N
    FROM    [dbo].[V_SOPORTE_TICKET] v
    WHERE   v.stk_recurrente = @ID
    GROUP BY v.CLIENTE_NOMBRE, v.PLANTA_NOMBRE
    ORDER BY COUNT(*) DESC

    SELECT TOP 30 v.stk_id, v.stk_folio, v.stk_titulo, v.stk_estado, v.ses_nombre, v.ses_tono, v.stk_usuario, v.USUARIO_NOMBRE,
            v.CLIENTE_NOMBRE, v.stk_fecha_actualizacion
    FROM    [dbo].[V_SOPORTE_TICKET] v
    WHERE   v.stk_recurrente = @ID
    ORDER BY v.stk_fecha_creacion DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOPORTE_RECURRENTE]
    @ID        INT,
    @CAUSA     NVARCHAR(500),
    @CONTENIDO INT,
    @USUARIO   INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'Solo el equipo de soporte puede editar un problema recurrente.', 16, 1) RETURN END

    UPDATE [dbo].[Soporte_Recurrente]
       SET sre_causa = ISNULL(NULLIF(LTRIM(RTRIM(@CAUSA)), ''), sre_causa),
           sre_contenido = ISNULL(@CONTENIDO, sre_contenido),
           sre_fecha_actualizacion = [dbo].[FNC_AHORA]()
     WHERE sre_id = @ID
    SELECT @@ROWCOUNT AS FILAS
GO


/* ========================================================================
   6. CREAR UN TICKET
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SOPORTE_TICKET]
    @CLIENTE          INT,
    @INSTALACION      INT = NULL,
    @USUARIO          INT,            -- quien tiene el problema
    @USUARIO_CREACION INT,            -- quien lo registro (soporte puede hacerlo por otro)
    @TITULO           NVARCHAR(200),
    @DESCRIPCION      NVARCHAR(MAX) = NULL,
    @CATEGORIA        VARCHAR(10),
    @PRIORIDAD        CHAR(1),
    @MODULO           NVARCHAR(150) = NULL,
    @SUBMODULO        NVARCHAR(150) = NULL,
    @PANTALLA         NVARCHAR(150) = NULL,
    @SECCION          NVARCHAR(150) = NULL,
    @RUTA             NVARCHAR(400) = NULL,
    @REGISTRO         NVARCHAR(200) = NULL,
    @NAVEGADOR        NVARCHAR(200) = NULL,
    @SUGERIDO         INT = NULL,     -- ayuda que se le mostro antes de reportar
    @SUGERIDO_VISTO   BIT = 0
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    SET @TITULO = LTRIM(RTRIM(ISNULL(@TITULO, '')))
    IF @TITULO = '' BEGIN RAISERROR(N'Escribe un título para el problema.', 16, 1) RETURN END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Categoria] WHERE sca_codigo = @CATEGORIA)
    BEGIN RAISERROR(N'Elige una categoría.', 16, 1) RETURN END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Prioridad] WHERE spr_codigo = @PRIORIDAD)
    BEGIN RAISERROR(N'Elige cuánto te afecta.', 16, 1) RETURN END
    IF [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO_CREACION, @CLIENTE, NULL, N'SOPORTE REPORTAR') = 0
    BEGIN RAISERROR(N'No tienes permiso para reportar problemas.', 16, 1) RETURN END

    DECLARE @AGENTE BIT = [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO_CREACION)

    /* La atencion por tickets es del PLAN del cliente y tiene cupo mensual
       (bloque 365, funcionalidad SOPORTE TICKETS). El equipo de soporte
       puede registrar igual: es quien decide atender fuera del plan. */
    IF @AGENTE = 0
    BEGIN
        IF [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD](@CLIENTE, N'SOPORTE TICKETS') = 0
        BEGIN RAISERROR(N'El plan de tu empresa no incluye atención por tickets. Busca tu respuesta en el centro de ayuda o habla con tu administrador.', 16, 1) RETURN END
        DECLARE @TOPE DECIMAL(18,2) = [dbo].[FNC_CLIENTE_LIMITE](@CLIENTE, N'SOPORTE TICKETS')
        IF @TOPE IS NOT NULL AND [dbo].[FNC_CLIENTE_CONSUMO](@CLIENTE, N'SOPORTE TICKETS') >= @TOPE
        BEGIN
            DECLARE @TOPE_I INT = CAST(@TOPE AS INT)
            RAISERROR(N'Tu empresa ya usó los %d tickets de soporte de este mes. El cupo se renueva el día 1.', 16, 1, @TOPE_I) RETURN
        END
    END

    IF @USUARIO <> @USUARIO_CREACION
    BEGIN
        IF @AGENTE = 0 BEGIN RAISERROR(N'Solo soporte puede registrar un problema en nombre de otra persona.', 16, 1) RETURN END
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] WHERE ucl_id_usuario = @USUARIO AND ucl_id_cliente = @CLIENTE)
        BEGIN RAISERROR(N'Esa persona no pertenece al cliente.', 16, 1) RETURN END
    END

    IF @INSTALACION IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion] WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE)
        SET @INSTALACION = NULL

    DECLARE @PERFIL NVARCHAR(200) = (
        SELECT STRING_AGG(CAST(pe.per_nombre AS NVARCHAR(200)), ', ')
          FROM [dbo].[Cliente_Usuario] cu
          JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
          JOIN [dbo].[Perfiles] pe ON pe.per_id = cup.cup_id_perfil
         WHERE cu.ucl_id_usuario = @USUARIO AND cu.ucl_id_cliente = @CLIENTE)
    IF @PERFIL IS NULL
        SET @PERFIL = (SELECT TOP 1 pe.per_nombre FROM [dbo].[Usuario_Perfil] up
                         JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil AND pe.per_tipo = 1
                        WHERE up.upe_usuario = @USUARIO)

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @ID INT
    DECLARE @AREA INT = (SELECT TOP 1 sar_id FROM [dbo].[Soporte_Area] WHERE sar_nombre = N'Mesa de Ayuda')

    BEGIN TRAN
        INSERT INTO [dbo].[Soporte_Ticket] (stk_cliente, stk_cliente_instalacion, stk_usuario, stk_titulo, stk_descripcion,
                                            stk_categoria, stk_prioridad, stk_estado, stk_area, stk_modulo, stk_submodulo,
                                            stk_pantalla, stk_seccion, stk_ruta, stk_registro, stk_navegador, stk_perfil,
                                            stk_contenido_sugerido, stk_usuario_creacion, stk_fecha_creacion, stk_fecha_actualizacion)
        VALUES (@CLIENTE, @INSTALACION, @USUARIO, LEFT(@TITULO, 200), NULLIF(LTRIM(RTRIM(@DESCRIPCION)), ''),
                @CATEGORIA, @PRIORIDAD, 'rep', @AREA, @MODULO, @SUBMODULO, @PANTALLA, @SECCION, @RUTA,
                NULLIF(LTRIM(RTRIM(@REGISTRO)), ''), @NAVEGADOR, @PERFIL, @SUGERIDO, @USUARIO_CREACION, @AHORA, @AHORA)
        SET @ID = SCOPE_IDENTITY()

        INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_texto, ste_fecha)
        VALUES (@ID, 'rep', @USUARIO, @TITULO, @AHORA)

        IF @USUARIO <> @USUARIO_CREACION
            INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_texto, ste_fecha)
            VALUES (@ID, 'sys', @USUARIO_CREACION, 1,
                    [dbo].[FNC_SOPORTE_NOMBRE](@USUARIO_CREACION) + N' lo registró en nombre de ' + [dbo].[FNC_SOPORTE_NOMBRE](@USUARIO) + N'.', @AHORA)

        /* La sugerencia previa queda en la trazabilidad: si siguio con el
           reporte, la ayuda no le resolvio el problema. */
        IF @SUGERIDO IS NOT NULL
            INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_texto, ste_contenido, ste_fecha)
            SELECT @ID, 'sys', NULL,
                   N'Se sugirió «' + c.ayc_titulo + N'»' + CASE WHEN @SUGERIDO_VISTO = 1 THEN N'; el usuario la abrió' ELSE N'' END
                   + N' y continuó con el reporte: la ayuda no resolvió el problema.', c.ayc_id, @AHORA
              FROM [dbo].[Ayuda_Contenido] c WHERE c.ayc_id = @SUGERIDO

        EXEC [dbo].[UPS_SOPORTE_RECURRENTE] @ID
    COMMIT

    SELECT stk_id, stk_folio FROM [dbo].[Soporte_Ticket] WHERE stk_id = @ID
GO


/* ========================================================================
   7. RESPONDER, PEDIR INFORMACION, NOTA INTERNA, ADJUNTAR
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SOPORTE_EVENTO]
    @TICKET          INT,
    @USUARIO         INT,
    @TIPO            VARCHAR(5),          -- com · req · int · file
    @TEXTO           NVARCHAR(MAX) = NULL,
    @CONTENIDO       INT = NULL,
    @ARCHIVO         INT = NULL,
    @ARCHIVO_NOMBRE  NVARCHAR(260) = NULL,
    @ARCHIVO_BYTE    BIGINT = NULL
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    DECLARE @DUENO INT, @ESTADO VARCHAR(5), @RESP INT, @FOLIO VARCHAR(20), @TIT NVARCHAR(200)
    SELECT @DUENO = stk_usuario, @ESTADO = stk_estado, @RESP = stk_responsable, @FOLIO = stk_folio, @TIT = stk_titulo
      FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET AND stk_habilitado = 1
    IF @DUENO IS NULL BEGIN RAISERROR(N'El problema no existe.', 16, 1) RETURN END

    DECLARE @AGENTE BIT = [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO)
    /* Si quien escribe es el que reporto, habla como usuario aunque tenga el
       permiso de soporte (alguien del equipo reportando su propio problema). */
    DECLARE @COMO_SOPORTE BIT = CASE WHEN @AGENTE = 1 AND @USUARIO <> @DUENO THEN 1 ELSE 0 END

    IF @AGENTE = 0 AND @USUARIO <> @DUENO BEGIN RAISERROR(N'No puedes responder este problema.', 16, 1) RETURN END
    IF @TIPO NOT IN ('com','req','int','file') BEGIN RAISERROR(N'Tipo de mensaje no válido.', 16, 1) RETURN END
    IF @COMO_SOPORTE = 0 AND @TIPO IN ('req','int') BEGIN RAISERROR(N'Solo soporte puede pedir información o dejar notas internas.', 16, 1) RETURN END
    IF @ESTADO = 'cer' BEGIN RAISERROR(N'El problema está cerrado. Si vuelve a ocurrir, repórtalo de nuevo.', 16, 1) RETURN END
    SET @TEXTO = NULLIF(LTRIM(RTRIM(@TEXTO)), '')
    IF @TIPO IN ('com','req','int') AND @TEXTO IS NULL BEGIN RAISERROR(N'Escribe el mensaje.', 16, 1) RETURN END
    IF @TIPO = 'file' AND @ARCHIVO IS NULL BEGIN RAISERROR(N'Falta el archivo.', 16, 1) RETURN END

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    BEGIN TRAN
        INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_interno, ste_texto,
                                                   ste_contenido, ste_archivo, ste_archivo_nombre, ste_archivo_byte, ste_fecha)
        VALUES (@TICKET, @TIPO, @USUARIO, @COMO_SOPORTE, CASE WHEN @TIPO = 'int' THEN 1 ELSE 0 END,
                ISNULL(@TEXTO, CASE WHEN @TIPO = 'file' THEN N'Adjuntó un archivo.' END),
                @CONTENIDO, @ARCHIVO, @ARCHIVO_NOMBRE, @ARCHIVO_BYTE, @AHORA)

        UPDATE [dbo].[Soporte_Ticket]
           SET stk_fecha_actualizacion = @AHORA, stk_usuario_actualizacion = @USUARIO,
               stk_fecha_primera_respuesta = CASE WHEN @COMO_SOPORTE = 1 AND @TIPO IN ('com','req') AND stk_fecha_primera_respuesta IS NULL
                                                  THEN @AHORA ELSE stk_fecha_primera_respuesta END
         WHERE stk_id = @TICKET

        IF @COMO_SOPORTE = 1 AND @TIPO = 'req'
        BEGIN
            IF @ESTADO <> 'esp' EXEC [dbo].[UPD_SOPORTE_TICKET_MOVER] @TICKET, 'esp', @USUARIO, 1
            DECLARE @T1 NVARCHAR(400) = [dbo].[FNC_SOPORTE_NOMBRE](@USUARIO) + N' te pidió más información'
            DECLARE @D1 NVARCHAR(1000) = @FOLIO + N' · ' + @TIT
            EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @DUENO, N'SOPORTE INFORMACION', @T1, @D1, @USUARIO
        END
        ELSE IF @COMO_SOPORTE = 1 AND @TIPO = 'com'
        BEGIN
            DECLARE @T2 NVARCHAR(400) = [dbo].[FNC_SOPORTE_NOMBRE](@USUARIO) + N' respondió tu problema'
            DECLARE @D2 NVARCHAR(1000) = @FOLIO + N' · «' + LEFT(@TEXTO, 140) + N'»'
            EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @DUENO, N'SOPORTE RESPUESTA', @T2, @D2, @USUARIO
        END
        ELSE IF @COMO_SOPORTE = 0
        BEGIN
            /* Respondio el usuario: si se le estaba esperando, el reloj vuelve
               a correr y el ticket vuelve a analisis. */
            IF @ESTADO = 'esp' EXEC [dbo].[UPD_SOPORTE_TICKET_MOVER] @TICKET, 'ana', NULL, 0
            DECLARE @T3 NVARCHAR(400) = [dbo].[FNC_SOPORTE_NOMBRE](@USUARIO) + N' respondió'
            DECLARE @D3 NVARCHAR(1000) = @FOLIO + N' · ' + ISNULL(N'«' + LEFT(@TEXTO, 140) + N'»', N'Adjuntó un archivo')
            EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @RESP, N'SOPORTE COMENTARIO', @T3, @D3, @USUARIO
        END
    COMMIT

    SELECT @TICKET AS stk_id
GO


/* ========================================================================
   8. ESTADO, ASIGNACION Y PRIORIDAD (solo soporte)
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOPORTE_TICKET_ESTADO]
    @TICKET  INT,
    @USUARIO INT,
    @ESTADO  VARCHAR(5),
    @NOTA    NVARCHAR(MAX) = NULL
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'Solo el equipo de soporte puede cambiar el estado.', 16, 1) RETURN END
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Estado] WHERE ses_codigo = @ESTADO)
    BEGIN RAISERROR(N'Estado no válido.', 16, 1) RETURN END

    DECLARE @DUENO INT, @DESDE VARCHAR(5), @FOLIO VARCHAR(20), @TIT NVARCHAR(200)
    SELECT @DUENO = stk_usuario, @DESDE = stk_estado, @FOLIO = stk_folio, @TIT = stk_titulo
      FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET AND stk_habilitado = 1
    IF @DUENO IS NULL BEGIN RAISERROR(N'El problema no existe.', 16, 1) RETURN END
    IF @DESDE = @ESTADO BEGIN SELECT @TICKET AS stk_id RETURN END

    SET @NOTA = NULLIF(LTRIM(RTRIM(@NOTA)), '')
    IF @ESTADO = 'res' AND @NOTA IS NULL
    BEGIN RAISERROR(N'Cuéntale al usuario qué se hizo para resolverlo.', 16, 1) RETURN END

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    DECLARE @NOMBRE NVARCHAR(60) = (SELECT ses_nombre FROM [dbo].[Soporte_Estado] WHERE ses_codigo = @ESTADO)

    BEGIN TRAN
        EXEC [dbo].[UPD_SOPORTE_TICKET_MOVER] @TICKET, @ESTADO, @USUARIO, 1

        IF @ESTADO = 'res'
        BEGIN
            INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_texto, ste_fecha)
            VALUES (@TICKET, 'res', @USUARIO, 1, @NOTA, @AHORA)
            INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_texto, ste_fecha)
            VALUES (@TICKET, 'sys', NULL, N'Se envió la encuesta «¿Tu problema fue solucionado?» al usuario.', @AHORA)
            UPDATE [dbo].[Soporte_Ticket]
               SET stk_fecha_primera_respuesta = ISNULL(stk_fecha_primera_respuesta, @AHORA)
             WHERE stk_id = @TICKET

            DECLARE @T1 NVARCHAR(400) = N'Resolvimos ' + @FOLIO + N'. ¿Se solucionó?'
            DECLARE @D1 NVARCHAR(1000) = @TIT + N' · Cuéntanos con una encuesta de 10 segundos'
            EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @DUENO, N'SOPORTE RESUELTO', @T1, @D1, @USUARIO
        END
        ELSE
        BEGIN
            IF @NOTA IS NOT NULL
                INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_texto, ste_fecha)
                VALUES (@TICKET, 'sys', @USUARIO, 1, @NOTA, @AHORA)

            DECLARE @T2 NVARCHAR(400) = N'Tu problema pasó a «' + @NOMBRE + N'»'
            DECLARE @D2 NVARCHAR(1000) = @FOLIO + N' · ' + @TIT
            EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @DUENO, N'SOPORTE ESTADO', @T2, @D2, @USUARIO
        END
    COMMIT

    SELECT @TICKET AS stk_id
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOPORTE_TICKET_ASIGNAR]
    @TICKET      INT,
    @USUARIO     INT,
    @RESPONSABLE INT,
    @AREA        INT = NULL
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'Solo el equipo de soporte puede asignar problemas.', 16, 1) RETURN END
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@RESPONSABLE) = 0
    BEGIN RAISERROR(N'Esa persona no es parte del equipo de soporte.', 16, 1) RETURN END

    DECLARE @ESTADO VARCHAR(5), @ANT INT, @FOLIO VARCHAR(20), @TIT NVARCHAR(200), @PRIO NVARCHAR(30)
    SELECT @ESTADO = t.stk_estado, @ANT = t.stk_responsable, @FOLIO = t.stk_folio, @TIT = t.stk_titulo, @PRIO = p.spr_nombre
      FROM [dbo].[Soporte_Ticket] t JOIN [dbo].[Soporte_Prioridad] p ON p.spr_codigo = t.stk_prioridad
     WHERE t.stk_id = @TICKET AND t.stk_habilitado = 1
    IF @ESTADO IS NULL BEGIN RAISERROR(N'El problema no existe.', 16, 1) RETURN END
    IF @ESTADO = 'cer' BEGIN RAISERROR(N'El problema está cerrado.', 16, 1) RETURN END
    IF @AREA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Area] WHERE sar_id = @AREA) SET @AREA = NULL

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    DECLARE @NOMBRE NVARCHAR(200) = [dbo].[FNC_SOPORTE_NOMBRE](@RESPONSABLE)

    BEGIN TRAN
        UPDATE [dbo].[Soporte_Ticket]
           SET stk_responsable = @RESPONSABLE, stk_area = ISNULL(@AREA, stk_area),
               stk_fecha_actualizacion = @AHORA, stk_usuario_actualizacion = @USUARIO
         WHERE stk_id = @TICKET

        INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_texto, ste_destinatario, ste_fecha)
        VALUES (@TICKET, 'asg', @USUARIO, 1,
                CASE WHEN @ANT IS NULL THEN N'Ticket asignado a ' ELSE N'Ticket reasignado a ' END + @NOMBRE
                + ISNULL(N' · ' + (SELECT sar_nombre FROM [dbo].[Soporte_Area] WHERE sar_id = @AREA), N'') + N'.',
                @RESPONSABLE, @AHORA)

        IF @ESTADO IN ('rep','rev') EXEC [dbo].[UPD_SOPORTE_TICKET_MOVER] @TICKET, 'asg', @USUARIO, 1

        DECLARE @T NVARCHAR(400) = N'Te asignaron ' + @FOLIO
        DECLARE @D NVARCHAR(1000) = @TIT + N' · ' + @PRIO
        EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @RESPONSABLE, N'SOPORTE ASIGNADO', @T, @D, @USUARIO
    COMMIT

    SELECT @TICKET AS stk_id
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOPORTE_TICKET_PRIORIDAD]
    @TICKET    INT,
    @USUARIO   INT,
    @PRIORIDAD CHAR(1)
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'Solo el equipo de soporte puede cambiar la prioridad.', 16, 1) RETURN END

    DECLARE @ANT CHAR(1) = (SELECT stk_prioridad FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET)
    IF @ANT IS NULL OR NOT EXISTS (SELECT 1 FROM [dbo].[Soporte_Prioridad] WHERE spr_codigo = @PRIORIDAD)
    BEGIN RAISERROR(N'Prioridad no válida.', 16, 1) RETURN END
    IF @ANT = @PRIORIDAD BEGIN SELECT @TICKET AS stk_id RETURN END

    UPDATE [dbo].[Soporte_Ticket] SET stk_prioridad = @PRIORIDAD, stk_fecha_actualizacion = [dbo].[FNC_AHORA](), stk_usuario_actualizacion = @USUARIO
     WHERE stk_id = @TICKET
    INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_texto)
    SELECT @TICKET, 'prio', @USUARIO, 1,
           N'Prioridad: ' + (SELECT spr_nombre FROM [dbo].[Soporte_Prioridad] WHERE spr_codigo = @ANT)
           + N' → ' + (SELECT spr_nombre FROM [dbo].[Soporte_Prioridad] WHERE spr_codigo = @PRIORIDAD)
    SELECT @TICKET AS stk_id
GO

CREATE OR ALTER PROCEDURE [dbo].[UPD_SOPORTE_TICKET_VINCULAR]
    @TICKET     INT,
    @USUARIO    INT,
    @RECURRENTE INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'Solo el equipo de soporte puede vincular problemas.', 16, 1) RETURN END

    DECLARE @TIT NVARCHAR(200) = (SELECT sre_titulo FROM [dbo].[Soporte_Recurrente] WHERE sre_id = @RECURRENTE AND sre_habilitado = 1)
    IF @TIT IS NULL BEGIN RAISERROR(N'El problema recurrente no existe.', 16, 1) RETURN END

    UPDATE [dbo].[Soporte_Ticket] SET stk_recurrente = @RECURRENTE, stk_fecha_actualizacion = [dbo].[FNC_AHORA]() WHERE stk_id = @TICKET
    INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_es_soporte, ste_texto)
    VALUES (@TICKET, 'sys', @USUARIO, 1, N'Vinculado al problema recurrente «' + @TIT + N'».')
    SELECT @TICKET AS stk_id
GO


/* ========================================================================
   9. ENCUESTA Y REAPERTURA (solo quien reporto)
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SOPORTE_ENCUESTA]
    @TICKET     INT,
    @USUARIO    INT,
    @RESPUESTA  VARCHAR(10),
    @ESTRELLAS  INT,
    @COMENTARIO NVARCHAR(1000) = NULL,
    @REABRIR    BIT = 0
AS
SET NOCOUNT ON
SET XACT_ABORT ON
    DECLARE @DUENO INT, @ESTADO VARCHAR(5), @RESP INT, @RES DATETIME, @FOLIO VARCHAR(20), @TIT NVARCHAR(200)
    SELECT @DUENO = stk_usuario, @ESTADO = stk_estado, @RESP = stk_responsable, @RES = stk_fecha_resolucion,
           @FOLIO = stk_folio, @TIT = stk_titulo
      FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET AND stk_habilitado = 1
    IF @DUENO IS NULL OR @DUENO <> @USUARIO BEGIN RAISERROR(N'Solo quien reportó el problema puede responder la encuesta.', 16, 1) RETURN END
    IF @ESTADO <> 'res' BEGIN RAISERROR(N'La encuesta se responde cuando el problema está resuelto.', 16, 1) RETURN END
    IF @RESPUESTA NOT IN ('si','parcial','no') BEGIN RAISERROR(N'Cuéntanos si se solucionó.', 16, 1) RETURN END
    IF EXISTS (SELECT 1 FROM [dbo].[Soporte_Encuesta] WHERE sen_ticket = @TICKET AND sen_fecha >= @RES)
    BEGIN RAISERROR(N'Ya respondiste la encuesta de esta resolución.', 16, 1) RETURN END

    IF @ESTRELLAS IS NULL OR @ESTRELLAS NOT BETWEEN 1 AND 5
        SET @ESTRELLAS = CASE @RESPUESTA WHEN 'si' THEN 5 WHEN 'parcial' THEN 3 ELSE 1 END

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()

    BEGIN TRAN
        INSERT INTO [dbo].[Soporte_Encuesta] (sen_ticket, sen_respuesta, sen_estrellas, sen_comentario, sen_responsable, sen_usuario, sen_fecha)
        VALUES (@TICKET, @RESPUESTA, @ESTRELLAS, NULLIF(LTRIM(RTRIM(@COMENTARIO)), ''), @RESP, @USUARIO, @AHORA)

        INSERT INTO [dbo].[Soporte_Ticket_Evento] (ste_ticket, ste_tipo, ste_usuario, ste_texto, ste_fecha)
        VALUES (@TICKET, 'fb', @USUARIO,
                N'Respondió la encuesta: ' + CASE @RESPUESTA WHEN 'si' THEN N'Sí' WHEN 'parcial' THEN N'Parcialmente' ELSE N'No' END
                + N' · ' + REPLICATE(N'★', @ESTRELLAS)
                + ISNULL(N' · «' + NULLIF(LTRIM(RTRIM(@COMENTARIO)), '') + N'»', N''), @AHORA)

        IF @REABRIR = 1
        BEGIN
            EXEC [dbo].[UPD_SOPORTE_TICKET_MOVER] @TICKET, 'rea', @USUARIO, 0
            DECLARE @T NVARCHAR(400) = @FOLIO + N' fue reabierto'
            DECLARE @D NVARCHAR(1000) = N'El usuario respondió «' + CASE @RESPUESTA WHEN 'no' THEN N'No' WHEN 'parcial' THEN N'Parcialmente' ELSE N'Sí' END + N'» en la encuesta · ' + @TIT
            EXEC [dbo].[INS_SOPORTE_AVISO] @TICKET, @RESP, N'SOPORTE REABIERTO', @T, @D, @USUARIO
        END
        ELSE
            EXEC [dbo].[UPD_SOPORTE_TICKET_MOVER] @TICKET, 'cer', NULL, 0
    COMMIT

    SELECT @TICKET AS stk_id
GO


/* ========================================================================
   10. LECTURAS
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_AGENTES]
    @USUARIO INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'No tienes acceso a la mesa de ayuda.', 16, 1) RETURN END

    /* El equipo sale de los datos: quien tenga SOPORTE GESTIONAR por su
       perfil de plataforma (o sea Root). Agregar un perfil al equipo es
       marcarle el permiso; aca no hay ids escritos. */
    SELECT  u.usu_id, LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS NOMBRE,
            PERFIL = (SELECT TOP 1 pe.per_nombre FROM [dbo].[Usuario_Perfil] up JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil
                       WHERE up.upe_usuario = u.usu_id AND pe.per_tipo = 1 ORDER BY pe.per_id),
            AREA = (SELECT TOP 1 a.sar_nombre FROM [dbo].[Soporte_Ticket] t JOIN [dbo].[Soporte_Area] a ON a.sar_id = t.stk_area
                     WHERE t.stk_responsable = u.usu_id ORDER BY t.stk_fecha_actualizacion DESC),
            ABIERTOS = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t JOIN [dbo].[Soporte_Estado] e ON e.ses_codigo = t.stk_estado
                         WHERE t.stk_responsable = u.usu_id AND e.ses_abierto = 1 AND t.stk_habilitado = 1)
    FROM    [dbo].[Usuario] u
    WHERE   ISNULL(u.usu_habilitado, 0) = 1
      AND   EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil AND pe.per_tipo = 1
                     WHERE up.upe_usuario = u.usu_id)
      AND   [dbo].[FNC_SOPORTE_ES_AGENTE](u.usu_id) = 1
    ORDER BY CASE WHEN u.usu_id = @USUARIO THEN 0 ELSE 1 END, NOMBRE

    SELECT sar_id, sar_nombre FROM [dbo].[Soporte_Area] WHERE sar_habilitado = 1 ORDER BY sar_orden
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_BANDEJA]
    @USUARIO   INT,
    @SOLO_MIOS BIT = 0      -- 1: «Mis problemas» (lo que yo reporte)
AS
SET NOCOUNT ON
    DECLARE @AGENTE BIT = [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO)
    IF @AGENTE = 0 SET @SOLO_MIOS = 1
    DECLARE @HACE90 DATETIME = DATEADD(DAY, -90, [dbo].[FNC_AHORA]())

    SELECT  v.stk_id, v.stk_folio, v.stk_titulo, v.stk_categoria, v.sca_nombre, v.sca_icono, v.stk_prioridad, v.spr_nombre, v.spr_barras,
            v.stk_estado, v.ses_nombre, v.ses_tono, v.ses_abierto, v.stk_usuario, v.USUARIO_NOMBRE, v.stk_perfil,
            v.stk_cliente, v.CLIENTE_NOMBRE, v.PLANTA_NOMBRE, v.stk_modulo, v.stk_pantalla, v.stk_registro,
            v.stk_responsable, v.RESPONSABLE_NOMBRE, v.stk_area, v.AREA_NOMBRE, v.stk_recurrente,
            v.stk_fecha_creacion, v.stk_fecha_actualizacion, v.SLA_TOTAL_MIN, v.SLA_USADO_MIN, v.spr_horas_sla,
            ULTIMO_TIPO = (SELECT TOP 1 e.ste_tipo FROM [dbo].[Soporte_Ticket_Evento] e
                            WHERE e.ste_ticket = v.stk_id AND (e.ste_interno = 0 OR @SOLO_MIOS = 0) ORDER BY e.ste_id DESC),
            /* Con novedades: algo que escribio OTRO despues de lo ultimo que
               esta persona abrio. Las notas internas solo cuentan para soporte. */
            NO_LEIDO = CAST(CASE WHEN EXISTS (
                            SELECT 1 FROM [dbo].[Soporte_Ticket_Evento] e
                             WHERE e.ste_ticket = v.stk_id
                               AND ISNULL(e.ste_usuario, 0) <> @USUARIO
                               AND (e.ste_interno = 0 OR @SOLO_MIOS = 0)
                               AND e.ste_tipo <> 'sys'
                               AND e.ste_id > ISNULL((SELECT l.stl_ultimo_evento FROM [dbo].[Soporte_Ticket_Lectura] l
                                                       WHERE l.stl_ticket = v.stk_id AND l.stl_usuario = @USUARIO), 0))
                            THEN 1 ELSE 0 END AS BIT),
            ENCUESTA = (SELECT TOP 1 s.sen_respuesta FROM [dbo].[Soporte_Encuesta] s WHERE s.sen_ticket = v.stk_id ORDER BY s.sen_id DESC)
    FROM    [dbo].[V_SOPORTE_TICKET] v
    WHERE   (@SOLO_MIOS = 0 OR v.stk_usuario = @USUARIO)
      AND   (v.ses_abierto = 1 OR v.stk_estado = 'res' OR v.stk_fecha_actualizacion >= @HACE90)
    ORDER BY v.stk_fecha_actualizacion DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_TICKET_360]
    @TICKET  INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    DECLARE @DUENO INT = (SELECT stk_usuario FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET AND stk_habilitado = 1)
    IF @DUENO IS NULL BEGIN RAISERROR(N'Ese problema no existe.', 16, 1) RETURN END

    DECLARE @AGENTE BIT = [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO)
    IF @AGENTE = 0 AND @DUENO <> @USUARIO BEGIN RAISERROR(N'Ese problema no existe.', 16, 1) RETURN END
    /* Quien reporto ve la vista de usuario aunque sea del equipo. */
    DECLARE @GESTIONA BIT = CASE WHEN @AGENTE = 1 AND @DUENO <> @USUARIO THEN 1 ELSE @AGENTE END
    DECLARE @VE_INTERNO BIT = CASE WHEN @AGENTE = 1 AND @DUENO <> @USUARIO THEN 1 ELSE 0 END

    /* Leido hasta el ultimo evento, y los avisos de la campana de este
       ticket quedan leidos y cerrados para esta persona. */
    DECLARE @ULT INT = (SELECT MAX(ste_id) FROM [dbo].[Soporte_Ticket_Evento] WHERE ste_ticket = @TICKET)
    MERGE [dbo].[Soporte_Ticket_Lectura] AS t
    USING (SELECT @TICKET AS tk, @USUARIO AS us) AS s ON t.stl_ticket = s.tk AND t.stl_usuario = s.us
    WHEN MATCHED THEN UPDATE SET stl_ultimo_evento = ISNULL(@ULT, 0), stl_fecha = [dbo].[FNC_AHORA]()
    WHEN NOT MATCHED THEN INSERT (stl_ticket, stl_usuario, stl_ultimo_evento) VALUES (@TICKET, @USUARIO, ISNULL(@ULT, 0));

    INSERT INTO [dbo].[Alerta_Lectura] (alr_alerta, alr_usuario, alr_fecha)
    SELECT a.ale_id, @USUARIO, [dbo].[FNC_AHORA]()
      FROM [dbo].[Alerta] a
     WHERE a.ale_soporte_ticket = @TICKET AND a.ale_usuario_destinatario = @USUARIO
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Lectura] l WHERE l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO)
    UPDATE [dbo].[Alerta] SET ale_alerta_estado = (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA')
     WHERE ale_soporte_ticket = @TICKET AND ale_usuario_destinatario = @USUARIO
       AND ale_alerta_estado <> (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA')

    /* 1. El ticket */
    SELECT  v.*, t.stk_descripcion, t.stk_navegador, t.stk_contenido_sugerido,
            @GESTIONA AS PUEDE_GESTIONAR, @VE_INTERNO AS VE_INTERNO,
            PRIMERA_RESPUESTA_MIN = DATEDIFF(MINUTE, v.stk_fecha_creacion, v.stk_fecha_primera_respuesta)
    FROM    [dbo].[V_SOPORTE_TICKET] v
    JOIN    [dbo].[Soporte_Ticket] t ON t.stk_id = v.stk_id
    WHERE   v.stk_id = @TICKET

    /* 2. La trazabilidad */
    SELECT  e.ste_id, e.ste_tipo, e.ste_usuario, e.ste_es_soporte, e.ste_interno, e.ste_texto, e.ste_estado_desde, e.ste_estado_hasta,
            e.ste_destinatario, e.ste_contenido, e.ste_archivo, e.ste_archivo_nombre, e.ste_archivo_byte, e.ste_fecha,
            [dbo].[FNC_SOPORTE_NOMBRE](e.ste_usuario) AS AUTOR,
            ed.ses_nombre AS DESDE_NOMBRE, ed.ses_tono AS DESDE_TONO, eh.ses_nombre AS HASTA_NOMBRE, eh.ses_tono AS HASTA_TONO,
            c.ayc_titulo AS CONTENIDO_TITULO, c.ayc_tipo AS CONTENIDO_TIPO, c.ayc_duracion AS CONTENIDO_DURACION
    FROM    [dbo].[Soporte_Ticket_Evento] e
    LEFT JOIN [dbo].[Soporte_Estado] ed ON ed.ses_codigo = e.ste_estado_desde
    LEFT JOIN [dbo].[Soporte_Estado] eh ON eh.ses_codigo = e.ste_estado_hasta
    LEFT JOIN [dbo].[Ayuda_Contenido] c ON c.ayc_id = e.ste_contenido
    WHERE   e.ste_ticket = @TICKET
      AND   (e.ste_interno = 0 OR @VE_INTERNO = 1)
    ORDER BY e.ste_id

    /* 3. La ultima encuesta */
    SELECT TOP 1 s.sen_respuesta, s.sen_estrellas, s.sen_comentario, s.sen_fecha, [dbo].[FNC_SOPORTE_NOMBRE](s.sen_responsable) AS RESPONSABLE
    FROM    [dbo].[Soporte_Encuesta] s WHERE s.sen_ticket = @TICKET ORDER BY s.sen_id DESC

    /* 4. Ayuda relacionada: la del problema recurrente primero, despues lo
       vinculado a la misma pantalla y al mismo modulo. */
    DECLARE @MOD NVARCHAR(150), @PANT NVARCHAR(150), @REC INT
    SELECT @MOD = stk_modulo, @PANT = stk_pantalla, @REC = stk_recurrente FROM [dbo].[Soporte_Ticket] WHERE stk_id = @TICKET
    SELECT TOP 3 c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_duracion, c.ayc_paginas, c.ayc_lectura, c.ayc_formato
    FROM    [dbo].[Ayuda_Contenido] c
    WHERE   c.ayc_habilitado = 1 AND c.ayc_estado = 'Publicado'
      AND   (c.ayc_id = (SELECT sre_contenido FROM [dbo].[Soporte_Recurrente] WHERE sre_id = @REC)
             OR EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE v.acv_contenido = c.ayc_id AND v.acv_modulo = @MOD))
    ORDER BY CASE WHEN c.ayc_id = (SELECT sre_contenido FROM [dbo].[Soporte_Recurrente] WHERE sre_id = @REC) THEN 0
                  WHEN EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Vinculo] v WHERE v.acv_contenido = c.ayc_id AND v.acv_pantalla = @PANT) THEN 1
                  ELSE 2 END,
             (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id) DESC

    /* 5. El problema recurrente */
    SELECT  r.sre_id, r.sre_titulo, r.sre_contenido,
            N = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_recurrente = r.sre_id
                   AND t.stk_fecha_creacion >= DATEADD(DAY, -30, [dbo].[FNC_AHORA]()))
    FROM    [dbo].[Soporte_Recurrente] r WHERE r.sre_id = @REC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_RESUMEN]
    @USUARIO INT
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 0
    BEGIN RAISERROR(N'No tienes acceso a la mesa de ayuda.', 16, 1) RETURN END

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    DECLARE @H30 DATETIME = DATEADD(DAY, -30, @AHORA), @H60 DATETIME = DATEADD(DAY, -60, @AHORA)

    /* 1. Indicadores de la mesa */
    SELECT  ABIERTOS     = SUM(CASE WHEN v.ses_abierto = 1 THEN 1 ELSE 0 END),
            SIN_ASIGNAR  = SUM(CASE WHEN v.ses_abierto = 1 AND v.stk_responsable IS NULL THEN 1 ELSE 0 END),
            CRITICOS     = SUM(CASE WHEN v.ses_abierto = 1 AND v.stk_prioridad IN ('c','a') THEN 1 ELSE 0 END),
            ESPERANDO    = SUM(CASE WHEN v.stk_estado = 'esp' THEN 1 ELSE 0 END),
            MIS_ABIERTOS = SUM(CASE WHEN v.ses_abierto = 1 AND v.stk_responsable = @USUARIO THEN 1 ELSE 0 END),
            VENCIDOS     = SUM(CASE WHEN v.ses_abierto = 1 AND v.SLA_USADO_MIN > v.SLA_TOTAL_MIN THEN 1 ELSE 0 END),
            NUEVOS_HOY   = SUM(CASE WHEN v.stk_fecha_creacion >= CAST(@AHORA AS DATE) THEN 1 ELSE 0 END),
            RESOLUCION_MIN = AVG(CASE WHEN v.stk_fecha_resolucion >= @H30 THEN CAST(v.SLA_USADO_MIN AS FLOAT) END),
            RESOLUCION_PREV_MIN = AVG(CASE WHEN v.stk_fecha_resolucion >= @H60 AND v.stk_fecha_resolucion < @H30 THEN CAST(v.SLA_USADO_MIN AS FLOAT) END),
            CSAT = (SELECT CAST(100.0 * SUM(CASE WHEN s.sen_estrellas >= 4 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS INT)
                      FROM [dbo].[Soporte_Encuesta] s WHERE s.sen_fecha >= @H30),
            ENCUESTAS = (SELECT COUNT(*) FROM [dbo].[Soporte_Encuesta] s WHERE s.sen_fecha >= @H30)
    FROM    [dbo].[V_SOPORTE_TICKET] v

    /* 2. Actividad reciente: el ultimo evento de cada ticket */
    SELECT TOP 6 e.ste_id, e.ste_tipo, e.ste_usuario, e.ste_es_soporte, e.ste_texto, e.ste_fecha,
            [dbo].[FNC_SOPORTE_NOMBRE](e.ste_usuario) AS AUTOR, eh.ses_nombre AS HASTA_NOMBRE, ed.ses_nombre AS DESDE_NOMBRE,
            t.stk_id, t.stk_folio, t.stk_titulo
    FROM    [dbo].[Soporte_Ticket_Evento] e
    JOIN    [dbo].[Soporte_Ticket] t ON t.stk_id = e.ste_ticket AND t.stk_habilitado = 1
    LEFT JOIN [dbo].[Soporte_Estado] eh ON eh.ses_codigo = e.ste_estado_hasta
    LEFT JOIN [dbo].[Soporte_Estado] ed ON ed.ses_codigo = e.ste_estado_desde
    WHERE   e.ste_id = (SELECT MAX(x.ste_id) FROM [dbo].[Soporte_Ticket_Evento] x WHERE x.ste_ticket = e.ste_ticket)
    ORDER BY e.ste_id DESC

    /* 3. Campanas y ayuda, para las tres areas del inicio */
    SELECT  ACTIVAS = SUM(CASE WHEN c.cam_estado = 'activa' THEN 1 ELSE 0 END),
            PROGRAMADAS = SUM(CASE WHEN c.cam_estado = 'programada' THEN 1 ELSE 0 END),
            ALCANCE = SUM(CASE WHEN c.cam_estado = 'activa' THEN c.cam_alcance ELSE 0 END),
            VISTAS = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e JOIN [dbo].[Campana] x ON x.cam_id = e.cen_campana
                       WHERE x.cam_estado = 'activa' AND e.cen_veces > 0),
            INTERACCIONES = (SELECT COUNT(*) FROM [dbo].[Campana_Entrega] e JOIN [dbo].[Campana] x ON x.cam_id = e.cen_campana
                              WHERE x.cam_estado = 'activa' AND e.cen_fecha_interaccion IS NOT NULL)
    FROM    [dbo].[Campana] c WHERE c.cam_habilitado = 1

    SELECT  PUBLICADOS = (SELECT COUNT(*) FROM [dbo].[Ayuda_Contenido] WHERE ayc_habilitado = 1 AND ayc_estado = 'Publicado'),
            VISTAS30   = (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] WHERE avs_tipo = 'vista' AND avs_fecha >= @H30)

    SELECT TOP 1 'top' AS CUAL, c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_fecha_actualizacion,
            (SELECT COUNT(*) FROM [dbo].[Ayuda_Vista] w WHERE w.avs_contenido = c.ayc_id AND w.avs_tipo = 'vista') AS VISTAS
    FROM    [dbo].[Ayuda_Contenido] c WHERE c.ayc_habilitado = 1 AND c.ayc_estado = 'Publicado'
    ORDER BY VISTAS DESC, c.ayc_id DESC

    SELECT TOP 1 'reciente' AS CUAL, c.ayc_id, c.ayc_tipo, c.ayc_titulo, c.ayc_fecha_actualizacion
    FROM    [dbo].[Ayuda_Contenido] c WHERE c.ayc_habilitado = 1 AND c.ayc_estado = 'Publicado'
    ORDER BY c.ayc_fecha_actualizacion DESC
GO

CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_ANALITICA]
    @USUARIO INT,
    @DIAS    INT = 30
AS
SET NOCOUNT ON
    IF [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'SOPORTE ANALITICA') = 0
    BEGIN RAISERROR(N'No tienes acceso a la analítica de soporte.', 16, 1) RETURN END
    IF @DIAS NOT IN (7, 30, 90) SET @DIAS = 30

    DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
    DECLARE @DESDE DATETIME = DATEADD(DAY, -@DIAS, CAST(@AHORA AS DATE)), @PREV DATETIME = DATEADD(DAY, -2 * @DIAS, CAST(@AHORA AS DATE))

    /* 1. Indicadores */
    SELECT  ABIERTOS   = SUM(CASE WHEN v.ses_abierto = 1 THEN 1 ELSE 0 END),
            NUEVOS_HOY = SUM(CASE WHEN v.stk_fecha_creacion >= CAST(@AHORA AS DATE) THEN 1 ELSE 0 END),
            CREADOS    = SUM(CASE WHEN v.stk_fecha_creacion >= @DESDE THEN 1 ELSE 0 END),
            CERRADOS   = SUM(CASE WHEN v.stk_fecha_resolucion >= @DESDE THEN 1 ELSE 0 END),
            PRIMERA_MIN      = AVG(CASE WHEN v.stk_fecha_creacion >= @DESDE AND v.stk_fecha_primera_respuesta IS NOT NULL
                                        THEN CAST(DATEDIFF(MINUTE, v.stk_fecha_creacion, v.stk_fecha_primera_respuesta) AS FLOAT) END),
            PRIMERA_PREV_MIN = AVG(CASE WHEN v.stk_fecha_creacion >= @PREV AND v.stk_fecha_creacion < @DESDE AND v.stk_fecha_primera_respuesta IS NOT NULL
                                        THEN CAST(DATEDIFF(MINUTE, v.stk_fecha_creacion, v.stk_fecha_primera_respuesta) AS FLOAT) END),
            RESOLUCION_MIN      = AVG(CASE WHEN v.stk_fecha_resolucion >= @DESDE THEN CAST(v.SLA_USADO_MIN AS FLOAT) END),
            RESOLUCION_PREV_MIN = AVG(CASE WHEN v.stk_fecha_resolucion >= @PREV AND v.stk_fecha_resolucion < @DESDE THEN CAST(v.SLA_USADO_MIN AS FLOAT) END),
            SLA_OK    = SUM(CASE WHEN v.stk_fecha_resolucion >= @DESDE AND v.SLA_USADO_MIN <= v.SLA_TOTAL_MIN THEN 1 ELSE 0 END),
            SLA_RESUELTOS = SUM(CASE WHEN v.stk_fecha_resolucion >= @DESDE THEN 1 ELSE 0 END),
            SLA_VENCIDOS  = SUM(CASE WHEN (v.ses_abierto = 1 OR v.stk_fecha_resolucion >= @DESDE) AND v.SLA_USADO_MIN > v.SLA_TOTAL_MIN THEN 1 ELSE 0 END),
            CSAT = (SELECT CAST(100.0 * SUM(CASE WHEN s.sen_estrellas >= 4 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS INT)
                      FROM [dbo].[Soporte_Encuesta] s WHERE s.sen_fecha >= @DESDE),
            ENCUESTAS = (SELECT COUNT(*) FROM [dbo].[Soporte_Encuesta] s WHERE s.sen_fecha >= @DESDE),
            REABIERTOS = (SELECT COUNT(DISTINCT e.ste_ticket) FROM [dbo].[Soporte_Ticket_Evento] e
                           WHERE e.ste_tipo = 'st' AND e.ste_estado_hasta = 'rea' AND e.ste_fecha >= @DESDE)
    FROM    [dbo].[V_SOPORTE_TICKET] v

    /* 2. Creados y resueltos por dia */
    ;WITH D AS (SELECT TOP (@DIAS) DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - @DIAS, CAST(@AHORA AS DATE)) AS dia
                  FROM sys.all_objects)
    SELECT  D.dia,
            CREADOS   = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_habilitado = 1 AND CAST(t.stk_fecha_creacion AS DATE) = D.dia),
            RESUELTOS = (SELECT COUNT(DISTINCT e.ste_ticket) FROM [dbo].[Soporte_Ticket_Evento] e
                          WHERE e.ste_tipo = 'st' AND e.ste_estado_hasta = 'res' AND CAST(e.ste_fecha AS DATE) = D.dia)
    FROM    D ORDER BY D.dia

    /* 3. Por modulo, 4. por cliente y planta, 5. por categoria (del periodo) */
    SELECT TOP 8 ISNULL(v.stk_modulo, N'Sin módulo') AS ETIQUETA, COUNT(*) AS N
    FROM [dbo].[V_SOPORTE_TICKET] v WHERE v.stk_fecha_creacion >= @DESDE
    GROUP BY v.stk_modulo ORDER BY COUNT(*) DESC

    SELECT TOP 8 v.CLIENTE_NOMBRE + CASE WHEN v.PLANTA_NOMBRE <> '' THEN N' · ' + v.PLANTA_NOMBRE ELSE N'' END AS ETIQUETA, COUNT(*) AS N
    FROM [dbo].[V_SOPORTE_TICKET] v WHERE v.stk_fecha_creacion >= @DESDE
    GROUP BY v.CLIENTE_NOMBRE, v.PLANTA_NOMBRE ORDER BY COUNT(*) DESC

    SELECT c.sca_codigo, c.sca_nombre AS ETIQUETA,
           N = (SELECT COUNT(*) FROM [dbo].[Soporte_Ticket] t WHERE t.stk_habilitado = 1 AND t.stk_categoria = c.sca_codigo AND t.stk_fecha_creacion >= @DESDE)
    FROM [dbo].[Soporte_Categoria] c ORDER BY N DESC, c.sca_orden

    /* 6. Abiertos por prioridad y 7. SLA por prioridad */
    SELECT p.spr_codigo, p.spr_nombre, p.spr_horas_sla,
           ABIERTOS = (SELECT COUNT(*) FROM [dbo].[V_SOPORTE_TICKET] v WHERE v.stk_prioridad = p.spr_codigo AND v.ses_abierto = 1),
           RESUELTOS = (SELECT COUNT(*) FROM [dbo].[V_SOPORTE_TICKET] v WHERE v.stk_prioridad = p.spr_codigo AND v.stk_fecha_resolucion >= @DESDE),
           EN_PLAZO = (SELECT COUNT(*) FROM [dbo].[V_SOPORTE_TICKET] v WHERE v.stk_prioridad = p.spr_codigo AND v.stk_fecha_resolucion >= @DESDE
                         AND v.SLA_USADO_MIN <= v.SLA_TOTAL_MIN)
    FROM [dbo].[Soporte_Prioridad] p ORDER BY p.spr_orden

    /* 8. Responsables */
    SELECT  v.stk_responsable, MAX(v.RESPONSABLE_NOMBRE) AS NOMBRE,
            ABIERTOS = SUM(CASE WHEN v.ses_abierto = 1 THEN 1 ELSE 0 END),
            RESUELTOS = SUM(CASE WHEN v.stk_fecha_resolucion >= @DESDE THEN 1 ELSE 0 END),
            RESOLUCION_MIN = AVG(CASE WHEN v.stk_fecha_resolucion >= @DESDE THEN CAST(v.SLA_USADO_MIN AS FLOAT) END),
            CSAT = (SELECT CAST(100.0 * SUM(CASE WHEN s.sen_estrellas >= 4 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS INT)
                      FROM [dbo].[Soporte_Encuesta] s WHERE s.sen_responsable = v.stk_responsable AND s.sen_fecha >= @DESDE)
    FROM    [dbo].[V_SOPORTE_TICKET] v
    WHERE   v.stk_responsable IS NOT NULL
    GROUP BY v.stk_responsable
    ORDER BY ABIERTOS DESC
GO

/* ¿Puede esta persona abrir este archivo de soporte o de ayuda aunque sea
   de otro cliente? Lo consulta VerArchivo: los adjuntos de un ticket los ve
   quien lo reporto y el equipo; los de la ayuda publicada, todos. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_ARCHIVO_PERMITIDO]
    @ARCHIVO INT,
    @USUARIO INT
AS
SET NOCOUNT ON
    SELECT PERMITIDO = CAST(CASE
        WHEN EXISTS (SELECT 1 FROM [dbo].[Soporte_Ticket_Evento] e JOIN [dbo].[Soporte_Ticket] t ON t.stk_id = e.ste_ticket
                      WHERE e.ste_archivo = @ARCHIVO
                        AND (t.stk_usuario = @USUARIO OR [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 1)
                        AND (e.ste_interno = 0 OR [dbo].[FNC_SOPORTE_ES_AGENTE](@USUARIO) = 1)) THEN 1
        WHEN EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido] c WHERE c.ayc_archivo = @ARCHIVO AND c.ayc_habilitado = 1
                        AND (c.ayc_estado = 'Publicado' OR [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 1)) THEN 1
        WHEN EXISTS (SELECT 1 FROM [dbo].[Ayuda_Contenido_Version] v WHERE v.aver_archivo = @ARCHIVO
                        AND [dbo].[FNC_SOPORTE_PUEDE](@USUARIO, N'AYUDA ADMINISTRAR') = 1) THEN 1
        WHEN EXISTS (SELECT 1 FROM [dbo].[Campana] c WHERE c.cam_archivo = @ARCHIVO AND c.cam_habilitado = 1) THEN 1
        ELSE 0 END AS BIT)
GO
