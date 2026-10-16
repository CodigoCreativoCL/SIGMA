/* ============================================================================
   SIGMA — Bloque 471
   CORREO COMO TRANSPORTE: COLA DE ENVÍO, CORREO DE ALERTAS Y JOBS QUE FALTABAN
   ----------------------------------------------------------------------------
   POR QUÉ UNA COLA
     Hasta aquí cada pantalla mandaba su correo «en el momento» y, si el SMTP
     fallaba, el correo se perdía. Con la cola (Correo_Cola) quien necesita
     avisar deja el mensaje escrito, se intenta enviar de inmediato y, si no
     sale, el job CORREOS_COLA lo reintenta (hasta 5 veces, espaciadas). Todo
     queda registrado: qué se envió, a quién y por qué falló.

   EL CORREO NO ES UN SISTEMA DE AVISOS APARTE
     Alerta ya es «el aviso» (con sus destinatarios: por permiso del tipo o un
     usuario puntual, como las respuestas de la mesa de ayuda). El correo es
     otro transporte del mismo dato (MD/SIGMA_APP_NOTIFICACIONES.md §9): el job
     ALERTAS_CORREO manda por correo las alertas nuevas y deja en Alerta_Correo
     a quién ya se le mandó cada una, para no repetir.

   JOBS NUEVOS (catálogo Job, bloque 461)
     CORREOS_COLA       cada 2 min   WEB  envía y reintenta lo que está en cola
     ALERTAS_CORREO     cada 5 min   WEB  alertas nuevas → correo a quien corresponde
     ALERTAS_DETECTAR   cada 5 min   SQL  detectores de alertas de cada cliente, sin navegador abierto
     SOPORTE_SLA        cada 30 min  SQL  problemas fuera de plazo → aviso al responsable o al equipo
     SOPORTE_AUTOCIERRE diario 04:00 SQL  cierra los problemas resueltos sin respuesta tras N días
     DEMOS_AVISO        diario 08:00 WEB  avisa al ejecutivo las demos que vencen en 2 días
   Idempotente.
   ============================================================================ */
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

/* ------------------------------------------------------------ cola de correo */
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Correo_Cola]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Correo_Cola]
    (
        [cco_id]              INT            NOT NULL IDENTITY(1,1),
        [cco_origen]          VARCHAR(40)    NOT NULL,
        [cco_para]            NVARCHAR(1000) NOT NULL,
        [cco_copia]           NVARCHAR(1000) NULL,
        [cco_asunto]          NVARCHAR(300)  NOT NULL,
        [cco_html]            NVARCHAR(MAX)  NOT NULL,
        [cco_estado]          VARCHAR(10)    NOT NULL CONSTRAINT DF_CCO_ESTADO DEFAULT 'PEND',
        [cco_intentos]        INT            NOT NULL CONSTRAINT DF_CCO_INTENTOS DEFAULT 0,
        [cco_proximo]         DATETIME       NOT NULL,
        [cco_error]           NVARCHAR(1000) NULL,
        [cco_fecha_creacion]  DATETIME       NOT NULL,
        [cco_fecha_envio]     DATETIME       NULL,
        CONSTRAINT PK_CORREO_COLA PRIMARY KEY CLUSTERED ([cco_id] ASC),
        CONSTRAINT CK_CCO_ESTADO CHECK ([cco_estado] IN ('PEND', 'ENVIANDO', 'ENVIADO', 'ERROR'))
    )
    CREATE NONCLUSTERED INDEX IX_CCO_PENDIENTE ON [dbo].[Correo_Cola] ([cco_estado], [cco_proximo]) INCLUDE ([cco_intentos])
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Alerta_Correo]') AND type = 'U')
BEGIN
    CREATE TABLE [dbo].[Alerta_Correo]
    (
        [aco_alerta]  INT      NOT NULL,
        [aco_usuario] INT      NOT NULL,
        [aco_fecha]   DATETIME NOT NULL,
        CONSTRAINT PK_ALERTA_CORREO PRIMARY KEY CLUSTERED ([aco_alerta], [aco_usuario])
    )
END
GO

CREATE OR ALTER PROCEDURE [dbo].[INS_CORREO_COLA]
@ID INT = NULL OUTPUT, @ORIGEN VARCHAR(40), @PARA NVARCHAR(1000), @COPIA NVARCHAR(1000) = NULL, @ASUNTO NVARCHAR(300), @HTML NVARCHAR(MAX)
AS
SET NOCOUNT ON
IF NULLIF(LTRIM(RTRIM(@PARA)), N'') IS NULL BEGIN RAISERROR('1.- EL CORREO NO TIENE DESTINATARIO.', 16, 1) RETURN -1 END
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
INSERT [dbo].[Correo_Cola] (cco_origen, cco_para, cco_copia, cco_asunto, cco_html, cco_proximo, cco_fecha_creacion)
VALUES (@ORIGEN, LTRIM(RTRIM(@PARA)), NULLIF(LTRIM(RTRIM(@COPIA)), N''), LEFT(@ASUNTO, 300), @HTML, @AHORA, @AHORA)
SET @ID = SCOPE_IDENTITY()
RETURN 0
GO

/* Los que tocan enviar, ya marcados «enviando» (un envío que quedó colgado más de 15 min vuelve a tocar). */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CORREO_COLA_PENDIENTES]
@TOPE INT = 25, @ID INT = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
DECLARE @T TABLE (id INT)
UPDATE TOP (@TOPE) [dbo].[Correo_Cola]
   SET cco_estado = 'ENVIANDO', cco_intentos = cco_intentos + 1, cco_proximo = @AHORA
OUTPUT inserted.cco_id INTO @T
 WHERE (@ID IS NOT NULL AND cco_id = @ID AND cco_estado = 'PEND')
    OR (@ID IS NULL AND ((cco_estado = 'PEND' AND cco_proximo <= @AHORA) OR (cco_estado = 'ENVIANDO' AND cco_proximo <= DATEADD(MINUTE, -15, @AHORA))))
SELECT c.cco_id AS ID, c.cco_origen AS ORIGEN, c.cco_para AS PARA, c.cco_copia AS COPIA, c.cco_asunto AS ASUNTO, c.cco_html AS HTML, c.cco_intentos AS INTENTOS
  FROM [dbo].[Correo_Cola] c JOIN @T t ON t.id = c.cco_id ORDER BY c.cco_id
RETURN 0
GO

/* Resultado de un envío: enviado, o vuelve a la cola (5, 10, 15, 20 min) hasta 5 intentos y queda en ERROR. */
CREATE OR ALTER PROCEDURE [dbo].[UPD_CORREO_COLA_RESULTADO]
@ID INT, @OK BIT, @ERROR NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
IF @OK = 1
    UPDATE [dbo].[Correo_Cola] SET cco_estado = 'ENVIADO', cco_fecha_envio = @AHORA, cco_error = NULL WHERE cco_id = @ID
ELSE
    UPDATE [dbo].[Correo_Cola]
       SET cco_error = LEFT(@ERROR, 1000),
           cco_estado = CASE WHEN cco_intentos >= 5 THEN 'ERROR' ELSE 'PEND' END,
           cco_proximo = DATEADD(MINUTE, 5 * cco_intentos, @AHORA)
     WHERE cco_id = @ID
RETURN 0
GO

/* ------------------------------------------------------------ alertas por correo */
CREATE OR ALTER PROCEDURE [dbo].[INS_ALERTA_CORREO]
@ALERTA INT, @USUARIO INT
AS
SET NOCOUNT ON
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Correo] WHERE aco_alerta = @ALERTA AND aco_usuario = @USUARIO)
    INSERT [dbo].[Alerta_Correo] (aco_alerta, aco_usuario, aco_fecha) VALUES (@ALERTA, @USUARIO, [dbo].[FNC_AHORA]())
RETURN 0
GO

/* Pares (alerta, persona) a los que todavía no se les mandó la alerta por correo.
     · Con destinatario puntual (respuestas de la mesa de ayuda): a esa persona.
     · Sin destinatario (detectores): a quien tenga el permiso del tipo en ese cliente, solo las de severidad 3 o más.
   No se manda lo que es difusión (campañas, ayuda nueva, trabajo compartido) ni lo de hace más de 3 días. */
CREATE OR ALTER PROCEDURE [dbo].[SEL_ALERTA_CORREO_PENDIENTE]
AS
SET NOCOUNT ON
DECLARE @DESDE DATETIME = DATEADD(DAY, -3, GETDATE())
;WITH A AS
(
    SELECT a.ale_id, a.ale_cliente, a.ale_titulo, a.ale_descripcion, a.ale_severidad, a.ale_soporte_ticket, a.ale_fecha_deteccion_utc,
           a.ale_usuario_destinatario, t.alt_codigo, t.alt_nombre, t.alt_permiso, ISNULL(t.alt_ficha_link, '') AS ficha_link
      FROM [dbo].[Alerta] a
      JOIN [dbo].[Alerta_Tipo] t ON t.alt_id = a.ale_alerta_tipo
      JOIN [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado AND e.aet_codigo = 'NUEVA'
     WHERE a.ale_habilitado = 1 AND a.ale_fecha_creacion >= @DESDE
       AND t.alt_codigo NOT IN ('CAMPANA', 'AYUDA NUEVA', 'COMPARTIDO')
)
SELECT a.ale_id AS ALERTA, a.ale_titulo AS TITULO, ISNULL(a.ale_descripcion, '') AS DESCRIPCION, a.ale_severidad AS SEVERIDAD, a.ale_soporte_ticket AS TICKET,
       CONVERT(VARCHAR(16), a.ale_fecha_deteccion_utc, 120) AS DETECTADA, a.alt_codigo AS TIPO_CODIGO, a.alt_nombre AS TIPO, a.ficha_link AS FICHA,
       c.cli_nombre AS CLIENTE, u.usu_id AS USUARIO, u.usu_correo AS CORREO,
       LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS NOMBRE
  FROM A a
  JOIN [dbo].[Cliente] c ON c.cli_id = a.ale_cliente
  JOIN [dbo].[Usuario] u ON u.usu_id = a.ale_usuario_destinatario
 WHERE a.ale_usuario_destinatario IS NOT NULL AND ISNULL(u.usu_habilitado, 0) = 1 AND ISNULL(u.usu_correo, '') <> ''
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Correo] x WHERE x.aco_alerta = a.ale_id AND x.aco_usuario = u.usu_id)
UNION ALL
SELECT a.ale_id, a.ale_titulo, ISNULL(a.ale_descripcion, ''), a.ale_severidad, a.ale_soporte_ticket,
       CONVERT(VARCHAR(16), a.ale_fecha_deteccion_utc, 120), a.alt_codigo, a.alt_nombre, a.ficha_link,
       c.cli_nombre, u.usu_id, u.usu_correo, LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, '')))
  FROM A a
  JOIN [dbo].[Cliente] c ON c.cli_id = a.ale_cliente
  JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_cliente = a.ale_cliente AND cu.ucl_habilitado = 1
  JOIN [dbo].[Usuario] u ON u.usu_id = cu.ucl_id_usuario
  JOIN [dbo].[Permiso] p ON p.prm_id = a.alt_permiso
 WHERE a.ale_usuario_destinatario IS NULL AND a.alt_permiso IS NOT NULL AND ISNULL(a.ale_severidad, 0) >= 3
   AND ISNULL(u.usu_habilitado, 0) = 1 AND ISNULL(u.usu_correo, '') <> ''
   AND [dbo].[FNC_USUARIO_TIENE_PERMISO](u.usu_id, a.ale_cliente, NULL, p.prm_codigo) = 1
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Correo] x WHERE x.aco_alerta = a.ale_id AND x.aco_usuario = u.usu_id)
ORDER BY 11, 1
RETURN 0
GO

/* ------------------------------------------------------------ mesa de ayuda: lo que necesita el correo */
CREATE OR ALTER PROCEDURE [dbo].[SEL_SOPORTE_CORREO]
@TICKET INT
AS
SET NOCOUNT ON
-- 0 · el ticket con quien lo reportó y su responsable
SELECT t.stk_id AS ID, t.stk_folio AS FOLIO, t.stk_titulo AS TITULO, t.stk_descripcion AS DESCRIPCION, e.ses_nombre AS ESTADO, p.spr_nombre AS PRIORIDAD,
       p.spr_horas_sla AS HORAS_SLA, c.cli_nombre AS CLIENTE, t.stk_responsable AS RESPONSABLE_ID,
       t.stk_usuario AS REPORTA_ID, LTRIM(RTRIM(ISNULL(r.usu_nombre, '') + ' ' + ISNULL(r.usu_apellido_paterno, ''))) AS REPORTA, r.usu_correo AS REPORTA_CORREO,
       LTRIM(RTRIM(ISNULL(s.usu_nombre, '') + ' ' + ISNULL(s.usu_apellido_paterno, ''))) AS RESPONSABLE, s.usu_correo AS RESPONSABLE_CORREO
  FROM [dbo].[Soporte_Ticket] t
  JOIN [dbo].[Cliente] c ON c.cli_id = t.stk_cliente
  JOIN [dbo].[Soporte_Estado] e ON e.ses_codigo = t.stk_estado
  JOIN [dbo].[Soporte_Prioridad] p ON p.spr_codigo = t.stk_prioridad
  LEFT JOIN [dbo].[Usuario] r ON r.usu_id = t.stk_usuario
  LEFT JOIN [dbo].[Usuario] s ON s.usu_id = t.stk_responsable
 WHERE t.stk_id = @TICKET
-- 1 · el equipo de soporte (quien tenga la facultad), con correo
SELECT u.usu_id AS ID, LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' ' + ISNULL(u.usu_apellido_paterno, ''))) AS NOMBRE, u.usu_correo AS CORREO
  FROM [dbo].[Usuario] u
 WHERE ISNULL(u.usu_habilitado, 0) = 1 AND ISNULL(u.usu_correo, '') <> ''
   AND EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil AND pe.per_tipo = 1 WHERE up.upe_usuario = u.usu_id)
   AND [dbo].[FNC_SOPORTE_ES_AGENTE](u.usu_id) = 1
RETURN 0
GO

/* ------------------------------------------------------------ jobs de la mesa de ayuda */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'SOPORTE VENCIDO')
BEGIN
    INSERT [dbo].[Alerta_Tipo] (alt_codigo, alt_nombre, alt_orden, alt_habilitado, alt_permiso, alt_icono, alt_menu_link, alt_ficha_link, alt_ficha_id_columna)
    SELECT N'SOPORTE VENCIDO', N'Problema fuera de plazo', ISNULL(MAX(alt_orden), 0) + 1, 1, NULL, N'mdi mdi-timer-alert-outline', NULL, N'~/View/Soporte/Problema.aspx', N'ale_soporte_ticket'
      FROM [dbo].[Alerta_Tipo]
END
GO

/* Problemas abiertos cuyo plazo (horas del SLA + las pausas) ya pasó, sin avisar antes. Avisa al responsable, o a todo el equipo si no tiene. */
CREATE OR ALTER PROCEDURE [dbo].[JOB_SOPORTE_SLA]
AS
SET NOCOUNT ON
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @N INT = 0
DECLARE @T INT, @FOLIO VARCHAR(20), @TIT NVARCHAR(200), @RESP INT, @H INT
DECLARE C CURSOR LOCAL FAST_FORWARD FOR
    SELECT t.stk_id, t.stk_folio, t.stk_titulo, t.stk_responsable, p.spr_horas_sla
      FROM [dbo].[Soporte_Ticket] t
      JOIN [dbo].[Soporte_Estado] e ON e.ses_codigo = t.stk_estado AND e.ses_abierto = 1 AND e.ses_pausa_sla = 0
      JOIN [dbo].[Soporte_Prioridad] p ON p.spr_codigo = t.stk_prioridad
     WHERE t.stk_habilitado = 1
       AND DATEADD(MINUTE, ISNULL(t.stk_sla_pausa_min, 0), DATEADD(HOUR, p.spr_horas_sla, t.stk_fecha_creacion)) < @AHORA
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Alerta] a JOIN [dbo].[Alerta_Tipo] y ON y.alt_id = a.ale_alerta_tipo AND y.alt_codigo = 'SOPORTE VENCIDO' WHERE a.ale_soporte_ticket = t.stk_id)
OPEN C
FETCH NEXT FROM C INTO @T, @FOLIO, @TIT, @RESP, @H
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @TT NVARCHAR(400) = @FOLIO + N' está fuera de plazo', @DD NVARCHAR(1000) = @TIT + N' · el plazo era de ' + CAST(@H AS NVARCHAR(10)) + N' h'
    IF @RESP IS NOT NULL
        EXEC [dbo].[INS_SOPORTE_AVISO] @T, @RESP, N'SOPORTE VENCIDO', @TT, @DD, NULL
    ELSE
    BEGIN
        DECLARE @A INT
        DECLARE CA CURSOR LOCAL FAST_FORWARD FOR
            SELECT u.usu_id FROM [dbo].[Usuario] u
             WHERE ISNULL(u.usu_habilitado, 0) = 1 AND [dbo].[FNC_SOPORTE_ES_AGENTE](u.usu_id) = 1
               AND EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] up JOIN [dbo].[Perfiles] pe ON pe.per_id = up.upe_perfil AND pe.per_tipo = 1 WHERE up.upe_usuario = u.usu_id)
        OPEN CA
        FETCH NEXT FROM CA INTO @A
        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC [dbo].[INS_SOPORTE_AVISO] @T, @A, N'SOPORTE VENCIDO', @TT, @DD, NULL
            FETCH NEXT FROM CA INTO @A
        END
        CLOSE CA DEALLOCATE CA
    END
    SET @N = @N + 1
    FETCH NEXT FROM C INTO @T, @FOLIO, @TIT, @RESP, @H
END
CLOSE C DEALLOCATE C
SELECT @N AS AVISADOS
RETURN 0
GO

MERGE [dbo].[Sys_Parametros] AS D
USING (VALUES ('SOPORTE_AUTOCIERRE_DIAS', N'Cierre automático de problemas resueltos', N'Días sin respuesta del usuario tras «Resuelto» para cerrar el problema solo.', '5')) AS O (codigo, nombre, descripcion, valor)
   ON D.par_codigo = O.codigo
WHEN NOT MATCHED THEN INSERT (par_codigo, par_nombre, par_descripcion, par_valor) VALUES (O.codigo, O.nombre, O.descripcion, O.valor);
GO

/* Cierra los problemas «Resuelto» que el usuario no respondió en N días (cambia el estado con el mismo SP de siempre, así que avisa al usuario). */
CREATE OR ALTER PROCEDURE [dbo].[JOB_SOPORTE_AUTOCIERRE]
AS
SET NOCOUNT ON
DECLARE @DIAS INT = ISNULL(TRY_CAST((SELECT par_valor FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'SOPORTE_AUTOCIERRE_DIAS') AS INT), 5)
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA](), @N INT = 0, @T INT
DECLARE @NOTA NVARCHAR(300) = N'Cierre automático: pasaron ' + CAST(@DIAS AS NVARCHAR(10)) + N' días sin respuesta al aviso de resolución.'
DECLARE C CURSOR LOCAL FAST_FORWARD FOR
    SELECT stk_id FROM [dbo].[Soporte_Ticket]
     WHERE stk_habilitado = 1 AND stk_estado = 'res' AND ISNULL(stk_fecha_resolucion, stk_fecha_actualizacion) < DATEADD(DAY, -@DIAS, @AHORA)
OPEN C
FETCH NEXT FROM C INTO @T
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [dbo].[UPD_SOPORTE_TICKET_ESTADO] @TICKET = @T, @USUARIO = 1, @ESTADO = 'cer', @NOTA = @NOTA
    SET @N = @N + 1
    FETCH NEXT FROM C INTO @T
END
CLOSE C DEALLOCATE C
SELECT @N AS CERRADOS
RETURN 0
GO

/* ------------------------------------------------------------ detectores de alertas sin navegador */
/* Los detectores corren solos en cada cliente habilitado, con el freno de 5 min de GEN_ALERTA_DETECTAR; ya no dependen de que alguien tenga la web abierta. */
CREATE OR ALTER PROCEDURE [dbo].[JOB_ALERTAS_DETECTAR]
AS
SET NOCOUNT ON
DECLARE @C INT, @N INT = 0
DECLARE K CURSOR LOCAL FAST_FORWARD FOR SELECT cli_id FROM [dbo].[Cliente] WHERE cli_habilitado = 1
OPEN K
FETCH NEXT FROM K INTO @C
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC [dbo].[GEN_ALERTA_DETECTAR] @CLIENTE = @C, @USUARIO = 1, @MINUTOS = 5
        SET @N = @N + 1
    END TRY
    BEGIN CATCH
        INSERT [dbo].[Sis_Excepcion] (lge_texto, lge_error, lge_fecha_act) VALUES ('JOB_ALERTAS_DETECTAR cliente=' + CAST(@C AS VARCHAR(10)), ERROR_MESSAGE(), GETDATE())
    END CATCH
    FETCH NEXT FROM K INTO @C
END
CLOSE K DEALLOCATE K
SELECT @N AS CLIENTES
RETURN 0
GO

/* ------------------------------------------------------------ demos por vencer (aviso al ejecutivo) */
CREATE OR ALTER PROCEDURE [dbo].[SEL_DEMOS_POR_AVISAR]
AS
SET NOCOUNT ON
DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
SELECT L.lea_id AS LEAD, L.lea_codigo AS CODIGO, L.lea_empresa AS EMPRESA, L.lea_contacto_nombre AS CONTACTO, CONVERT(VARCHAR(10), D.ldm_expira, 120) AS EXPIRA,
       DATEDIFF(DAY, @HOY, D.ldm_expira) AS DIAS, U.usu_id AS EJECUTIVO_ID, U.usu_correo AS EJECUTIVO_CORREO,
       LTRIM(RTRIM(ISNULL(U.usu_nombre, '') + ' ' + ISNULL(U.usu_apellido_paterno, ''))) AS EJECUTIVO
  FROM [dbo].[Lead_Demo] D
  JOIN [dbo].[Lead] L ON L.lea_id = D.ldm_lead AND L.lea_habilitado = 1 AND L.lea_estado = 'DEMO'
  JOIN [dbo].[Usuario] U ON U.usu_id = L.lea_ejecutivo AND ISNULL(U.usu_correo, '') <> ''
 WHERE D.ldm_estado IN ('ACTIVA', 'EXTENDIDA') AND DATEDIFF(DAY, @HOY, D.ldm_expira) BETWEEN 0 AND 2
   AND NOT EXISTS (SELECT 1 FROM [dbo].[Lead_Actividad] A WHERE A.lac_lead = L.lea_id AND A.lac_titulo = N'Aviso al ejecutivo: la demo vence pronto' AND A.lac_fecha >= D.ldm_inicio)
RETURN 0
GO

/* ------------------------------------------------------------ catálogo de jobs */
DECLARE @AHORA DATETIME = [dbo].[FNC_AHORA]()
MERGE [dbo].[Job] AS D
USING (VALUES
  ('CORREOS_COLA',      N'Enviar correos en cola',           N'Envía los correos que están en cola y reintenta los que fallaron (hasta 5 veces, espaciados).', 'WEB', NULL, 'MINUTOS', CAST(NULL AS TIME(0)), 2),
  ('ALERTAS_CORREO',    N'Alertas por correo',               N'Manda por correo las alertas nuevas: respuestas de la mesa de ayuda a quien corresponde y las de severidad 3 o más a quien tenga el permiso del tipo. No repite.', 'WEB', NULL, 'MINUTOS', NULL, 5),
  ('ALERTAS_DETECTAR',  N'Detectar alertas',                 N'Corre los detectores de alertas de cada cliente sin esperar a que alguien abra la web.', 'SQL', 'JOB_ALERTAS_DETECTAR', 'MINUTOS', NULL, 5),
  ('SOPORTE_SLA',       N'Mesa de ayuda · plazos vencidos',  N'Avisa al responsable (o al equipo) los problemas abiertos cuyo plazo ya pasó.', 'SQL', 'JOB_SOPORTE_SLA', 'MINUTOS', NULL, 30),
  ('SOPORTE_AUTOCIERRE',N'Mesa de ayuda · cierre automático',N'Cierra los problemas resueltos que el usuario no respondió en SOPORTE_AUTOCIERRE_DIAS días.', 'SQL', 'JOB_SOPORTE_AUTOCIERRE', 'DIARIO', CAST('04:00' AS TIME(0)), NULL),
  ('DEMOS_AVISO',       N'Aviso de demos por vencer',        N'Avisa por correo al ejecutivo las demos que vencen en los próximos 2 días.', 'WEB', NULL, 'DIARIO', CAST('08:00' AS TIME(0)), NULL)
) AS O (codigo, nombre, descripcion, tipo, sp, frecuencia, hora, minutos)
   ON D.job_codigo = O.codigo
WHEN NOT MATCHED THEN
    INSERT (job_codigo, job_nombre, job_descripcion, job_tipo, job_sp, job_frecuencia, job_hora, job_minutos, job_activo, job_proxima)
    VALUES (O.codigo, O.nombre, O.descripcion, O.tipo, O.sp, O.frecuencia, O.hora, O.minutos, 1, [dbo].[FNC_JOB_PROXIMA](O.frecuencia, O.hora, O.minutos, @AHORA))
WHEN MATCHED THEN
    UPDATE SET D.job_nombre = O.nombre, D.job_descripcion = O.descripcion, D.job_tipo = O.tipo, D.job_sp = O.sp;
GO

PRINT '471_CORREO_COLA_Y_JOBS aplicado.'
GO
