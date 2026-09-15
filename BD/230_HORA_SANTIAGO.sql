USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  15-09-2026
-- DESCRIPTION:     LA HORA DE NEGOCIO DE LA BASE ES LA DE SANTIAGO DE
--                  CHILE, NO LA DEL SERVIDOR DEL HOSTING.
-- =============================================
-- EL PROBLEMA
--   El SQL Server del hosting corre en UTC-7. GETDATE() devuelve esa hora,
--   asi que entre las 20:00 y las 24:00 de Chile la base cree que todavia
--   es el dia anterior. Se vio en las pruebas del 15-09-2026: un precio
--   comercial "vigente desde hoy" no regia (SEL_PLAN_COMERCIAL comparaba
--   contra CAST(GETDATE() AS DATE)), y todas las fechas de creacion y
--   actualizacion que no pasan por FNC_PAIS_HORA quedaban cuatro horas
--   atrasadas.
--
-- LA SOLUCION
--   1. FNC_AHORA(): la hora de Santiago, resuelta con AT TIME ZONE sobre
--      SYSDATETIMEOFFSET(), asi que da igual donde este alojado el servidor
--      y el horario de verano lo maneja Windows. Es el reloj de la
--      plataforma; FNC_PAIS_HORA(@PAIS) sigue siendo el reloj de cada
--      cliente cuando el SP sabe de que pais es.
--   2. Todo modulo (SP, funcion, vista) que todavia llamaba GETDATE() se
--      vuelve a crear con [dbo].[FNC_AHORA]() en su lugar. El cuerpo es el
--      que estaba en la base al generar este bloque (_scratch/gen_230.py lo
--      lee de sys.sql_modules): solo cambia esa llamada.
--   3. Los DEFAULT (getdate()) de las columnas de auditoria pasan a
--      ([dbo].[FNC_AHORA]()).
--   GETUTCDATE() no se toca: las columnas *_utc son UTC a proposito.
-- =============================================

/* Se crea solo si no existe: una vez que los DEFAULT la referencian, SQL
   Server no deja alterarla, y no hace falta. */
IF OBJECT_ID('dbo.FNC_AHORA') IS NULL
    EXEC('CREATE FUNCTION [dbo].[FNC_AHORA]()
          RETURNS DATETIME
          AS
          BEGIN
              RETURN CAST(SYSDATETIMEOFFSET() AT TIME ZONE ''Pacific SA Standard Time'' AS DATETIME)
          END')
GO

-- ---------- FNC_CLIENTE_LIMITE (FN) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- FNC_CLIENTE_LIMITE (FN) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   13. FNC_CLIENTE_LIMITE
       Devuelve el tope de una funcionalidad de tipo LIMITE.
       NULL = sin tope. Los INS_ la consultan antes de crear.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_LIMITE]
(
    @CLIENTE              INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @FUN INT, @PLAN INT, @LIMITE DECIMAL(18,2), @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    SELECT @FUN = fun_id FROM [dbo].[Funcionalidad] WHERE fun_codigo = @FUNCIONALIDAD_CODIGO
    SELECT @PLAN = sus_plan_comercial FROM [dbo].[Suscripcion] WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1
    IF @FUN IS NULL OR @PLAN IS NULL RETURN 0

    SELECT TOP 1 @LIMITE = pcf.pcf_limite
      FROM [dbo].[Plan_Comercial_Funcionalidad] pcf
     WHERE pcf.pcf_plan_comercial = @PLAN
       AND pcf.pcf_funcionalidad  = @FUN
       AND pcf.pcf_habilitado     = 1
       AND pcf.pcf_incluida       = 1
       AND (pcf.pcf_cliente IS NULL OR pcf.pcf_cliente = @CLIENTE)
       AND (pcf.pcf_vigencia_hasta IS NULL OR pcf.pcf_vigencia_hasta >= @HOY)
     ORDER BY CASE WHEN pcf.pcf_cliente IS NULL THEN 1 ELSE 0 END

    RETURN @LIMITE      -- NULL = sin tope
END
GO

-- ---------- FNC_CLIENTE_TIENE_FUNCIONALIDAD (FN) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- FNC_CLIENTE_TIENE_FUNCIONALIDAD (FN) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   12. FNC_CLIENTE_TIENE_FUNCIONALIDAD
       La excepcion del cliente gana sobre la regla del plan.
       Mismo patron que los permisos por usuario del Anexo D.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_CLIENTE_TIENE_FUNCIONALIDAD]
(
    @CLIENTE             INT,
    @FUNCIONALIDAD_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @FUN INT, @PLAN INT, @INCLUIDA BIT, @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    SELECT @FUN = fun_id FROM [dbo].[Funcionalidad]
     WHERE fun_codigo = @FUNCIONALIDAD_CODIGO AND fun_habilitado = 1
    IF @FUN IS NULL RETURN 0

    SELECT @PLAN = sus_plan_comercial FROM [dbo].[Suscripcion]
     WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1
    IF @PLAN IS NULL RETURN 0

    -- La fila del cliente gana; si no hay, manda la del plan.
    SELECT TOP 1 @INCLUIDA = pcf.pcf_incluida
      FROM [dbo].[Plan_Comercial_Funcionalidad] pcf
     WHERE pcf.pcf_plan_comercial = @PLAN
       AND pcf.pcf_funcionalidad  = @FUN
       AND pcf.pcf_habilitado     = 1
       AND (pcf.pcf_cliente IS NULL OR pcf.pcf_cliente = @CLIENTE)
       AND (pcf.pcf_vigencia_hasta IS NULL OR pcf.pcf_vigencia_hasta >= @HOY)
     ORDER BY CASE WHEN pcf.pcf_cliente IS NULL THEN 1 ELSE 0 END

    RETURN ISNULL(@INCLUIDA, 0)
END
GO

-- ---------- FNC_SUSCRIPCION_VIGENTE (TF) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- FNC_SUSCRIPCION_VIGENTE (TF) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   11. FNC_SUSCRIPCION_VIGENTE
       Unica fuente de verdad. VENCIDA y EN GRACIA se CALCULAN: un estado
       que cambia solo porque paso el tiempo no puede depender de un job.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_SUSCRIPCION_VIGENTE] (@KEY_HASH VARBINARY(32))
RETURNS @R TABLE
(
    CLIENTE         INT,
    SUSCRIPCION     INT,
    PLAN_COMERCIAL  INT,
    ESTADO          NVARCHAR(20),
    FECHA_FIN       DATE,
    DIAS_RESTANTES  INT,
    PUEDE_OPERAR    BIT
)
AS
BEGIN
    DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    INSERT @R (CLIENTE, SUSCRIPCION, PLAN_COMERCIAL, ESTADO, FECHA_FIN, DIAS_RESTANTES, PUEDE_OPERAR)
    SELECT  s.sus_cliente,
            s.sus_id,
            s.sus_plan_comercial,
            CASE
                WHEN s.sus_suscripcion_estado = 3 THEN N'CANCELADA'
                WHEN s.sus_suscripcion_estado = 2 THEN N'SUSPENDIDA'
                WHEN s.sus_fecha_fin IS NULL      THEN N'VENCIDA'
                WHEN s.sus_fecha_fin >= @HOY      THEN N'VIGENTE'
                WHEN DATEADD(DAY, s.sus_dias_gracia, s.sus_fecha_fin) >= @HOY THEN N'EN GRACIA'
                ELSE N'VENCIDA'
            END,
            s.sus_fecha_fin,
            DATEDIFF(DAY, @HOY, s.sus_fecha_fin),
            CASE WHEN s.sus_suscripcion_estado = 1
                  AND s.sus_habilitado = 1
                  AND DATEADD(DAY, s.sus_dias_gracia, ISNULL(s.sus_fecha_fin, '19000101')) >= @HOY
                 THEN 1 ELSE 0 END
    FROM    [dbo].[Suscripcion] s
    WHERE   s.sus_key_hash = @KEY_HASH

    RETURN
END
GO

-- ---------- FNC_USUARIO_TIENE_PERMISO (FN) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- FNC_USUARIO_TIENE_PERMISO (FN) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ============================================================================
   SIGMA — Bloque 102
   UNA SOLA REGLA PARA "¿ESTE USUARIO TIENE ESTE PERMISO?"
   ----------------------------------------------------------------------------

   Cierra la decisión que el MD dejaba marcada con ⚠ desde el bloque 62.

   EL PROBLEMA, MEDIDO

   Había dos implementaciones de la misma pregunta y se contradecían en los
   dos sentidos. Comprobado contra la base antes de tocar nada:

     · Marcela (Administrador del Cliente SOLO en Hamburgo), preguntando por
       un cliente AJENO:
           SEL_USUARIO_PERMISOS  ->  34 permisos     <-- el agujero
           FNC_USUARIO_TIENE_...  ->  0

     · Una cuenta de plataforma que no sea Root (Soporte, Gerente Comercial):
           SEL_USUARIO_PERMISOS  ->  32 permisos
           FNC_USUARIO_TIENE_...  ->  0              <-- arbol de la app vacio

   La causa es la misma en los dos casos: el SP mira Usuario_Perfil sin
   preguntarse de que tipo es el perfil, y la funcion no lo mira nunca.

   POR QUE PASA

   Desde el bloque 49, Usuario_Perfil esta poblado EN ESPEJO de
   Cliente_Usuario_Perfil. Ese espejo existe porque hay pantallas heredadas
   que consultan esa tabla, y reescribirlas todas era mas riesgo que
   beneficio. Pero el espejo NO es una fuente de permisos: es una copia. El
   SP lo estaba tratando como fuente, y por eso el perfil que Marcela tiene
   en Hamburgo la seguia a cualquier cliente.

   LA REGLA QUE SE ADOPTA

     Un perfil en Usuario_Perfil otorga permisos SOLO si es de plataforma
     (per_tipo = 1). Los de tipo Cliente que estan ahi son el espejo, y el
     espejo no otorga nada: los permisos dentro de un cliente salen de
     Cliente_Usuario_Perfil de ESE cliente.

   Es una sola frase, se aplica igual en las dos implementaciones, y se apoya
   en un dato que ya existe -per_tipo- en vez de en una lista que alguien
   tenga que mantener.

   POR QUE ESTA Y NO LAS DOS DEL MD

   El documento planteaba: o el SP deja de contar el espejo, o el espejo deja
   de poblarse. Ninguna de las dos arregla el segundo caso: la funcion seguia
   dejando sin permisos a Soporte y a Gerente Comercial, que no tienen
   afiliacion a ningun cliente. Hacia falta tocar las dos puntas.

   Y dejar de poblar el espejo tampoco era viable: SEL_CLIENTE_USUARIO_ELEGIBLE
   decide quien ve todos los clientes mirando Usuario_Perfil, y
   SEL_CLIENTE_USUARIO exige una fila ahi para listar a alguien. Vaciarlo
   rompe las dos.

   LO QUE ADEMAS SE IGUALA

   Habia una tercera diferencia que el MD no registraba: la funcion exige
   autorizacion vigente en la planta (Cliente_Instalacion_Usuario) y el SP no
   la miraba. Hoy esta latente -todos los llamadores pasan @INSTALACION en
   NULL- pero se activa sola el dia que la app pase la planta. Se agrega al
   SP con la misma semantica.

   Con una excepcion en ambas: la autorizacion de planta aplica a lo que
   viene del CLIENTE, no a un permiso de plataforma. Un Soporte diagnosticando
   un problema no esta asignado a ninguna planta y nunca va a estarlo.
   ============================================================================ */


/* ========================================================================
   1. LA FUNCION
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO         INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY             DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
    DECLARE @POR_PLATAFORMA  BIT  = 0
    DECLARE @POR_CLIENTE     BIT  = 0
    DECLARE @OTORGADO        BIT
    DECLARE @DEL_CLIENTE     BIT

    SELECT @PERMISO = prm_id
      FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    /* ---- Root ve todo ----
       Es una regla distinta de "su perfil otorga este permiso": Root accede
       incluso a lo que no esta en su matriz. Por eso sigue siendo un atajo
       propio y no un caso mas de perfil de plataforma. */
    IF EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil]
                WHERE upe_usuario = @USUARIO AND upe_perfil = 1)
        RETURN 1

    /* ---- Perfil de PLATAFORMA (bloque 102) ----
       Soporte y Gerente Comercial no tienen afiliacion a ningun cliente, asi
       que la comprobacion de mas abajo los dejaba en cero y el arbol de la
       app les salia vacio. Sus permisos salen de su perfil global, y ese
       perfil vale porque es de tipo 1.

       Los de tipo 2 que hay en esa misma tabla son el espejo del bloque 49 y
       NO se cuentan: si se contaran, el perfil que alguien tiene en su
       empresa lo seguiria a cualquier otra. */
    IF EXISTS (SELECT 1
                 FROM [dbo].[Usuario_Perfil] up
                 JOIN [dbo].[Perfiles]       per ON per.per_id = up.upe_perfil
                                                AND per.per_tipo = 1
                                                AND per.per_habilitado = 1
                 JOIN [dbo].[Perfil_Permiso] ppe ON ppe.ppe_perfil  = up.upe_perfil
                                                AND ppe.ppe_permiso = @PERMISO
                WHERE up.upe_usuario = @USUARIO)
        SET @POR_PLATAFORMA = 1

    /* ---- Lo que entrega el cliente ---- */
    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO
       AND ucl_id_cliente = @CLIENTE
       AND ISNULL(ucl_habilitado, 0) = 1

    IF @CLIENTE_USUARIO IS NOT NULL
    BEGIN
        -- 1. El perfil DENTRO de ese cliente
        IF EXISTS (SELECT 1
                     FROM [dbo].[Cliente_Usuario_Perfil] cup
                     JOIN [dbo].[Perfil_Permiso]         ppe ON ppe.ppe_perfil = cup.cup_id_perfil
                    WHERE cup.cup_id_cliente_usuario = @CLIENTE_USUARIO
                      AND ppe.ppe_permiso            = @PERMISO)
            SET @POR_CLIENTE = 1

        -- 2. La regla puntual: la de la planta gana sobre la global
        SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
          FROM [dbo].[Cliente_Usuario_Permiso] cpm
         WHERE cpm.cpm_cliente_usuario = @CLIENTE_USUARIO
           AND cpm.cpm_permiso         = @PERMISO
           AND cpm.cpm_habilitado      = 1
           AND cpm.cpm_instalacion_area IS NULL
           AND (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
           AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
           AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
         ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END
    END

    -- 3. La regla puntual manda sobre el perfil del cliente, exista o no
    SET @DEL_CLIENTE = CASE WHEN @OTORGADO IS NOT NULL THEN @OTORGADO ELSE @POR_CLIENTE END

    /* 4. Sin autorizacion vigente en la planta no hay permiso que valga.
          Aplica a lo del cliente, no a lo de plataforma: quien da soporte no
          esta asignado a plantas. */
    IF @DEL_CLIENTE = 1 AND @INSTALACION IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        WHERE ciu.ciu_id_usuario     = @USUARIO
                          AND ciu.ciu_id_instalacion = @INSTALACION
                          AND ciu.ciu_habilitado     = 1
                          AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                          AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            SET @DEL_CLIENTE = 0
    END

    RETURN CASE WHEN @POR_PLATAFORMA = 1 OR @DEL_CLIENTE = 1 THEN 1 ELSE 0 END
END
GO

-- ---------- FNC_USUARIO_TIENE_PERMISO_AREA (FN) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- FNC_USUARIO_TIENE_PERMISO_AREA (FN) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   10. FNC_USUARIO_TIENE_PERMISO_AREA                               HU-007

       El mismo criterio, un escalon mas fino. Orden de especificidad:
       area gana sobre planta, y planta gana sobre cliente.
   ======================================================================== */

CREATE OR ALTER FUNCTION [dbo].[FNC_USUARIO_TIENE_PERMISO_AREA]
(
    @USUARIO        INT,
    @CLIENTE        INT,
    @INSTALACION    INT,
    @AREA           INT,
    @PERMISO_CODIGO NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @PERMISO         INT
    DECLARE @CLIENTE_USUARIO INT
    DECLARE @HOY             DATE = CAST([dbo].[FNC_AHORA]() AS DATE)
    DECLARE @OTORGADO        BIT

    /* Sin area, la pregunta es la de siempre. */
    IF @AREA IS NULL
        RETURN [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, @INSTALACION, @PERMISO_CODIGO)

    SELECT @PERMISO = prm_id
      FROM [dbo].[Permiso]
     WHERE prm_codigo = @PERMISO_CODIGO AND prm_habilitado = 1
    IF @PERMISO IS NULL RETURN 0

    SELECT @CLIENTE_USUARIO = ucl_id
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id_usuario = @USUARIO
       AND ucl_id_cliente = @CLIENTE
       AND ISNULL(ucl_habilitado, 0) = 1
    IF @CLIENTE_USUARIO IS NULL RETURN 0

    -- Excepcion escrita para ESTA area
    SELECT TOP 1 @OTORGADO = cpm.cpm_otorgado
      FROM [dbo].[Cliente_Usuario_Permiso] cpm
     WHERE cpm.cpm_cliente_usuario  = @CLIENTE_USUARIO
       AND cpm.cpm_permiso          = @PERMISO
       AND cpm.cpm_habilitado       = 1
       AND cpm.cpm_instalacion_area = @AREA
       AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
       AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)

    IF @OTORGADO IS NOT NULL
    BEGIN
        /* Aun concedido en el area, la autorizacion vigente en la planta
           sigue siendo condicion necesaria. */
        IF @OTORGADO = 1 AND @INSTALACION IS NOT NULL
           AND NOT EXISTS (SELECT 1
                             FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                            WHERE ciu.ciu_id_usuario     = @USUARIO
                              AND ciu.ciu_id_instalacion = @INSTALACION
                              AND ciu.ciu_habilitado     = 1
                              AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                              AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
            RETURN 0

        RETURN @OTORGADO
    END

    -- Sin excepcion de area, decide el nivel de planta
    RETURN [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, @INSTALACION, @PERMISO_CODIGO)
END
GO

-- ---------- VW_CHECKLIST_HALLAZGO_PENDIENTE (V) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- VW_CHECKLIST_HALLAZGO_PENDIENTE (V) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER VIEW [dbo].[VW_CHECKLIST_HALLAZGO_PENDIENTE]
AS
SELECT
    CHA.[cha_id],
    CHA.[cha_cliente],
    CHA.[cha_titulo],
    CHA.[cha_descripcion],
    CHA.[cha_severidad],
    SEV.[sev_nombre]                AS [severidad_nombre],
    CHA.[cha_generado_ia],
    CHA.[cha_confianza_ia],
    CHA.[cha_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    CEJ.[cej_usuario_ejecutor],
    CHA.[cha_fecha_creacion],
    DATEDIFF(DAY, CHA.[cha_fecha_creacion], [dbo].[FNC_AHORA]()) AS [dia_esperando],
    CASE WHEN CHA.[cha_motivo_descarte] IS NOT NULL THEN 'DESCARTADO' ELSE 'PENDIENTE' END AS [situacion]
FROM [dbo].[Checklist_Hallazgo] CHA
    LEFT JOIN [dbo].[Checklist_Ejecucion] CEJ ON CEJ.[cej_id] = CHA.[cha_checklist_ejecucion]
    LEFT JOIN [dbo].[Activo]              ACT ON ACT.[act_id] = CHA.[cha_activo]
    LEFT JOIN [dbo].[Severidad]           SEV ON SEV.[sev_id] = CHA.[cha_severidad]
WHERE CHA.[cha_orden_trabajo] IS NULL
  AND CHA.[cha_habilitado]    = 1
GO

-- ---------- VW_ORDEN_TRABAJO_TABLERO (V) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- VW_ORDEN_TRABAJO_TABLERO (V) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER VIEW [dbo].[VW_ORDEN_TRABAJO_TABLERO]
AS
SELECT
    OTR.[otr_id],
    OTR.[otr_cliente],
    OTR.[otr_cliente_instalacion],
    OTR.[otr_correlativo],
    OTR.[otr_titulo],
    OTR.[otr_orden_trabajo_estado],
    OTE.[ote_nombre]                    AS [estado_nombre],
    OTT.[ott_nombre]                    AS [tipo_nombre],
    OPR.[opr_nombre]                    AS [prioridad_nombre],
    OTO.[oto_nombre]                    AS [origen_nombre],
    OTR.[otr_activo],
    ACT.[act_codigo],
    ACT.[act_nombre],
    OTR.[otr_fecha_programada_utc],
    OTR.[otr_fecha_inicio_real_utc],
    OTR.[otr_fecha_fin_real_utc],
    -- Estados DERIVADOS: existen como consulta, no como columna.
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] A
                       WHERE A.[ota_orden_trabajo] = OTR.[otr_id])
         THEN 1 ELSE 0 END              AS [esta_asignada],
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Validacion] V
                       WHERE V.[otv_orden_trabajo] = OTR.[otr_id]
                         AND V.[otv_validacion_tipo] = 2            -- VALIDACION
                         AND V.[otv_resultado]       = 'APROBADO')
         THEN 1 ELSE 0 END              AS [esta_validada],
    -- Horas reales: suma de la mano de obra, no un campo tipeado.
    ISNULL((SELECT SUM(M.[omo_minuto]) FROM [dbo].[Orden_Trabajo_Mano_Obra] M
             WHERE M.[omo_orden_trabajo] = OTR.[otr_id]), 0)      AS [minuto_mano_obra],
    -- Costo de terceros: suma de los servicios contratados.
    ISNULL((SELECT SUM(S.[ots_monto]) FROM [dbo].[Orden_Trabajo_Servicio] S
             WHERE S.[ots_orden_trabajo] = OTR.[otr_id]
               AND S.[ots_habilitado]    = 1), 0)                 AS [monto_servicio_externo],
    -- Cuantos dias lleva abierta. Estado 5 = CERRADA.
    CASE WHEN OTR.[otr_orden_trabajo_estado] = 5 THEN NULL
         ELSE DATEDIFF(DAY, OTR.[otr_fecha_creacion], [dbo].[FNC_AHORA]()) END AS [dia_abierta]
FROM [dbo].[Orden_Trabajo] OTR
    INNER JOIN [dbo].[Orden_Trabajo_Estado]    OTE ON OTE.[ote_id] = OTR.[otr_orden_trabajo_estado]
    INNER JOIN [dbo].[Orden_Trabajo_Tipo]      OTT ON OTT.[ott_id] = OTR.[otr_orden_trabajo_tipo]
    INNER JOIN [dbo].[Orden_Trabajo_Prioridad] OPR ON OPR.[opr_id] = OTR.[otr_orden_trabajo_prioridad]
    INNER JOIN [dbo].[Orden_Trabajo_Origen]    OTO ON OTO.[oto_id] = OTR.[otr_orden_trabajo_origen]
    LEFT  JOIN [dbo].[Activo]                  ACT ON ACT.[act_id] = OTR.[otr_activo]
WHERE OTR.[otr_habilitado] = 1
GO

-- ---------- VW_PLANIFICADOR_PENDIENTE_CIERRE (V) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- VW_PLANIFICADOR_PENDIENTE_CIERRE (V) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   10. VW_PLANIFICADOR_PENDIENTE_CIERRE
       "Ahi es donde el planner tiene la pega de cerrarlas todas."
       Esta vista ES esa pega, contada.
   ======================================================================== */

CREATE OR ALTER VIEW [dbo].[VW_PLANIFICADOR_PENDIENTE_CIERRE]
AS
SELECT
    otr.otr_cliente                                     AS CLIENTE,
    otr.otr_id                                          AS ORDEN_TRABAJO,
    otr.otr_activo                                      AS ACTIVO,
    ott.ott_nombre                                      AS TIPO,
    opr.opr_nombre                                      AS PRIORIDAD,
    oto.oto_nombre                                      AS ORIGEN,
    otr.otr_ot_origen                                   AS NACIO_DE_LA_OT,
    otr.otr_fecha_ocurrencia                            AS FECHA_OCURRENCIA,
    otr.otr_registro_posterior                          AS REGISTRO_POSTERIOR,
    DATEDIFF(DAY, ISNULL(otr.otr_fecha_ocurrencia, otr.otr_fecha_creacion), [dbo].[FNC_AHORA]()) AS DIAS_ESPERANDO,
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] ota
                       WHERE ota.ota_orden_trabajo = otr.otr_id AND ota.ota_proveedor IS NOT NULL)
         THEN 1 ELSE 0 END                              AS TIENE_TRABAJO_EXTERNO,
    CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo] ptr
                       WHERE ptr.ptr_orden_trabajo = otr.otr_id
                         AND ptr.ptr_permiso_trabajo_estado NOT IN (2, 5))
         THEN 1 ELSE 0 END                              AS BLOQUEADA_POR_PERMISO
  FROM [dbo].[Orden_Trabajo] otr
  LEFT JOIN [dbo].[Orden_Trabajo_Tipo]      ott ON ott.ott_id = otr.otr_orden_trabajo_tipo
  LEFT JOIN [dbo].[Orden_Trabajo_Prioridad] opr ON opr.opr_id = otr.otr_orden_trabajo_prioridad
  LEFT JOIN [dbo].[Orden_Trabajo_Origen]    oto ON oto.oto_id = otr.otr_orden_trabajo_origen
 WHERE otr.otr_orden_trabajo_estado = 3
GO

-- ---------- API_GEN_PREDICCION_TENDENCIA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_GEN_PREDICCION_TENDENCIA (P) · 6 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  07-09-2026
-- DESCRIPTION:     EL PREDICTOR DE LINEA BASE DE SIGMA AI.
-- =============================================
-- QUE HACE, EN UNA FRASE
--
--   Para cada variable vigilada de cada equipo, ajusta una recta sobre las
--   lecturas de los ultimos 120 dias y calcula cuando esa recta llegara al
--   valor critico declarado. Nada mas.
--
-- POR QUE CADA NUMERO QUE MUESTRA ES DEFENDIBLE
--
--   `pre_dia_restante` es la solucion de una ecuacion de primer grado sobre
--   datos reales. `pre_confianza` es el R2 del ajuste. El intervalo sale del
--   error estandar de la pendiente, no de un margen elegido a dedo. Y
--   `pre_probabilidad` es **la parte del intervalo de cruce que cae dentro del
--   horizonte**: si el equipo puede cruzar el umbral entre el dia 20 y el dia
--   200, y el horizonte son 90 dias, la probabilidad es la fraccion de esa
--   ventana que queda antes del dia 90.
--
--   Esa definicion importa. «Probabilidad de falla» suena a que el modelo sabe
--   algo sobre fallas, y no sabe nada: no ha visto ninguna. Lo que si puede
--   afirmar es cuando una variable medida va a cruzar un limite declarado, y
--   con cuanta incertidumbre. La pantalla dice exactamente eso, y **siempre
--   con el condicional**: es lo que pasa si la tendencia se mantiene.
--
-- PROBABILIDAD Y SEVERIDAD NO SON LO MISMO
--
--   La probabilidad dice si va a cruzar dentro del horizonte; la severidad,
--   que tan pronto. La primera decide si se alerta -contra los umbrales del
--   modelo-, la segunda con que urgencia -contra los plazos declarados en los
--   hiperparametros-. Sacar las dos del mismo numero fue el primer intento y
--   dejaba TODO en critico: con noventa dias de horizonte casi todo lo que
--   cruza tiene probabilidad 1, incluida una vibracion que recien llega al
--   limite en cincuenta dias. Una pantalla donde todo es critico no prioriza
--   nada.
--
-- CUANDO NO DICE NADA
--
--   Con menos de cuatro lecturas, con R2 bajo 0,35, con pendiente que no sube,
--   o con el cruce mas alla del horizonte: **no se emite prediccion**. Callar
--   es una respuesta valida y es la correcta cuando los datos no alcanzan. La
--   pantalla, en cambio, si tiene que decir por que esta callando -«faltan
--   lecturas», «se mueve sin patron»- y para eso esta el @TIPO 5 del SEL.
--
-- SE PUEDE VOLVER A CORRER
--
--   Una corrida por (activo, variable, dia) gracias al uuid deterministico. Un
--   proceso nocturno que se ejecute dos veces no deja dos predicciones del
--   mismo equipo el mismo dia, que es lo que despues hace que la curva
--   historica tenga escalones falsos.
-- =============================================


CREATE OR ALTER PROCEDURE [dbo].[API_GEN_PREDICCION_TENDENCIA]
     @CLIENTE      INT
    ,@USUARIO      INT
    ,@INSTALACION  INT = NULL
    ,@ACTIVO       INT = NULL
AS
SET NOCOUNT ON

BEGIN

    DECLARE @MPV INT, @HORIZONTE INT, @UMB_ALERTA DECIMAL(9,6), @UMB_CRITICO DECIMAL(9,6)
    DECLARE @HIPER NVARCHAR(MAX)

    SELECT TOP 1
           @MPV         = mpv.[mpv_id]
          ,@HORIZONTE   = mpr.[mpr_horizonte_dia]
          ,@UMB_ALERTA  = mpr.[mpr_umbral_alerta]
          ,@UMB_CRITICO = mpr.[mpr_umbral_critico]
          ,@HIPER       = mpv.[mpv_hiperparametro]
      FROM [dbo].[Modelo_Predictivo]         mpr
      JOIN [dbo].[Modelo_Predictivo_Version] mpv
             ON  mpv.[mpv_modelo_predictivo]   = mpr.[mpr_id]
             AND mpv.[mpv_plan_version_estado] = 2        -- PUBLICADO
             AND mpv.[mpv_habilitado]          = 1
     WHERE mpr.[mpr_codigo]     = N'TENDENCIA VARIABLE'
       AND mpr.[mpr_habilitado] = 1
     ORDER BY mpv.[mpv_numero] DESC

    IF @MPV IS NULL
    BEGIN
        RAISERROR('No hay una version publicada del modelo de tendencia.', 16, 1)
        RETURN
    END

    /* Los parametros salen del modelo, con un valor por omision por si la
       fila viniera sin JSON. Que vivan en la fila y no aca es lo que permite
       ajustar el criterio de una planta sin tocar el procedimiento. */
    DECLARE @VENTANA      INT = ISNULL(TRY_CAST(JSON_VALUE(@HIPER, '$.ventana_dia')      AS INT), 120)
    DECLARE @MINIMO       INT = ISNULL(TRY_CAST(JSON_VALUE(@HIPER, '$.lecturas_minimas') AS INT), 4)
    DECLARE @R2_MINIMO DECIMAL(5,4) =
        ISNULL(TRY_CAST(JSON_VALUE(@HIPER, '$.r2_minimo') AS DECIMAL(5,4)), 0.35)
    DECLARE @DIAS_CRITICO INT = ISNULL(TRY_CAST(JSON_VALUE(@HIPER, '$.dias_critico') AS INT), 7)
    DECLARE @DIAS_ALTO    INT = ISNULL(TRY_CAST(JSON_VALUE(@HIPER, '$.dias_alto')    AS INT), 30)

    DECLARE @HOY DATETIME = GETUTCDATE()

    /* ---------------------------------------------------------------------
       Las variables a evaluar. Se materializan primero para no recorrer la
       tabla viva mientras se le escriben predicciones.
       --------------------------------------------------------------------- */
    DECLARE @OBJETIVO TABLE
        ([ava_id]   INT PRIMARY KEY
        ,[activo]   INT
        ,[variable] INT
        ,[unidad]   INT
        ,[critico]  DECIMAL(18,6)
        ,[hecho]    BIT DEFAULT 0)

    INSERT INTO @OBJETIVO ([ava_id], [activo], [variable], [unidad], [critico])
    SELECT ava.[ava_id], ava.[ava_activo], ava.[ava_variable_medicion]
          ,ava.[ava_unidad_medida], ava.[ava_valor_critico]
      FROM [dbo].[Activo_Variable] ava
      JOIN [dbo].[Activo]          act ON act.[act_id] = ava.[ava_activo]
     WHERE ava.[ava_cliente]      = @CLIENTE
       AND ava.[ava_habilitado]   = 1
       AND ava.[ava_valor_critico] IS NOT NULL
       AND act.[act_habilitado]   = 1
       AND (@INSTALACION IS NULL OR act.[act_cliente_instalacion] = @INSTALACION)
       AND (@ACTIVO      IS NULL OR act.[act_id] = @ACTIVO)

    DECLARE @EMITIDAS INT = 0, @OMITIDAS INT = 0

    DECLARE @AVA INT, @ACT INT, @VAR INT, @UME INT, @CRIT DECIMAL(18,6)

    WHILE EXISTS (SELECT 1 FROM @OBJETIVO WHERE [hecho] = 0)
    BEGIN

        SELECT TOP 1 @AVA = [ava_id], @ACT = [activo], @VAR = [variable]
                    ,@UME = [unidad], @CRIT = [critico]
          FROM @OBJETIVO WHERE [hecho] = 0 ORDER BY [ava_id]

        UPDATE @OBJETIVO SET [hecho] = 1 WHERE [ava_id] = @AVA

        /* ---- Las lecturas de la ventana ---- */
        DECLARE @LECTURAS TABLE ([x] DECIMAL(18,6), [y] DECIMAL(18,6))
        DELETE FROM @LECTURAS

        DECLARE @DESDE DATETIME = DATEADD(DAY, -@VENTANA, @HOY)

        INSERT INTO @LECTURAS ([x], [y])
        SELECT DATEDIFF(HOUR, @DESDE, amd.[amd_fecha_medicion_utc]) / 24.0
              ,amd.[amd_valor_canonico]
          FROM [dbo].[Activo_Medicion] amd
         WHERE amd.[amd_cliente]          = @CLIENTE
           AND amd.[amd_activo]           = @ACT
           AND amd.[amd_activo_variable]  = @AVA
           AND amd.[amd_medicion_calidad] = 1              -- solo lecturas validas
           AND amd.[amd_fecha_medicion_utc] >= @DESDE

        DECLARE @N INT = (SELECT COUNT(*) FROM @LECTURAS)

        IF @N < @MINIMO
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        /* ---- Minimos cuadrados ----
           Sxx y Sxy son las sumas centradas; con ellas salen la pendiente, el
           intercepto, el R2 y el error estandar sin recorrer los datos otra
           vez. */
        DECLARE @SX DECIMAL(28,10), @SY DECIMAL(28,10)
               ,@SXX DECIMAL(28,10), @SXY DECIMAL(28,10), @SYY DECIMAL(28,10)
               ,@MX DECIMAL(28,10), @MY DECIMAL(28,10)

        SELECT @SX = SUM([x]), @SY = SUM([y])
              ,@SXX = SUM([x] * [x]), @SXY = SUM([x] * [y]), @SYY = SUM([y] * [y])
          FROM @LECTURAS

        SET @MX = @SX / @N
        SET @MY = @SY / @N

        DECLARE @CXX DECIMAL(28,10) = @SXX - @N * @MX * @MX
        DECLARE @CXY DECIMAL(28,10) = @SXY - @N * @MX * @MY
        DECLARE @CYY DECIMAL(28,10) = @SYY - @N * @MY * @MY

        /* Todas las lecturas el mismo dia: no hay tendencia que ajustar. */
        IF @CXX IS NULL OR @CXX <= 0.000001
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        DECLARE @PENDIENTE DECIMAL(28,10) = @CXY / @CXX
        DECLARE @INTERCEPTO DECIMAL(28,10) = @MY - @PENDIENTE * @MX
        DECLARE @R2 DECIMAL(28,10) =
            CASE WHEN @CYY <= 0.000001 THEN 0
                 ELSE (@CXY * @CXY) / (@CXX * @CYY) END

        /* La variable no sube, o sube sin patron: no hay nada que anunciar. */
        IF @PENDIENTE <= 0 OR @R2 < @R2_MINIMO
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        /* ---- Donde esta hoy y cuando cruza ---- */
        DECLARE @HOY_X DECIMAL(28,10) = DATEDIFF(HOUR, @DESDE, @HOY) / 24.0
        DECLARE @ACTUAL DECIMAL(28,10) =
            (SELECT TOP 1 [y] FROM @LECTURAS ORDER BY [x] DESC)

        /* Cuanto abarcan las lecturas de verdad, que NO es el largo de la
           ventana: la ventana son 120 dias y los datos pueden ser de los
           ultimos 60. Decir «sostenido en 120 dias» cuando solo hay 60 de
           historia es exagerar la evidencia, justo en la frase que la persona
           va a usar para decidir si desarma la maquina. */
        DECLARE @ABARCA INT = (SELECT CAST(MAX([x]) - MIN([x]) AS INT) FROM @LECTURAS)

        /* Ya paso el limite: eso no es una prediccion, es un hecho, y lo tiene
           que levantar la alerta de medicion fuera de rango -que existe y es
           de otro tipo-. Anunciar como «va a pasar» algo que ya paso le quita
           urgencia a lo que ya es urgente. */
        IF @ACTUAL >= @CRIT
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        DECLARE @X_CRUCE DECIMAL(28,10) = (@CRIT - @INTERCEPTO) / @PENDIENTE
        DECLARE @DIAS DECIMAL(28,10) = @X_CRUCE - @HOY_X

        IF @DIAS <= 0 OR @DIAS > @HORIZONTE
        BEGIN
            SET @OMITIDAS = @OMITIDAS + 1
            CONTINUE
        END

        /* ---- El intervalo, del error estandar de la pendiente ----
           s^2 = residuos / (n-2); se_pendiente = s / raiz(Sxx). Con n = 4 el
           divisor es 2 y el intervalo sale ancho, que es exactamente lo que
           corresponde: cuatro puntos no permiten afirmar mucho. */
        DECLARE @SSE DECIMAL(28,10) = @CYY - @PENDIENTE * @CXY
        IF @SSE < 0 SET @SSE = 0

        DECLARE @S DECIMAL(28,10) =
            CASE WHEN @N > 2 THEN SQRT(@SSE / (@N - 2)) ELSE 0 END
        DECLARE @SE_PEND DECIMAL(28,10) = @S / SQRT(@CXX)

        DECLARE @P_ALTA DECIMAL(28,10) = @PENDIENTE + 1.96 * @SE_PEND
        DECLARE @P_BAJA DECIMAL(28,10) = @PENDIENTE - 1.96 * @SE_PEND

        --  Sube mas rapido -> cruza antes. Por eso el limite inferior de dias
        --  sale de la pendiente ALTA.
        DECLARE @DIAS_MIN DECIMAL(28,10) =
            CASE WHEN @P_ALTA > 0 THEN (@CRIT - @ACTUAL) / @P_ALTA ELSE @DIAS END

        --  Si la pendiente baja no es positiva, la recta podria no cruzar
        --  nunca: el limite superior se corta en el horizonte en vez de irse
        --  al infinito.
        DECLARE @DIAS_MAX DECIMAL(28,10) =
            CASE WHEN @P_BAJA > 0
                 THEN (@CRIT - @ACTUAL) / @P_BAJA
                 ELSE CAST(@HORIZONTE AS DECIMAL(28,10)) * 4 END

        IF @DIAS_MIN < 0 SET @DIAS_MIN = 0
        IF @DIAS_MAX < @DIAS_MIN SET @DIAS_MAX = @DIAS_MIN

        /* ---- La probabilidad: cuanto del intervalo cae dentro del horizonte ---- */
        DECLARE @PROB DECIMAL(9,6)

        IF @DIAS_MAX <= @DIAS_MIN
            SET @PROB = CASE WHEN @DIAS <= @HORIZONTE THEN 1 ELSE 0 END
        ELSE
            SET @PROB = CAST(
                CASE
                    WHEN @DIAS_MIN >= @HORIZONTE THEN 0
                    WHEN @DIAS_MAX <= @HORIZONTE THEN 1
                    ELSE (@HORIZONTE - @DIAS_MIN) / (@DIAS_MAX - @DIAS_MIN)
                END AS DECIMAL(9,6))

        IF @PROB < 0 SET @PROB = 0
        IF @PROB > 1 SET @PROB = 1

        /* ---- Severidad y probabilidad responden preguntas distintas ----
           La probabilidad contesta «¿va a cruzar dentro del horizonte?» y la
           severidad contesta «¿que tan pronto?». Son ejes independientes y
           mezclarlos da un resultado inutil: con un horizonte de 90 dias, casi
           todo lo que cruza tiene probabilidad 1, y si la severidad saliera de
           ahi **todo seria critico** -incluida una vibracion que recien cruza
           en cincuenta dias-. Una pantalla donde todo es critico no prioriza
           nada.

           Asi que la probabilidad decide **si se alerta** (los umbrales del
           modelo: hay que creerle lo suficiente) y los dias deciden **con que
           urgencia**, contra los plazos declarados en los hiperparametros. */
        DECLARE @SEV INT =
            CASE WHEN @DIAS <= @DIAS_CRITICO THEN 5     -- CRITICA
                 WHEN @DIAS <= @DIAS_ALTO    THEN 4     -- ALTA
                 ELSE 3 END                             -- ADVERTENCIA

        /* ---- Una prediccion por (activo, variable, dia) ---- */
        DECLARE @UUID UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER,
            HASHBYTES('MD5', CONCAT(N'TEND|', @CLIENTE, N'|', @ACT, N'|', @AVA,
                                    N'|', CONVERT(NVARCHAR(10), @HOY, 112))))

        IF EXISTS (SELECT 1 FROM [dbo].[Prediccion] WHERE [pre_uuid] = @UUID)
            CONTINUE

        DECLARE @FECHA_EVENTO DATETIME = DATEADD(HOUR, CAST(@DIAS * 24 AS INT), @HOY)

        BEGIN TRY
            BEGIN TRANSACTION

            INSERT INTO [dbo].[Prediccion]
                ([pre_uuid], [pre_cliente], [pre_modelo_predictivo_version]
                ,[pre_prediccion_estado], [pre_activo]
                ,[pre_valor], [pre_probabilidad], [pre_dia_restante]
                ,[pre_fecha_evento_estimada_utc], [pre_severidad], [pre_confianza]
                ,[pre_intervalo_inferior], [pre_intervalo_superior]
                ,[pre_fecha_calculo_utc], [pre_fecha_vigencia_hasta_utc]
                ,[pre_usuario_creacion], [pre_fecha_creacion], [pre_habilitado])
            VALUES
                (@UUID, @CLIENTE, @MPV
                ,1, @ACT                                   -- 1 = GENERADA
                ,CAST(@ACTUAL AS DECIMAL(18,6)), @PROB, CAST(@DIAS AS INT)
                ,@FECHA_EVENTO, @SEV, CAST(@R2 AS DECIMAL(9,6))
                ,CAST(@DIAS_MIN AS DECIMAL(18,6)), CAST(@DIAS_MAX AS DECIMAL(18,6))
                /* Vigente hasta que se vuelva a calcular: una prediccion vieja
                   colgada en la pantalla es peor que ninguna. */
                ,@HOY, DATEADD(DAY, 7, @HOY)
                ,@USUARIO, [dbo].[FNC_AHORA](), 1)

            DECLARE @PRE INT = SCOPE_IDENTITY()

            /* ---- Lo que se uso para calcularla ---- */
            INSERT INTO [dbo].[Prediccion_Caracteristica]
                ([pcr_prediccion], [pcr_caracteristica_modelo], [pcr_valor]
                ,[pcr_imputado], [pcr_usuario_creacion], [pcr_fecha_creacion])
            SELECT @PRE, cmo.[cmo_id]
                  ,CASE cmo.[cmo_codigo]
                       WHEN N'VALOR_ACTUAL'   THEN CAST(@ACTUAL AS DECIMAL(18,6))
                       WHEN N'PENDIENTE_DIA'  THEN CAST(@PENDIENTE AS DECIMAL(18,6))
                       WHEN N'LECTURAS'       THEN @N
                       WHEN N'R2'             THEN CAST(@R2 AS DECIMAL(18,6))
                       WHEN N'UMBRAL_CRITICO' THEN @CRIT
                   END
                  ,0, @USUARIO, [dbo].[FNC_AHORA]()
              FROM [dbo].[Caracteristica_Modelo] cmo
              JOIN [dbo].[Modelo_Predictivo_Version] mv ON mv.[mpv_id] = @MPV
             WHERE cmo.[cmo_modelo_predictivo] = mv.[mpv_modelo_predictivo]
               AND cmo.[cmo_habilitado] = 1

            /* ---- Las tres razones ----
               Son frases sobre datos reales, no plantillas de marketing. Cada
               una nombra el numero del que sale, porque una razon que no se
               puede verificar no ayuda a decidir si desarmar una maquina. */
            DECLARE @SIMBOLO NVARCHAR(20) =
                ISNULL((SELECT [ume_simbolo] FROM [dbo].[Unidad_Medida] WHERE [ume_id] = @UME), N'')

            INSERT INTO [dbo].[Prediccion_Explicacion]
                ([pex_prediccion], [pex_caracteristica_modelo], [pex_orden], [pex_texto]
                ,[pex_contribucion], [pex_direccion]
                ,[pex_valor_observado], [pex_valor_referencia]
                ,[pex_usuario_creacion], [pex_fecha_creacion])
            VALUES
                 (@PRE
                 ,(SELECT TOP 1 [cmo_id] FROM [dbo].[Caracteristica_Modelo] c
                    JOIN [dbo].[Modelo_Predictivo_Version] m ON m.[mpv_id] = @MPV
                   WHERE c.[cmo_modelo_predictivo] = m.[mpv_modelo_predictivo]
                     AND c.[cmo_codigo] = N'PENDIENTE_DIA')
                 ,1
                 ,CONCAT(N'Viene subiendo ',
                         FORMAT(@PENDIENTE, N'0.###', N'es-CL'), N' ', @SIMBOLO,
                         N' por dia, sostenido en los ultimos ',
                         CAST(@ABARCA AS NVARCHAR(10)), N' dias.')
                 ,NULL, N'AUMENTA'
                 ,CAST(@PENDIENTE AS DECIMAL(18,6)), NULL
                 ,@USUARIO, [dbo].[FNC_AHORA]())

                ,(@PRE
                 ,(SELECT TOP 1 [cmo_id] FROM [dbo].[Caracteristica_Modelo] c
                    JOIN [dbo].[Modelo_Predictivo_Version] m ON m.[mpv_id] = @MPV
                   WHERE c.[cmo_modelo_predictivo] = m.[mpv_modelo_predictivo]
                     AND c.[cmo_codigo] = N'VALOR_ACTUAL')
                 ,2
                 ,CONCAT(N'Hoy marca ', FORMAT(@ACTUAL, N'0.#', N'es-CL'), N' ', @SIMBOLO,
                         N' y el limite del equipo es ',
                         FORMAT(@CRIT, N'0.#', N'es-CL'), N' ', @SIMBOLO, N'.')
                 ,NULL, N'AUMENTA'
                 ,CAST(@ACTUAL AS DECIMAL(18,6)), @CRIT
                 ,@USUARIO, [dbo].[FNC_AHORA]())

                ,(@PRE
                 ,(SELECT TOP 1 [cmo_id] FROM [dbo].[Caracteristica_Modelo] c
                    JOIN [dbo].[Modelo_Predictivo_Version] m ON m.[mpv_id] = @MPV
                   WHERE c.[cmo_modelo_predictivo] = m.[mpv_modelo_predictivo]
                     AND c.[cmo_codigo] = N'R2')
                 ,3
                 ,CONCAT(N'La subida es pareja: ', CAST(@N AS NVARCHAR(10)),
                         N' lecturas se ajustan a una recta con R2 ',
                         FORMAT(@R2, N'0.00', N'es-CL'), N'.')
                 ,NULL, NULL
                 ,CAST(@R2 AS DECIMAL(18,6)), @R2_MINIMO
                 ,@USUARIO, [dbo].[FNC_AHORA]())

            /* ---- La alerta, solo si pasa el umbral declarado ----
               Bajo 0,60 la prediccion queda registrada pero no interrumpe a
               nadie: se ve en el panel de SIGMA AI y no genera alerta. Alertar
               por todo es la forma mas rapida de que dejen de mirar las
               alertas. */
            IF @PROB >= @UMB_ALERTA
            BEGIN
                DECLARE @NOMBRE NVARCHAR(200) =
                    (SELECT CONCAT([act_codigo], N' ', [act_nombre]) FROM [dbo].[Activo] WHERE [act_id] = @ACT)
                DECLARE @VNOMBRE NVARCHAR(200) =
                    (SELECT [vme_nombre] FROM [dbo].[Variable_Medicion] WHERE [vme_id] = @VAR)
                DECLARE @INST INT =
                    (SELECT [act_cliente_instalacion] FROM [dbo].[Activo] WHERE [act_id] = @ACT)

                INSERT INTO [dbo].[Alerta]
                    ([ale_uuid], [ale_cliente], [ale_cliente_instalacion]
                    ,[ale_alerta_tipo], [ale_alerta_estado], [ale_severidad]
                    ,[ale_titulo], [ale_descripcion], [ale_fecha_deteccion_utc]
                    ,[ale_activo], [ale_prediccion]
                    ,[ale_valor_observado], [ale_valor_umbral], [ale_unidad_medida]
                    ,[ale_fecha_primera_ocurrencia_utc], [ale_fecha_ultima_ocurrencia_utc]
                    ,[ale_ocurrencias]
                    ,[ale_usuario_creacion], [ale_fecha_creacion], [ale_habilitado])
                VALUES
                    (NEWID(), @CLIENTE, @INST
                    ,4, 1, @SEV                            -- 4 = PREDICCION RIESGO, 1 = NUEVA
                    ,CONCAT(@VNOMBRE, N' en alza en ', @NOMBRE)
                    ,CONCAT(N'La ', LOWER(@VNOMBRE), N' viene subiendo y, de seguir asi, alcanza el limite del equipo en unos ',
                            CAST(CAST(@DIAS AS INT) AS NVARCHAR(10)), N' dias.')
                    ,@HOY
                    ,@ACT, @PRE
                    ,CAST(@ACTUAL AS DECIMAL(18,6)), @CRIT, @UME
                    ,@HOY, @HOY, 1
                    ,@USUARIO, [dbo].[FNC_AHORA](), 1)

                UPDATE [dbo].[Prediccion]
                   SET [pre_alerta] = SCOPE_IDENTITY()
                 WHERE [pre_id] = @PRE
            END

            COMMIT TRANSACTION
            SET @EMITIDAS = @EMITIDAS + 1
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
            DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
            RAISERROR(@MSG, 16, 1)
            RETURN
        END CATCH

    END

    SELECT @EMITIDAS AS [EMITIDAS], @OMITIDAS AS [OMITIDAS]

END
GO

-- ---------- API_INS_BITACORA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_BITACORA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
--   Idempotente por `bit_uuid`, generado en el telefono al empezar a escribir.
--   Si se generara al enviar, un reintento de la cola dejaria el turno contado
--   dos veces -y en una bitacora eso no es un duplicado molesto, es un relato
--   que se contradice-.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA]
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@INSTALACION       INT
    ,@TIPO              INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@TITULO            NVARCHAR(400)    = NULL
    ,@AREA              INT              = NULL
    ,@ACTIVO            INT              = NULL
    ,@COMPONENTE        INT              = NULL
    ,@ORDEN_TRABAJO     INT              = NULL
    ,@FECHA_EVENTO      DATETIME         = NULL
    ,@TURNO             NVARCHAR(40)     = NULL
    ,@REQUIERE_ATENCION BIT              = 0
    ,@SEVERIDAD         INT              = NULL
    ,@LATITUD           DECIMAL(9,6)     = NULL
    ,@LONGITUD          DECIMAL(9,6)     = NULL
    ,@OFFLINE           BIT              = 0
    ,@ENTRADA_MODO      INT              = 1        -- 1 = TECLADO
    ,@DICTADO_UUID      UNIQUEIDENTIFIER = NULL
    ,@TEXTO_DICTADO     NVARCHAR(MAX)    = NULL
    ,@DICTADO_CONFIANZA DECIMAL(5,4)     = NULL
    ,@DICTADO_SEGUNDOS  INT              = NULL
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        /* ---- Reenvio de la cola ---- */
        DECLARE @YA INT
        SELECT @YA = [bit_id] FROM [dbo].[Bitacora] WHERE [bit_uuid] = @UUID

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SET @ID = @YA
            SELECT @YA AS [bit_id], 1 AS [YA_ESTABA]
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada esta vacia.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                        WHERE [ciu_id_instalacion] = @INSTALACION
                          AND [ciu_id_usuario]     = @USUARIO
                          AND ISNULL([ciu_habilitado], 0) = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No estas afiliado a esa planta.', 16, 1)
            RETURN
        END

        /* Un incidente sin severidad no se puede priorizar despues, y la
           bitacora sirve justamente para eso: que el turno siguiente sepa que
           mirar primero. */
        IF @TIPO = 3 AND @SEVERIDAD IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Un incidente necesita su severidad.', 16, 1)
            RETURN
        END

        /* ---- El dictado, si lo hubo ---- */
        DECLARE @DVO INT = NULL

        IF @DICTADO_UUID IS NOT NULL
            EXEC [dbo].[API_INS_DICTADO_VOZ]
                 @UUID        = @DICTADO_UUID
                ,@USUARIO     = @USUARIO
                ,@CLIENTE     = @CLIENTE
                ,@TEXTO       = @TEXTO_DICTADO      -- lo crudo, no lo corregido
                ,@CONFIANZA   = @DICTADO_CONFIANZA
                ,@SEGUNDOS    = @DICTADO_SEGUNDOS
                ,@DISPOSITIVO = @DISPOSITIVO
                ,@ID          = @DVO OUTPUT

        INSERT INTO [dbo].[Bitacora]
            ([bit_uuid], [bit_cliente], [bit_cliente_instalacion]
            ,[bit_instalacion_area], [bit_bitacora_tipo]
            ,[bit_activo], [bit_activo_componente], [bit_orden_trabajo]
            ,[bit_titulo], [bit_texto], [bit_fecha_evento_utc], [bit_turno]
            ,[bit_requiere_atencion], [bit_severidad]
            ,[bit_dictado_voz], [bit_entrada_modo]
            ,[bit_latitud], [bit_longitud]
            ,[bit_offline_creado], [bit_fecha_sincronizacion_utc]
            ,[bit_usuario_creacion], [bit_fecha_creacion])
        VALUES
            (@UUID, @CLIENTE, @INSTALACION
            ,@AREA, @TIPO
            ,@ACTIVO, @COMPONENTE, @ORDEN_TRABAJO
            ,@TITULO, @TEXTO, ISNULL(@FECHA_EVENTO, GETUTCDATE()), @TURNO
            ,@REQUIERE_ATENCION, @SEVERIDAD
            ,@DVO, CASE WHEN @DVO IS NOT NULL THEN 2 ELSE @ENTRADA_MODO END
            ,@LATITUD, @LONGITUD
            ,@OFFLINE, GETUTCDATE()
            ,@USUARIO, [dbo].[FNC_AHORA]())

        DECLARE @BIT INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SET @ID = @BIT
        SELECT @BIT AS [bit_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_BITACORA_COMENTARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_BITACORA_COMENTARIO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
--   Igual que en las tareas: append-only, con hilo por `bco_comentario_padre`
--   y sin uuid propio, asi que la proteccion contra el reenvio es el contenido
--   dentro de una ventana corta.
--
--   Comentar es lo que puede hacer un tercero. Rectificar, no: agregar es de
--   cualquiera, corregir el relato es de quien lo escribio.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA_COMENTARIO]
     @ID INT = NULL OUTPUT
    ,@BITACORA          INT
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@PADRE             INT              = NULL
    ,@DICTADO_UUID      UNIQUEIDENTIFIER = NULL
    ,@TEXTO_DICTADO     NVARCHAR(MAX)    = NULL
    ,@DICTADO_CONFIANZA DECIMAL(5,4)     = NULL
    ,@DICTADO_SEGUNDOS  INT              = NULL
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario esta vacio.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Bitacora] bit
                         JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                                ON  ciu.[ciu_id_instalacion] = bit.[bit_cliente_instalacion]
                                AND ciu.[ciu_id_usuario]     = @USUARIO
                                AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                        WHERE bit.[bit_id]      = @BITACORA
                          AND bit.[bit_cliente] = @CLIENTE)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @PADRE IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora_Comentario]
                            WHERE [bco_id] = @PADRE
                              AND [bco_bitacora] = @BITACORA)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario al que respondes no es de esta entrada.', 16, 1)
            RETURN
        END

        DECLARE @YA INT

        SELECT TOP 1 @YA = [bco_id]
          FROM [dbo].[Bitacora_Comentario]
         WHERE [bco_bitacora]        = @BITACORA
           AND [bco_usuario_creacion] = @USUARIO
           AND [bco_texto]            = @TEXTO
           AND [bco_fecha_creacion]  >= DATEADD(MINUTE, -5, [dbo].[FNC_AHORA]())
         ORDER BY [bco_id] DESC

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SET @ID = @YA
            SELECT @YA AS [bco_id], 1 AS [YA_ESTABA]
            RETURN
        END

        DECLARE @DVO INT = NULL

        IF @DICTADO_UUID IS NOT NULL
            EXEC [dbo].[API_INS_DICTADO_VOZ]
                 @UUID        = @DICTADO_UUID
                ,@USUARIO     = @USUARIO
                ,@CLIENTE     = @CLIENTE
                ,@TEXTO       = @TEXTO_DICTADO
                ,@CONFIANZA   = @DICTADO_CONFIANZA
                ,@SEGUNDOS    = @DICTADO_SEGUNDOS
                ,@DISPOSITIVO = @DISPOSITIVO
                ,@ID          = @DVO OUTPUT

        INSERT INTO [dbo].[Bitacora_Comentario]
            ([bco_bitacora], [bco_comentario_padre], [bco_texto]
            ,[bco_dictado_voz], [bco_usuario_creacion], [bco_fecha_creacion])
        VALUES
            (@BITACORA, @PADRE, @TEXTO, @DVO, @USUARIO, [dbo].[FNC_AHORA]())

        DECLARE @BCO INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SET @ID = @BCO
        SELECT @BCO AS [bco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_BITACORA_RECTIFICACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_BITACORA_RECTIFICACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
--   No es un UPDATE. La entrada original queda intacta y esto agrega una fila
--   con el texto corregido y **el motivo, que es obligatorio**.
--
--   Sin motivo la rectificacion no vale nada: quien lea la bitacora despues
--   necesita saber si el texto cambio porque el primero estaba mal escrito,
--   porque se supo algo nuevo, o porque a alguien no le gusto como sonaba. Las
--   tres cosas se leen muy distinto.
--
--   Solo puede rectificar quien escribio. Que un tercero corrija el relato de
--   otro convierte la bitacora en un documento sin autor.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_BITACORA_RECTIFICACION]
     @ID INT = NULL OUTPUT
    ,@BITACORA  INT
    ,@USUARIO   INT
    ,@CLIENTE   INT
    ,@TEXTO     NVARCHAR(MAX)
    ,@MOTIVO    NVARCHAR(1000)
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @AUTOR INT, @ORIGINAL NVARCHAR(MAX)

        SELECT @AUTOR = bit.[bit_usuario_creacion]
              ,@ORIGINAL = bit.[bit_texto]
          FROM [dbo].[Bitacora] bit
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = bit.[bit_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE bit.[bit_id]      = @BITACORA
           AND bit.[bit_cliente] = @CLIENTE

        IF @AUTOR IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La entrada no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @AUTOR <> @USUARIO
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Solo quien escribio la entrada puede rectificarla. Si hay algo que agregar, comenta.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El texto rectificado esta vacio.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@MOTIVO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Para rectificar hay que decir por que.', 16, 1)
            RETURN
        END

        /* El texto vigente: el ultimo rectificado, o el original si es la
           primera correccion. Rectificar dejandolo igual no aporta nada y
           ensucia la historia. */
        DECLARE @VIGENTE NVARCHAR(MAX) =
            ISNULL((SELECT TOP 1 [bre_texto_rectificado]
                      FROM [dbo].[Bitacora_Rectificacion]
                     WHERE [bre_bitacora] = @BITACORA
                     ORDER BY [bre_id] DESC), @ORIGINAL)

        IF @TEXTO = @VIGENTE
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El texto es el mismo que ya estaba.', 16, 1)
            RETURN
        END

        INSERT INTO [dbo].[Bitacora_Rectificacion]
            ([bre_bitacora], [bre_texto_rectificado], [bre_motivo]
            ,[bre_usuario_creacion], [bre_fecha_creacion])
        VALUES
            (@BITACORA, @TEXTO, @MOTIVO, @USUARIO, [dbo].[FNC_AHORA]())

        DECLARE @BRE INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SET @ID = @BRE
        SELECT @BRE AS [bre_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_CHECKLIST_EJECUCION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_CHECKLIST_EJECUCION (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
--   Idempotente por uuid. Y ademas: si esta persona ya tiene un BORRADOR de
--   esta ocurrencia, se devuelve ese en vez de crear otro. Una pauta a medias
--   que se abandona y se rehace pierde lo caminado, y en terreno eso significa
--   volver a recorrer la planta.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_CHECKLIST_EJECUCION]
     @ID INT = NULL OUTPUT
    ,@UUID          UNIQUEIDENTIFIER
    ,@USUARIO       INT
    ,@CLIENTE       INT
    ,@OCURRENCIA    INT            = NULL
    ,@VERSION       INT            = NULL
    ,@ACTIVO        INT            = NULL
    ,@DISPOSITIVO   NVARCHAR(200)  = NULL
    ,@OFFLINE       BIT            = 0
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @YA INT

        SELECT @YA = [cej_id]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_uuid]    = @UUID
           AND [cej_cliente] = @CLIENTE

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SET @ID = @YA
            SELECT @YA AS [cej_id], 1 AS [YA_EXISTIA]
            RETURN
        END

        /* Un borrador previo de la misma ocurrencia se retoma. */
        IF @OCURRENCIA IS NOT NULL
        BEGIN
            SELECT TOP 1 @YA = [cej_id]
              FROM [dbo].[Checklist_Ejecucion]
             WHERE [cej_checklist_ocurrencia]       = @OCURRENCIA
               AND [cej_usuario_ejecutor]           = @USUARIO
               AND [cej_checklist_ejecucion_estado] = 1
               AND [cej_habilitado]                 = 1
             ORDER BY [cej_id] DESC

            IF @YA IS NOT NULL
            BEGIN
                COMMIT TRANSACTION
                SET @ID = @YA
                SELECT @YA AS [cej_id], 1 AS [YA_EXISTIA]
                RETURN
            END
        END

        /* La version: de la ocurrencia si viene, del parametro si no. */
        DECLARE @VER INT = @VERSION

        IF @VER IS NULL AND @OCURRENCIA IS NOT NULL
            SELECT @VER = [coc_checklist_plantilla_version]
                  ,@ACTIVO = ISNULL(@ACTIVO, [coc_activo])
              FROM [dbo].[Checklist_Ocurrencia]
             WHERE [coc_id]      = @OCURRENCIA
               AND [coc_cliente] = @CLIENTE

        IF @VER IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No se indico que pauta ejecutar.', 16, 1)
            RETURN
        END

        /* Solo se ejecutan versiones PUBLICADAS. Una en borrador todavia se
           esta escribiendo, y una retirada dejo de ser la norma: llenarla
           produciria un registro que nadie puede defender en una auditoria. */
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Version]
                        WHERE [cpv_id] = @VER
                          AND [cpv_checklist_version_estado] = 2
                          AND [cpv_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esa version de la pauta no esta publicada.', 16, 1)
            RETURN
        END

        DECLARE @TOTAL INT =
            (SELECT COUNT(*) FROM [dbo].[Checklist_Plantilla_Item]
              WHERE [cpi_checklist_plantilla_version] = @VER
                AND [cpi_habilitado] = 1)

        INSERT INTO [dbo].[Checklist_Ejecucion]
            ([cej_uuid], [cej_cliente], [cej_checklist_ocurrencia]
            ,[cej_checklist_plantilla_version], [cej_activo]
            ,[cej_usuario_ejecutor], [cej_checklist_ejecucion_estado]
            ,[cej_fecha_inicio_utc], [cej_dispositivo], [cej_offline_creado]
            ,[cej_item_total], [cej_item_respondido], [cej_item_no_conforme]
            ,[cej_usuario_creacion], [cej_fecha_creacion], [cej_habilitado])
        VALUES
            (@UUID, @CLIENTE, @OCURRENCIA
            ,@VER, @ACTIVO
            ,@USUARIO, 1                        -- 1 BORRADOR
            ,GETUTCDATE(), @DISPOSITIVO, @OFFLINE
            ,@TOTAL, 0, 0
            ,@USUARIO, [dbo].[FNC_AHORA](), 1)

        DECLARE @CEJ INT = SCOPE_IDENTITY()

        /* La ocurrencia pasa a EN EJECUCION para que no aparezca dos veces en
           la bandeja de otro. */
        IF @OCURRENCIA IS NOT NULL
            UPDATE [dbo].[Checklist_Ocurrencia]
               SET [coc_checklist_ocurrencia_estado] = 3
                  ,[coc_usuario_actualizacion]       = @USUARIO
                  ,[coc_fecha_actualizacion]         = [dbo].[FNC_AHORA]()
             WHERE [coc_id] = @OCURRENCIA
               AND [coc_checklist_ocurrencia_estado] IN (1, 2)

        COMMIT TRANSACTION
        SET @ID = @CEJ
        SELECT @CEJ AS [cej_id], 0 AS [YA_EXISTIA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_COMPARTIR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_COMPARTIR (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   API_INS_COMPARTIR - deja el aviso en la bandeja del compaÃ±ero

   POR QUE EL TITULO LO ARMA EL SP Y NO LA APP

     Â«Ramiro Perez te compartio OT-1Â» tiene que decir lo mismo venga del
     telefono de quien sea. Si lo armara la app, dos versiones distintas
     escribirian dos textos para el mismo hecho, y el que quede guardado
     dependeria de quien tenga la app mas vieja.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_INS_COMPARTIR]
@ID           INT = NULL OUTPUT,
@CLIENTE      INT,
@USUARIO      INT,
@DESTINATARIO INT,
@ENTIDAD      VARCHAR(20),
@ENTIDAD_ID   INT,
@MENSAJE      NVARCHAR(500) = NULL,
@UUID         UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

/* Idempotencia, igual que el resto de las escrituras de la app: sin seÃ±al se
   reintenta, y sin esto el compaÃ±ero recibiria el mismo aviso cuatro veces. */
IF (@UUID IS NOT NULL)
BEGIN
    SET @ID = NULL
    SELECT @ID = ale_id FROM [dbo].[Alerta] WHERE ale_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID AS [ID], '200' AS [CODE], 'Ya estaba compartido.' AS [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

IF (@ENTIDAD NOT IN ('ORDEN', 'TAREA', 'ACTIVO'))
BEGIN
    RAISERROR('1.- ESE TIPO DE TRABAJO NO SE PUEDE COMPARTIR.', 16, 1)
    RETURN -1
END

IF (@DESTINATARIO = @USUARIO)
BEGIN
    RAISERROR('2.- NO PUEDES COMPARTIRTE UN TRABAJO A TI MISMO.', 16, 1)
    RETURN -1
END

DECLARE @TIPO INT, @ESTADO INT, @QUIEN NVARCHAR(200), @QUE NVARCHAR(300)
DECLARE @INSTALACION INT, @ACTIVO INT, @ORDEN INT

SELECT @TIPO = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'COMPARTIDO'
/* NUEVA, no ABIERTA: los estados de este catalogo son NUEVA, RECONOCIDA,
   EN GESTION, RESUELTA y DESCARTADA. Un trabajo recien compartido esta sin
   mirar, que es exactamente NUEVA. */
SELECT TOP 1 @ESTADO = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'

SELECT @QUIEN = LTRIM(RTRIM(ISNULL(usu_nombre, N'') + N' ' + ISNULL(usu_apellido_paterno, N'')))
  FROM [dbo].[Usuario] WHERE usu_id = @USUARIO

/* Que se comparte, y de donde cuelga. El vinculo importa: es lo que deja que
   la pantalla de la alerta ABRA el trabajo en vez de solo describirlo. */
IF (@ENTIDAD = 'ORDEN')
BEGIN
    SELECT  @QUE = N'OT-' + CAST(otr_correlativo AS NVARCHAR(20)) + N' - ' + otr_titulo,
            @INSTALACION = otr_cliente_instalacion,
            @ACTIVO = otr_activo,
            @ORDEN = otr_id
      FROM  [dbo].[Orden_Trabajo]
     WHERE  otr_id = @ENTIDAD_ID AND otr_cliente = @CLIENTE
END
ELSE IF (@ENTIDAD = 'TAREA')
BEGIN
    SELECT  @QUE = TAR.tar_titulo,
            @INSTALACION = TAR.tar_cliente_instalacion,
            @ACTIVO = TAR.tar_activo
      FROM  [dbo].[Tarea_Ocurrencia] TOC
      JOIN  [dbo].[Tarea] TAR ON TAR.tar_id = TOC.toc_tarea
     WHERE  TOC.toc_id = @ENTIDAD_ID AND TAR.tar_cliente = @CLIENTE
END
ELSE
BEGIN
    SELECT  @QUE = act_codigo + N' - ' + act_nombre,
            @INSTALACION = act_cliente_instalacion,
            @ACTIVO = act_id
      FROM  [dbo].[Activo]
     WHERE  act_id = @ENTIDAD_ID AND act_cliente = @CLIENTE
END

IF (@QUE IS NULL)
BEGIN
    RAISERROR('3.- ESE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END

/* El destinatario tiene que trabajar en ESA instalacion. Compartir con quien
   no puede pisar la planta es mandarle un aviso que no puede atender. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                WHERE ciu_id_usuario     = @DESTINATARIO
                  AND ciu_id_instalacion = @INSTALACION
                  AND ISNULL(ciu_habilitado, 0) = 1)
BEGIN
    RAISERROR('4.- ESA PERSONA NO ESTA ASIGNADA A LA INSTALACION DEL TRABAJO.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO [dbo].[Alerta]
        (ale_uuid, ale_cliente, ale_cliente_instalacion, ale_alerta_tipo,
         ale_alerta_estado, ale_severidad, ale_titulo, ale_descripcion,
         ale_fecha_deteccion_utc, ale_activo, ale_orden_trabajo,
         ale_usuario_destinatario,
         ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
    VALUES
        (@UUID, @CLIENTE, @INSTALACION, @TIPO,
         @ESTADO, 2, @QUIEN + N' te compartiÃ³ ' + @QUE,
         ISNULL(@MENSAJE, N'Puede que necesite una mano. Ãbrelo para ver de quÃ© se trata.'),
         GETUTCDATE(), @ACTIVO, @ORDEN,
         @DESTINATARIO,
         @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('5.- NO FUE POSIBLE COMPARTIR EL TRABAJO.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION

SELECT @ID AS [ID], '201' AS [CODE], 'Compartido.' AS [MENSAJE]
RETURN 0
GO

-- ---------- API_INS_DICTADO_VOZ (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_DICTADO_VOZ (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     EL DICTADO POR VOZ COMO REGISTRO, NO COMO FLAG.
-- =============================================
-- POR QUE ESTE BLOQUE EXISTE
--
--   La primera version de los comentarios trataba `tco_dictado_voz` como una
--   marca de «esto se dicto» y escribia un 1. No lo es: es una **FK a
--   Dictado_Voz**, y la base lo rechazo. La correccion no fue cambiar el
--   valor, fue entender que el modelo pide otra cosa —y lo que pide es
--   bastante mas util que un booleano—.
--
--   `Dictado_Voz` la usan seis lugares -orden de trabajo, falla, bitacora,
--   comentario de bitacora, respuesta de checklist y comentario de tarea-. Que
--   sea una tabla compartida y no una columna en cada una significa que el
--   dictado es un hecho por si mismo: quien hablo, cuando, con que motor, en
--   que idioma, cuanto duro, cuantos intentos hizo falta, que confianza
--   devolvio el reconocedor y **que texto salio antes de que la persona lo
--   corrigiera**.
--
--   Esa ultima es la que importa. `dvo_texto` guarda la transcripcion cruda y
--   el comentario guarda lo que la persona dio por bueno. Si fueran el mismo
--   campo no habria forma de saber nunca si el reconocedor sirve en una sala
--   de maquinas -que es exactamente lo que hay que saber antes de apostar la
--   captura en terreno a la voz-.
--
-- EL AUDIO NO SE GUARDA
--
--   `dvo_archivo` queda en NULL siempre. Se graba lo que se transcribio, no la
--   voz: guardar audio de la gente trabajando es una carga de privacidad que
--   no hace falta para nada de lo que el sistema tiene que hacer. La columna
--   existe por si algun dia hay motivo; hoy no lo hay.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - REGISTRAR UN DICTADO
-- ---------------------------------------------------------------------------
--   Idempotente por `dvo_uuid`, generado en el telefono al terminar de
--   dictar. Si el envio se reintenta, devuelve el mismo id en vez de un
--   segundo dictado de la misma frase.
--
--   Nace en PROCESADO (3) y no en PENDIENTE: el reconocimiento ya ocurrio en
--   el telefono antes de llamar. PENDIENTE queda para el dia que exista un
--   motor en la nube que reciba audio y responda despues.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_DICTADO_VOZ]
     @UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@IDIOMA            NVARCHAR(20)   = N'es-CL'
    ,@MOTOR             INT            = 1        -- 1 = en el telefono
    ,@MODELO            NVARCHAR(200)  = NULL
    ,@CONFIANZA         DECIMAL(5,4)   = NULL
    ,@SEGUNDOS          INT            = NULL
    ,@INTENTOS          INT            = 1
    ,@CONFIRMADO        BIT            = 1
    ,@CONFIRMADO_VOZ    BIT            = 0
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
    ,@ID                INT            = NULL OUTPUT
AS
SET NOCOUNT ON

BEGIN

    SELECT @ID = [dvo_id] FROM [dbo].[Dictado_Voz] WHERE [dvo_uuid] = @UUID

    IF @ID IS NOT NULL
        RETURN

    DECLARE @IDI INT =
        (SELECT TOP 1 [idi_id] FROM [dbo].[Idioma]
          WHERE [idi_codigo] = @IDIOMA AND [idi_habilitado] = 1)

    /* Un codigo de idioma que el telefono reporte y aca no exista no puede
       botar el comentario: el dictado se guarda igual, en el idioma por
       omision, porque el texto vale mas que la etiqueta. */
    IF @IDI IS NULL
        SET @IDI = (SELECT TOP 1 [idi_id] FROM [dbo].[Idioma]
                     WHERE [idi_codigo] = N'es-CL')

    INSERT INTO [dbo].[Dictado_Voz]
        ([dvo_uuid], [dvo_cliente], [dvo_usuario], [dvo_fecha_utc]
        ,[dvo_archivo], [dvo_voz_motor], [dvo_modelo_version], [dvo_idioma]
        ,[dvo_texto], [dvo_confianza], [dvo_duracion_segundo], [dvo_intentos]
        ,[dvo_confirmado], [dvo_confirmado_por_voz], [dvo_fecha_confirmacion_utc]
        ,[dvo_dispositivo_uuid], [dvo_proceso_estado]
        ,[dvo_usuario_creacion], [dvo_fecha_creacion])
    VALUES
        (@UUID, @CLIENTE, @USUARIO, GETUTCDATE()
        ,NULL, @MOTOR, @MODELO, @IDI                       -- el audio no se guarda
        ,@TEXTO, @CONFIANZA, @SEGUNDOS, ISNULL(@INTENTOS, 1)
        ,@CONFIRMADO, @CONFIRMADO_VOZ
        ,CASE WHEN @CONFIRMADO = 1 THEN GETUTCDATE() END
        ,@DISPOSITIVO, 3
        ,@USUARIO, [dbo].[FNC_AHORA]())

    SET @ID = SCOPE_IDENTITY()

END
GO

-- ---------- API_INS_EVIDENCIA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_EVIDENCIA (P) · 3 [dbo].[FNC_AHORA]() reemplazado(s)
-- DESCRIPTION:     FOTOS DE EVIDENCIA DESDE EL TELEFONO.
-- =============================================
-- UN SP Y NO UNO POR PANTALLA
--
--   `Archivo_Vinculo` es polimorfica a proposito: tiene una columna por cada
--   cosa a la que se le puede colgar un archivo -orden, paso, falla, bitacora,
--   respuesta de checklist, hallazgo, permiso de trabajo, tarea-. El modelo ya
--   decidio que la evidencia es una sola idea con muchos duenos, asi que un
--   INS por pantalla seria repetir ocho veces la misma escritura y garantizar
--   que un dia difieran.
--
--   El @DESTINO dice a cual columna va. Es feo comparado con ocho SP, pero es
--   una fealdad que se lee en un solo lugar.
--
-- EL BLOB VA PRIMERO, LA FILA DESPUES
--
--   Es la regla que ya fijo `INS_ARCHIVO` y este bloque la respeta: una fila
--   sin blob es un enlace roto silencioso -alguien abre la foto meses despues
--   y no hay nada-, y un blob sin fila es basura que se puede recolectar. De
--   los dos desastres se elige el recuperable.
--
-- IDEMPOTENTE POR EL UUID DEL ARCHIVO
--
--   Lo genera el telefono al sacar la foto, no al enviarla. Una foto tomada
--   sin senal se reintenta varias veces; sin esto, la tarea quedaria con la
--   misma foto cuatro veces y nadie sabria cual mirar.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - REGISTRAR UNA EVIDENCIA YA SUBIDA AL BLOB
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_EVIDENCIA]
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT

    /* TAREA | ORDEN | PASO | RESPUESTA | FALLA | HALLAZGO | ACTIVO */
    ,@DESTINO           NVARCHAR(20)
    ,@DESTINO_ID        INT

    ,@CATEGORIA         INT            = 5          -- 5 = DURANTE
    ,@NOMBRE_ORIGINAL   NVARCHAR(255)
    ,@NOMBRE_ALMACENADO NVARCHAR(255)
    ,@RUTA              NVARCHAR(500)
    ,@MIME              NVARCHAR(100)  = N'image/jpeg'
    ,@EXTENSION         NVARCHAR(20)   = N'jpg'
    ,@BYTE              BIGINT
    ,@HASH              NVARCHAR(64)   = NULL
    ,@ANCHO             INT            = NULL
    ,@ALTO              INT            = NULL
    ,@LATITUD           DECIMAL(9,6)   = NULL
    ,@LONGITUD          DECIMAL(9,6)   = NULL
    ,@CAPTURA_UTC       DATETIME       = NULL
    ,@DISPOSITIVO       NVARCHAR(400)  = NULL
    ,@TITULO            NVARCHAR(400)  = NULL
    ,@DESCRIPCION       NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY

        DECLARE @DES NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@DESTINO, N''))))

        IF @DES NOT IN (N'TAREA', N'ORDEN', N'PASO', N'RESPUESTA',
                        N'FALLA', N'HALLAZGO', N'ACTIVO', N'BITACORA', N'COMPONENTE',
                        N'REPUESTO')
        BEGIN
            RAISERROR('Ese destino de evidencia no existe.', 16, 1)
            RETURN
        END

        /* ---- Reenvio de la cola: devolver lo mismo, no una segunda foto ---- */
        DECLARE @ARC INT

        SELECT @ARC = [arc_id] FROM [dbo].[Archivo] WHERE [arc_uuid] = @UUID

        IF @ARC IS NOT NULL
        BEGIN
            SET @ID = @ARC
            SELECT @ARC AS [arc_id], 1 AS [YA_ESTABA]
            RETURN
        END

        BEGIN TRANSACTION

        INSERT INTO [dbo].[Archivo]
            ([arc_uuid], [arc_cliente], [arc_archivo_categoria]
            ,[arc_nombre_original], [arc_nombre_almacenado], [arc_ruta]
            ,[arc_mime], [arc_extension], [arc_byte], [arc_hash]
            ,[arc_ancho_pixel], [arc_alto_pixel]
            ,[arc_latitud], [arc_longitud], [arc_fecha_captura_utc]
            ,[arc_dispositivo], [arc_archivo_antivirus_estado]
            ,[arc_usuario_creacion], [arc_fecha_creacion]
            ,[arc_usuario_actualizacion], [arc_fecha_actualizacion]
            ,[arc_habilitado])
        VALUES
            (@UUID, @CLIENTE, @CATEGORIA
            ,@NOMBRE_ORIGINAL, @NOMBRE_ALMACENADO, @RUTA
            ,@MIME, @EXTENSION, @BYTE, @HASH
            ,@ANCHO, @ALTO
            ,@LATITUD, @LONGITUD, @CAPTURA_UTC
            ,@DISPOSITIVO, 1                            -- 1 = PENDIENTE antivirus
            ,@USUARIO, [dbo].[FNC_AHORA]()
            ,@USUARIO, [dbo].[FNC_AHORA]()
            ,1)

        SET @ARC = SCOPE_IDENTITY()

        /* El orden dentro del destino: se muestran en el orden en que se
           sacaron, y con captura sin senal el id no respeta ese orden. */
        DECLARE @ORDEN INT =
            (SELECT ISNULL(MAX([avi_orden]), 0) + 1
               FROM [dbo].[Archivo_Vinculo]
              WHERE (@DES = N'TAREA'     AND [avi_tarea_ejecucion] = @DESTINO_ID)
                 OR (@DES = N'ORDEN'     AND [avi_orden_trabajo] = @DESTINO_ID)
                 OR (@DES = N'PASO'      AND [avi_orden_trabajo_paso] = @DESTINO_ID)
                 OR (@DES = N'RESPUESTA' AND [avi_checklist_ejecucion_respuesta] = @DESTINO_ID)
                 OR (@DES = N'FALLA'     AND [avi_falla] = @DESTINO_ID)
                 OR (@DES = N'HALLAZGO'  AND [avi_checklist_hallazgo] = @DESTINO_ID)
                 OR (@DES = N'ACTIVO'    AND [avi_activo] = @DESTINO_ID)
                 OR (@DES = N'BITACORA'  AND [avi_bitacora] = @DESTINO_ID)
                 OR (@DES = N'COMPONENTE' AND [avi_activo_componente] = @DESTINO_ID)
                 OR (@DES = N'REPUESTO'  AND [avi_repuesto] = @DESTINO_ID))

        INSERT INTO [dbo].[Archivo_Vinculo]
            ([avi_archivo]
            ,[avi_tarea_ejecucion], [avi_orden_trabajo], [avi_orden_trabajo_paso]
            ,[avi_checklist_ejecucion_respuesta], [avi_falla]
            ,[avi_checklist_hallazgo], [avi_activo], [avi_bitacora]
            ,[avi_activo_componente], [avi_repuesto]
            ,[avi_es_referencia], [avi_orden], [avi_titulo], [avi_descripcion]
            ,[avi_usuario_creacion], [avi_fecha_creacion], [avi_habilitado])
        VALUES
            (@ARC
            ,CASE WHEN @DES = N'TAREA'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'ORDEN'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'PASO'      THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'RESPUESTA' THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'FALLA'     THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'HALLAZGO'  THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'ACTIVO'    THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'BITACORA'  THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'COMPONENTE' THEN @DESTINO_ID END
            ,CASE WHEN @DES = N'REPUESTO'  THEN @DESTINO_ID END
            /* Una foto de terreno nunca es �de referencia�: la referencia es
               como deberia verse el equipo, y esto es como se veia. */
            ,0, @ORDEN, @TITULO, @DESCRIPCION
            ,@USUARIO, [dbo].[FNC_AHORA](), 1)

        COMMIT TRANSACTION
        SET @ID = @ARC
        SELECT @ARC AS [arc_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_MARCACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_MARCACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:			HECTOR LOHAUS
-- Fecha creación:	20-12-2023
-- Description:		INSERTA MARCACION
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[API_INS_MARCACION]
@ID INT = NULL OUTPUT
--,@ARCHIVO_BINARIO VARBINARY(MAX) = NULL
--,@ARCHIVO_ID INT = NULL
,@ARCHIVO_NOMBRE VARCHAR(500) = NULL
,@ARCHIVO_EXTENSION VARCHAR(500) = NULL
,@ARCHIVO_TAMANO VARCHAR(200) = NULL
,@ARCHIVO INT = NULL
,@USUARIO INT
,@TIPO_MARCA INT
,@FECHA DATETIME
,@GPS INT
,@LATITUD DECIMAL(9,6) = NULL
,@LONGITUD DECIMAL(9,6) = NULL
,@MODO_HORA_DISPOSITIVO INT
,@HORA_DISPOSITIVO_SERVIDOR INT
,@AUTO_MANUAL INT
,@HASH VARCHAR(70)
,@DISPOSITIVO VARCHAR(300)
,@ID_INSTALACION INT = NULL
,@BINARIO VARBINARY(MAX) = NULL

AS
SET NOCOUNT ON

BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT

	SELECT	@PAIS = UPA_ID_PAIS
	FROM	USUARIO_PAISES
	WHERE	UPA_ID_USUARIO = @USUARIO
	
	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)

	IF (@DATE_NOW IS NULL) BEGIN
		SET @DATE_NOW = [dbo].[FNC_AHORA]()
	END
END

BEGIN TRANSACTION

	DECLARE @ARCHIVO_ID INT = NULL

	IF(@BINARIO IS NOT NULL) BEGIN

		INSERT MARCACION_BINARIO
			(
				MAB_BINARIO
			)
		VALUES
			(
				@BINARIO
			)

		SET @ARCHIVO_ID = SCOPE_IDENTITY()
		
	END

	INSERT MARCACION
		(
			MAR_ID_USUARIO,
			MAR_ARCHIVO,
			MAR_TIPO_MARCACION,
			MAR_FECHA_HORA_MARCACION,
			MAR_GPS,
			MAR_LATITUD,
			MAR_LONGITUD,
			MAR_MODO_HORA_DISPOSITIVO,
			MAR_HORA_DISPOSITIVO_SERVIDOR,
			MAR_AUTO_MANUAL,
			MAR_FECHA_CREACION,
			MAR_HASH,
			MAR_DISPOSITIVO
		) 
	VALUES 
		(
			@USUARIO,
			@ARCHIVO_ID,
			@TIPO_MARCA,
			@DATE_NOW,
			@GPS,
			@LATITUD,
			@LONGITUD,
			@MODO_HORA_DISPOSITIVO,
			@HORA_DISPOSITIVO_SERVIDOR,
			@AUTO_MANUAL,
			@DATE_NOW,
			@HASH,
			@DISPOSITIVO
		)
	
	SET @ID = SCOPE_IDENTITY()


	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'API_INS_MARCACION ' + ',' +
						  LTRIM(@USUARIO)  + ',' +
						  LTRIM(@TIPO_MARCA)        + ',' +
						  LTRIM(@FECHA)
						  
		
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible crear el registro.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- API_INS_ORDEN_TRABAJO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_ORDEN_TRABAJO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     ALTA DE ORDEN DE TRABAJO CORRECTIVA DESDE TERRENO
--                  (HU-110, Sprint 5) Y SUS PASOS.
-- =============================================
-- IDEMPOTENTE POR UUID, Y NO ES UN ADORNO
--
--   El telefono encola el alta y la envia cuando hay senal. Si el servidor
--   graba pero la respuesta se pierde -el caso del timeout, que en una sala
--   de maquinas es lo normal-, el reintento llega con el MISMO uuid y aca se
--   responde la orden ya creada en vez de crear una segunda.
--
--   El uuid lo genera la app AL ENCOLAR, no al enviar. Generado al enviar,
--   cada reintento traeria uno nuevo y esta proteccion no serviria de nada.
--
-- EL CORRELATIVO SE CALCULA ADENTRO
--
--   Por cliente, con UPDLOCK/HOLDLOCK sobre la lectura del maximo. Dos altas
--   simultaneas del mismo cliente se serializan; si el numero lo eligiera la
--   app, dos tecnicos sin senal crearian la OT-15 los dos.
--
-- LOS PASOS ENTRAN EN LA MISMA TRANSACCION
--
--   Una OT correctiva sin pasos no se puede ejecutar, y una OT a medias es
--   peor que ninguna: el tecnico la ve en la bandeja, la toma, y no tiene que
--   hacer. Van juntas o no va ninguna.
-- =============================================


CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO]
     @ID INT = NULL OUTPUT
    ,@UUID              UNIQUEIDENTIFIER
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@INSTALACION       INT
    ,@TITULO            NVARCHAR(400)
    ,@DESCRIPCION       NVARCHAR(MAX) = NULL
    ,@ACTIVO            INT           = NULL
    ,@AREA              INT           = NULL
    ,@TIPO              INT           = 2      -- 2 CORRECTIVA
    ,@ESTRATEGIA        INT           = 3      -- 3 EMERGENCIA
    ,@PRIORIDAD         INT           = 3      -- 3 ALTA
    ,@FECHA_EVENTO_UTC  DATETIME      = NULL
    ,@REQUIERE_PERMISO  BIT           = 0
    ,@PASOS             NVARCHAR(MAX) = NULL   -- un paso por linea
    ,@ENTRADA_MODO      INT           = 1      -- 1 TECLADO, 2 VOZ
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        /* ---- Idempotencia. Va PRIMERO: si ya existe no se valida nada mas,
           porque revalidar podria rechazar hoy algo que ayer se acepto. ---- */
        DECLARE @YA INT

        SELECT @YA = [otr_id]
          FROM [dbo].[Orden_Trabajo]
         WHERE [otr_uuid]    = @UUID
           AND [otr_cliente] = @CLIENTE

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SET @ID = @YA
            SELECT @YA AS [otr_id], 1 AS [YA_EXISTIA]
            RETURN
        END

        /* ---- La instalacion tiene que ser del cliente Y estar autorizada
           para esta persona. Las dos cosas: la primera evita crear en otra
           empresa, la segunda evita crear en una planta que no le toca. ---- */
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion] cin
                         JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                                ON  ciu.[ciu_id_instalacion] = cin.[cin_id]
                                AND ciu.[ciu_id_usuario]     = @USUARIO
                                AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                        WHERE cin.[cin_id]         = @INSTALACION
                          AND cin.[cin_cliente]    = @CLIENTE
                          AND cin.[cin_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No tienes autorizada esa instalacion.', 16, 1)
            RETURN
        END

        IF @ACTIVO IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                            WHERE [act_id]                  = @ACTIVO
                              AND [act_cliente_instalacion] = @INSTALACION
                              AND [act_habilitado]          = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El activo no pertenece a esa instalacion.', 16, 1)
            RETURN
        END

        IF LTRIM(RTRIM(ISNULL(@TITULO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden necesita un titulo que diga que pasa.', 16, 1)
            RETURN
        END

        /* ---- El correlativo, serializado por cliente. ---- */
        DECLARE @CORRELATIVO INT

        SELECT @CORRELATIVO = ISNULL(MAX([otr_correlativo]), 0) + 1
          FROM [dbo].[Orden_Trabajo] WITH (UPDLOCK, HOLDLOCK)
         WHERE [otr_cliente] = @CLIENTE

        INSERT INTO [dbo].[Orden_Trabajo]
            ([otr_uuid], [otr_cliente], [otr_cliente_instalacion], [otr_correlativo]
            ,[otr_instalacion_area], [otr_activo]
            ,[otr_orden_trabajo_tipo], [otr_orden_trabajo_estrategia]
            ,[otr_orden_trabajo_origen], [otr_orden_trabajo_estado]
            ,[otr_orden_trabajo_prioridad]
            ,[otr_usuario_generador], [otr_titulo], [otr_descripcion]
            ,[otr_fecha_evento_utc], [otr_requiere_permiso]
            ,[otr_registro_posterior], [otr_entrada_modo]
            ,[otr_usuario_creacion], [otr_fecha_creacion], [otr_habilitado])
        VALUES
            (@UUID, @CLIENTE, @INSTALACION, @CORRELATIVO
            ,@AREA, @ACTIVO
            ,@TIPO, @ESTRATEGIA
            ,1, 1                              -- origen 1, estado 1 ABIERTA
            ,@PRIORIDAD
            ,@USUARIO, @TITULO, @DESCRIPCION
            ,ISNULL(@FECHA_EVENTO_UTC, GETUTCDATE()), @REQUIERE_PERMISO
            /* Si el evento ocurrio antes de que se registre, queda marcado.
               Una OT abierta tres horas despues de la falla no miente sobre
               cuando paro la maquina. */
            ,CASE WHEN @FECHA_EVENTO_UTC IS NOT NULL
                   AND @FECHA_EVENTO_UTC < DATEADD(MINUTE, -30, GETUTCDATE())
                  THEN 1 ELSE 0 END
            ,@ENTRADA_MODO
            ,@USUARIO, [dbo].[FNC_AHORA](), 1)

        DECLARE @OTR_ID INT = SCOPE_IDENTITY()

        /* ---- Los pasos, uno por linea. ---- */
        IF @PASOS IS NOT NULL AND LTRIM(RTRIM(@PASOS)) <> N''
        BEGIN
            INSERT INTO [dbo].[Orden_Trabajo_Paso]
                ([otp_orden_trabajo], [otp_orden], [otp_nombre]
                ,[otp_obligatorio], [otp_resultado_paso]
                ,[otp_usuario_creacion], [otp_fecha_creacion], [otp_habilitado])
            SELECT
                 @OTR_ID
                ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                ,LTRIM(RTRIM([value]))
                ,1
                ,4                              -- 4 PENDIENTE
                ,@USUARIO, [dbo].[FNC_AHORA](), 1
              FROM STRING_SPLIT(@PASOS, NCHAR(10))
             WHERE LTRIM(RTRIM([value])) <> N''
        END

        INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
            ([oeh_orden_trabajo], [oeh_estado_anterior], [oeh_estado_nuevo]
            ,[oeh_motivo], [oeh_usuario_creacion])
        VALUES
            (@OTR_ID, NULL, 1, N'Creada desde terreno', @USUARIO)

        COMMIT TRANSACTION

        SET @ID = @OTR_ID
        SELECT @OTR_ID AS [otr_id], 0 AS [YA_EXISTIA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_ORDEN_TRABAJO_MANO_OBRA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_ORDEN_TRABAJO_MANO_OBRA (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- HU-115 #3 · API_INS_ORDEN_TRABAJO_MANO_OBRA: el ejecutante se valida antes
-- de insertar (antes: FK_OMO_USUARIO crudo hacia el telefono). Copia de la
-- definicion del bloque 193 con la comprobacion agregada.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_MANO_OBRA]
     @ID INT = NULL OUTPUT
    ,@OTR_ID         INT
    ,@USUARIO        INT            -- quien registra
    ,@CLIENTE        INT
    ,@FECHA_INICIO   DATETIME
    ,@FECHA_FIN      DATETIME       = NULL
    ,@MINUTOS        INT            = NULL
    ,@ESPECIALIDAD   INT            = NULL
    ,@ES_HORA_EXTRA  BIT            = 0
    ,@OBSERVACION    NVARCHAR(1000) = NULL
    ,@USUARIO_TRAMO  INT            = NULL   -- de quien es el tramo
    /* Nace en el telefono AL ENCOLAR. Opcional: la web no lo manda. */
    ,@UUID           UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    /* ---- Idempotencia: si el uuid ya paso, se devuelve el tramo que ya hay ----
       Va ANTES de la transaccion y de toda validacion. Sin esto, un reintento
       sobre una orden que entretanto se cerro respondia "la orden esta
       cerrada" por un tramo que SI se habia registrado. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [omo_id] FROM [dbo].[Orden_Trabajo_Mano_Obra]
         WHERE [omo_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SET @ID = @YA
            SELECT @YA AS [omo_id]
            RETURN
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT

        SELECT @ESTADO = otr.[otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo] otr
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = otr.[otr_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE otr.[otr_id]      = @OTR_ID
           AND otr.[otr_cliente] = @CLIENTE
           AND otr.[otr_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden esta cerrada. No se puede agregar mano de obra.', 16, 1)
            RETURN
        END

        /* El tramo es de quien lo trabajo; por omision, de quien lo registra. */
        DECLARE @DE_QUIEN INT = ISNULL(@USUARIO_TRAMO, @USUARIO)

        /* HU-115 #3: el ejecutante tiene que existir y ser una persona del
           cliente. Antes un usuario_tramo invalido reventaba contra la FK y
           el telefono recibia el texto crudo de SQL Server. */
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Usuario] u
                         JOIN [dbo].[Cliente_Usuario] cu ON cu.ucl_id_usuario = u.usu_id AND cu.ucl_id_cliente = @CLIENTE
                        WHERE u.usu_id = @DE_QUIEN AND u.usu_habilitado = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Indica quien trabajo el tramo: un usuario del cliente. Sin usuario ni proveedor el tramo se rechaza.', 16, 1)
            RETURN
        END

        /* Los minutos: del rango si hay fin, del parametro si no. */
        DECLARE @MIN INT = ISNULL(@MINUTOS,
                                  CASE WHEN @FECHA_FIN IS NULL THEN NULL
                                       ELSE DATEDIFF(MINUTE, @FECHA_INICIO, @FECHA_FIN) END)

        IF @MIN IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Falta la hora de termino o la cantidad de minutos.', 16, 1)
            RETURN
        END

        IF @MIN <= 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El termino no puede ser anterior al inicio.', 16, 1)
            RETURN
        END

        /* Un turno no dura mas de un dia. Un tramo de 30 horas es un error de
           fecha, y grabarlo arruina el MTTR del activo por meses. */
        IF @MIN > 1440
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El tramo supera las 24 horas. Revisa las fechas.', 16, 1)
            RETURN
        END

        /* La especialidad, si no viene, se toma de la que tenga la persona.
           Escribirla a mano en cada registro es donde aparecen las faltas de
           ortografia que despues no agrupan en un informe. */
        DECLARE @ESP INT = @ESPECIALIDAD

        IF @ESP IS NULL
            SELECT TOP 1 @ESP = ue.[ues_especialidad]
              FROM [dbo].[Usuario_Especialidad] ue
             WHERE ue.[ues_usuario]    = @DE_QUIEN
               AND ISNULL(ue.[ues_habilitado], 1) = 1
             ORDER BY ue.[ues_id]

        INSERT INTO [dbo].[Orden_Trabajo_Mano_Obra]
            ([omo_orden_trabajo], [omo_usuario], [omo_especialidad]
            ,[omo_fecha_inicio_utc], [omo_fecha_fin_utc], [omo_minuto]
            ,[omo_es_hora_extra], [omo_observacion], [omo_uuid]
            ,[omo_usuario_creacion], [omo_fecha_creacion])
        VALUES
            (@OTR_ID, @DE_QUIEN, @ESP
            ,@FECHA_INICIO, @FECHA_FIN, @MIN
            ,@ES_HORA_EXTRA, @OBSERVACION, @UUID
            ,@USUARIO, [dbo].[FNC_AHORA]())

        DECLARE @OMO_ID INT = SCOPE_IDENTITY()

        /* La duracion real de la OT es la suma de sus tramos. Se recalcula en
           vez de acumularse: acumular deja el total mintiendo el dia que un
           tramo se borre. */
        UPDATE [dbo].[Orden_Trabajo]
           SET [otr_duracion_real_minuto] =
                   (SELECT SUM([omo_minuto]) FROM [dbo].[Orden_Trabajo_Mano_Obra]
                     WHERE [omo_orden_trabajo] = @OTR_ID)
              ,[otr_usuario_actualizacion] = @USUARIO
              ,[otr_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
         WHERE [otr_id] = @OTR_ID

        COMMIT TRANSACTION
        SET @ID = @OMO_ID
        SELECT @OMO_ID AS [omo_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_ORDEN_TRABAJO_PASO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_ORDEN_TRABAJO_PASO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_PASO]
    /* @ID primero y OUTPUT, como manda PATRON_SP. No es un detalle: el
       controller llama con `devuelveId: true` y `Datos.Ejecutar` agrega este
       parametro, asi que un SP que no lo declare responde
       «@ID is not a parameter» y el endpoint entero devuelve 400. */
     @ID              INT = NULL OUTPUT
    ,@OTR_ID          INT
    ,@USUARIO         INT
    ,@CLIENTE         INT
    ,@NOMBRE          NVARCHAR(400)
    ,@DESCRIPCION     NVARCHAR(MAX)  = NULL
    /* 1 CONFORME, 2 NO CONFORME, 3 NO APLICA. Nulo = queda pendiente. */
    ,@RESULTADO_PASO  INT            = NULL
    ,@OBSERVACION     NVARCHAR(MAX)  = NULL
    ,@UUID            UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    /* ---- Idempotencia: va ANTES de toda validacion ----
       Un reintento sobre una orden que entretanto se finalizo respondia «la
       orden ya no esta en ejecucion» por un paso que SI se habia registrado. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [otp_id] FROM [dbo].[Orden_Trabajo_Paso]
         WHERE [otp_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SET @ID = @YA
            SELECT @YA AS [otp_id]
            RETURN
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT

        /* La misma regla de plantas que el resto: la orden tiene que estar en
           una instalacion autorizada para esta persona. */
        SELECT @ESTADO = otr.[otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo] otr
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = otr.[otr_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE otr.[otr_id]         = @OTR_ID
           AND otr.[otr_cliente]    = @CLIENTE
           AND otr.[otr_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        /* Mismo corte que la mano de obra: sobre una orden cerrada no se
           escribe. Antes de eso si, porque alguien puede acordarse de algo
           mientras la orden espera cierre. */
        IF @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden esta cerrada. No se le pueden agregar pasos.', 16, 1)
            RETURN
        END

        IF (@NOMBRE IS NULL OR LTRIM(RTRIM(@NOMBRE)) = N'')
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Escribe que fue lo que hiciste.', 16, 1)
            RETURN
        END

        /* Al final de los que ya hay: lo que se agrega mientras se trabaja va
           despues de la pauta, en el orden en que ocurrio. */
        DECLARE @ORDEN INT = ISNULL(
            (SELECT MAX([otp_orden]) FROM [dbo].[Orden_Trabajo_Paso]
              WHERE [otp_orden_trabajo] = @OTR_ID), 0) + 1

        DECLARE @HECHO BIT = CASE WHEN @RESULTADO_PASO IS NULL THEN 0 ELSE 1 END

        INSERT INTO [dbo].[Orden_Trabajo_Paso]
            ([otp_orden_trabajo], [otp_orden], [otp_nombre], [otp_descripcion]
            ,[otp_obligatorio], [otp_resultado_paso], [otp_resultado]
            ,[otp_usuario_ejecutor], [otp_fecha_ejecucion_utc]
            ,[otp_uuid], [otp_usuario_creacion], [otp_fecha_creacion]
            ,[otp_habilitado])
        VALUES
            (@OTR_ID, @ORDEN, LTRIM(RTRIM(@NOMBRE)), @DESCRIPCION
            /* Nunca obligatorio: lo agrega quien trabaja, y no puede acabar
               siendo un requisito que le impida cerrar su propia orden. */
            ,0, ISNULL(@RESULTADO_PASO, 0), @OBSERVACION
            ,CASE WHEN @HECHO = 1 THEN @USUARIO END
            ,CASE WHEN @HECHO = 1 THEN GETUTCDATE() END
            ,@UUID, @USUARIO, [dbo].[FNC_AHORA]()
            ,1)

        SET @ID = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SELECT @ID AS [otp_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

-- ---------- API_INS_ORDEN_TRABAJO_VALIDACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_ORDEN_TRABAJO_VALIDACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 4) API_INS_ORDEN_TRABAJO_VALIDACION — firmar
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_ORDEN_TRABAJO_VALIDACION]
@ID             INT = NULL OUTPUT,
@UUID           UNIQUEIDENTIFIER,
@ORDEN          INT,
@VALIDACION_TIPO INT,
@RESULTADO      NVARCHAR(40),
@OBSERVACION    NVARCHAR(MAX) = NULL,
@ARCHIVO_FIRMA  INT = NULL,
@USUARIO        INT,
@CLIENTE        INT
AS
SET NOCOUNT ON

BEGIN TRY

    /* IDEMPOTENTE POR EL UUID

       El telefono lo genera AL ENCOLAR, no al enviar. Una firma capturada sin
       señal se reintenta varias veces; sin esto quedarian tres firmas de la
       misma persona con tres segundos de diferencia, y la orden pareceria
       validada por triplicado. Se devuelve la que ya estaba. */
    DECLARE @YA INT = (SELECT otv_id FROM [dbo].[Orden_Trabajo_Validacion]
                        WHERE otv_uuid = @UUID)

    IF (@YA IS NOT NULL)
    BEGIN
        SET @ID = @YA
        SELECT @YA AS OTV_ID, 1 AS YA_ESTABA
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                    WHERE otr_id = @ORDEN AND otr_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA ORDEN NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Validacion_Tipo]
                    WHERE vat_id = @VALIDACION_TIPO AND vat_habilitado = 1)
    BEGIN
        RAISERROR('2.- ESE TIPO DE VALIDACION NO EXISTE.', 16, 1)
        RETURN
    END

    /* EL VOCABULARIO LO PONE LA BASE, NO ESTE SP

       La tabla ya trae `CK_OTV_RESULTADO`, que solo admite APROBADO y
       RECHAZADO. La primera version de este SP validaba «ACEPTADA» y
       «RECHAZADA» -las palabras de la especificacion de la vista- y **todo
       INSERT rebotaba contra el CHECK**: el SP decia que si y la tabla decia
       que no.

       La regla vive en un solo sitio, y ese sitio es el CHECK. Aca solo se
       normaliza y se traduce un mensaje entendible, porque el error crudo del
       constraint no le dice nada a quien firma. */
    SET @RESULTADO = UPPER(LTRIM(RTRIM(ISNULL(@RESULTADO, N''))))

    -- Se acepta lo que dice la vista y se guarda lo que dice la base.
    IF (@RESULTADO IN (N'ACEPTADA', N'ACEPTADO', N'APROBADA')) SET @RESULTADO = N'APROBADO'
    IF (@RESULTADO = N'RECHAZADA') SET @RESULTADO = N'RECHAZADO'

    IF (@RESULTADO NOT IN (N'APROBADO', N'RECHAZADO'))
    BEGIN
        RAISERROR('3.- EL RESULTADO DEBE SER APROBADO O RECHAZADO.', 16, 1)
        RETURN
    END

    /* EL MOTIVO ES OBLIGATORIO AL RECHAZAR

       Un rechazo sin motivo obliga a ir a preguntarle a quien firmo, y en un
       turno de noche esa persona ya se fue. Es la misma regla que el cambio de
       estado de un activo, y se hace cumplir ACA para que valga tambien para
       la web. */
    IF (@RESULTADO = N'RECHAZADO' AND LTRIM(RTRIM(ISNULL(@OBSERVACION, N''))) = N'')
    BEGIN
        RAISERROR('4.- INDIQUE EL MOTIVO DEL RECHAZO.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Validacion]
        (otv_uuid, otv_orden_trabajo, otv_validacion_tipo, otv_usuario,
         otv_resultado, otv_fecha_utc, otv_observacion, otv_archivo_firma,
         otv_usuario_creacion, otv_fecha_creacion)
    VALUES
        (@UUID, @ORDEN, @VALIDACION_TIPO, @USUARIO,
         @RESULTADO, GETUTCDATE(), @OBSERVACION, @ARCHIVO_FIRMA,
         @USUARIO, [dbo].[FNC_AHORA]())

    SET @ID = SCOPE_IDENTITY()

    SELECT @ID AS OTV_ID, 0 AS YA_ESTABA

END TRY
BEGIN CATCH
    DECLARE @MSG NVARCHAR(2000) = ERROR_MESSAGE()
    RAISERROR(@MSG, 16, 1)
END CATCH
GO

-- ---------- API_INS_TAREA_COMENTARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_INS_TAREA_COMENTARIO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
--   El dictado se crea **dentro de la misma transaccion** que el comentario y
--   no en una llamada aparte. Un comentario y su dictado son un solo acto: si
--   fueran dos envios, la cola podria dejar uno sin el otro y quedaria o un
--   comentario que miente sobre como se escribio, o un dictado huerfano que no
--   se puede leer desde ninguna parte.
--
--   `@TEXTO` es lo que la persona dio por bueno; `@TEXTO_DICTADO` es lo que
--   entendio el telefono. Cuando no se corrigio nada son iguales, y esta bien
--   que lo sean: lo que importa es poder ver cuando **no** lo fueron.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_INS_TAREA_COMENTARIO]
     @ID INT = NULL OUTPUT
    ,@OCURRENCIA        INT
    ,@USUARIO           INT
    ,@CLIENTE           INT
    ,@TEXTO             NVARCHAR(MAX)
    ,@PADRE             INT              = NULL
    ,@DICTADO_UUID      UNIQUEIDENTIFIER = NULL
    ,@TEXTO_DICTADO     NVARCHAR(MAX)    = NULL
    ,@DICTADO_CONFIANZA DECIMAL(5,4)     = NULL
    ,@DICTADO_SEGUNDOS  INT              = NULL
    ,@DICTADO_INTENTOS  INT              = 1
    ,@DISPOSITIVO       UNIQUEIDENTIFIER = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        IF LTRIM(RTRIM(ISNULL(@TEXTO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario esta vacio.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Tarea_Ocurrencia] toc
                         JOIN [dbo].[Tarea]            tar ON tar.[tar_id] = toc.[toc_tarea]
                    LEFT JOIN [dbo].[Activo]           act ON act.[act_id] = tar.[tar_activo]
                         JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                                ON  ciu.[ciu_id_instalacion] = ISNULL(tar.[tar_cliente_instalacion],
                                                                      act.[act_cliente_instalacion])
                                AND ciu.[ciu_id_usuario]     = @USUARIO
                                AND ISNULL(ciu.[ciu_habilitado], 0) = 1
                        WHERE toc.[toc_id]      = @OCURRENCIA
                          AND toc.[toc_cliente] = @CLIENTE)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La tarea no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        IF @PADRE IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Comentario]
                            WHERE [tco_id] = @PADRE
                              AND [tco_tarea_ocurrencia] = @OCURRENCIA)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El comentario al que respondes no es de esta tarea.', 16, 1)
            RETURN
        END

        DECLARE @YA INT

        SELECT TOP 1 @YA = [tco_id]
          FROM [dbo].[Tarea_Comentario]
         WHERE [tco_tarea_ocurrencia] = @OCURRENCIA
           AND [tco_usuario_creacion] = @USUARIO
           AND [tco_texto]            = @TEXTO
           AND [tco_fecha_creacion]  >= DATEADD(MINUTE, -5, [dbo].[FNC_AHORA]())
         ORDER BY [tco_id] DESC

        IF @YA IS NOT NULL
        BEGIN
            COMMIT TRANSACTION
            SET @ID = @YA
            SELECT @YA AS [tco_id], 1 AS [YA_ESTABA]
            RETURN
        END

        /* ---- El dictado, si lo hubo ---- */
        DECLARE @DVO INT = NULL

        IF @DICTADO_UUID IS NOT NULL
            EXEC [dbo].[API_INS_DICTADO_VOZ]
                 @UUID        = @DICTADO_UUID
                ,@USUARIO     = @USUARIO
                ,@CLIENTE     = @CLIENTE
                ,@TEXTO       = @TEXTO_DICTADO      -- lo crudo, no lo corregido
                ,@CONFIANZA   = @DICTADO_CONFIANZA
                ,@SEGUNDOS    = @DICTADO_SEGUNDOS
                ,@INTENTOS    = @DICTADO_INTENTOS
                ,@DISPOSITIVO = @DISPOSITIVO
                ,@ID          = @DVO OUTPUT

        INSERT INTO [dbo].[Tarea_Comentario]
            ([tco_tarea_ocurrencia], [tco_comentario_padre], [tco_texto]
            ,[tco_dictado_voz], [tco_usuario_creacion], [tco_fecha_creacion])
        VALUES
            (@OCURRENCIA, @PADRE, @TEXTO
            ,@DVO, @USUARIO, [dbo].[FNC_AHORA]())

        DECLARE @TCO INT = SCOPE_IDENTITY()

        COMMIT TRANSACTION
        SET @ID = @TCO
        SELECT @TCO AS [tco_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_SEL_APP_INSTALACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_SEL_APP_INSTALACION (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_APP_INSTALACION]
@CLIENTE INT,
@USUARIO INT,
@ID      INT = NULL,
@FILTRO  VARCHAR(200) = NULL
AS
SET NOCOUNT ON

    SELECT      CIN.cin_id            AS cin_id,
                CIN.cin_cliente       AS cin_cliente,
                CIN.cin_codigo        AS cin_codigo,
                CIN.cin_nombre        AS cin_nombre,
                CIN.cin_descripcion   AS cin_descripcion,
                CIN.cin_direccion     AS cin_direccion,
                CIN.cin_zona_horaria  AS cin_zona_horaria,
                CIN.cin_latitud       AS cin_latitud,
                CIN.cin_longitud      AS cin_longitud,
                CIN.cin_habilitado    AS cin_habilitado
    FROM        [dbo].[Cliente_Instalacion] CIN
    /* INNER, no LEFT: sin fila de asignacion la planta no sale. */
    JOIN        [dbo].[Cliente_Instalacion_Usuario] CIU
            ON  CIU.ciu_id_instalacion = CIN.cin_id
            AND CIU.ciu_id_usuario     = @USUARIO
            AND ISNULL(CIU.ciu_habilitado, 0) = 1
            /* La asignacion puede tener vigencia: un reemplazo por turno no
               deja ver la planta para siempre. NULL = sin limite. */
            AND (CIU.ciu_fecha_inicio IS NULL OR CIU.ciu_fecha_inicio <= [dbo].[FNC_AHORA]())
            AND (CIU.ciu_fecha_fin    IS NULL OR CIU.ciu_fecha_fin    >= [dbo].[FNC_AHORA]())
    WHERE       CIN.cin_cliente    = @CLIENTE
      AND       CIN.cin_habilitado = 1
      AND       (@ID IS NULL OR CIN.cin_id = @ID)
      AND       (@FILTRO IS NULL OR @FILTRO = ''
                 OR CIN.cin_nombre   LIKE '%' + @FILTRO + '%'
                 OR CIN.cin_codigo   LIKE '%' + @FILTRO + '%'
                 OR CIN.cin_direccion LIKE '%' + @FILTRO + '%')
    ORDER BY    CIN.cin_nombre
GO

-- ---------- API_SEL_EVIDENCIA_MIAS (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_SEL_EVIDENCIA_MIAS (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 2) API_SEL_EVIDENCIA_MIAS — lo que subi yo, con su registro
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_EVIDENCIA_MIAS]
@USUARIO    INT,
@CLIENTE    INT,
@DIAS       INT = 30,
@PAGINA     INT = 1,
@TAMANO     INT = 50,
@TOTAL      INT = NULL OUTPUT
AS
SET NOCOUNT ON

IF @PAGINA < 1 SET @PAGINA = 1
IF @TAMANO < 1 SET @TAMANO = 50
IF @TAMANO > 200 SET @TAMANO = 200
IF @DIAS   < 1 SET @DIAS   = 30
DECLARE @OFFSET INT = (@PAGINA - 1) * @TAMANO

/* UNA VENTANA DE DIAS, NO TODO EL HISTORIAL

   La pregunta es «se subio lo de este turno», no «que fotografie en dos
   años». Sin tope, un tecnico con dos temporadas de trabajo bajaria miles de
   filas para mirar las seis de ayer. */
DECLARE @DESDE DATETIME = DATEADD(DAY, -@DIAS, [dbo].[FNC_AHORA]())

SELECT  arc.arc_id                  AS ARC_ID,
        arc.arc_uuid                AS ARC_UUID,
        arc.arc_ruta                AS ARC_RUTA,
        arc.arc_nombre_original     AS ARC_NOMBRE,
        arc.arc_mime                AS ARC_MIME,
        arc.arc_byte                AS ARC_BYTE,
        ISNULL(arc.arc_fecha_captura_utc, arc.arc_fecha_creacion) AS FECHA_CAPTURA_UTC,
        arc.arc_fecha_creacion      AS FECHA_SUBIDA,
        aca.aca_nombre              AS CATEGORIA_NOMBRE,
        avi.avi_descripcion         AS DESCRIPCION,

        /* De que cuelga, en palabras. El primero que no sea nulo manda: un
           vinculo tiene exactamente un dueño, la tabla solo esta preparada
           para muchos tipos de dueño. */
        CASE
            WHEN avi.avi_orden_trabajo IS NOT NULL      THEN N'Orden de trabajo'
            WHEN avi.avi_orden_trabajo_paso IS NOT NULL THEN N'Paso de una orden'
            WHEN avi.avi_tarea_ejecucion IS NOT NULL    THEN N'Tarea'
            WHEN avi.avi_bitacora IS NOT NULL           THEN N'Bitácora'
            WHEN avi.avi_falla IS NOT NULL              THEN N'Falla'
            WHEN avi.avi_checklist_hallazgo IS NOT NULL THEN N'Hallazgo'
            WHEN avi.avi_checklist_ejecucion_respuesta IS NOT NULL THEN N'Pauta'
            WHEN avi.avi_activo_componente IS NOT NULL  THEN N'Componente'
            WHEN avi.avi_activo IS NOT NULL             THEN N'Equipo'
            WHEN avi.avi_repuesto IS NOT NULL           THEN N'Repuesto'
            WHEN avi.avi_permiso_trabajo IS NOT NULL    THEN N'Permiso de trabajo'
            ELSE N'Sin registro'
        END                         AS DESTINO_TIPO,

        /* CAST a texto en TODAS las ramas, no solo en las que parecen
           numero. `otr_correlativo` es INT, y sin el CAST el COALESCE entero
           se resuelve como INT: la primera bitacora con titulo hacia caer el
           endpoint con «Conversion failed converting the nvarchar value
           'Prueba 193' to data type int». Un COALESCE mezcla tipos en
           silencio hasta que un dato real lo delata. */
        COALESCE(CAST(otr.otr_correlativo AS NVARCHAR(200)),
                 CAST(otp.otr_correlativo AS NVARCHAR(200)),
                 CAST(bit.bit_titulo      AS NVARCHAR(200)),
                 CAST(fal.fal_titulo      AS NVARCHAR(200)),
                 CAST(aco.aco_codigo      AS NVARCHAR(200)),
                 CAST(act.act_codigo      AS NVARCHAR(200)),
                 CAST(rep.rep_codigo      AS NVARCHAR(200)),
                 CAST(ptr.ptr_numero      AS NVARCHAR(200)),
                 N'')               AS DESTINO_TEXTO,

        COALESCE(avi.avi_orden_trabajo,
                 avi.avi_bitacora,
                 avi.avi_falla,
                 avi.avi_activo_componente,
                 avi.avi_activo,
                 avi.avi_repuesto,
                 avi.avi_permiso_trabajo) AS DESTINO_ID
INTO    #mias
FROM    [dbo].[Archivo_Vinculo] avi
INNER JOIN [dbo].[Archivo] arc ON arc.arc_id = avi.avi_archivo
LEFT  JOIN [dbo].[Archivo_Categoria] aca ON aca.aca_id = arc.arc_archivo_categoria
LEFT  JOIN [dbo].[Orden_Trabajo] otr ON otr.otr_id = avi.avi_orden_trabajo
LEFT  JOIN [dbo].[Orden_Trabajo_Paso] otps ON otps.otp_id = avi.avi_orden_trabajo_paso
LEFT  JOIN [dbo].[Orden_Trabajo] otp ON otp.otr_id = otps.otp_orden_trabajo
LEFT  JOIN [dbo].[Bitacora] bit ON bit.bit_id = avi.avi_bitacora
LEFT  JOIN [dbo].[Falla] fal ON fal.fal_id = avi.avi_falla
LEFT  JOIN [dbo].[Activo_Componente] aco ON aco.aco_id = avi.avi_activo_componente
LEFT  JOIN [dbo].[Activo] act ON act.act_id = avi.avi_activo
LEFT  JOIN [dbo].[Repuesto] rep ON rep.rep_id = avi.avi_repuesto
LEFT  JOIN [dbo].[Permiso_Trabajo] ptr ON ptr.ptr_id = avi.avi_permiso_trabajo
WHERE   arc.arc_cliente          = @CLIENTE
  AND   arc.arc_usuario_creacion = @USUARIO
  AND   arc.arc_habilitado       = 1
  AND   avi.avi_habilitado       = 1
  AND   arc.arc_fecha_creacion  >= @DESDE

SET @TOTAL = (SELECT COUNT(*) FROM #mias)

-- Lo mas reciente primero: se abre para comprobar lo del turno que acaba.
SELECT * FROM #mias
ORDER BY FECHA_SUBIDA DESC, ARC_ID DESC
OFFSET @OFFSET ROWS FETCH NEXT @TAMANO ROWS ONLY

DROP TABLE #mias

RETURN(0)
GO

-- ---------- API_UPD_CHECKLIST_CERRAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPD_CHECKLIST_CERRAR (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 4 - CERRAR LA EJECUCION
-- ---------------------------------------------------------------------------
--   Se exige que los OBLIGATORIOS esten respondidos. ï¿½No aplicaï¿½ cuenta como
--   respuesta: no todo item corresponde a todo equipo, y obligar a inventar un
--   valor para poder cerrar es peor que aceptar el ï¿½no aplicaï¿½.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_CHECKLIST_CERRAR]
     @CEJ_ID       INT
    ,@USUARIO      INT
    ,@CLIENTE      INT
    ,@OBSERVACION  NVARCHAR(MAX) = NULL
    /* Los minutos que MIDIO la app, descontando las pausas.

       `DATEDIFF` sobre la hora de inicio cuenta como trabajo el rato que se
       espero una pieza o un permiso, y esa espera es justo lo que ensucia el
       dato que esta medicion existe para obtener. Cuando la app manda su
       cronometro, manda el suyo; si no viene â€”una ejecucion cerrada desde la
       web, o una version anterior de la appâ€” se conserva el calculo de antes,
       que es mejor que nada. */
    ,@MINUTOS      INT = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @VER INT, @OCU INT, @INICIO DATETIME

        SELECT @ESTADO = [cej_checklist_ejecucion_estado]
              ,@VER    = [cej_checklist_plantilla_version]
              ,@OCU    = [cej_checklist_ocurrencia]
              ,@INICIO = [cej_fecha_inicio_utc]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_id]              = @CEJ_ID
           AND [cej_cliente]         = @CLIENTE
           AND [cej_usuario_ejecutor] = @USUARIO
           AND [cej_habilitado]      = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La ejecucion no existe o no es tuya.', 16, 1)
            RETURN
        END

        /* Idempotente: cerrar dos veces responde lo mismo. Es el caso del
           reintento de la cola. */
        IF @ESTADO <> 1
        BEGIN
            COMMIT TRANSACTION
            SELECT @CEJ_ID AS [cej_id], 1 AS [YA_ESTABA]
            RETURN
        END

        DECLARE @FALTAN INT =
            (SELECT COUNT(*)
               FROM [dbo].[Checklist_Plantilla_Item] i
              WHERE i.[cpi_checklist_plantilla_version] = @VER
                AND i.[cpi_habilitado]   = 1
                AND i.[cpi_obligatorio]  = 1
                AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Ejecucion_Respuesta] r
                                 WHERE r.[cer_checklist_ejecucion]      = @CEJ_ID
                                   AND r.[cer_checklist_plantilla_item] = i.[cpi_id]
                                   AND r.[cer_habilitado]               = 1))

        IF @FALTAN > 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @M NVARCHAR(200) =
                CONCAT(N'Faltan ', @FALTAN, N' items obligatorios por responder.')
            RAISERROR(@M, 16, 1)
            RETURN
        END

        UPDATE [dbo].[Checklist_Ejecucion]
           SET [cej_checklist_ejecucion_estado] = 3           -- ENVIADA
              ,[cej_fecha_fin_utc]              = GETUTCDATE()
              ,[cej_duracion_minuto]            = ISNULL(@MINUTOS, DATEDIFF(MINUTE, @INICIO, GETUTCDATE()))
              ,[cej_fecha_sincronizacion_utc]   = GETUTCDATE()
              ,[cej_observacion]                = ISNULL(@OBSERVACION, [cej_observacion])
              ,[cej_usuario_actualizacion]      = @USUARIO
              ,[cej_fecha_actualizacion]        = [dbo].[FNC_AHORA]()
         WHERE [cej_id] = @CEJ_ID

        IF @OCU IS NOT NULL
            UPDATE [dbo].[Checklist_Ocurrencia]
               SET [coc_checklist_ocurrencia_estado] = 4      -- COMPLETADA
                  ,[coc_usuario_actualizacion]       = @USUARIO
                  ,[coc_fecha_actualizacion]         = [dbo].[FNC_AHORA]()
             WHERE [coc_id] = @OCU

        COMMIT TRANSACTION

        SELECT @CEJ_ID AS [cej_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_UPD_ORDEN_TRABAJO_PASO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPD_ORDEN_TRABAJO_PASO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 3 - COMPLETAR UN PASO (HU-114)
-- ---------------------------------------------------------------------------
--   La app captura el paso en terreno y lo envia cuando hay senal. Por eso:
--
--   * Se comprueba que la OT este EN EJECUCION: completar pasos de una orden
--     cerrada dejaria un registro que nadie puede explicar.
--
--   * Se comprueba que quien lo completa sea el responsable o este asignado.
--     La regla vive aca y no en la pantalla porque la app puede estar
--     desactualizada; el servidor no.
--
--   * Es IDEMPOTENTE por paso: reenviar el mismo paso ya completado no
--     duplica ni falla, devuelve lo mismo. Es el caso del timeout, donde el
--     servidor grabo pero la respuesta no llego.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_ORDEN_TRABAJO_PASO]
     @OTP_ID           INT
    ,@USUARIO          INT
    ,@CLIENTE          INT
    ,@RESULTADO_PASO   INT              -- 1 CONFORME, 2 NO CONFORME, 3 NO APLICA
    ,@OBSERVACION      NVARCHAR(MAX) = NULL
    ,@ENTRADA_MODO     INT           = 1  -- 1 TECLADO, 2 VOZ
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @OTR_ID INT, @ESTADO INT, @YA INT

        SELECT @OTR_ID = otr.[otr_id]
              ,@ESTADO = otr.[otr_orden_trabajo_estado]
              ,@YA     = otp.[otp_resultado_paso]
          FROM [dbo].[Orden_Trabajo_Paso] otp
          JOIN [dbo].[Orden_Trabajo]      otr ON otr.[otr_id] = otp.[otp_orden_trabajo]
         WHERE otp.[otp_id]        = @OTP_ID
           AND otp.[otp_habilitado] = 1
           AND otr.[otr_cliente]    = @CLIENTE
           AND otr.[otr_habilitado] = 1

        IF @OTR_ID IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El paso no existe o no pertenece a este cliente.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Resultado_Paso]
                        WHERE [rpa_id] = @RESULTADO_PASO AND [rpa_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('El resultado indicado no existe.', 16, 1)
            RETURN
        END

        /* Idempotencia: si ya quedo con el mismo resultado, se responde igual
           y no se toca nada. Un reintento del telefono no es un error. */
        IF @YA = @RESULTADO_PASO
        BEGIN
            COMMIT TRANSACTION
            SELECT @OTP_ID AS [otp_id], @OTR_ID AS [otr_id], 1 AS [YA_ESTABA]
            RETURN
        END

        IF @ESTADO <> 2
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden no esta en ejecucion. Tomala antes de completar pasos.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo] o
                        WHERE o.[otr_id] = @OTR_ID AND o.[otr_usuario_responsable] = @USUARIO)
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Asignacion] a
                            WHERE a.[ota_orden_trabajo] = @OTR_ID
                              AND a.[ota_usuario]       = @USUARIO
                              AND a.[ota_habilitado]    = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('No estas asignado a esta orden de trabajo.', 16, 1)
            RETURN
        END

        UPDATE [dbo].[Orden_Trabajo_Paso]
           SET [otp_resultado_paso]       = @RESULTADO_PASO
              ,[otp_resultado]            = @OBSERVACION
              ,[otp_usuario_ejecutor]     = @USUARIO
              ,[otp_fecha_ejecucion_utc]  = GETUTCDATE()
              ,[otp_usuario_actualizacion] = @USUARIO
              ,[otp_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
         WHERE [otp_id] = @OTP_ID

        /* El modo de entrada queda en la OT: una cifra dictada y una tecleada
           no se auditan igual. */
        IF @ENTRADA_MODO = 2
            UPDATE [dbo].[Orden_Trabajo]
               SET [otr_entrada_modo] = 2
             WHERE [otr_id] = @OTR_ID

        COMMIT TRANSACTION

        SELECT @OTP_ID AS [otp_id], @OTR_ID AS [otr_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

-- ---------- API_UPD_PREDICCION_REVISION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPD_PREDICCION_REVISION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 2 - RECONOCER O DESCARTAR
-- ---------------------------------------------------------------------------
--   Descartar **exige motivo**. Una prediccion descartada sin explicacion no
--   se puede aprender: cuando alguien revise si el modelo sirve, necesita
--   saber si se descarto porque era un falso positivo, porque el equipo ya se
--   iba a cambiar, o porque nadie le creyo. Las tres cosas llevan a decisiones
--   distintas sobre el modelo.
--
--   Y el motivo es lo unico que hoy sostiene a `Modelo_Monitoreo`: los falsos
--   positivos que ahi se cuentan salen de aca.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPD_PREDICCION_REVISION]
     @ID        INT
    ,@USUARIO   INT
    ,@CLIENTE   INT
    ,@ACEPTAR   BIT
    ,@MOTIVO    NVARCHAR(1000) = NULL
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @ALERTA INT

        SELECT @ESTADO = pre.[pre_prediccion_estado]
              ,@ALERTA = pre.[pre_alerta]
          FROM [dbo].[Prediccion] pre
          JOIN [dbo].[Activo]     act ON act.[act_id] = pre.[pre_activo]
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = act.[act_cliente_instalacion]
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE pre.[pre_id]         = @ID
           AND pre.[pre_cliente]    = @CLIENTE
           AND pre.[pre_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La prediccion no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        /* Ya materializada: salio una orden de trabajo de ella y revisarla
           ahora no cambiaria nada. */
        IF @ESTADO = 5
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esta prediccion ya se convirtio en una orden de trabajo.', 16, 1)
            RETURN
        END

        IF @ACEPTAR = 0 AND LTRIM(RTRIM(ISNULL(@MOTIVO, N''))) = N''
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Para descartar una prediccion hay que decir por que.', 16, 1)
            RETURN
        END

        /* Ya revisada con el mismo veredicto: la cola reintentando. */
        IF (@ACEPTAR = 1 AND @ESTADO = 3) OR (@ACEPTAR = 0 AND @ESTADO = 4)
        BEGIN
            COMMIT TRANSACTION
            SELECT @ID AS [pre_id], 1 AS [YA_ESTABA]
            RETURN
        END

        UPDATE [dbo].[Prediccion]
           SET [pre_prediccion_estado]    = CASE WHEN @ACEPTAR = 1 THEN 3 ELSE 4 END
              ,[pre_usuario_revision]     = @USUARIO
              ,[pre_fecha_revision_utc]   = GETUTCDATE()
              ,[pre_motivo_descarte]      = CASE WHEN @ACEPTAR = 0 THEN @MOTIVO END
              ,[pre_usuario_actualizacion] = @USUARIO
              ,[pre_fecha_actualizacion]  = [dbo].[FNC_AHORA]()
         WHERE [pre_id] = @ID

        /* La alerta sigue a la prediccion. Se reusa el SP de estado en vez de
           escribir las columnas a mano: es el que sabe cuales mueve y el que
           deja el rastro en Alerta_Historial.

           El estado va en una variable porque EXEC no acepta una expresion
           como argumento: un CASE ahi es error de sintaxis. */
        DECLARE @ESTADO_ALERTA VARCHAR(50) =
            CASE WHEN @ACEPTAR = 1 THEN 'RECONOCIDA' ELSE 'DESCARTADA' END

        IF @ALERTA IS NOT NULL
            EXEC [dbo].[UPD_ALERTA_ESTADO]
                 @ALERTA      = @ALERTA
                ,@CLIENTE     = @CLIENTE
                ,@USUARIO     = @USUARIO
                ,@ESTADO      = @ESTADO_ALERTA
                ,@MOTIVO      = @MOTIVO
                ,@RESPONSABLE = NULL

        COMMIT TRANSACTION
        SELECT @ID AS [pre_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_UPS_CHECKLIST_RESPUESTA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPS_CHECKLIST_RESPUESTA (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 3 - RESPONDER UN ITEM
-- ---------------------------------------------------------------------------
--   Es un UPSERT por (ejecucion, item): volver a responder ACTUALIZA. Eso es
--   lo que hace que reenviar una pauta de treinta items desde la cola sea
--   seguro, y tambien que el tecnico pueda corregirse antes de cerrar.
--
--   El rango se evalua ACA contra Checklist_Item_Validacion. Fuera de rango
--   no impide grabar -es el hallazgo- pero queda marcado, y si la plantilla
--   lo pide se abre el Checklist_Hallazgo.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_CHECKLIST_RESPUESTA]
     @CEJ_ID         INT
    ,@USUARIO        INT
    ,@CLIENTE        INT
    ,@ITEM           INT
    ,@VALOR_TEXTO    NVARCHAR(MAX)  = NULL
    ,@VALOR_NUMERO   DECIMAL(18,4)  = NULL
    ,@VALOR_BOOLEANO BIT            = NULL
    ,@VALOR_FECHA    DATETIME       = NULL
    ,@NO_APLICA      BIT            = 0
    ,@COMENTARIO     NVARCHAR(MAX)  = NULL
    ,@ENTRADA_MODO   INT            = 1
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @VER INT, @ACTIVO INT

        SELECT @ESTADO = [cej_checklist_ejecucion_estado]
              ,@VER    = [cej_checklist_plantilla_version]
              ,@ACTIVO = [cej_activo]
          FROM [dbo].[Checklist_Ejecucion]
         WHERE [cej_id]              = @CEJ_ID
           AND [cej_cliente]         = @CLIENTE
           AND [cej_usuario_ejecutor] = @USUARIO
           AND [cej_habilitado]      = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La ejecucion no existe o no es tuya.', 16, 1)
            RETURN
        END

        IF @ESTADO <> 1
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La pauta ya fue enviada. No se puede cambiar una respuesta.', 16, 1)
            RETURN
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla_Item]
                        WHERE [cpi_id] = @ITEM
                          AND [cpi_checklist_plantilla_version] = @VER
                          AND [cpi_habilitado] = 1)
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Ese item no pertenece a la pauta que se esta llenando.', 16, 1)
            RETURN
        END

        /* ---- El rango, contra la validacion de la plantilla ---- */
        DECLARE @FUERA BIT = 0, @HALLAZGO BIT = 0, @MENSAJE_VAL NVARCHAR(500)

        SELECT TOP 1
               @FUERA = CASE
                   WHEN @NO_APLICA = 1 OR @VALOR_NUMERO IS NULL THEN 0
                   WHEN [civ_valor_minimo] IS NOT NULL AND @VALOR_NUMERO < [civ_valor_minimo] THEN 1
                   WHEN [civ_valor_maximo] IS NOT NULL AND @VALOR_NUMERO > [civ_valor_maximo] THEN 1
                   ELSE 0 END
              ,@HALLAZGO    = ISNULL([civ_genera_hallazgo], 0)
              ,@MENSAJE_VAL = [civ_mensaje]
          FROM [dbo].[Checklist_Item_Validacion]
         WHERE [civ_checklist_plantilla_item] = @ITEM
           AND [civ_habilitado] = 1

        /* Una opcion marcada como no conforme tambien es un hallazgo. */
        IF @FUERA = 0 AND @VALOR_TEXTO IS NOT NULL
            SELECT @FUERA = CASE WHEN ISNULL([cio_es_conforme], 1) = 0 THEN 1 ELSE 0 END
              FROM [dbo].[Checklist_Item_Opcion]
             WHERE [cio_checklist_plantilla_item] = @ITEM
               AND [cio_codigo]                   = @VALOR_TEXTO
               AND [cio_habilitado]               = 1

        /* ---- Un SI/NO se evalua contra las opciones de la plantilla, NUNCA
           contra el valor.

           La primera version marcaba como no conforme todo SI/NO respondido
           «No». Es un error de criterio: a «¿Hay fugas visibles?» la buena
           respuesta ES «No», y a «¿Opera sin ruidos?» es «Si». El significado
           depende de como este redactada la pregunta, y eso solo lo sabe quien
           escribio la pauta.

           Por eso la conformidad se declara en Checklist_Item_Opcion con
           `cio_es_conforme` -SI y NO como dos opciones- y aca solo se lee. Una
           pauta que no lo declare no marca nada, que es preferible a marcarlo
           al reves. */
        IF @FUERA = 0 AND @VALOR_BOOLEANO IS NOT NULL AND @NO_APLICA = 0
            SELECT @FUERA = CASE WHEN ISNULL([cio_es_conforme], 1) = 0 THEN 1 ELSE 0 END
              FROM [dbo].[Checklist_Item_Opcion]
             WHERE [cio_checklist_plantilla_item] = @ITEM
               AND [cio_codigo] = CASE WHEN @VALOR_BOOLEANO = 1 THEN N'SI' ELSE N'NO' END
               AND [cio_habilitado] = 1

        /* ---- El UPSERT ---- */
        DECLARE @CER INT

        SELECT @CER = [cer_id]
          FROM [dbo].[Checklist_Ejecucion_Respuesta]
         WHERE [cer_checklist_ejecucion]      = @CEJ_ID
           AND [cer_checklist_plantilla_item] = @ITEM

        IF @CER IS NULL
        BEGIN
            INSERT INTO [dbo].[Checklist_Ejecucion_Respuesta]
                ([cer_checklist_ejecucion], [cer_checklist_plantilla_item]
                ,[cer_valor_texto], [cer_valor_numero], [cer_valor_booleano]
                ,[cer_valor_fecha], [cer_fuera_rango], [cer_no_aplica]
                ,[cer_comentario], [cer_entrada_modo], [cer_fecha_respuesta_utc]
                ,[cer_usuario_creacion], [cer_fecha_creacion], [cer_habilitado])
            VALUES
                (@CEJ_ID, @ITEM
                ,@VALOR_TEXTO, @VALOR_NUMERO, @VALOR_BOOLEANO
                ,@VALOR_FECHA, @FUERA, @NO_APLICA
                ,@COMENTARIO, @ENTRADA_MODO, GETUTCDATE()
                ,@USUARIO, [dbo].[FNC_AHORA](), 1)

            SET @CER = SCOPE_IDENTITY()
        END
        ELSE
        BEGIN
            UPDATE [dbo].[Checklist_Ejecucion_Respuesta]
               SET [cer_valor_texto]           = @VALOR_TEXTO
                  ,[cer_valor_numero]          = @VALOR_NUMERO
                  ,[cer_valor_booleano]        = @VALOR_BOOLEANO
                  ,[cer_valor_fecha]           = @VALOR_FECHA
                  ,[cer_fuera_rango]           = @FUERA
                  ,[cer_no_aplica]             = @NO_APLICA
                  ,[cer_comentario]            = @COMENTARIO
                  ,[cer_entrada_modo]          = @ENTRADA_MODO
                  ,[cer_fecha_respuesta_utc]   = GETUTCDATE()
                  ,[cer_usuario_actualizacion] = @USUARIO
                  ,[cer_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
             WHERE [cer_id] = @CER
        END

        /* ---- El hallazgo, si la plantilla lo pide y el valor lo amerita ----

           Uno por respuesta: si el tecnico corrige el valor y vuelve a quedar
           fuera de rango, no se abren dos. */
        IF @FUERA = 1 AND @HALLAZGO = 1
           AND NOT EXISTS (SELECT 1 FROM [dbo].[Checklist_Hallazgo]
                            WHERE [cha_checklist_ejecucion_respuesta] = @CER)
        BEGIN
            DECLARE @TEXTO NVARCHAR(400) =
                (SELECT [cpi_texto] FROM [dbo].[Checklist_Plantilla_Item] WHERE [cpi_id] = @ITEM)

            INSERT INTO [dbo].[Checklist_Hallazgo]
                ([cha_uuid], [cha_cliente], [cha_checklist_ejecucion]
                ,[cha_checklist_ejecucion_respuesta], [cha_activo]
                ,[cha_titulo], [cha_descripcion], [cha_proceso_estado]
                ,[cha_generado_ia], [cha_usuario_creacion], [cha_fecha_creacion]
                ,[cha_habilitado])
            VALUES
                (NEWID(), @CLIENTE, @CEJ_ID
                ,@CER, @ACTIVO
                ,LEFT(ISNULL(@TEXTO, N'Hallazgo de checklist'), 400)
                ,ISNULL(@MENSAJE_VAL, @COMENTARIO), 1
                ,0, @USUARIO, [dbo].[FNC_AHORA]()
                ,1)
        END

        /* ---- Los contadores de la ejecucion.

           Se recalculan, no se acumulan: acumular deja el total mintiendo el
           dia que una respuesta cambie de conforme a no conforme. ---- */
        UPDATE [dbo].[Checklist_Ejecucion]
           SET [cej_item_respondido] =
                   (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion_Respuesta]
                     WHERE [cer_checklist_ejecucion] = @CEJ_ID AND [cer_habilitado] = 1)
              ,[cej_item_no_conforme] =
                   (SELECT COUNT(*) FROM [dbo].[Checklist_Ejecucion_Respuesta]
                     WHERE [cer_checklist_ejecucion] = @CEJ_ID AND [cer_habilitado] = 1
                       AND [cer_fuera_rango] = 1)
              ,[cej_usuario_actualizacion] = @USUARIO
              ,[cej_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
         WHERE [cej_id] = @CEJ_ID

        COMMIT TRANSACTION

        SELECT @CER AS [cer_id], @FUERA AS [fuera_rango],
               @MENSAJE_VAL AS [mensaje]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- API_UPS_FAVORITO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPS_FAVORITO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   API_UPS_FAVORITO - marca o desmarca, y devuelve como quedo

   POR QUE UN SOLO SP Y NO UN INS + UN DEL

     La estrella es un interruptor: la app no sabe â€”ni tiene por que saberâ€” si
     el favorito ya estaba antes de tocarla. Con dos endpoints, dos toques
     rapidos pueden cruzarse y dejar el estado invertido respecto de lo que
     muestra la pantalla. Un UPS que devuelve ES_FAVORITO deja que la pantalla
     se pinte con lo que dijo la base, no con lo que supone.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_FAVORITO]
@USUARIO    INT,
@CLIENTE    INT,
@ENTIDAD    VARCHAR(20),
@ENTIDAD_ID INT
AS
SET NOCOUNT ON

    IF (@ENTIDAD NOT IN ('ORDEN', 'TAREA', 'ACTIVO'))
    BEGIN
        RAISERROR('1.- ESE TIPO DE FAVORITO NO EXISTE.', 16, 1)
        RETURN -1
    END

    DECLARE @ID INT

    SELECT  @ID = ufv_id
    FROM    [dbo].[Usuario_Favorito]
    WHERE   ufv_usuario = @USUARIO
      AND   ((@ENTIDAD = 'ORDEN'  AND ufv_orden_trabajo    = @ENTIDAD_ID)
          OR (@ENTIDAD = 'TAREA'  AND ufv_tarea_ocurrencia = @ENTIDAD_ID)
          OR (@ENTIDAD = 'ACTIVO' AND ufv_activo           = @ENTIDAD_ID))

    IF (@ID IS NOT NULL)
    BEGIN
        DELETE FROM [dbo].[Usuario_Favorito] WHERE ufv_id = @ID
        SELECT CAST(0 AS BIT) AS ES_FAVORITO
        RETURN 0
    END

    INSERT INTO [dbo].[Usuario_Favorito]
        (ufv_usuario, ufv_cliente,
         ufv_orden_trabajo, ufv_tarea_ocurrencia, ufv_activo,
         ufv_usuario_creacion, ufv_fecha_creacion)
    VALUES
        (@USUARIO, @CLIENTE,
         CASE WHEN @ENTIDAD = 'ORDEN'  THEN @ENTIDAD_ID END,
         CASE WHEN @ENTIDAD = 'TAREA'  THEN @ENTIDAD_ID END,
         CASE WHEN @ENTIDAD = 'ACTIVO' THEN @ENTIDAD_ID END,
         @USUARIO, [dbo].[FNC_AHORA]())

    SELECT CAST(1 AS BIT) AS ES_FAVORITO
GO

-- ---------- API_UPS_TAREA_EJECUCION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- API_UPS_TAREA_EJECUCION (P) · 5 [dbo].[FNC_AHORA]() reemplazado(s)
-- ---------------------------------------------------------------------------
-- 3 - LA TAREA QUE EXIGE EVIDENCIA NO SE CIERRA SIN FOTO
-- ---------------------------------------------------------------------------
--   `tar_requiere_evidencia` estaba en la tabla y no lo miraba nadie: una
--   bandera que no se comprueba es peor que no tenerla, porque quien la marca
--   cree que sirve de algo.
--
--   Se comprueba en el SERVIDOR y no solo en la app: un telefono con la
--   version vieja cerraria sin foto en silencio.
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_UPS_TAREA_EJECUCION]
     @UUID          UNIQUEIDENTIFIER
    ,@USUARIO       INT
    ,@CLIENTE       INT
    ,@OCURRENCIA    INT
    ,@FINALIZAR     BIT            = 0
    ,@CONFORME      BIT            = NULL
    ,@RESULTADO     NVARCHAR(MAX)  = NULL
    ,@MINUTOS       INT            = NULL
    ,@DISPOSITIVO   NVARCHAR(200)  = NULL
    ,@OFFLINE       BIT            = 0
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO INT, @EXIGE BIT

        SELECT @ESTADO = toc.[toc_tarea_ocurrencia_estado]
              ,@EXIGE  = tar.[tar_requiere_evidencia]
          FROM [dbo].[Tarea_Ocurrencia] toc
          JOIN [dbo].[Tarea]            tar ON tar.[tar_id] = toc.[toc_tarea]
     LEFT JOIN [dbo].[Activo]           act ON act.[act_id] = tar.[tar_activo]
          JOIN [dbo].[Cliente_Instalacion_Usuario] ciu
                 ON  ciu.[ciu_id_instalacion] = ISNULL(tar.[tar_cliente_instalacion],
                                                       act.[act_cliente_instalacion])
                 AND ciu.[ciu_id_usuario]     = @USUARIO
                 AND ISNULL(ciu.[ciu_habilitado], 0) = 1
         WHERE toc.[toc_id]         = @OCURRENCIA
           AND toc.[toc_cliente]    = @CLIENTE
           AND toc.[toc_habilitado] = 1

        IF @ESTADO IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La tarea no existe o no esta en una planta autorizada.', 16, 1)
            RETURN
        END

        /* ---- La ejecucion: por uuid, o la abierta de esta persona ---- */
        --  El uuid se busca ANTES de mirar el estado. Si no, un reintento de
        --  la cola -que reenvia el mismo cierre porque no alcanzo a ver la
        --  respuesta- se encuentra la tarea ya cerrada por el envio anterior y
        --  recibe un error por algo que si quedo grabado. El tecnico veria un
        --  fallo falso y volveria a llenar lo que ya estaba.
        DECLARE @TEJ INT

        SELECT @TEJ = [tej_id]
          FROM [dbo].[Tarea_Ejecucion]
         WHERE [tej_uuid] = @UUID

        IF @TEJ IS NULL AND @ESTADO >= 4
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('Esta tarea ya esta cerrada.', 16, 1)
            RETURN
        END

        IF @TEJ IS NULL
            SELECT TOP 1 @TEJ = [tej_id]
              FROM [dbo].[Tarea_Ejecucion]
             WHERE [tej_tarea_ocurrencia] = @OCURRENCIA
               AND [tej_usuario_ejecutor] = @USUARIO
               AND [tej_fecha_fin_utc] IS NULL
               AND [tej_habilitado]       = 1
             ORDER BY [tej_id] DESC

        IF @TEJ IS NULL
        BEGIN
            INSERT INTO [dbo].[Tarea_Ejecucion]
                ([tej_uuid], [tej_tarea_ocurrencia], [tej_usuario_ejecutor]
                ,[tej_fecha_inicio_utc], [tej_dispositivo], [tej_offline_creado]
                ,[tej_usuario_creacion], [tej_fecha_creacion], [tej_habilitado])
            VALUES
                (@UUID, @OCURRENCIA, @USUARIO
                ,GETUTCDATE(), @DISPOSITIVO, @OFFLINE
                ,@USUARIO, [dbo].[FNC_AHORA](), 1)

            SET @TEJ = SCOPE_IDENTITY()

            UPDATE [dbo].[Tarea_Ocurrencia]
               SET [toc_tarea_ocurrencia_estado] = 3          -- EN EJECUCION
                  ,[toc_usuario_actualizacion]   = @USUARIO
                  ,[toc_fecha_actualizacion]     = [dbo].[FNC_AHORA]()
             WHERE [toc_id] = @OCURRENCIA
               AND [toc_tarea_ocurrencia_estado] IN (1, 2)

            /* Quien la toma queda como responsable, si no habia ninguno. */
            IF NOT EXISTS (SELECT 1 FROM [dbo].[Tarea_Ocurrencia_Asignacion]
                            WHERE [toa_tarea_ocurrencia] = @OCURRENCIA
                              AND [toa_es_responsable]   = 1)
                INSERT INTO [dbo].[Tarea_Ocurrencia_Asignacion]
                    ([toa_tarea_ocurrencia], [toa_usuario], [toa_es_responsable]
                    ,[toa_fecha_asignacion_utc], [toa_fecha_aceptacion_utc]
                    ,[toa_usuario_creacion], [toa_fecha_creacion])
                VALUES
                    (@OCURRENCIA, @USUARIO, 1
                    ,GETUTCDATE(), GETUTCDATE()
                    ,@USUARIO, [dbo].[FNC_AHORA]())
        END

        /* ---- El cierre ---- */
        IF @FINALIZAR = 1
        BEGIN
            DECLARE @YA_CERRADA BIT =
                CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Tarea_Ejecucion]
                                   WHERE [tej_id] = @TEJ
                                     AND [tej_fecha_fin_utc] IS NOT NULL)
                     THEN 1 ELSE 0 END

            IF @YA_CERRADA = 1
            BEGIN
                COMMIT TRANSACTION
                SELECT @TEJ AS [tej_id], 1 AS [YA_ESTABA]
                RETURN
            END

            /* «No realizada» necesita explicacion: sin motivo, una tarea que
               no se hizo es indistinguible de una que se olvido, y el
               historial del activo queda con un hueco que nadie puede
               interpretar despues. */
            IF @CONFORME = 0 AND LTRIM(RTRIM(ISNULL(@RESULTADO, N''))) = N''
            BEGIN
                ROLLBACK TRANSACTION
                RAISERROR('Si la tarea no se pudo hacer, escribe por que.', 16, 1)
                RETURN
            END

            /* La foto se exige solo cuando la tarea SI se hizo. Si no se pudo
               hacer, no hay nada que fotografiar -y pedirla igual dejaria a la
               persona sin forma de cerrar algo que honestamente no ocurrio-. */
            IF @EXIGE = 1 AND ISNULL(@CONFORME, 1) = 1
               AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Vinculo]
                                WHERE [avi_tarea_ejecucion] = @TEJ
                                  AND [avi_habilitado] = 1)
            BEGIN
                ROLLBACK TRANSACTION
                RAISERROR('Esta tarea pide una foto antes de cerrarla.', 16, 1)
                RETURN
            END

            DECLARE @INICIO DATETIME =
                (SELECT [tej_fecha_inicio_utc] FROM [dbo].[Tarea_Ejecucion] WHERE [tej_id] = @TEJ)

            UPDATE [dbo].[Tarea_Ejecucion]
               SET [tej_fecha_fin_utc]            = GETUTCDATE()
                  ,[tej_duracion_minuto]          = ISNULL(@MINUTOS,
                                                      DATEDIFF(MINUTE, @INICIO, GETUTCDATE()))
                  ,[tej_resultado]                = @RESULTADO
                  ,[tej_conforme]                 = ISNULL(@CONFORME, 1)
                  ,[tej_fecha_sincronizacion_utc] = GETUTCDATE()
                  ,[tej_usuario_actualizacion]    = @USUARIO
                  ,[tej_fecha_actualizacion]      = [dbo].[FNC_AHORA]()
             WHERE [tej_id] = @TEJ

            /* Conforme -> COMPLETADA; no conforme -> NO REALIZADA. Son dos
               desenlaces distintos y el historial tiene que distinguirlos. */
            UPDATE [dbo].[Tarea_Ocurrencia]
               SET [toc_tarea_ocurrencia_estado] =
                       CASE WHEN ISNULL(@CONFORME, 1) = 1 THEN 4 ELSE 5 END
                  ,[toc_usuario_actualizacion]   = @USUARIO
                  ,[toc_fecha_actualizacion]     = [dbo].[FNC_AHORA]()
             WHERE [toc_id] = @OCURRENCIA
        END

        COMMIT TRANSACTION
        SELECT @TEJ AS [tej_id], 0 AS [YA_ESTABA]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MSG NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MSG, 16, 1)
    END CATCH

END
GO

-- ---------- DEL_ARCHIVO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_ARCHIVO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   4. DEL_ARCHIVO

      Baja LOGICA. El blob no se toca: puede estar referenciado
      desde un comprobante de pago de hace dos anos, y esos no se borran.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_ARCHIVO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Archivo]
    SET     arc_habilitado            = 0,
            arc_usuario_actualizacion = @USUARIO,
            arc_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   arc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_ARCHIVO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE ELIMINAR EL ARCHIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_BODEGA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_BODEGA (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[DEL_BODEGA]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @HAB BIT, @SALDO INT

SELECT @HAB = bod_habilitado FROM [dbo].[Bodega] WHERE bod_id = @ID AND bod_cliente = @CLIENTE

IF (@HAB IS NULL)
BEGIN
    RAISERROR('1.- LA BODEGA NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@HAB = 0)
BEGIN
    SELECT @ID [ID], '200' [CODE], 'La bodega ya estaba dada de baja.' [MENSAJE]
    RETURN 0
END

SELECT @SALDO = COUNT(*) FROM [dbo].[Inventario_Saldo]
 WHERE isa_bodega = @ID AND isa_cantidad > 0

IF (@SALDO > 0)
BEGIN
    DECLARE @MSG NVARCHAR(400) =
        '2.- NO SE PUEDE DAR DE BAJA: LA BODEGA TIENE ' + LTRIM(STR(@SALDO))
      + ' REPUESTO(S) CON EXISTENCIA. TRASLADELOS O AJUSTELOS PRIMERO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Bodega]
    SET    bod_habilitado = 0, bod_usuario_actualizacion = @USUARIO,
           bod_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  bod_id = @ID

    -- Las ubicaciones son partes de la bodega: se van con ella.
    UPDATE [dbo].[Bodega_Ubicacion]
    SET    bub_habilitado = 0, bub_usuario_actualizacion = @USUARIO,
           bub_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  bub_bodega = @ID AND bub_habilitado = 1

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Bodega dada de baja.' [MENSAJE]
RETURN 0
GO

-- ---------- DEL_BODEGA_UBICACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_BODEGA_UBICACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[DEL_BODEGA_UBICACION]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u
                    JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
                   WHERE u.bub_id = @ID AND b.bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA UBICACION NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* Los movimientos guardan la ubicacion en la que ocurrieron. Es
       historia: la ubicacion se deshabilita, no se borra, y el movimiento
       viejo sigue diciendo de que estante salio. */

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Bodega_Ubicacion]
    SET    bub_habilitado = 0, bub_usuario_actualizacion = @USUARIO,
           bub_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  bub_id = @ID

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Ubicación dada de baja.' [MENSAJE]
RETURN 0
GO

-- ---------- DEL_CLIENTE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_CLIENTE (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   5. HU-010: ELIMINAR UN CLIENTE ES BAJA LOGICA

      DEL_CLIENTE borraba de verdad: la fila de Cliente, sus afiliaciones y
      los perfiles de esas afiliaciones.

      No corresponde, por dos motivos.

      El primero es contable. Un cliente tiene suscripciones, periodos
      emitidos y pagos verificados. Eso es documentacion comercial que hay
      que conservar, y borrar el cliente deja periodos y pagos apuntando a
      una empresa que ya no existe: el historial de facturacion queda
      ilegible justo cuando alguien lo necesita.

      El segundo es que ya se comportaba a medias como baja logica: el SP se
      negaba a borrar si el cliente tenia plantas. O sea que el unico cliente
      que se podia borrar era el que no tenia nada, y para ese la diferencia
      entre borrar y deshabilitar es ninguna.

      Ahora deshabilita: el cliente deja de aparecer en el selector y sus
      usuarios no entran -SEL_LOGIN exige una afiliacion a cliente
      habilitado-, pero no se pierde un solo registro. Volver a habilitarlo
      es un UPDATE.

      Se conserva el guard de plantas. Con una baja logica ya no es
      estrictamente necesario, pero sigue siendo la conversacion correcta:
      dar de baja una empresa con plantas activas casi siempre es un error de
      quien aprieta el boton, y conviene que tenga que desarmarla primero.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_CLIENTE]
 @ID      INT
,@USUARIO INT
AS
SET NOCOUNT ON

    IF (EXISTS(SELECT TOP 1 1 FROM [dbo].[Cliente_Instalacion] WHERE CIN_CLIENTE = @ID))
    BEGIN
        RAISERROR('1. No es posible dar de baja, el cliente posee plantas', 16, 1);
        RETURN -1;
    END

    BEGIN TRANSACTION

        /* Baja LOGICA. No se borra ni el cliente ni sus afiliaciones: se
           apagan. Los periodos y pagos siguen apuntando a una empresa que
           existe, y el dia que vuelva no hay que rearmarle los usuarios. */
        UPDATE  [dbo].[Cliente]
        SET     cli_habilitado            = 0,
                cli_usuario_actualizacion = @USUARIO,
                cli_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   cli_id = @ID
          AND   ISNULL(cli_habilitado, 0) = 1

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_CLIENTE ' + LTRIM(STR(@ID))
            EXEC [dbo].[INS_EXCEPCION]
                 @MSG       = '1.- El cliente no existe o ya estaba deshabilitado.',
                 @VARIABLES = @VARIABLES
            RETURN -1
        END

        /* Las afiliaciones se apagan tambien: sin esto la gente del cliente
           seguiria entrando, porque su fila en Cliente_Usuario sigue viva.
           SEL_LOGIN exige cliente habilitado, asi que con el UPDATE de
           arriba ya no entrarian; esto lo deja consistente ademas para las
           consultas que miran la afiliacion sin mirar al cliente. */
        UPDATE  [dbo].[Cliente_Usuario]
        SET     ucl_habilitado = 0
        WHERE   ucl_id_cliente = @ID

    COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_CLIENTE_INSTALACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_CLIENTE_INSTALACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:			Ignacio Montano
-- Fecha creación:	06-02-2025
-- Description:		Eliminar Cliente_instalacion
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_CLIENTE_INSTALACION]
@ID INT
,@USUARIO INT 
AS
SET NOCOUNT ON

-- VALIDACION DE HORA
BEGIN
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT


		SELECT @PAIS_USUARIO = CLI_PAIS 
		FROM CLIENTE
		INNER JOIN CLIENTE_INSTALACION ON CIN_CLIENTE = CLI_ID
		WHERE CIN_ID = @ID

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = [dbo].[FNC_AHORA]()
END


BEGIN TRANSACTION


	-- ACTUALIZO USUARIO Y FECHA PARA LOG
	BEGIN
		UPDATE CLIENTE_INSTALACION 
		SET CIN_USUARIO_ACTUALIZACION = @USUARIO,
			CIN_FECHA_ACTUALIZACION = @DATE_NOW
		WHERE CIN_ID = @ID
	END

	DELETE	CLIENTE_INSTALACION
	WHERE	CIN_ID = @ID
				
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'DEL_CLIENTE_INSTALACION ' + LTRIM(STR(@ID))
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Eliminar el CLIENTE_INSTALACION.',
			@VARIABLES = @VARIABLES
		RETURN -1 
	END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_MODULOS_SISTEMA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_MODULOS_SISTEMA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:		BRYAN CHAVEZ
-- Fecha creación: 02-06-2026
-- Description: Elimina un módulo del sistema
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_MODULOS_SISTEMA]
    @ID      INT,
    @USUARIO INT,
@PAIS VARCHAR(MAX)

AS
SET NOCOUNT ON

--OBTENCION FECHA SEGUN PAIS
DECLARE @DATE_NOW DATETIME

-- Si viene más de un país (detectamos coma)
IF CHARINDEX(',', @PAIS) > 0
BEGIN
	SET @DATE_NOW = [dbo].[FNC_AHORA]()
END
ELSE
BEGIN
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION

    DECLARE @VARIABLES VARCHAR(MAX)

    UPDATE MODULOS_SISTEMA
	SET		mds_usuario_act = @USUARIO
			,mds_fecha_act = @DATE_NOW
	WHERE	mds_id = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION

		SET @VARIABLES = 'DEL_MODULOS_SISTEMA  ' + STR(@ID) 						
		EXEC INS_EXCEPCION 
			@MSG = '1.-  NO FUE POSIBLE ACTUALIZAR LA FECHA DE ELIMINACIÓN.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END


    DELETE FROM MODULOS_SISTEMA WHERE mds_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        SET @VARIABLES = 'DEL_MODULOS_SISTEMA ' + STR(@ID) + ',' + STR(@USUARIO)
        EXEC INS_EXCEPCION
            @MSG       = '1.- NO FUE POSIBLE ELIMINAR EL MÓDULO DEL SISTEMA.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- DEL_PAISES (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_PAISES (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:			BRYAN CHAVEZ
-- Fecha creación:	04-02-2025
-- Description:		Eliminar Paises
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_PAISES]
@ID INT
,@USUARIO INT
,@PAIS VARCHAR(MAX)

AS
SET NOCOUNT ON

--OBTENCION FECHA SEGUN PAIS
DECLARE @DATE_NOW DATETIME

-- Si viene más de un país (detectamos coma)
IF CHARINDEX(',', @PAIS) > 0
BEGIN
	SET @DATE_NOW = [dbo].[FNC_AHORA]()
END
ELSE
BEGIN
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END
--VALIDACIONES
BEGIN

	IF EXISTS(SELECT 1 FROM USUARIO_PAISES WHERE UPA_ID_PAIS = @ID)BEGIN
		RAISERROR('2. No puedes eliminar el registro porque tiene un usuario asociado.', 16,1)
		RETURN -2;
	END

	IF EXISTS(SELECT 1 FROM CLIENTE WHERE cli_pais = @ID)BEGIN
		RAISERROR('3. No puedes eliminar el registro porque tiene un cliente asociado.', 16,1)
		RETURN -3;
	END
END

BEGIN TRANSACTION

	UPDATE PAISES
	SET		PAI_USUARIO_ACTUALIZACION = @USUARIO
			,PAI_FECHA_ACTUALIZACION = @DATE_NOW
	WHERE	PAI_ID = @ID

	DELETE PAISES
	WHERE	PAI_ID = @ID


			
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'DEL_PAISES ' + LTRIM(STR(@ID))
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Eliminar el Paises.',
			@VARIABLES = @VARIABLES
		RETURN -1 
	END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_PLAN_COMERCIAL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_PLAN_COMERCIAL (P) · 3 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_COMERCIAL]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

DECLARE @EXISTE      BIT = 0
       ,@HABILITADO  BIT
       ,@NOMBRE      NVARCHAR(100)
       ,@VIVAS       INT

SELECT  @EXISTE     = 1
       ,@HABILITADO = plc_habilitado
       ,@NOMBRE     = plc_nombre
FROM    [dbo].[Plan_Comercial]
WHERE   plc_id = @ID

IF (@EXISTE = 0)
BEGIN
    RAISERROR('1.- EL PLAN COMERCIAL NO EXISTE.', 16, 1)
    RETURN -1
END

/* Ya deshabilitado: no es un error, es que alguien apreto dos veces o dos
   personas hicieron lo mismo. Devolver un error obligaria a la pantalla a
   distinguir "fallo" de "ya estaba", y termina mostrando un rojo por algo
   que salio bien. */
IF (@HABILITADO = 0)
BEGIN
    SELECT @ID [ID], '200' [CODE], 'El plan ya estaba dado de baja.' [MENSAJE]
    RETURN 0
END

SELECT  @VIVAS = COUNT(*)
FROM    [dbo].[Suscripcion]
WHERE   sus_plan_comercial = @ID
  AND   ISNULL(sus_habilitado, 0) = 1

IF (@VIVAS > 0)
BEGIN
    DECLARE @MSG NVARCHAR(400) =
        '2.- NO SE PUEDE DAR DE BAJA EL PLAN ' + ISNULL(@NOMBRE, '') + ': HAY '
      + LTRIM(STR(@VIVAS)) + ' SUSCRIPCION(ES) VIGENTE(S) USANDOLO. '
      + 'CAMBIE ESOS CLIENTES DE PLAN PRIMERO.'

    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial]
    SET     plc_habilitado            = 0
           ,plc_publico               = 0      -- deja de ofrecerse, ademas
           ,plc_usuario_actualizacion = @USUARIO
           ,plc_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   plc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_COMERCIAL @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '3.- NO FUE POSIBLE DAR DE BAJA EL PLAN.'
        RETURN -1
    END

    -- Las partes del plan se van con el.
    UPDATE  [dbo].[Plan_Comercial_Precio]
    SET     pcp_habilitado            = 0
           ,pcp_usuario_actualizacion = @USUARIO
           ,pcp_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   pcp_plan_comercial = @ID
      AND   ISNULL(pcp_habilitado, 0) = 1

    UPDATE  [dbo].[Plan_Comercial_Funcionalidad]
    SET     pcf_habilitado            = 0
           ,pcf_usuario_actualizacion = @USUARIO
           ,pcf_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   pcf_plan_comercial = @ID
      AND   ISNULL(pcf_habilitado, 0) = 1

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Plan dado de baja.' [MENSAJE]
RETURN 0
GO

-- ---------- DEL_PLAN_COMERCIAL_PRECIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_PLAN_COMERCIAL_PRECIO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   4. DEL_PLAN_COMERCIAL_PRECIO

      Retira una periodicidad de la venta. Baja LOGICA: la fila se conserva
      porque puede haber cotizado periodos que todavia se consultan.

      Sin fila vigente, esa combinacion plan+periodicidad deja de venderse.
      La ausencia de precio ES la regla del modelo, no un error.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_COMERCIAL_PRECIO]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial_Precio]
    SET     pcp_habilitado            = 0,
            pcp_vigencia_hasta        = ISNULL(pcp_vigencia_hasta, CAST([dbo].[FNC_AHORA]() AS DATE)),
            pcp_usuario_actualizacion = @USUARIO,
            pcp_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   pcp_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_COMERCIAL_PRECIO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE RETIRAR EL PRECIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_PLAN_FUNCIONALIDAD (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_PLAN_FUNCIONALIDAD (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   3. DEL_PLAN_FUNCIONALIDAD

      Quita la fila. Baja LOGICA, y con una consecuencia que hay que tener
      clara: sin fila, la funcionalidad queda NEGADA, no "sin definir".
      FNC_CLIENTE_TIENE_FUNCIONALIDAD devuelve 0 por defecto.

      Sirve sobre todo para retirar una EXCEPCION de cliente y que vuelva a
      mandar la regla del plan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_PLAN_FUNCIONALIDAD]
@ID      INT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial_Funcionalidad]
    SET     pcf_habilitado            = 0,
            pcf_usuario_actualizacion = @USUARIO,
            pcf_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   pcf_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_PLAN_FUNCIONALIDAD @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE QUITAR LA FUNCIONALIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_PRIVACIDAD_MODULOS_SISTEMA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_PRIVACIDAD_MODULOS_SISTEMA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:         BRYAN CHAVEZ
-- FECHA CREACIÓN: 08-06-2026
-- DESCRIPTION:    DELETE PRIVACIDAD MODULO SISTEMA
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_PRIVACIDAD_MODULOS_SISTEMA]
    @ID INT,
    @USUARIO INT,
@PAIS VARCHAR(MAX)

AS
SET NOCOUNT ON

--OBTENCION FECHA SEGUN PAIS
DECLARE @DATE_NOW DATETIME

-- Si viene más de un país (detectamos coma)
IF CHARINDEX(',', @PAIS) > 0
BEGIN
	SET @DATE_NOW = [dbo].[FNC_AHORA]()
END
ELSE
BEGIN
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION

    --- ACTUALIZO EL REGISTRO PARA EL LOG
    BEGIN
        UPDATE Privacidad_Modulos_Sistema
        SET PMS_USUARIO_ACT = @USUARIO
            ,PMS_FECHA_ACT = @DATE_NOW
        WHERE PMS_ID = @ID
    END

    DELETE FROM PRIVACIDAD_MODULOS_SISTEMA WHERE PMS_ID = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RAISERROR('NO FUE POSIBLE ELIMINAR EL REGISTRO DE PRIVACIDAD.', 16, 1)
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- DEL_REPUESTO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_REPUESTO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[DEL_REPUESTO]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

DECLARE @HAB BIT, @EXIST DECIMAL(18,4)

SELECT @HAB = rep_habilitado FROM [dbo].[Repuesto] WHERE rep_id = @ID AND rep_cliente = @CLIENTE

IF (@HAB IS NULL)
BEGIN
    RAISERROR('1.- EL REPUESTO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@HAB = 0)
BEGIN
    SELECT @ID [ID], '200' [CODE], 'El repuesto ya estaba dado de baja.' [MENSAJE]
    RETURN 0
END

SELECT @EXIST = ISNULL(SUM(isa_cantidad), 0) FROM [dbo].[Inventario_Saldo] WHERE isa_repuesto = @ID

IF (@EXIST > 0)
BEGIN
    DECLARE @MSG NVARCHAR(400) =
        '2.- NO SE PUEDE DAR DE BAJA: QUEDAN ' + LTRIM(STR(CAST(@EXIST AS INT)))
      + ' UNIDAD(ES) EN BODEGA. AJUSTE LA EXISTENCIA A CERO PRIMERO.'
    RAISERROR(@MSG, 16, 1)
    RETURN -1
END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Repuesto]
    SET    rep_habilitado = 0, rep_usuario_actualizacion = @USUARIO,
           rep_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  rep_id = @ID

    -- Los umbrales de un repuesto que ya no se usa dejarian alertas vivas.
    UPDATE [dbo].[Repuesto_Bodega_Stock]
    SET    rbs_habilitado = 0, rbs_usuario_actualizacion = @USUARIO,
           rbs_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  rbs_repuesto = @ID AND rbs_habilitado = 1

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Repuesto dado de baja.' [MENSAJE]
RETURN 0
GO

-- ---------- DEL_REPUESTO_BODEGA_STOCK (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_REPUESTO_BODEGA_STOCK (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[DEL_REPUESTO_BODEGA_STOCK]
    @ID      INT,
    @CLIENTE INT,
    @USUARIO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Bodega_Stock]
                    WHERE rbs_id = @ID AND rbs_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LOS UMBRALES NO EXISTEN.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE [dbo].[Repuesto_Bodega_Stock]
    SET    rbs_habilitado = 0, rbs_usuario_actualizacion = @USUARIO,
           rbs_fecha_actualizacion = [dbo].[FNC_AHORA]()
    WHERE  rbs_id = @ID

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Umbrales retirados.' [MENSAJE]
RETURN 0
GO

-- ---------- DEL_UNIDAD_MEDIDA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_UNIDAD_MEDIDA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   T-2283 - DEL_UNIDAD_MEDIDA
      Baja logica. Rechaza si la unidad esta en uso -medidores, repuestos,
      variables, atributos- o si otra unidad la usa como base, en vez de
      dejar esas filas apuntando a una unidad dada de baja.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_UNIDAD_MEDIDA]
@ID         INT,
@USUARIO    INT

AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @ID)
BEGIN
    RAISERROR('1.- LA UNIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_unidad_base = @ID)
    BEGIN
        RAISERROR('2.- OTRAS UNIDADES LA USAN COMO BASE. NO SE PUEDE DAR DE BAJA.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor] WHERE ame_unidad_medida = @ID)
    OR EXISTS (SELECT 1 FROM [dbo].[Repuesto]       WHERE rep_unidad_medida = @ID)
    OR EXISTS (SELECT 1 FROM [dbo].[Activo_Variable] WHERE ava_unidad_medida = @ID)
    OR EXISTS (SELECT 1 FROM [dbo].[Atributo_Tecnico] WHERE ate_unidad_medida = @ID)
    BEGIN
        RAISERROR('3.- LA UNIDAD ESTA EN USO (MEDIDORES, REPUESTOS, VARIABLES O ATRIBUTOS). DESHABILITELA EN VEZ DE ELIMINARLA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Unidad_Medida]
    SET     ume_habilitado            = 0
           ,ume_usuario_actualizacion = @USUARIO
           ,ume_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   ume_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_UNIDAD_MEDIDA ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE DAR DE BAJA LA UNIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_USUARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_USUARIO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:		SEBASTIAN LEON
-- CREATE DATE:	01-09-2021
-- DESCRIPTION:	ELIMINA USUARIOS
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_USUARIO]
@ID INT,
@USUARIO INT,
@PAIS VARCHAR(MAX)

AS
SET NOCOUNT ON

--OBTENCION FECHA SEGUN PAIS
DECLARE @DATE_NOW DATETIME

-- Si viene más de un país (detectamos coma)
IF CHARINDEX(',', @PAIS) > 0
BEGIN
	SET @DATE_NOW = [dbo].[FNC_AHORA]()
END
ELSE
BEGIN
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

-- VALIDACIONES
BEGIN
	-- VALIDAR SI EL USUARIO ESTA ASOCIADO A UN CLIENTE Y ME INDICA CUAL
	BEGIN 
		DECLARE @ClienteNombre VARCHAR(255);

		SELECT TOP 1 @ClienteNombre = CLI_NOMBRE
				FROM CLIENTE 
				INNER JOIN CLIENTE_USUARIO  ON CLI_ID = UCL_ID_CLIENTE
				WHERE UCL_ID_USUARIO = LTRIM(RTRIM(@ID));

		IF @ClienteNombre IS NOT NULL
		BEGIN
			RAISERROR('1. No es posible eliminar, el usuario está asociado al cliente: %s.', 16, 1, @ClienteNombre);
			RETURN -1;
		END
	END
END

BEGIN TRANSACTION

	DECLARE @VARIABLES VARCHAR(MAX)

    UPDATE USUARIO
	SET		usu_usuario_act = @USUARIO
			,usu_fecha_act = @DATE_NOW
	WHERE	usu_id = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION

		SET @VARIABLES = 'DEL_USUARIO  ' + STR(@ID) 						
		EXEC INS_EXCEPCION 
			@MSG = '1.-  NO FUE POSIBLE ACTUALIZAR LA FECHA DE ELIMINACIÓN.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END

	UPDATE USUARIO_PAISES
	SET		upa_usuario_act = @USUARIO
			,upa_fecha_act = @DATE_NOW
	WHERE	upa_id = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION

		SET @VARIABLES = 'DEL_USUARIO  ' + STR(@ID) 						
		EXEC INS_EXCEPCION 
			@MSG = '1.-  NO FUE POSIBLE ACTUALIZAR LA FECHA DE ELIMINACIÓN.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END


	-- ELIMINO EL PAIS ASOCIADO
	DELETE	USUARIO_PAISES
	WHERE	UPA_ID_USUARIO = @ID

	-- ELIMINO EL PERFIL ASOCIADO
	DELETE	USUARIO_PERFIL
	WHERE	UPE_USUARIO = @ID


	-- ELIMINO EL USUARIO 
	DELETE	USUARIO
	WHERE	USU_ID = @ID
	
	SET @ID = SCOPE_IDENTITY()	
	
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		RAISERROR('1.- No fue posible actualizar el registro.', 16,1)		
		RETURN -1  
	END		

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEL_USUARIO_PAISES (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- DEL_USUARIO_PAISES (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:		BRYAN CHAVEZ
-- CREATE DATE: 04-02-2025
-- DESCRIPTION:	ELIMINA RELACION USUARIO PERFIL
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[DEL_USUARIO_PAISES]
@ID INT,
@USUARIO INT,
@PAIS VARCHAR(MAX)

AS
SET NOCOUNT ON
-- OBTENGO LA HORA SEGUN PAIS
DECLARE @DATE_NOW DATETIME

-- Si viene más de un país (detectamos coma)
IF CHARINDEX(',', @PAIS) > 0
BEGIN
	SET @DATE_NOW = [dbo].[FNC_AHORA]()
END
ELSE
BEGIN
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END
BEGIN TRANSACTION

	DECLARE @VARIABLES VARCHAR(MAX)

 --   UPDATE USUARIO_PAISES
	--SET		UPA_USUARIO_ACT = @USUARIO
	--		,UPA_FECHA_ACT = @DATE_NOW
	--WHERE	UPA_ID = @ID

	--IF @@ROWCOUNT = 0 BEGIN
	--	ROLLBACK TRANSACTION

	--	SET @VARIABLES = 'DEL_USUARIO_PAISES  ' + STR(@ID) 						
	--	EXEC INS_EXCEPCION 
	--		@MSG = '1.-  NO FUE POSIBLE ACTUALIZAR LA FECHA DE ELIMINACIÓN.',
	--		@VARIABLES = @VARIABLES
	--	RETURN -1  
	--END

	DELETE	USUARIO_PAISES
	WHERE	UPA_ID  = @ID
	
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		SET @VARIABLES = 'DEL_USUARIO_PAISES ' + STR(@ID) 
						
		
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible eliminar el registro.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- GEN_ALERTA_INVENTARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- GEN_ALERTA_INVENTARIO (P) · 6 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[GEN_ALERTA_INVENTARIO]
    @CLIENTE INT,
    @USUARIO INT = 1,
    @DIAS_AVISO_VENCIMIENTO INT = 60
AS
SET NOCOUNT ON

DECLARE @MIN INT, @MAX INT, @VENC INT, @POR_VENCER INT
DECLARE @NUEVA INT, @RESUELTA INT
DECLARE @SEV_ALTA INT, @SEV_ADV INT, @SEV_CRITICA INT
DECLARE @AHORA DATETIME = GETUTCDATE()
DECLARE @ABIERTAS TABLE (ID INT)

SELECT @MIN        = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'STOCK MINIMO'
SELECT @MAX        = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'STOCK MAXIMO'
SELECT @VENC       = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LOTE VENCIDO'
SELECT @POR_VENCER = alt_id FROM [dbo].[Alerta_Tipo] WHERE alt_codigo = 'LOTE POR VENCER'

SELECT @NUEVA    = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'NUEVA'
SELECT @RESUELTA = aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'RESUELTA'

SELECT @SEV_ALTA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ALTA'
SELECT @SEV_ADV  = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'ADVERTENCIA'
SELECT @SEV_CRITICA = sev_id FROM [dbo].[Severidad] WHERE sev_codigo = 'CRITICA'


/* ---- Lo que HOY esta mal ----
   Se calcula una vez y se guarda, porque se usa dos veces: para abrir lo que
   falta y para cerrar lo que sobra. */
IF OBJECT_ID('tempdb..#HALLAZGO') IS NOT NULL DROP TABLE #HALLAZGO

CREATE TABLE #HALLAZGO (
    TIPO INT, REPUESTO INT, BODEGA INT NULL, LOTE INT NULL,
    TITULO NVARCHAR(400), DESCRIPCION NVARCHAR(1000),
    OBSERVADO DECIMAL(18,4), UMBRAL DECIMAL(18,4),
    UNIDAD INT NULL, SEVERIDAD INT)

/* Stock: el umbral esta definido por (repuesto, bodega), asi que la
   comparacion se hace sobre el TOTAL de la bodega y no sobre cada estante. */
;WITH SALDO AS (
    SELECT s.isa_repuesto, s.isa_bodega, SUM(s.isa_cantidad) AS CANT
    FROM   [dbo].[Inventario_Saldo] s
    WHERE  s.isa_cliente = @CLIENTE
    GROUP BY s.isa_repuesto, s.isa_bodega
)
INSERT INTO #HALLAZGO
SELECT  @MIN, r.rep_id, b.bod_id, NULL,
        CASE WHEN ISNULL(sa.CANT, 0) <= 0
              THEN r.rep_codigo + N' SIN EXISTENCIA en ' + b.bod_nombre
              ELSE r.rep_codigo + N' bajo el mínimo en ' + b.bod_nombre END,
        N'Hay ' + LTRIM(STR(CAST(ISNULL(sa.CANT, 0) AS DECIMAL(18,2)), 18, 2)) + N' ' + ume.ume_simbolo +
        N' y el mínimo es ' + LTRIM(STR(CAST(st.rbs_stock_minimo AS DECIMAL(18,2)), 18, 2)) +
        N'. Faltan ' + LTRIM(STR(CAST(st.rbs_stock_minimo - ISNULL(sa.CANT, 0) AS DECIMAL(18,2)), 18, 2)) + N'.',
        ISNULL(sa.CANT, 0), st.rbs_stock_minimo, r.rep_unidad_medida,
        CASE WHEN ISNULL(sa.CANT, 0) <= 0 THEN @SEV_CRITICA ELSE @SEV_ALTA END
FROM    [dbo].[Repuesto_Bodega_Stock] st
JOIN    [dbo].[Repuesto] r ON r.rep_id = st.rbs_repuesto AND r.rep_cliente = @CLIENTE
JOIN    [dbo].[Bodega] b   ON b.bod_id = st.rbs_bodega
JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
LEFT JOIN SALDO sa ON sa.isa_repuesto = st.rbs_repuesto AND sa.isa_bodega = st.rbs_bodega
WHERE   st.rbs_habilitado = 1
  AND   r.rep_habilitado = 1
  AND   st.rbs_stock_minimo IS NOT NULL
  AND   ISNULL(sa.CANT, 0) < st.rbs_stock_minimo

;WITH SALDO AS (
    SELECT s.isa_repuesto, s.isa_bodega, SUM(s.isa_cantidad) AS CANT
    FROM   [dbo].[Inventario_Saldo] s
    WHERE  s.isa_cliente = @CLIENTE
    GROUP BY s.isa_repuesto, s.isa_bodega
)
INSERT INTO #HALLAZGO
SELECT  @MAX, r.rep_id, b.bod_id, NULL,
        r.rep_codigo + N' sobre el máximo en ' + b.bod_nombre,
        N'Hay ' + LTRIM(STR(CAST(sa.CANT AS DECIMAL(18,2)), 18, 2)) + N' ' + ume.ume_simbolo +
        N' y el máximo es ' + LTRIM(STR(CAST(st.rbs_stock_maximo AS DECIMAL(18,2)), 18, 2)) + N'.',
        sa.CANT, st.rbs_stock_maximo, r.rep_unidad_medida, @SEV_ADV
FROM    [dbo].[Repuesto_Bodega_Stock] st
JOIN    [dbo].[Repuesto] r ON r.rep_id = st.rbs_repuesto AND r.rep_cliente = @CLIENTE
JOIN    [dbo].[Bodega] b   ON b.bod_id = st.rbs_bodega
JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
JOIN    SALDO sa ON sa.isa_repuesto = st.rbs_repuesto AND sa.isa_bodega = st.rbs_bodega
WHERE   st.rbs_habilitado = 1
  AND   r.rep_habilitado = 1
  AND   st.rbs_stock_maximo IS NOT NULL
  AND   sa.CANT > st.rbs_stock_maximo

/* Lotes: solo los que TODAVIA tienen existencia. Avisar de un lote vencido
   que ya se consumio entero es ruido: no hay nada que hacer con el. */
INSERT INTO #HALLAZGO
SELECT  CASE WHEN l.rlo_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE) THEN @VENC ELSE @POR_VENCER END,
        r.rep_id, NULL, l.rlo_id,
        CASE WHEN l.rlo_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE)
             THEN N'Lote ' + l.rlo_codigo + N' de ' + r.rep_codigo + N' está vencido'
             ELSE N'Lote ' + l.rlo_codigo + N' de ' + r.rep_codigo + N' vence pronto' END,
        N'Vence el ' + CONVERT(NVARCHAR(10), l.rlo_fecha_vencimiento, 103) +
        N' y quedan ' + LTRIM(STR(CAST(q.CANT AS DECIMAL(18,2)), 18, 2)) + N' ' + ume.ume_simbolo + N'.',
        q.CANT, NULL, r.rep_unidad_medida,
        CASE WHEN l.rlo_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE) THEN @SEV_CRITICA ELSE @SEV_ADV END
FROM    [dbo].[Repuesto_Lote] l
JOIN    [dbo].[Repuesto] r ON r.rep_id = l.rlo_repuesto
JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
JOIN    (SELECT isa_repuesto_lote, SUM(isa_cantidad) AS CANT
         FROM   [dbo].[Inventario_Saldo]
         WHERE  isa_cliente = @CLIENTE AND isa_repuesto_lote IS NOT NULL
         GROUP BY isa_repuesto_lote
         HAVING SUM(isa_cantidad) > 0) q ON q.isa_repuesto_lote = l.rlo_id
WHERE   l.rlo_cliente = @CLIENTE
  AND   l.rlo_habilitado = 1
  AND   l.rlo_fecha_vencimiento IS NOT NULL
  AND   DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), l.rlo_fecha_vencimiento) <= @DIAS_AVISO_VENCIMIENTO


/* ---- Abrir lo que empezo a pasar ---- */
INSERT INTO [dbo].[Alerta]
    (ale_uuid, ale_cliente, ale_alerta_tipo, ale_alerta_estado, ale_severidad,
     ale_titulo, ale_descripcion, ale_fecha_deteccion_utc,
     ale_repuesto, ale_bodega, ale_repuesto_lote,
     ale_valor_observado, ale_valor_umbral, ale_unidad_medida,
     ale_usuario_creacion, ale_fecha_creacion, ale_habilitado)
SELECT  NEWID(), @CLIENTE, h.TIPO, @NUEVA, h.SEVERIDAD,
        h.TITULO, h.DESCRIPCION, @AHORA,
        h.REPUESTO, h.BODEGA, h.LOTE,
        h.OBSERVADO, h.UMBRAL, h.UNIDAD,
        @USUARIO, [dbo].[FNC_AHORA](), 1
FROM    #HALLAZGO h
WHERE   NOT EXISTS (
            SELECT 1 FROM [dbo].[Alerta] a
            WHERE  a.ale_cliente = @CLIENTE
              AND  a.ale_alerta_tipo = h.TIPO
              AND  a.ale_habilitado = 1
              AND  a.ale_alerta_estado NOT IN (@RESUELTA,
                     (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'))
              AND  ISNULL(a.ale_repuesto, -1)      = ISNULL(h.REPUESTO, -1)
              AND  ISNULL(a.ale_bodega, -1)        = ISNULL(h.BODEGA, -1)
              AND  ISNULL(a.ale_repuesto_lote, -1) = ISNULL(h.LOTE, -1))

DECLARE @ABIERTAS_N INT = @@ROWCOUNT


/* ---- Cerrar lo que dejo de pasar ----
   Se marca RESUELTA y no se borra: quien pregunte "cuantas veces nos quedamos
   sin este repuesto" necesita que la historia siga ahi. */
UPDATE  a
SET     a.ale_alerta_estado       = @RESUELTA,
        a.ale_fecha_atencion_utc  = @AHORA,
        a.ale_usuario_actualizacion = @USUARIO,
        a.ale_fecha_actualizacion = [dbo].[FNC_AHORA]()
FROM    [dbo].[Alerta] a
WHERE   a.ale_cliente = @CLIENTE
  AND   a.ale_habilitado = 1
  AND   a.ale_alerta_tipo IN (@MIN, @MAX, @VENC, @POR_VENCER)
  AND   a.ale_alerta_estado NOT IN (@RESUELTA,
          (SELECT aet_id FROM [dbo].[Alerta_Estado] WHERE aet_codigo = 'DESCARTADA'))
  AND   NOT EXISTS (
            SELECT 1 FROM #HALLAZGO h
            WHERE  h.TIPO = a.ale_alerta_tipo
              AND  ISNULL(h.REPUESTO, -1) = ISNULL(a.ale_repuesto, -1)
              AND  ISNULL(h.BODEGA, -1)   = ISNULL(a.ale_bodega, -1)
              AND  ISNULL(h.LOTE, -1)     = ISNULL(a.ale_repuesto_lote, -1))

SELECT  @ABIERTAS_N AS ABIERTAS, @@ROWCOUNT AS CERRADAS
RETURN 0
GO

-- ---------- INS_ACTIVO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_ACTIVO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   T-2003 - INS_ACTIVO
      Alta de un activo dentro de transaccion. Valida el codigo unico por
      cliente ANTES de la transaccion y sella las fechas con la hora local
      del pais del cliente (FNC_PAIS_HORA), no con [dbo].[FNC_AHORA](): SIGMA opera en
      cinco paises y un activo creado en Panama no puede fecharse con la hora
      de Chile.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ACTIVO]
@ID                     INT = NULL OUTPUT,
@CLIENTE                INT,
@CLIENTE_INSTALACION    INT,
@INSTALACION_AREA       INT = NULL,
@ACTIVO_TIPO            INT,
@ACTIVO_MODELO          INT = NULL,
@ACTIVO_ESTADO          INT,
@ACTIVO_PADRE           INT = NULL,
@CENTRO_COSTO           INT = NULL,
@CRITICIDAD_NIVEL       INT,
@CODIGO                 NVARCHAR(50),
@NOMBRE                 NVARCHAR(200),
@NUMERO_SERIE           NVARCHAR(100) = NULL,
@FABRICANTE             NVARCHAR(200) = NULL,
@ANIO_FABRICACION       INT = NULL,
@FECHA_PUESTA_MARCHA    DATE = NULL,
@DESCRIPCION            NVARCHAR(500) = NULL,
@REGISTRO_ORIGEN        INT = NULL,
@USUARIO                INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

-- Origen por defecto: creado en la web (Registro_Origen id 2 = PLANIFICADOR WEB).
SET @REGISTRO_ORIGEN = ISNULL(@REGISTRO_ORIGEN, 2)

BEGIN
    -- Codigo unico por cliente (HU-035 escenario 2).
    IF EXISTS (SELECT 1 FROM [dbo].[Activo]
                WHERE act_cliente = @CLIENTE AND act_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UN ACTIVO CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- La planta tiene que ser del mismo cliente: un activo no puede colgar
    -- de la instalacion de otra empresa.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- El activo padre, si se indica, tambien es del mismo cliente.
    IF @ACTIVO_PADRE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Activo]
                        WHERE act_id = @ACTIVO_PADRE AND act_cliente = @CLIENTE)
    BEGIN
        RAISERROR('3.- EL ACTIVO SUPERIOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Activo]
        (
            act_cliente,
            act_cliente_instalacion,
            act_instalacion_area,
            act_activo_tipo,
            act_activo_modelo,
            act_activo_estado,
            act_activo_padre,
            act_centro_costo,
            act_criticidad_nivel,
            act_codigo,
            act_nombre,
            act_numero_serie,
            act_fabricante,
            act_anio_fabricacion,
            act_fecha_puesta_marcha,
            act_descripcion,
            act_registro_origen,
            act_usuario_creacion,
            act_fecha_creacion,
            act_usuario_actualizacion,
            act_fecha_actualizacion,
            act_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @INSTALACION_AREA,
            @ACTIVO_TIPO,
            @ACTIVO_MODELO,
            @ACTIVO_ESTADO,
            @ACTIVO_PADRE,
            @CENTRO_COSTO,
            @CRITICIDAD_NIVEL,
            @CODIGO,
            @NOMBRE,
            @NUMERO_SERIE,
            @FABRICANTE,
            @ANIO_FABRICACION,
            @FECHA_PUESTA_MARCHA,
            @DESCRIPCION,
            @REGISTRO_ORIGEN,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Activo]
        SET    [act_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('ACT', @ID)
        WHERE  [act_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ACTIVO @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '4.- NO FUE POSIBLE INSERTAR EL ACTIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_ARCHIVO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_ARCHIVO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   2. INS_ARCHIVO

      Registra un archivo YA SUBIDO al Blob Storage. El SP no maneja
      binarios: recibe la ruta del blob y los metadatos. El orden importa
      -primero el blob, despues la fila- porque una fila sin blob es un
      enlace roto silencioso, y un blob sin fila es basura recuperable.

      @HASH permite deduplicar. NO se deduplica aqui: dos pagos distintos
      pueden adjuntar la misma cartola y cada uno necesita su propia fila
      para que dar de baja uno no deje al otro sin comprobante. El hash
      queda para que un dia se pueda limpiar el contenedor sabiendo que
      copias apuntan al mismo contenido.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_ARCHIVO]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@CATEGORIA         INT,
@NOMBRE_ORIGINAL   NVARCHAR(255),
@NOMBRE_ALMACENADO NVARCHAR(255),
@RUTA              NVARCHAR(500),   -- ruta del blob: contenedor/carpeta/nombre
@MIME              NVARCHAR(100) = NULL,
@EXTENSION         NVARCHAR(20) = NULL,
@BYTE              BIGINT,
@HASH              NVARCHAR(64) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL CLIENTE NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* La categoria puede ser global (aca_cliente NULL) o propia del
       cliente. Una categoria de OTRO cliente no sirve. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo_Categoria]
                    WHERE aca_id = @CATEGORIA
                      AND aca_habilitado = 1
                      AND (aca_cliente IS NULL OR aca_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- LA CATEGORÍA DE ARCHIVO NO EXISTE O NO PERTENECE AL CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @BYTE IS NULL OR @BYTE <= 0
    BEGIN
        RAISERROR('3.- EL ARCHIVO ESTÁ VACÍO.', 16, 1)
        RETURN -1
    END

    IF @RUTA IS NULL OR LEN(LTRIM(@RUTA)) = 0
    BEGIN
        RAISERROR('4.- FALTA LA RUTA DEL BLOB.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Archivo]
        (arc_cliente, arc_archivo_categoria, arc_nombre_original, arc_nombre_almacenado,
         arc_ruta, arc_mime, arc_extension, arc_byte, arc_hash,
         arc_archivo_antivirus_estado,
         arc_usuario_creacion, arc_fecha_creacion,
         arc_usuario_actualizacion, arc_fecha_actualizacion, arc_habilitado)
    VALUES
        (@CLIENTE, @CATEGORIA, @NOMBRE_ORIGINAL, @NOMBRE_ALMACENADO,
         @RUTA, @MIME, @EXTENSION, @BYTE, @HASH,
         1,                                  -- 1 = PENDIENTE de antivirus
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_ARCHIVO @CLIENTE = ' + LTRIM(STR(@CLIENTE))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '5.- NO FUE POSIBLE REGISTRAR EL ARCHIVO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_BODEGA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_BODEGA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[INS_BODEGA]
    @ID          INT OUTPUT,
    @CLIENTE     INT,
    @INSTALACION INT,
    @CODIGO      NVARCHAR(100),
    @NOMBRE      NVARCHAR(400),
    @DESCRIPCION NVARCHAR(1000) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('1.- INDIQUE EL CODIGO DE LA BODEGA.', 16, 1)
        RETURN -1
    END

    /* La planta tiene que ser del cliente. Sin esto, un id de otra empresa
       en el combo crearia una bodega dentro de la planta ajena. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                    WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Bodega]
                WHERE bod_cliente = @CLIENTE AND bod_codigo = @CODIGO)
    BEGIN
        RAISERROR('3.- YA EXISTE UNA BODEGA CON ESE CODIGO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Bodega]
        (bod_cliente, bod_cliente_instalacion, bod_codigo, bod_nombre, bod_descripcion,
         bod_usuario_creacion, bod_fecha_creacion, bod_habilitado)
    VALUES (@CLIENTE, @INSTALACION, LTRIM(RTRIM(@CODIGO)), @NOMBRE, @DESCRIPCION,
            @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ---- 
       El codigo depende del ID y el ID no existe hasta aca. La ficha
       manda 'AUTO'; ese valor satisface el NOT NULL, pasa por el
       INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Bodega]
        SET    [bod_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('BOD', @ID)
        WHERE  [bod_id] = @ID


COMMIT TRANSACTION
RETURN 0
GO

-- ---------- INS_BODEGA_UBICACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_BODEGA_UBICACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[INS_BODEGA_UBICACION]
    @ID      INT OUTPUT,
    @BODEGA  INT,
    @CLIENTE INT,
    @CODIGO  NVARCHAR(100),
    @NOMBRE  NVARCHAR(400),
    @USUARIO INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA BODEGA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL CODIGO DE LA UBICACION.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                WHERE bub_bodega = @BODEGA AND bub_codigo = @CODIGO)
    BEGIN
        RAISERROR('3.- YA EXISTE UNA UBICACION CON ESE CODIGO EN LA BODEGA.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Bodega_Ubicacion]
        (bub_bodega, bub_codigo, bub_nombre, bub_usuario_creacion, bub_fecha_creacion, bub_habilitado)
    VALUES (@BODEGA, LTRIM(RTRIM(@CODIGO)), @NOMBRE, @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ---- 
       El codigo depende del ID y el ID no existe hasta aca. La ficha
       manda 'AUTO'; ese valor satisface el NOT NULL, pasa por el
       INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Bodega_Ubicacion]
        SET    [bub_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('UBI', @ID)
        WHERE  [bub_id] = @ID


COMMIT TRANSACTION
RETURN 0
GO

-- ---------- INS_CATALOGO_VALOR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_CATALOGO_VALOR (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   4. INS_CATALOGO_VALOR                                            HU-021

      Agrega un valor PROPIO del cliente. Nunca del sistema: el escenario 1
      dice "queda disponible solo para mi cliente", y por eso @CLIENTE es
      obligatorio y siempre se escribe.

      El INSERT se arma segun las columnas que tenga esa tabla en concreto.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CATALOGO_VALOR]
@ID           INT = NULL OUTPUT,
@CATALOGO     INT,
@CLIENTE      INT,
@CODIGO       NVARCHAR(200),
@NOMBRE       NVARCHAR(400),
@DESCRIPCION  NVARCHAR(1000) = NULL,
@ORDEN        INT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @TABLA NVARCHAR(128), @PFX NVARCHAR(10), @AMPLIABLE BIT
DECLARE @OBJETO INT, @SQL NVARCHAR(MAX)
DECLARE @COLS NVARCHAR(MAX) = '', @VALS NVARCHAR(MAX) = ''
DECLARE @EXISTE INT

SELECT  @TABLA = ctl_tabla, @PFX = ctl_prefijo, @AMPLIABLE = ctl_ampliable
FROM    [dbo].[Catalogo] WHERE ctl_id = @CATALOGO

BEGIN
    IF @TABLA IS NULL
    BEGIN
        RAISERROR('1.- EL CATÁLOGO NO ESTÁ REGISTRADO.', 16, 1)
        RETURN -1
    END

    -- Escenario 2: en un catalogo no ampliable la accion no existe
    IF @AMPLIABLE = 0
    BEGIN
        RAISERROR('2.- ESTE CATÁLOGO NO ADMITE VALORES PROPIOS.', 16, 1)
        RETURN -1
    END

    SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))
    IF @OBJETO IS NULL
    BEGIN
        RAISERROR('3.- LA TABLA DEL CATÁLOGO NO EXISTE EN LA BASE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_cliente')
    BEGIN
        RAISERROR('4.- ESTE CATÁLOGO ESTÁ MARCADO COMO AMPLIABLE PERO SU TABLA NO TIENE COLUMNA DE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('5.- DEBE INDICAR EL CLIENTE DUEÑO DEL VALOR.', 16, 1)
        RETURN -1
    END
END

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

/* Codigo unico por cliente y catalogo, contando tambien los del sistema:
   el usuario final ve unos y otros en la misma lista. */
SET @SQL = N'SELECT @P_OUT = COUNT(*) FROM [dbo].' + QUOTENAME(@TABLA) + N'
             WHERE ' + QUOTENAME(@PFX + '_codigo') + N' = @P_CODIGO
               AND (' + QUOTENAME(@PFX + '_cliente') + N' IS NULL
                    OR ' + QUOTENAME(@PFX + '_cliente') + N' = @P_CLIENTE)'

EXEC sp_executesql @SQL,
     N'@P_CODIGO NVARCHAR(200), @P_CLIENTE INT, @P_OUT INT OUTPUT',
     @P_CODIGO = @CODIGO, @P_CLIENTE = @CLIENTE, @P_OUT = @EXISTE OUTPUT

IF @EXISTE > 0
BEGIN
    RAISERROR('6.- YA EXISTE UN VALOR CON EL CÓDIGO "%s" EN ESTE CATÁLOGO.', 16, 1, @CODIGO)
    RETURN -1
END

-- Columnas obligatorias en todo catalogo
SET @COLS = QUOTENAME(@PFX + '_codigo') + N',' + QUOTENAME(@PFX + '_nombre') + N','
          + QUOTENAME(@PFX + '_cliente') + N',' + QUOTENAME(@PFX + '_habilitado')
SET @VALS = N'@P_CODIGO,@P_NOMBRE,@P_CLIENTE,1'

-- Columnas que solo tienen algunos catalogos
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_descripcion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_descripcion')
    SET @VALS = @VALS + N',@P_DESCRIPCION'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_orden')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_orden')
    SET @VALS = @VALS + N',@P_ORDEN'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_usuario_creacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_usuario_creacion')
    SET @VALS = @VALS + N',@P_USUARIO'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_fecha_creacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_fecha_creacion')
    SET @VALS = @VALS + N',[dbo].[FNC_AHORA]()'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_usuario_actualizacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_usuario_actualizacion')
    SET @VALS = @VALS + N',@P_USUARIO'
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_fecha_actualizacion')
BEGIN
    SET @COLS = @COLS + N',' + QUOTENAME(@PFX + '_fecha_actualizacion')
    SET @VALS = @VALS + N',[dbo].[FNC_AHORA]()'
END

SET @SQL = N'INSERT INTO [dbo].' + QUOTENAME(@TABLA) + N' (' + @COLS + N')
             VALUES (' + @VALS + N');
             SELECT @P_ID = CAST(SCOPE_IDENTITY() AS INT);'

--PRINT @SQL

BEGIN TRANSACTION

    EXEC sp_executesql @SQL,
         N'@P_CODIGO NVARCHAR(200), @P_NOMBRE NVARCHAR(400), @P_CLIENTE INT,
           @P_DESCRIPCION NVARCHAR(1000), @P_ORDEN INT, @P_USUARIO INT, @P_ID INT OUTPUT',
         @P_CODIGO = @CODIGO, @P_NOMBRE = @NOMBRE, @P_CLIENTE = @CLIENTE,
         @P_DESCRIPCION = @DESCRIPCION, @P_ORDEN = @ORDEN, @P_USUARIO = @USUARIO,
         @P_ID = @ID OUTPUT

    IF @ID IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CATALOGO_VALOR @CATALOGO = ' + LTRIM(STR(@CATALOGO)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '7.- NO FUE POSIBLE INSERTAR EL VALOR DEL CATÁLOGO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_CHECKLIST_ITEM (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_CHECKLIST_ITEM (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   5. INS_CHECKLIST_ITEM
      Un campo del checklist. genera_medicion se deja en 0 aqui: mandar el
      valor a la serie del activo exige la variable de UN activo concreto, que
      se resuelve al ejecutar la pauta, no al disenarla. Los rangos van en la
      validacion (SP 6).
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_ITEM]
@ID                 INT = NULL OUTPUT,
@VERSION            INT,
@SECCION            INT = NULL,
@CODIGO             NVARCHAR(50),
@TEXTO              NVARCHAR(500),
@TIPO               INT,
@ORDEN              INT = 1,
@OBLIGATORIO        BIT = 1,
@PERMITE_COMENTARIO BIT = 1,
@REQUIERE_EVIDENCIA BIT = 0,
@UNIDAD             INT = NULL,
@USUARIO            INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION
    INSERT [dbo].[Checklist_Plantilla_Item]
        (cpi_checklist_plantilla_version, cpi_checklist_plantilla_seccion, cpi_codigo, cpi_texto,
         cpi_checklist_item_tipo, cpi_orden, cpi_obligatorio, cpi_permite_comentario, cpi_requiere_evidencia,
         cpi_unidad_medida, cpi_genera_medicion,
         cpi_usuario_creacion, cpi_fecha_creacion, cpi_usuario_actualizacion, cpi_fecha_actualizacion, cpi_habilitado)
    VALUES
        (@VERSION, @SECCION, @CODIGO, @TEXTO,
         @TIPO, @ORDEN, @OBLIGATORIO, @PERMITE_COMENTARIO, @REQUIERE_EVIDENCIA,
         @UNIDAD, 0,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)
    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_CHECKLIST_ITEM', @MSG = '1.- NO FUE POSIBLE INSERTAR EL CAMPO.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- INS_CHECKLIST_PLANTILLA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_CHECKLIST_PLANTILLA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   T-4069 - INS_CHECKLIST_PLANTILLA
      Alta dentro de transaccion. Valida el codigo unico por cliente ANTES de
      la transaccion y sella las fechas con la hora local del pais del cliente
      (FNC_PAIS_HORA), no con [dbo].[FNC_AHORA](): SIGMA opera en cinco paises.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_PLANTILLA]
@ID                         INT = NULL OUTPUT,
@CLIENTE                    INT,
@CLIENTE_INSTALACION        INT = NULL,
@CHECKLIST_ASIGNACION_TIPO  INT = NULL,
@ACTIVO_TIPO                INT = NULL,
@CODIGO                     NVARCHAR(50),
@NOMBRE                     NVARCHAR(200),
@DESCRIPCION                NVARCHAR(MAX) = NULL,
@USUARIO                    INT

AS
SET NOCOUNT ON

DECLARE @PAIS INT, @DATE_NOW DATETIME

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @DATE_NOW = [dbo].[FNC_PAIS_HORA](@PAIS)

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    -- Codigo unico por cliente (escenario de negocio de HU-090).
    IF EXISTS (SELECT 1 FROM [dbo].[Checklist_Plantilla]
                WHERE cpl_cliente = @CLIENTE AND cpl_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UNA PLANTILLA CON EL CODIGO "%s" EN ESTE CLIENTE.', 16, 1, @CODIGO)
        RETURN -1
    END

    -- La planta, si se indica, tiene que ser del mismo cliente.
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                        WHERE cin_id = @CLIENTE_INSTALACION AND cin_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Checklist_Plantilla]
        (
            cpl_cliente,
            cpl_cliente_instalacion,
            cpl_checklist_asignacion_tipo,
            cpl_activo_tipo,
            cpl_codigo,
            cpl_nombre,
            cpl_descripcion,
            cpl_usuario_creacion,
            cpl_fecha_creacion,
            cpl_usuario_actualizacion,
            cpl_fecha_actualizacion,
            cpl_habilitado
        )
    VALUES
        (
            @CLIENTE,
            @CLIENTE_INSTALACION,
            @CHECKLIST_ASIGNACION_TIPO,
            @ACTIVO_TIPO,
            @CODIGO,
            @NOMBRE,
            @DESCRIPCION,
            @USUARIO,
            @DATE_NOW,
            @USUARIO,
            @DATE_NOW,
            1
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CHECKLIST_PLANTILLA @CLIENTE = ' + LTRIM(STR(@CLIENTE)) +
                                          ',@CODIGO = ' + ISNULL(@CODIGO, '')

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '3.- NO FUE POSIBLE INSERTAR LA PLANTILLA.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_CHECKLIST_SECCION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_CHECKLIST_SECCION (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   4. INS_CHECKLIST_SECCION
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_SECCION]
@ID         INT = NULL OUTPUT,
@VERSION    INT,
@CODIGO     NVARCHAR(50),
@NOMBRE     NVARCHAR(200),
@ORDEN      INT = 1,
@USUARIO    INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION
    INSERT [dbo].[Checklist_Plantilla_Seccion]
        (cps_checklist_plantilla_version, cps_codigo, cps_nombre, cps_orden,
         cps_usuario_creacion, cps_fecha_creacion, cps_usuario_actualizacion, cps_fecha_actualizacion, cps_habilitado)
    VALUES
        (@VERSION, @CODIGO, @NOMBRE, @ORDEN, @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)
    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_CHECKLIST_SECCION', @MSG = '1.- NO FUE POSIBLE INSERTAR LA SECCION.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- INS_CHECKLIST_VALIDACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_CHECKLIST_VALIDACION (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   6. INS_CHECKLIST_VALIDACION  (los rangos min/max/advertencia/critico)
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[INS_CHECKLIST_VALIDACION]
@ITEM           INT,
@MINIMO         DECIMAL(18,6) = NULL,
@MAXIMO         DECIMAL(18,6) = NULL,
@ADVERTENCIA    DECIMAL(18,6) = NULL,
@CRITICO        DECIMAL(18,6) = NULL,
@GENERA_ALERTA  BIT = 1,
@USUARIO        INT
AS
SET NOCOUNT ON

-- Sin ningun umbral no hay validacion que guardar.
IF (@MINIMO IS NULL AND @MAXIMO IS NULL AND @ADVERTENCIA IS NULL AND @CRITICO IS NULL)
    RETURN(0)

BEGIN TRANSACTION
    INSERT [dbo].[Checklist_Item_Validacion]
        (civ_checklist_plantilla_item, civ_valor_minimo, civ_valor_maximo, civ_valor_advertencia, civ_valor_critico,
         civ_genera_alerta, civ_requiere_comentario_fuera_rango,
         civ_usuario_creacion, civ_fecha_creacion, civ_usuario_actualizacion, civ_fecha_actualizacion, civ_habilitado)
    VALUES
        (@ITEM, @MINIMO, @MAXIMO, @ADVERTENCIA, @CRITICO,
         @GENERA_ALERTA, 1,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = 'INS_CHECKLIST_VALIDACION', @MSG = '1.- NO FUE POSIBLE INSERTAR EL RANGO.'
        RETURN -1
    END
COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- INS_CLIENTE_USUARIO_PERMISO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_CLIENTE_USUARIO_PERMISO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   11. INS_CLIENTE_USUARIO_PERMISO                                  HU-007

       Se agrega el ambito de AREA y se corrige la llamada a INS_EXCEPCION.

       LA CORRECCION: la version anterior llamaba
           EXEC INS_EXCEPCION '6.- ...', @CLIENTE_USUARIO, @PERMISO
       por posicion. El primer parametro de INS_EXCEPCION es @CODIGO INT,
       asi que ese texto se intentaba convertir a entero y reventaba con un
       error de conversion en vez de registrar el mensaje. Ahora va por
       nombre, como manda PATRON_SP §7.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_CLIENTE_USUARIO_PERMISO]
    @ID                     INT = NULL OUTPUT,
    @CLIENTE_USUARIO        INT,
    @PERMISO                INT,
    @CLIENTE_INSTALACION    INT = NULL,
    @INSTALACION_AREA       INT = NULL,
    @OTORGADO               BIT = 1,
    @FECHA_INICIO           DATE = NULL,
    @FECHA_FIN              DATE = NULL,
    @MOTIVO                 NVARCHAR(500) = NULL,
    @CLIENTE                INT,
    @USUARIO                INT
AS
SET NOCOUNT ON

DECLARE @USUARIO_DESTINO INT

BEGIN
    -- 1. Quien otorga debe tener la facultad en ese cliente
    IF [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, N'ASIGNAR PERMISO TERRENO') = 0
    BEGIN
        RAISERROR('1.- NO TIENE LA FACULTAD DE ASIGNAR PERMISOS DE TERRENO.', 16, 1)
        RETURN -1
    END

    -- 2. El permiso debe ser asignable a una persona
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso]
                    WHERE prm_id = @PERMISO AND prm_asignable_usuario = 1 AND prm_habilitado = 1)
    BEGIN
        RAISERROR('2.- ESE PERMISO NO PUEDE ASIGNARSE A UN USUARIO.', 16, 1)
        RETURN -1
    END

    -- 3. El usuario destino debe estar afiliado a ese cliente
    SELECT @USUARIO_DESTINO = ucl_id_usuario
      FROM [dbo].[Cliente_Usuario]
     WHERE ucl_id = @CLIENTE_USUARIO AND ucl_id_cliente = @CLIENTE AND ISNULL(ucl_habilitado, 0) = 1
    IF @USUARIO_DESTINO IS NULL
    BEGIN
        RAISERROR('3.- EL USUARIO NO ESTA AFILIADO Y VIGENTE EN ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    -- 4. Si se acota a una planta, el usuario debe estar autorizado en ella
    IF @CLIENTE_INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion_Usuario]
                        WHERE ciu_id_usuario = @USUARIO_DESTINO
                          AND ciu_id_instalacion = @CLIENTE_INSTALACION
                          AND ciu_habilitado = 1)
    BEGIN
        RAISERROR('4.- EL USUARIO NO ESTA AUTORIZADO EN ESA PLANTA.', 16, 1)
        RETURN -1
    END

    -- 5. Nadie se otorga permisos a si mismo
    IF @USUARIO_DESTINO = @USUARIO
    BEGIN
        RAISERROR('5.- NO PUEDE ASIGNARSE PERMISOS A SI MISMO.', 16, 1)
        RETURN -1
    END

    /* 6. El area tiene que pertenecer a la planta indicada. Sin esto se
          podria acotar un permiso a un area de OTRA planta, y la excepcion
          quedaria escrita en un lugar donde nadie la va a evaluar. */
    IF @INSTALACION_AREA IS NOT NULL
    BEGIN
        IF @CLIENTE_INSTALACION IS NULL
        BEGIN
            RAISERROR('6.- PARA ACOTAR A UN ÁREA DEBE INDICAR TAMBIÉN LA PLANTA.', 16, 1)
            RETURN -1
        END

        IF NOT EXISTS (SELECT 1 FROM [dbo].[Instalacion_Area]
                        WHERE iar_id = @INSTALACION_AREA
                          AND iar_cliente_instalacion = @CLIENTE_INSTALACION
                          AND iar_cliente = @CLIENTE)
        BEGIN
            RAISERROR('7.- EL ÁREA NO PERTENECE A ESA PLANTA.', 16, 1)
            RETURN -1
        END
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Cliente_Usuario_Permiso]
        (cpm_cliente_usuario, cpm_permiso, cpm_cliente_instalacion, cpm_instalacion_area, cpm_otorgado,
         cpm_fecha_inicio, cpm_fecha_fin, cpm_motivo,
         cpm_usuario_creacion, cpm_fecha_creacion,
         cpm_usuario_actualizacion, cpm_fecha_actualizacion, cpm_habilitado)
    VALUES
        (@CLIENTE_USUARIO, @PERMISO, @CLIENTE_INSTALACION, @INSTALACION_AREA, @OTORGADO,
         @FECHA_INICIO, @FECHA_FIN, @MOTIVO,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_CLIENTE_USUARIO_PERMISO ' +
                                          '@CLIENTE_USUARIO = ' + LTRIM(STR(@CLIENTE_USUARIO)) + ',' +
                                          '@PERMISO = ' + LTRIM(STR(@PERMISO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '8.- NO FUE POSIBLE ASIGNAR EL PERMISO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_EXCEPCION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_EXCEPCION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:		Sebastian Leon 
-- Create date: 23-12-2011
-- Description:	Inserta eventos de errores en la ejecución de SP
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_EXCEPCION]
@CODIGO INT = NULL OUTPUT,
@VARIABLES VARCHAR(MAX),
@MSG VARCHAR(MAX)

AS

BEGIN
	INSERT SIS_EXCEPCION (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
	values (@VARIABLES, @MSG, [dbo].[FNC_AHORA]()) 

	SET @CODIGO = @@IDENTITY

	IF @@ROWCOUNT = 0 BEGIN
		RAISERROR('No se pudo ingresar el registro de log de excepción.', 16, 1)
		RETURN -1
	END

	SET @MSG = @MSG + '. Error ID: ' + LTRIM(STR(@CODIGO)) + '.'
	RAISERROR(@MSG, 16, 1)

END
RETURN @CODIGO
GO

-- ---------- INS_INVENTARIO_MOVIMIENTO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_INVENTARIO_MOVIMIENTO (P) · 11 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[INS_INVENTARIO_MOVIMIENTO]
    @ID                INT OUTPUT,
    @CLIENTE           INT,
    @REPUESTO          INT,
    @BODEGA            INT,
    @TIPO              INT,
    @CANTIDAD          DECIMAL(18,4),
    @UBICACION         INT = NULL,
    @LOTE              INT = NULL,
    @COSTO_UNITARIO    DECIMAL(18,4) = NULL,
    @MONEDA            INT = NULL,
    @ORDEN_TRABAJO     INT = NULL,
    @BODEGA_DESTINO    INT = NULL,
    @UBICACION_DESTINO INT = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @UUID              UNIQUEIDENTIFIER = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

DECLARE @SIGNO        INT
       ,@SALDO        DECIMAL(18,4)
       ,@CONTROLA     BIT
       ,@AHORA        DATETIME = GETUTCDATE()
       ,@MSG          NVARCHAR(500)
       ,@COSTO_PROM   DECIMAL(18,4)
       ,@CANT_PREVIA  DECIMAL(18,4)
       ,@TIENE_UBIC   BIT

/* ---- Idempotencia: si el uuid ya paso, no se repite ----
   Va ANTES de cualquier validacion. Un reintento no tiene por que volver a
   pasar por reglas que ya pasaron, y si entretanto el saldo bajo, la
   segunda llamada fallaria por algo que ya estaba hecho. */
IF (@UUID IS NOT NULL)
BEGIN
    /* NULL a la fuerza: un SELECT sin filas NO toca la variable, y el
       llamador manda 0. Sin esto, TODO movimiento con uuid responderia
       "ya estaba registrado" y no se guardaria nada. */
    SET @ID = NULL

    SELECT @ID = imo_id FROM [dbo].[Inventario_Movimiento] WHERE imo_uuid = @UUID

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'El movimiento ya estaba registrado.' [MENSAJE]
        RETURN 0
    END
END

SET @UUID = ISNULL(@UUID, NEWID())

/* ---- Tipo y signo ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Inventario_Movimiento_Tipo]
                WHERE imt_id = @TIPO AND imt_habilitado = 1)
BEGIN
    RAISERROR('1.- EL TIPO DE MOVIMIENTO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@TIPO = 7)
BEGIN
    RAISERROR('2.- EL TRASLADO DE INGRESO NO SE REGISTRA SOLO: LO GENERA EL TRASLADO DE SALIDA.', 16, 1)
    RETURN -1
END

/* La reubicacion no suma ni resta al total de la bodega. */
SET @SIGNO = CASE WHEN @TIPO = 9              THEN 0
                  WHEN @TIPO IN (1, 3, 4, 7)  THEN 1
                  ELSE -1 END

/* ---- Cantidad ----
   Siempre positiva. El signo lo pone el tipo, no quien llama: aceptar
   negativos permitiria un "ingreso de -5" que descuenta sin dejar rastro de
   que fue una salida. */
IF (@CANTIDAD IS NULL OR @CANTIDAD <= 0)
BEGIN
    RAISERROR('3.- LA CANTIDAD DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END

/* ---- Repuesto y bodega, del cliente ---- */
SELECT @CONTROLA = rep_controla_lote
FROM   [dbo].[Repuesto]
WHERE  rep_id = @REPUESTO AND rep_cliente = @CLIENTE AND rep_habilitado = 1

IF (@CONTROLA IS NULL)
BEGIN
    RAISERROR('4.- EL REPUESTO NO EXISTE O ESTA DADO DE BAJA.', 16, 1)
    RETURN -1
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega]
                WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE AND bod_habilitado = 1)
BEGIN
    RAISERROR('5.- LA BODEGA NO EXISTE O ESTA DADA DE BAJA.', 16, 1)
    RETURN -1
END

IF (@UBICACION IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                     WHERE bub_id = @UBICACION AND bub_bodega = @BODEGA))
BEGIN
    RAISERROR('6.- LA UBICACION NO PERTENECE A ESA BODEGA.', 16, 1)
    RETURN -1
END

/* ---- La ubicacion es obligatoria si la bodega tiene estantes ----
   Ver el encabezado del bloque: sin esto el saldo por ubicacion se degrada
   con cada movimiento que no la informa. */
SET @TIENE_UBIC = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                                     WHERE bub_bodega = @BODEGA AND bub_habilitado = 1)
                       THEN 1 ELSE 0 END

/* El tipo 9 queda fuera: en una reubicacion el "donde queda" lo dice la
   ubicacion de DESTINO, y el origen nulo es el caso que hay que reparar. */
IF (@TIENE_UBIC = 1 AND @UBICACION IS NULL AND @TIPO <> 9)
BEGIN
    RAISERROR('15.- ESTA BODEGA TIENE UBICACIONES: INDIQUE DE CUAL SALE O A CUAL ENTRA.', 16, 1)
    RETURN -1
END

/* ---- Lote ---- */
IF (@CONTROLA = 1 AND @SIGNO = 1 AND @LOTE IS NULL)
BEGIN
    RAISERROR('7.- ESTE REPUESTO CONTROLA LOTE: INDIQUE EL LOTE DEL INGRESO.', 16, 1)
    RETURN -1
END

IF (@LOTE IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Lote]
                     WHERE rlo_id = @LOTE AND rlo_repuesto = @REPUESTO))
BEGIN
    RAISERROR('8.- EL LOTE NO PERTENECE A ESE REPUESTO.', 16, 1)
    RETURN -1
END

/* ---- Motivo ----
   Un ajuste sin motivo es una diferencia que nadie va a poder explicar
   despues. Se exige texto, no una marca. */
IF (@TIPO IN (4, 5, 8) AND (@OBSERVACION IS NULL OR LEN(LTRIM(@OBSERVACION)) < 5))
BEGIN
    RAISERROR('9.- INDIQUE EL MOTIVO DEL AJUSTE (AL MENOS 5 CARACTERES).', 16, 1)
    RETURN -1
END

/* ---- Traslado entre bodegas ---- */
IF (@TIPO = 6)
BEGIN
    IF (@BODEGA_DESTINO IS NULL)
    BEGIN
        RAISERROR('10.- INDIQUE LA BODEGA DE DESTINO DEL TRASLADO.', 16, 1)
        RETURN -1
    END

    IF (@BODEGA_DESTINO = @BODEGA)
    BEGIN
        RAISERROR('11.- LA BODEGA DE DESTINO NO PUEDE SER LA MISMA DE ORIGEN.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega]
                    WHERE bod_id = @BODEGA_DESTINO AND bod_cliente = @CLIENTE AND bod_habilitado = 1)
    BEGIN
        RAISERROR('12.- LA BODEGA DE DESTINO NO EXISTE O ESTA DADA DE BAJA.', 16, 1)
        RETURN -1
    END

    /* La bodega que recibe tambien puede tener estantes, y entonces hay que
       decir en cual queda. Si no los tiene, entra al cubo sin ubicacion. */
    IF (@UBICACION_DESTINO IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                         WHERE bub_id = @UBICACION_DESTINO AND bub_bodega = @BODEGA_DESTINO))
    BEGIN
        RAISERROR('16.- LA UBICACION DE DESTINO NO PERTENECE A LA BODEGA DE DESTINO.', 16, 1)
        RETURN -1
    END

    IF (@UBICACION_DESTINO IS NULL
        AND EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                     WHERE bub_bodega = @BODEGA_DESTINO AND bub_habilitado = 1))
    BEGIN
        RAISERROR('17.- LA BODEGA DE DESTINO TIENE UBICACIONES: INDIQUE EN CUAL QUEDA.', 16, 1)
        RETURN -1
    END
END

/* ---- Reubicacion dentro de la misma bodega ---- */
IF (@TIPO = 9)
BEGIN
    IF (@UBICACION_DESTINO IS NULL)
    BEGIN
        RAISERROR('18.- LA REUBICACION NECESITA LA UBICACION DE DESTINO.', 16, 1)
        RETURN -1
    END

    IF (@UBICACION = @UBICACION_DESTINO)
    BEGIN
        RAISERROR('19.- LA UBICACION DE DESTINO NO PUEDE SER LA MISMA DE ORIGEN.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion]
                    WHERE bub_id = @UBICACION_DESTINO AND bub_bodega = @BODEGA)
    BEGIN
        RAISERROR('20.- LA UBICACION DE DESTINO NO PERTENECE A ESA BODEGA.', 16, 1)
        RETURN -1
    END

    IF (@BODEGA_DESTINO IS NOT NULL)
    BEGIN
        RAISERROR('21.- LA REUBICACION ES DENTRO DE LA MISMA BODEGA: PARA CAMBIAR DE BODEGA USE UN TRASLADO.', 16, 1)
        RETURN -1
    END
END

/* ---- La orden de trabajo, si viene, es de este cliente ----
   Sin esto lo unico que ataja un numero inventado es la clave foranea, y
   su mensaje no se le puede mostrar a nadie. Y una orden de otro cliente
   la FK la deja pasar: el consumo se anotaria en la orden de otra empresa. */
IF (@ORDEN_TRABAJO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo]
                     WHERE otr_id = @ORDEN_TRABAJO AND otr_cliente = @CLIENTE))
BEGIN
    RAISERROR('14.- LA ORDEN DE TRABAJO NO EXISTE O NO ES DE ESTE CLIENTE.', 16, 1)
    RETURN -1
END


/* ---- Saldo suficiente ----

   SE MIDE EL CUBO, NO LA BODEGA

     Antes bastaba que la bodega tuviera suficiente. Ahora se saca de un
     estante concreto: que la bodega tenga 50 no ayuda si en ESE estante
     hay 2. Preguntar por la bodega dejaria pasar la salida y el estante
     quedaria negativo, que es justo lo que el bloque 71 acaba de arreglar.

   El mensaje dice la existencia actual del cubo, que es lo que el bodeguero
   necesita para decidir: un "no hay suficiente" a secas lo obliga a ir a
   consultar en otra pantalla. */
IF (@SIGNO = -1 OR @TIPO = 9)
BEGIN
    SET @SALDO = NULL

    SELECT @SALDO = isa_cantidad
    FROM   [dbo].[Inventario_Saldo]
    WHERE  isa_cliente  = @CLIENTE
      AND  isa_repuesto = @REPUESTO
      AND  isa_bodega   = @BODEGA
      AND  ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
      AND  ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)

    SET @SALDO = ISNULL(@SALDO, 0)

    IF (@CANTIDAD > @SALDO)
    BEGIN
        SET @MSG = '13.- EXISTENCIA INSUFICIENTE EN ESA UBICACION: HAY '
                 + LTRIM(STR(CAST(@SALDO AS DECIMAL(18,2)), 18, 2))
                 + ' Y SE INTENTA SACAR ' + LTRIM(STR(CAST(@CANTIDAD AS DECIMAL(18,2)), 18, 2)) + '.'
        RAISERROR(@MSG, 16, 1)
        RETURN -1
    END
END


/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    /* ---- 1. El movimiento ---- */
    INSERT INTO [dbo].[Inventario_Movimiento]
        (imo_uuid, imo_cliente, imo_repuesto, imo_bodega, imo_bodega_ubicacion,
         imo_repuesto_lote, imo_inventario_movimiento_tipo, imo_cantidad,
         imo_costo_unitario, imo_moneda, imo_fecha_movimiento_utc, imo_orden_trabajo,
         imo_bodega_destino, imo_bodega_ubicacion_destino, imo_observacion,
         imo_usuario_creacion, imo_fecha_creacion)
    VALUES (@UUID, @CLIENTE, @REPUESTO, @BODEGA, @UBICACION, @LOTE, @TIPO, @CANTIDAD,
            @COSTO_UNITARIO, @MONEDA, @AHORA, @ORDEN_TRABAJO, @BODEGA_DESTINO,
            @UBICACION_DESTINO, @OBSERVACION, @USUARIO, [dbo].[FNC_AHORA]())

    SET @ID = SCOPE_IDENTITY()

    /* ---- 2. El cubo de origen ----

       El costo promedio se recalcula SOLO cuando entra mercaderia con
       costo. En una salida el promedio no cambia: sacar diez unidades no
       hace que las que quedan hayan costado otra cosa. */
    IF (@TIPO <> 9)
    BEGIN
        SET @CANT_PREVIA = NULL

        SELECT @CANT_PREVIA = isa_cantidad, @COSTO_PROM = isa_costo_promedio
        FROM   [dbo].[Inventario_Saldo]
        WHERE  isa_cliente  = @CLIENTE
          AND  isa_repuesto = @REPUESTO
          AND  isa_bodega   = @BODEGA
          AND  ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
          AND  ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)

        IF (@CANT_PREVIA IS NULL)
        BEGIN
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
                 isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
                 isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA, @UBICACION, @LOTE, @SIGNO * @CANTIDAD, 0,
                    @COSTO_UNITARIO, @AHORA, @USUARIO, [dbo].[FNC_AHORA]())
        END
        ELSE
        BEGIN
            IF (@SIGNO = 1 AND @COSTO_UNITARIO IS NOT NULL)
                SET @COSTO_PROM = ((ISNULL(@COSTO_PROM, @COSTO_UNITARIO) * @CANT_PREVIA)
                                   + (@COSTO_UNITARIO * @CANTIDAD))
                                  / NULLIF(@CANT_PREVIA + @CANTIDAD, 0)

            UPDATE  [dbo].[Inventario_Saldo]
            SET     isa_cantidad                = isa_cantidad + (@SIGNO * @CANTIDAD)
                   ,isa_costo_promedio          = @COSTO_PROM
                   ,isa_fecha_ultimo_movimiento = @AHORA
                   ,isa_usuario_actualizacion   = @USUARIO
                   ,isa_fecha_actualizacion     = [dbo].[FNC_AHORA]()
            WHERE   isa_cliente  = @CLIENTE
              AND   isa_repuesto = @REPUESTO
              AND   isa_bodega   = @BODEGA
              AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
              AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)
        END
    END

    /* ---- 3. La reubicacion: sale de un estante y entra al otro ----
       Un solo movimiento, dos cubos. El total de la bodega no se mueve. */
    IF (@TIPO = 9)
    BEGIN
        UPDATE  [dbo].[Inventario_Saldo]
        SET     isa_cantidad                = isa_cantidad - @CANTIDAD
               ,isa_fecha_ultimo_movimiento = @AHORA
               ,isa_usuario_actualizacion   = @USUARIO
               ,isa_fecha_actualizacion     = [dbo].[FNC_AHORA]()
        WHERE   isa_cliente  = @CLIENTE
          AND   isa_repuesto = @REPUESTO
          AND   isa_bodega   = @BODEGA
          AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION, -1)
          AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)

        IF EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                    WHERE isa_cliente  = @CLIENTE
                      AND isa_repuesto = @REPUESTO
                      AND isa_bodega   = @BODEGA
                      AND ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
                      AND ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1))
            UPDATE  [dbo].[Inventario_Saldo]
            SET     isa_cantidad                = isa_cantidad + @CANTIDAD
                   ,isa_fecha_ultimo_movimiento = @AHORA
                   ,isa_usuario_actualizacion   = @USUARIO
                   ,isa_fecha_actualizacion     = [dbo].[FNC_AHORA]()
            WHERE   isa_cliente  = @CLIENTE
              AND   isa_repuesto = @REPUESTO
              AND   isa_bodega   = @BODEGA
              AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
              AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)
        ELSE
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
                 isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
                 isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA, @UBICACION_DESTINO, @LOTE, @CANTIDAD, 0,
                    NULL, @AHORA, @USUARIO, [dbo].[FNC_AHORA]())
    END

    /* ---- 4. El traslado: su otra mitad ----
       El movimiento de ingreso en destino se genera aca, no lo manda quien
       llama. Si dependiera de dos llamadas, una caida entre las dos dejaria
       el repuesto sin existir en ninguna de las dos bodegas. */
    IF (@TIPO = 6)
    BEGIN
        INSERT INTO [dbo].[Inventario_Movimiento]
            (imo_uuid, imo_cliente, imo_repuesto, imo_bodega, imo_bodega_ubicacion,
             imo_repuesto_lote, imo_inventario_movimiento_tipo, imo_cantidad,
             imo_costo_unitario, imo_moneda, imo_fecha_movimiento_utc, imo_observacion,
             imo_usuario_creacion, imo_fecha_creacion)
        VALUES (NEWID(), @CLIENTE, @REPUESTO, @BODEGA_DESTINO, @UBICACION_DESTINO, @LOTE,
                7, @CANTIDAD, @COSTO_UNITARIO, @MONEDA, @AHORA,
                ISNULL(@OBSERVACION, N'') + N' (traslado desde el movimiento ' + LTRIM(STR(@ID)) + N')',
                @USUARIO, [dbo].[FNC_AHORA]())

        IF EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                    WHERE isa_cliente  = @CLIENTE
                      AND isa_repuesto = @REPUESTO
                      AND isa_bodega   = @BODEGA_DESTINO
                      AND ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
                      AND ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1))
            UPDATE  [dbo].[Inventario_Saldo]
            SET     isa_cantidad                = isa_cantidad + @CANTIDAD
                   ,isa_fecha_ultimo_movimiento = @AHORA
                   ,isa_usuario_actualizacion   = @USUARIO
                   ,isa_fecha_actualizacion     = [dbo].[FNC_AHORA]()
            WHERE   isa_cliente  = @CLIENTE
              AND   isa_repuesto = @REPUESTO
              AND   isa_bodega   = @BODEGA_DESTINO
              AND   ISNULL(isa_bodega_ubicacion, -1) = ISNULL(@UBICACION_DESTINO, -1)
              AND   ISNULL(isa_repuesto_lote, -1)    = ISNULL(@LOTE, -1)
        ELSE
            INSERT INTO [dbo].[Inventario_Saldo]
                (isa_cliente, isa_repuesto, isa_bodega, isa_bodega_ubicacion, isa_repuesto_lote,
                 isa_cantidad, isa_cantidad_reservada, isa_costo_promedio,
                 isa_fecha_ultimo_movimiento, isa_usuario_actualizacion, isa_fecha_actualizacion)
            VALUES (@CLIENTE, @REPUESTO, @BODEGA_DESTINO, @UBICACION_DESTINO, @LOTE,
                    @CANTIDAD, 0, @COSTO_UNITARIO, @AHORA, @USUARIO, [dbo].[FNC_AHORA]())
    END

    /* ---- 5. La orden de trabajo ----

       Consumo suma a lo consumido. Devolucion suma a lo devuelto Y resta de
       lo consumido, que es literalmente lo que pide el criterio: "la
       cantidad consumida de la orden se reduce en la misma cifra".

       No baja de cero: devolver mas de lo que se llevo es un error de
       digitacion, y dejar un consumo negativo contaminaria el costo de la
       intervencion. */
    IF (@ORDEN_TRABAJO IS NOT NULL AND @TIPO IN (2, 3))
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Repuesto]
                        WHERE ore_orden_trabajo = @ORDEN_TRABAJO AND ore_repuesto = @REPUESTO)
            INSERT INTO [dbo].[Orden_Trabajo_Repuesto]
                (ore_orden_trabajo, ore_repuesto, ore_cantidad_planificada,
                 ore_cantidad_consumida, ore_cantidad_devuelta,
                 ore_usuario_creacion, ore_fecha_creacion, ore_habilitado)
            VALUES (@ORDEN_TRABAJO, @REPUESTO, 0, 0, 0, @USUARIO, [dbo].[FNC_AHORA](), 1)

        UPDATE  [dbo].[Orden_Trabajo_Repuesto]
        SET     ore_cantidad_consumida = CASE
                    WHEN @TIPO = 2 THEN ISNULL(ore_cantidad_consumida, 0) + @CANTIDAD
                    WHEN @TIPO = 3 THEN CASE WHEN ISNULL(ore_cantidad_consumida, 0) - @CANTIDAD < 0
                                             THEN 0
                                             ELSE ISNULL(ore_cantidad_consumida, 0) - @CANTIDAD END
                    ELSE ore_cantidad_consumida END
               ,ore_cantidad_devuelta = CASE
                    WHEN @TIPO = 3 THEN ISNULL(ore_cantidad_devuelta, 0) + @CANTIDAD
                    ELSE ore_cantidad_devuelta END
               ,ore_usuario_actualizacion = @USUARIO
               ,ore_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   ore_orden_trabajo = @ORDEN_TRABAJO AND ore_repuesto = @REPUESTO
    END

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Movimiento registrado.' [MENSAJE]
RETURN 0
GO

-- ---------- INS_MODULOS_SISTEMA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_MODULOS_SISTEMA (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:		BRYAN CHAVEZ
-- Fecha creación: 02-06-2026
-- Description: Inserta un módulo del sistema
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_MODULOS_SISTEMA]
    @NOMBRE  VARCHAR(200),
    @USUARIO INT
AS
SET NOCOUNT ON

IF EXISTS (SELECT 1 FROM MODULOS_SISTEMA WHERE mds_nombre = @NOMBRE)
BEGIN
    RAISERROR('1.- Ya existe un módulo con ese nombre.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    INSERT INTO MODULOS_SISTEMA (mds_nombre, mds_habilitado, mds_usuario_creacion, mds_fecha_creacion, mds_usuario_act, mds_fecha_act)
    VALUES (@NOMBRE, 1, @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA]())

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_MODULOS_SISTEMA ' + ISNULL(@NOMBRE, '') + ',' + STR(@USUARIO)
        EXEC INS_EXCEPCION
            @MSG       = '1.- NO FUE POSIBLE INSERTAR EL MÓDULO DEL SISTEMA.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

SELECT SCOPE_IDENTITY() AS mds_id
RETURN(0)
GO

-- ---------- INS_PAISES (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_PAISES (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:		BRYAN CHAVEZ
-- CREATE DATE:	04-02-2025
-- DESCRIPTION:	INSERTA PAISES
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_PAISES]
@ID INT = NULL OUTPUT,
@NOMBRE VARCHAR(200),
@SUMA_RESTA VARCHAR(1),
@HORA INT,
@HABILITADO BIT,
@USUARIO INT

AS
SET NOCOUNT ON

-- Validaciones
BEGIN 
		-- Validar si ya existe un país con el mismo nombre
		IF EXISTS (SELECT 1 FROM PAISES WHERE PAI_NOMBRE = @NOMBRE)
		BEGIN
			RAISERROR('1. El país con el nombre "%s" ya existe.', 16, 1, @NOMBRE)
			RETURN -1
		END
END

BEGIN TRANSACTION

	INSERT PAISES
		(
			PAI_NOMBRE,
			PAI_SUMA_RESTA,
			PAI_HORA,
			PAI_HABILITADO,
			PAI_USUARIO_CREACION,
			PAI_FECHA_CREACION,
			PAI_USUARIO_ACTUALIZACION,
			PAI_FECHA_ACTUALIZACION
		) 
	VALUES 
		(
			@NOMBRE,
			@SUMA_RESTA,
			@HORA,
			@HABILITADO,
			@USUARIO,
			[dbo].[FNC_AHORA](),
			@USUARIO,
			[dbo].[FNC_AHORA]()
		)
	
	
	SET @ID = SCOPE_IDENTITY()	
	
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'INS_PAISES ' + LTRIM(STR(@ID))
						
		EXEC INS_EXCEPCION 
			@MSG = '1.- NO FUE POSIBLE INSERTAR EL PAIS.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_PERFIL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_PERFIL (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   2. INS_PERFIL                                                    HU-015
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_PERFIL]
@ID               INT = NULL OUTPUT,
@NOMBRE           VARCHAR(200),
@DESCRIPCION      VARCHAR(8000) = NULL,
@TIPO             INT,
@CLIENTE          INT = NULL,
@SOLO_EJECUCION   BIT = 0,
@HABILITADO       BIT,
@USUARIO          INT

AS
SET NOCOUNT ON

BEGIN
    /* Antes el nombre era unico en TODA la base. Con multicliente eso
       impedia que dos empresas tuvieran cada una su "Supervisor". Ahora la
       unicidad es dentro del mismo dueno. */
    IF EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                WHERE per_nombre = @NOMBRE
                  AND ISNULL(per_cliente, 0) = ISNULL(@CLIENTE, 0))
    BEGIN
        RAISERROR('1.- El perfil con el nombre "%s" ya existe.', 16, 1, @NOMBRE)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Perfiles]
        (
            per_nombre,
            per_descripcion,
            per_tipo,
            per_cliente,
            per_solo_ejecucion,
            per_habilitado,
            per_usuario_creacion,
            per_fecha_creacion,
            per_usuario_act,
            per_fecha_act
        )
    VALUES
        (
            @NOMBRE,
            @DESCRIPCION,
            @TIPO,
            @CLIENTE,
            @SOLO_EJECUCION,
            @HABILITADO,
            @USUARIO,
            [dbo].[FNC_AHORA](),
            @USUARIO,
            [dbo].[FNC_AHORA]()
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_PERFIL ' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '2.- NO FUE POSIBLE CREAR EL PERFIL.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_PLAN_COMERCIAL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_PLAN_COMERCIAL (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   1. INS_PLAN_COMERCIAL

      El plan nace SIN precio. Es deliberado: un plan sin fila en
      Plan_Comercial_Precio simplemente no se vende -asi lo definio el
      modelo, la ausencia de precio es la regla- y eso permite dejarlo
      preparado mientras se acuerda cuanto va a costar.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_PLAN_COMERCIAL]
@ID           INT = NULL OUTPUT,
@CODIGO       NVARCHAR(50),
@NOMBRE       NVARCHAR(100),
@DESCRIPCION  NVARCHAR(500) = NULL,
@ORDEN        INT,
@DIAS_GRACIA  INT = 5,
@PUBLICO      BIT = 1,
@USUARIO      INT

AS
SET NOCOUNT ON

BEGIN
    IF @CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0
    BEGIN
        RAISERROR('1.- EL CÓDIGO DEL PLAN ES OBLIGATORIO.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial]
                WHERE plc_codigo = @CODIGO COLLATE DATABASE_DEFAULT)
    BEGIN
        RAISERROR('2.- YA EXISTE UN PLAN CON EL CÓDIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    /* El orden decide que es subir y que es bajar de plan (8). Dos planes
       con el mismo orden dejan a UPS_SUSCRIPCION_PLAN sin criterio: la
       comparacion da falso en ambos sentidos y todo cambio entre ellos se
       trata como downgrade, sin que nadie entienda por que. */
    IF @ORDEN IS NULL
    BEGIN
        RAISERROR('3.- EL ORDEN ES OBLIGATORIO: DEFINE QUÉ ES SUBIR Y QUÉ ES BAJAR DE PLAN.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_orden = @ORDEN)
    BEGIN
        RAISERROR('4.- YA HAY UN PLAN CON EL ORDEN %d. EL ORDEN DEBE SER ÚNICO.', 16, 1, @ORDEN)
        RETURN -1
    END

    IF @DIAS_GRACIA IS NULL OR @DIAS_GRACIA < 0
    BEGIN
        RAISERROR('5.- LOS DÍAS DE GRACIA NO PUEDEN SER NEGATIVOS.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Plan_Comercial]
        (plc_codigo, plc_nombre, plc_descripcion, plc_orden, plc_dias_gracia, plc_publico,
         plc_usuario_creacion, plc_fecha_creacion,
         plc_usuario_actualizacion, plc_fecha_actualizacion, plc_habilitado)
    VALUES
        (@CODIGO, @NOMBRE, @DESCRIPCION, @ORDEN, @DIAS_GRACIA, @PUBLICO,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    DECLARE @FILAS_INS INT = @@ROWCOUNT
    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Plan_Comercial]
        SET    [plc_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('PLC', @ID)
        WHERE  [plc_id] = @ID


    IF @FILAS_INS = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_PLAN_COMERCIAL @CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE CREAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_PRIVACIDAD_MODULOS_SISTEMA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_PRIVACIDAD_MODULOS_SISTEMA (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:         BRYAN CHAVEZ
-- FECHA CREACIÓN: 08-06-2026
-- DESCRIPTION:    INSERTA PRIVACIDAD MODULO SISTEMA
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_PRIVACIDAD_MODULOS_SISTEMA]
    @ID          INT          OUTPUT,
    @ID_MODULO   INT,
    @DESCRIPCION NVARCHAR(MAX),
    @USUARIO     INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION

    INSERT INTO PRIVACIDAD_MODULOS_SISTEMA
        (
            PMS_ID_MODULO,
            PMS_DESCRIPCION,
            PMS_USUARIO_CREACION,
            PMS_FECHA_CREACION,
            PMS_USUARIO_ACT,
            PMS_FECHA_ACT
        )
    VALUES
        (
            @ID_MODULO,
            @DESCRIPCION,
            @USUARIO,
            [dbo].[FNC_AHORA](),
            @USUARIO,
            [dbo].[FNC_AHORA]()
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES_INS VARCHAR(MAX)
        SET @VARIABLES_INS = 'INS_PRIVACIDAD_MODULOS_SISTEMA ' +
                             '@ID_MODULO = ' + LTRIM(STR(@ID_MODULO)) + ', ' +
                             '@USUARIO = '   + LTRIM(STR(@USUARIO))
        EXEC INS_EXCEPCION
            @MSG       = '1.- NO FUE POSIBLE CREAR EL REGISTRO DE PRIVACIDAD.',
            @VARIABLES = @VARIABLES_INS
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- INS_REPUESTO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_REPUESTO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ============================ INS_REPUESTO, con @REPUESTO_TIPO ============ */
CREATE OR ALTER PROCEDURE [dbo].[INS_REPUESTO]
    @ID               INT OUTPUT,
    @CLIENTE          INT,
    @CODIGO           NVARCHAR(100),
    @NOMBRE           NVARCHAR(400),
    @UNIDAD_MEDIDA    INT,
    @FABRICANTE       NVARCHAR(400) = NULL,
    @MODELO           NVARCHAR(400) = NULL,
    @DESCRIPCION      NVARCHAR(1000) = NULL,
    @ES_REPARABLE     BIT = 0,
    @ES_CONSUMIBLE    BIT = 0,
    @CONTROLA_LOTE    BIT = 0,
    @COSTO_REFERENCIA DECIMAL(18,4) = NULL,
    @MONEDA           INT = NULL,
    @VIDA_UTIL_HORA   DECIMAL(18,4) = NULL,
    @VIDA_UTIL_DIA    INT = NULL,
    @VIDA_UTIL_CICLO  DECIMAL(18,4) = NULL,
    @REPUESTO_TIPO    INT = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('1.- INDIQUE EL CODIGO DEL REPUESTO.', 16, 1)
        RETURN -1
    END

    IF (@NOMBRE IS NULL OR LEN(LTRIM(@NOMBRE)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL NOMBRE DEL REPUESTO.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                    WHERE ume_id = @UNIDAD_MEDIDA AND ume_habilitado = 1)
    BEGIN
        RAISERROR('3.- LA UNIDAD DE MEDIDA NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF EXISTS (SELECT 1 FROM [dbo].[Repuesto]
                WHERE rep_cliente = @CLIENTE AND rep_codigo = @CODIGO)
    BEGIN
        RAISERROR('4.- YA EXISTE UN REPUESTO CON ESE CODIGO.', 16, 1)
        RETURN -1
    END

    /* Cero no es "no aplica", es "dura cero". Se rechaza para que el NULL
       siga significando lo unico que puede significar: no se sabe. */
    IF (@VIDA_UTIL_HORA IS NOT NULL AND @VIDA_UTIL_HORA <= 0)
     OR (@VIDA_UTIL_DIA IS NOT NULL AND @VIDA_UTIL_DIA <= 0)
     OR (@VIDA_UTIL_CICLO IS NOT NULL AND @VIDA_UTIL_CICLO <= 0)
    BEGIN
        RAISERROR('5.- LA VIDA UTIL DEBE SER MAYOR QUE CERO. DEJELA VACIA SI NO SE CONOCE.', 16, 1)
        RETURN -1
    END

SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Repuesto]
        (rep_uuid, rep_cliente, rep_unidad_medida, rep_codigo, rep_nombre,
         rep_fabricante, rep_modelo, rep_descripcion, rep_es_reparable,
         rep_es_consumible, rep_controla_lote, rep_repuesto_tipo, rep_costo_referencia, rep_moneda,
         rep_vida_util_hora, rep_vida_util_dia, rep_vida_util_ciclo,
         rep_usuario_creacion, rep_fecha_creacion, rep_habilitado)
    VALUES (NEWID(), @CLIENTE, @UNIDAD_MEDIDA, LTRIM(RTRIM(@CODIGO)), @NOMBRE,
            @FABRICANTE, @MODELO, @DESCRIPCION, ISNULL(@ES_REPARABLE, 0),
            ISNULL(@ES_CONSUMIBLE, 0), ISNULL(@CONTROLA_LOTE, 0), @REPUESTO_TIPO,
            @COSTO_REFERENCIA, @MONEDA,
            @VIDA_UTIL_HORA, @VIDA_UTIL_DIA, @VIDA_UTIL_CICLO,
            @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ---- 
       El codigo depende del ID y el ID no existe hasta aca. La ficha
       manda 'AUTO'; ese valor satisface el NOT NULL, pasa por el
       INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Repuesto]
        SET    [rep_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('REP', @ID)
        WHERE  [rep_id] = @ID


COMMIT TRANSACTION
RETURN 0
GO

-- ---------- INS_REPUESTO_LOTE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_REPUESTO_LOTE (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[INS_REPUESTO_LOTE]
    @ID                INT OUTPUT,
    @CLIENTE           INT,
    @REPUESTO          INT,
    @CODIGO            NVARCHAR(200),
    @FECHA_INGRESO     DATE = NULL,
    @FECHA_VENCIMIENTO DATE = NULL,
    @PROVEEDOR         INT = NULL,
    @COSTO_UNITARIO    DECIMAL(18,4) = NULL,
    @MONEDA            INT = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0)
    BEGIN
        RAISERROR('2.- INDIQUE EL CODIGO DEL LOTE.', 16, 1)
        RETURN -1
    END

    /* Idempotente por (repuesto, codigo): si el lote ya existe se devuelve.
       Volver a recibir del mismo lote es lo normal, no un error. */
    /* NULL a la fuerza: el llamador manda 0 y sin esto el SP responde
           "el lote ya existia" para un lote que no existe. */
        SET @ID = NULL

        SELECT @ID = rlo_id FROM [dbo].[Repuesto_Lote]
     WHERE rlo_repuesto = @REPUESTO AND rlo_codigo = @CODIGO

    IF (@ID IS NOT NULL)
    BEGIN
        SELECT @ID [ID], '200' [CODE], 'El lote ya existía.' [MENSAJE]
        RETURN 0
    END

    IF (@FECHA_VENCIMIENTO IS NOT NULL AND @FECHA_INGRESO IS NOT NULL
        AND @FECHA_VENCIMIENTO < @FECHA_INGRESO)
    BEGIN
        RAISERROR('3.- LA FECHA DE VENCIMIENTO NO PUEDE SER ANTERIOR A LA DE INGRESO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    INSERT INTO [dbo].[Repuesto_Lote]
        (rlo_cliente, rlo_repuesto, rlo_codigo, rlo_fecha_ingreso, rlo_fecha_vencimiento,
         rlo_proveedor, rlo_costo_unitario, rlo_moneda, rlo_observacion,
         rlo_usuario_creacion, rlo_fecha_creacion, rlo_habilitado)
    VALUES (@CLIENTE, @REPUESTO, LTRIM(RTRIM(@CODIGO)),
            ISNULL(@FECHA_INGRESO, CAST([dbo].[FNC_AHORA]() AS DATE)), @FECHA_VENCIMIENTO,
            @PROVEEDOR, @COSTO_UNITARIO, @MONEDA, @OBSERVACION, @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ---- 
       El codigo depende del ID y el ID no existe hasta aca. La ficha
       manda 'AUTO'; ese valor satisface el NOT NULL, pasa por el
       INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Repuesto_Lote]
        SET    [rlo_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('LOT', @ID)
        WHERE  [rlo_id] = @ID


COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Lote creado.' [MENSAJE]
RETURN 0
GO

-- ---------- INS_SUSCRIPCION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_SUSCRIPCION (P) · 3 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   3. INS_SUSCRIPCION

      Una por cliente, para siempre (§5.1). La clave la genera la
      aplicacion y llega partida: el prefijo se guarda visible para poder
      identificarla en soporte, y del resto solo se guarda el hash.

      sus_fecha_fin nace NULL: todavia no se ha emitido ningun periodo, asi
      que la suscripcion existe pero no habilita nada. Es correcto -y
      FNC_SUSCRIPCION_VIGENTE ya lo trata como VENCIDA- porque cobrar es lo
      que la pone en marcha.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION]
@ID                INT = NULL OUTPUT,
@CLIENTE           INT,
@PLAN_COMERCIAL    INT,
@KEY_PREFIJO       NVARCHAR(20),
@KEY_TEXTO         VARCHAR(200),
@CONTACTO_NOMBRE   NVARCHAR(200) = NULL,
@CONTACTO_EMAIL    NVARCHAR(200) = NULL,
@CONTACTO_TELEFONO NVARCHAR(50) = NULL,
@OBSERVACION       NVARCHAR(1000) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @DIAS_GRACIA INT

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Suscripcion] WHERE sus_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- ESTE CLIENTE YA TIENE UNA SUSCRIPCIÓN. USE EL CAMBIO DE PLAN O LA RENOVACIÓN.', 16, 1)
        RETURN -1
    END

    SELECT @DIAS_GRACIA = plc_dias_gracia
      FROM [dbo].[Plan_Comercial]
     WHERE plc_id = @PLAN_COMERCIAL AND plc_habilitado = 1

    IF @DIAS_GRACIA IS NULL
    BEGIN
        RAISERROR('2.- EL PLAN COMERCIAL NO EXISTE O ESTÁ DESHABILITADO.', 16, 1)
        RETURN -1
    END

    IF @KEY_TEXTO IS NULL OR LEN(@KEY_TEXTO) < 16
    BEGIN
        RAISERROR('3.- LA CLAVE DE SUSCRIPCIÓN NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Suscripcion]
        (sus_cliente, sus_key_prefijo, sus_key_hash, sus_suscripcion_estado,
         sus_plan_comercial, sus_fecha_inicio, sus_fecha_fin, sus_dias_gracia,
         sus_fecha_emision_key_utc, sus_contacto_nombre, sus_contacto_email,
         sus_contacto_telefono, sus_observacion,
         sus_usuario_creacion, sus_fecha_creacion,
         sus_usuario_actualizacion, sus_fecha_actualizacion, sus_habilitado)
    VALUES
        (@CLIENTE, @KEY_PREFIJO, HASHBYTES('SHA2_256', @KEY_TEXTO), 1,
         @PLAN_COMERCIAL, CAST([dbo].[FNC_AHORA]() AS DATE), NULL, @DIAS_GRACIA,
         GETUTCDATE(), @CONTACTO_NOMBRE, @CONTACTO_EMAIL,
         @CONTACTO_TELEFONO, @OBSERVACION,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_SUSCRIPCION @CLIENTE = ' + LTRIM(STR(@CLIENTE))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE CREAR LA SUSCRIPCIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_SUSCRIPCION_BLOQUEO_LOG (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_SUSCRIPCION_BLOQUEO_LOG (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   6. INS_SUSCRIPCION_BLOQUEO_LOG                                    §6.7

      Append-only. Cada rechazo por suscripcion queda registrado.

      No es paranoia: es lo que permite responder "¿desde cuando no puede
      entrar este cliente?" cuando llama enojado, en vez de adivinar.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_BLOQUEO_LOG]
@CLIENTE   INT = NULL,
@ESTADO    NVARCHAR(20),
@ORIGEN    NVARCHAR(20) = N'WEB',
@ENDPOINT  NVARCHAR(200) = NULL,
@IP        NVARCHAR(50) = NULL,
@USUARIO   INT = NULL

AS
SET NOCOUNT ON

DECLARE @SUSCRIPCION INT, @PREFIJO NVARCHAR(20)

SELECT TOP 1 @SUSCRIPCION = sus_id, @PREFIJO = sus_key_prefijo
  FROM [dbo].[Suscripcion]
 WHERE sus_cliente = @CLIENTE AND sus_habilitado = 1

INSERT [dbo].[Suscripcion_Bloqueo_Log]
    (sbl_suscripcion, sbl_key_prefijo, sbl_estado, sbl_origen,
     sbl_endpoint, sbl_ip, sbl_fecha_utc, sbl_usuario_creacion, sbl_fecha_creacion)
VALUES
    (@SUSCRIPCION, @PREFIJO, @ESTADO, @ORIGEN,
     @ENDPOINT, @IP, GETUTCDATE(), @USUARIO, [dbo].[FNC_AHORA]())

RETURN(0)
GO

-- ---------- INS_SUSCRIPCION_PAGO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_SUSCRIPCION_PAGO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   7. INS_SUSCRIPCION_PAGO

      El cliente declara una transferencia y adjunta el comprobante. NO se
      da por pagado: nace DECLARADO y alguien lo verifica contra la cartola
      (§5.4). Un abono que se aceptara solo porque el cliente lo escribio
      seria una factura pagada por decreto.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_PAGO]
@ID                 INT = NULL OUTPUT,
@PERIODO            INT,
@MONTO_DECLARADO    DECIMAL(18,2),
@FECHA_TRANSFERENCIA DATE,
@BANCO              NVARCHAR(100) = NULL,
@NUMERO_OPERACION   NVARCHAR(100) = NULL,
@ARCHIVO            INT,
@USUARIO            INT

AS
SET NOCOUNT ON

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Periodo]
                    WHERE spe_id = @PERIODO AND spe_habilitado = 1)
    BEGIN
        RAISERROR('1.- EL PERÍODO NO EXISTE O ESTÁ ANULADO.', 16, 1)
        RETURN -1
    END

    /* El comprobante es OBLIGATORIO: spa_archivo es NOT NULL en el modelo.
       No es un descuido de la tabla, es la regla — §5.3 llama a esto "el
       abono con comprobante" y §5.4 describe cómo se analiza. Un abono sin
       respaldo no se puede verificar contra la cartola, que es justamente
       lo que convierte una declaración en un pago. */
    IF @ARCHIVO IS NULL
    BEGIN
        RAISERROR('2.- DEBE ADJUNTAR EL COMPROBANTE DE LA TRANSFERENCIA.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Archivo] WHERE arc_id = @ARCHIVO)
    BEGIN
        RAISERROR('3.- EL COMPROBANTE INDICADO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @MONTO_DECLARADO IS NULL OR @MONTO_DECLARADO <= 0
    BEGIN
        RAISERROR('4.- EL MONTO DECLARADO DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    /* El numero de operacion se repite = el mismo comprobante cargado dos
       veces. Sin esto, un doble clic duplica el abono y el periodo queda
       pagado dos veces. */
    IF @NUMERO_OPERACION IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Suscripcion_Pago]
                    WHERE spa_numero_operacion = @NUMERO_OPERACION
                      AND spa_habilitado = 1)
    BEGIN
        RAISERROR('5.- YA EXISTE UN PAGO REGISTRADO CON EL NÚMERO DE OPERACIÓN "%s".', 16, 1, @NUMERO_OPERACION)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Suscripcion_Pago]
        (spa_suscripcion_periodo, spa_monto_declarado_clp, spa_monto_verificado_clp,
         spa_fecha_transferencia, spa_banco, spa_numero_operacion, spa_archivo,
         spa_suscripcion_pago_estado, spa_usuario_creacion, spa_fecha_creacion,
         spa_usuario_actualizacion, spa_fecha_actualizacion, spa_habilitado)
    VALUES
        (@PERIODO, @MONTO_DECLARADO, NULL,
         @FECHA_TRANSFERENCIA, @BANCO, @NUMERO_OPERACION, @ARCHIVO,
         1, @USUARIO, [dbo].[FNC_AHORA](),          -- 1 = DECLARADO
         @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_SUSCRIPCION_PAGO @PERIODO = ' + LTRIM(STR(@PERIODO))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE REGISTRAR EL PAGO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_SUSCRIPCION_PERIODO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_SUSCRIPCION_PERIODO (P) · 5 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   5. INS_SUSCRIPCION_PERIODO                                        §4.3

      EMITIR ES CONGELAR. Se guardan tres numeros y no una referencia:

        spe_valor_uf_plan  cuantas UF cuesta el periodo
        spe_valor_uf_dia   cuantos pesos valia una UF ese dia
        spe_monto_clp      el producto, que es lo que se cobra

      Si en vez de eso se guardara una FK a Valor_Uf, abrir el comprobante
      dentro de dos anos recalcularia con la UF de entonces y mostraria un
      monto que nadie pago nunca.

      El periodo arranca donde termina el anterior, no en la fecha de hoy:
      pagar con tres dias de atraso no debe regalar ni quitar dias.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_SUSCRIPCION_PERIODO]
@ID                INT = NULL OUTPUT,
@SUSCRIPCION       INT,
@PERIODICIDAD      INT,
@PLAN_COMERCIAL    INT = NULL,
@FECHA_INICIO      DATE = NULL,
@ES_IMPLANTACION   BIT = 0,
@VALOR_UF_MANUAL   DECIMAL(18,4) = NULL,
@OBSERVACION       NVARCHAR(1000) = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

DECLARE @CLIENTE      INT,
        @FIN_ANTERIOR DATE,
        @UF_PLAN      DECIMAL(18,4),
        @UF_DIA       DECIMAL(18,4),
        @FECHA_UF     DATE = CAST([dbo].[FNC_AHORA]() AS DATE),
        @FECHA_FIN    DATE,
        @MESES        INT,
        @MONTO        DECIMAL(18,2)

BEGIN
    SELECT @CLIENTE = sus_cliente,
           @PLAN_COMERCIAL = ISNULL(@PLAN_COMERCIAL, sus_plan_comercial),
           @FIN_ANTERIOR = sus_fecha_fin
      FROM [dbo].[Suscripcion]
     WHERE sus_id = @SUSCRIPCION

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('1.- LA SUSCRIPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    SELECT @MESES = CASE pcb_codigo
                        WHEN N'MENSUAL'    THEN 1
                        WHEN N'TRIMESTRAL' THEN 3
                        WHEN N'ANUAL'      THEN 12
                    END
      FROM [dbo].[Periodicidad_Cobro]
     WHERE pcb_id = @PERIODICIDAD AND pcb_habilitado = 1

    IF @MESES IS NULL
    BEGIN
        RAISERROR('2.- LA PERIODICIDAD DE COBRO NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END

    /* El periodo continua donde termino el anterior. Solo cuando no hay
       ninguno -o el anterior quedo muy atras- se parte de hoy. */
    SET @FECHA_INICIO = ISNULL(@FECHA_INICIO,
                               CASE WHEN @FIN_ANTERIOR IS NULL OR @FIN_ANTERIOR < CAST([dbo].[FNC_AHORA]() AS DATE)
                                    THEN CAST([dbo].[FNC_AHORA]() AS DATE)
                                    ELSE DATEADD(DAY, 1, @FIN_ANTERIOR) END)

    SET @FECHA_FIN = DATEADD(DAY, -1, DATEADD(MONTH, @MESES, @FECHA_INICIO))

    -- El precio VIGENTE del plan para esa periodicidad.
    IF @VALOR_UF_MANUAL IS NOT NULL
        SET @UF_PLAN = @VALOR_UF_MANUAL
    ELSE
        SELECT TOP 1 @UF_PLAN = pcp_valor_uf
          FROM [dbo].[Plan_Comercial_Precio]
         WHERE pcp_plan_comercial = @PLAN_COMERCIAL
           AND pcp_periodicidad_cobro = @PERIODICIDAD
           AND pcp_habilitado = 1
           AND pcp_vigencia_desde <= @FECHA_UF
           AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @FECHA_UF)
         ORDER BY pcp_vigencia_desde DESC

    /* La implantacion no tiene precio definido en el modelo comercial. Sin
       un valor explicito se emite en cero en vez de inventar uno: un cobro
       con un numero que nadie acordo es peor que un cobro en cero. */
    IF @ES_IMPLANTACION = 1 AND @VALOR_UF_MANUAL IS NULL
        SET @UF_PLAN = 0

    IF @UF_PLAN IS NULL
    BEGIN
        RAISERROR('3.- EL PLAN NO TIENE PRECIO VIGENTE PARA ESA PERIODICIDAD.', 16, 1)
        RETURN -1
    END

    SET @UF_DIA = [dbo].[FNC_VALOR_UF](@FECHA_UF)

    IF @UF_DIA IS NULL OR @UF_DIA <= 0
    BEGIN
        RAISERROR('4.- NO HAY VALOR DE UF CARGADO. NO SE PUEDE EMITIR UN PERÍODO SIN ÉL.', 16, 1)
        RETURN -1
    END

    SET @MONTO = ROUND(@UF_PLAN * @UF_DIA, 0)
END

BEGIN TRANSACTION

    INSERT [dbo].[Suscripcion_Periodo]
        (spe_suscripcion, spe_plan_comercial, spe_periodicidad_cobro,
         spe_fecha_inicio, spe_fecha_fin,
         spe_valor_uf_plan, spe_valor_uf_dia, spe_fecha_valor_uf,
         spe_monto_clp, spe_monto_pagado_clp, spe_suscripcion_periodo_estado,
         spe_es_implantacion, spe_observacion,
         spe_usuario_creacion, spe_fecha_creacion,
         spe_usuario_actualizacion, spe_fecha_actualizacion, spe_habilitado)
    VALUES
        (@SUSCRIPCION, @PLAN_COMERCIAL, @PERIODICIDAD,
         @FECHA_INICIO, @FECHA_FIN,
         @UF_PLAN, @UF_DIA, @FECHA_UF,
         @MONTO, 0, 1,                       -- 1 = PENDIENTE PAGO
         @ES_IMPLANTACION, @OBSERVACION,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_SUSCRIPCION_PERIODO @SUSCRIPCION = ' + LTRIM(STR(@SUSCRIPCION))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '5.- NO FUE POSIBLE EMITIR EL PERÍODO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_UNIDAD_MEDIDA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_UNIDAD_MEDIDA (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   T-2281 - INS_UNIDAD_MEDIDA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_UNIDAD_MEDIDA]
@ID             INT = NULL OUTPUT,
@MAGNITUD       INT,
@UNIDAD_BASE    INT = NULL,
@CODIGO         NVARCHAR(20),
@NOMBRE         NVARCHAR(100),
@SIMBOLO        NVARCHAR(20),
@FACTOR         DECIMAL(18,6) = 1,
@OFFSET         DECIMAL(18,6) = 0,
@USUARIO        INT

AS
SET NOCOUNT ON

SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))
SET @FACTOR = ISNULL(@FACTOR, 1)
SET @OFFSET = ISNULL(@OFFSET, 0)

BEGIN
    -- Codigo unico global.
    IF EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = @CODIGO)
    BEGIN
        RAISERROR('1.- YA EXISTE UNA UNIDAD CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    -- Una sola unidad base por magnitud (indice UX_UME_MAGNITUD_BASE).
    IF @UNIDAD_BASE IS NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                    WHERE ume_magnitud = @MAGNITUD AND ume_unidad_base IS NULL)
    BEGIN
        RAISERROR('2.- ESA MAGNITUD YA TIENE UNA UNIDAD BASE. ELIJA UNA UNIDAD BASE PARA LA NUEVA.', 16, 1)
        RETURN -1
    END

    -- La unidad base, si se indica, tiene que ser de la misma magnitud.
    IF @UNIDAD_BASE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida]
                        WHERE ume_id = @UNIDAD_BASE AND ume_magnitud = @MAGNITUD)
    BEGIN
        RAISERROR('3.- LA UNIDAD BASE DEBE SER DE LA MISMA MAGNITUD.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Unidad_Medida]
        (ume_magnitud, ume_unidad_base, ume_codigo, ume_nombre, ume_simbolo,
         ume_factor, ume_offset, ume_usuario_creacion, ume_fecha_creacion,
         ume_usuario_actualizacion, ume_fecha_actualizacion, ume_habilitado)
    VALUES
        (@MAGNITUD, @UNIDAD_BASE, @CODIGO, @NOMBRE, @SIMBOLO,
         @FACTOR, @OFFSET, @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()
    /* ---- CODIGO AUTOMATICO ----
       El codigo depende del ID, y el ID no existe hasta esta linea.
       La ficha manda 'AUTO': ese valor satisface el NOT NULL, pasa
       por el INSERT y nunca queda guardado. */
    IF (@CODIGO IS NULL OR LEN(LTRIM(@CODIGO)) = 0 OR UPPER(LTRIM(RTRIM(@CODIGO))) = 'AUTO')
        UPDATE [dbo].[Unidad_Medida]
        SET    [ume_codigo] = [dbo].[FNC_CODIGO_AUTOMATICO]('UNI', @ID)
        WHERE  [ume_id] = @ID


    IF @ID IS NULL
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'INS_UNIDAD_MEDIDA @CODIGO = ' + ISNULL(@CODIGO, '')
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE INSERTAR LA UNIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_USUARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_USUARIO (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   7. INS_USUARIO                                                   HU-014

      Se agrega la validacion del digito verificador (solo para clientes
      chilenos) y la contrasena entra hasheada desde el primer dia.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO]
@ID                INT = NULL OUTPUT,
@IDENTIFICADOR     VARCHAR(100),
@CLIENTE           INT = NULL,
@LOGIN             VARCHAR(100),
@PASSWORD          VARCHAR(100),
@NOMBRES           VARCHAR(200),
@APELLIDO_PATERNO  VARCHAR(100),
@APELLIDO_MATERNO  VARCHAR(100) = NULL,
@FONO1             VARCHAR(50) = NULL,
@CORREO            VARCHAR(200),
@FOTO              VARBINARY(MAX) = NULL,
@EXTENSION         VARCHAR(10) = NULL,
@IDIOMA            INT = NULL,
@USUARIO           INT,
@HABILITADO        BIT

AS
SET NOCOUNT ON

DECLARE @PAIS_CHILE INT
DECLARE @PAIS_CLIENTE INT
DECLARE @SALT VARCHAR(50) = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

SELECT @PAIS_CHILE = pai_id FROM [dbo].[Paises] WHERE pai_nombre = 'Chile'

IF @CLIENTE IS NOT NULL
    SELECT @PAIS_CLIENTE = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE

--VALIDACIONES
BEGIN
    IF EXISTS(SELECT 1 FROM [dbo].[Usuario] WHERE usu_identificador = LTRIM(RTRIM(@IDENTIFICADOR)))
    BEGIN
        RAISERROR('1. Ya existe un usuario registrado con el identificador indicado.', 16, 1)
        RETURN -1
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario] WHERE usu_login = LTRIM(RTRIM(@LOGIN)))
    BEGIN
        RAISERROR('2. Ya existe un usuario registrado con el login indicado.', 16, 1)
        RETURN -2
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario] WHERE usu_correo = LTRIM(RTRIM(@CORREO)))
    BEGIN
        RAISERROR('3. Ya existe un usuario registrado con el correo indicado.', 16, 1)
        RETURN -3
    END

    /* El digito verificador se exige solo cuando el cliente es chileno. En
       Peru, Argentina, Ecuador o Panama el identificador tiene otro formato
       y esta comprobacion lo rechazaria sin razon. */
    IF @CLIENTE IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS_CLIENTE, @IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('4. El identificador "%s" no es válido para el país del cliente.', 16, 1, @IDENTIFICADOR)
        RETURN -4
    END
END

BEGIN TRANSACTION

    INSERT [dbo].[Usuario]
        (
            usu_identificador,
            usu_login,
            usu_password,
            usu_password_salt,
            usu_nombre,
            usu_apellido_paterno,
            usu_apellido_materno,
            usu_telefono,
            usu_correo,
            usu_idioma,
            usu_usuario_creacion,
            usu_fecha_creacion,
            usu_usuario_act,
            usu_fecha_act,
            usu_foto,
            usu_habilitado
        )
    VALUES
        (
            @IDENTIFICADOR,
            @LOGIN,
            [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT),
            @SALT,
            @NOMBRES,
            @APELLIDO_PATERNO,
            /* usu_apellido_materno es NOT NULL en la tabla. El parametro es
               opcional porque no todo el mundo lo tiene, asi que se guarda
               vacio en vez de NULL. */
            ISNULL(@APELLIDO_MATERNO, ''),
            @FONO1,
            @CORREO,
            @IDIOMA,
            @USUARIO,
            [dbo].[FNC_AHORA](),
            @USUARIO,
            [dbo].[FNC_AHORA](),
            @FOTO,
            @HABILITADO
        )

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'INS_USUARIO ' + ISNULL(@IDENTIFICADOR, '') + ',' + ISNULL(@LOGIN, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '5.- NO FUE POSIBLE INSERTAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

    -- El historial arranca con la contrasena inicial
    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES
        (@ID, [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT), @USUARIO, [dbo].[FNC_AHORA]())

    IF(@FOTO IS NOT NULL)BEGIN
        INSERT INTO [dbo].[Usuario_Foto]
            (uft_usuario, uft_binario, uft_extension, uft_fecha_creacion)
        VALUES
            (@ID, @FOTO, @EXTENSION, [dbo].[FNC_AHORA]())
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_USUARIO_PAISES (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_USUARIO_PAISES (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:		BRAULIO VIDAL
-- CREATE DATE: 24-04-2019
-- DESCRIPTION:	INSERTA UNA RELACION USUARIO EMPRESA
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO_PAISES]
@USUARIO INT,
@PAISES INT,
@USUARIO_CREA INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

	INSERT Usuario_Paises
		(
			UPA_ID_USUARIO,
			UPA_ID_PAIS,
			UPA_USUARIO_CREACION,
			UPA_FECHA_CREACION,
			UPA_USUARIO_ACT,
			UPA_FECHA_ACT
		)
	VALUES 
		(	
			@USUARIO,
			@PAISES,
			@USUARIO_CREA, 
			[dbo].[FNC_AHORA](),
			@USUARIO_CREA,
			[dbo].[FNC_AHORA]()
		)
	
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'INS_USUARIO_PAISES ' + 							
							STR(@USUARIO)+ ',' +
							STR(@PAISES)
													
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible insertar el registro.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
	COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- INS_USUARIO_RECUPERACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_USUARIO_RECUPERACION (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   5. INS_USUARIO_RECUPERACION                                      HU-004

      Genera el enlace de un solo uso.

      EL MENSAJE ES EL MISMO EXISTA O NO EL CORREO (escenario 1). Por eso
      este SP devuelve 0 siempre y nunca RAISERROR: si fallara cuando el
      correo no existe, la pantalla delataria que cuentas hay registradas.

      Devuelve @ENVIAR: 1 si hay que mandar el correo, 0 si no hay a quien.
      El C# manda el correo solo cuando vale 1 y muestra el mismo texto en
      los dos casos.

      Se guarda el HASH del token. El token en claro lo genera el C# y viaja
      una sola vez, en el correo.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_USUARIO_RECUPERACION]
@ID          INT = NULL OUTPUT,
@CORREO      VARCHAR(200),
@TOKEN       VARCHAR(200),
@IP          NVARCHAR(50) = NULL,
@ENVIAR      BIT = 0 OUTPUT,
@USUARIO_ID  INT = 0 OUTPUT

AS
SET NOCOUNT ON

DECLARE @MINUTOS_VIGENCIA INT = 60

SET @ENVIAR     = 0
SET @USUARIO_ID = 0

SELECT  TOP 1 @USUARIO_ID = usu_id
FROM    [dbo].[Usuario]
WHERE   usu_correo = @CORREO
  AND   usu_habilitado = 1

IF @USUARIO_ID IS NULL OR @USUARIO_ID = 0
BEGIN
    SET @USUARIO_ID = 0
    RETURN(0)
END

BEGIN TRANSACTION

    /* Los enlaces anteriores que siguen vivos se anulan: pedir uno nuevo
       invalida el anterior, si no habria varios validos a la vez. */
    UPDATE  [dbo].[Usuario_Recuperacion]
    SET     ure_fecha_uso = [dbo].[FNC_AHORA]()
    WHERE   ure_usuario = @USUARIO_ID
      AND   ure_fecha_uso IS NULL
      AND   ure_fecha_expiracion > [dbo].[FNC_AHORA]()

    INSERT [dbo].[Usuario_Recuperacion]
        (ure_usuario, ure_token_hash, ure_fecha_expiracion, ure_ip_solicitud,
         ure_usuario_creacion, ure_fecha_creacion)
    VALUES
        (@USUARIO_ID,
         HASHBYTES('SHA2_256', @TOKEN),
         DATEADD(MINUTE, @MINUTOS_VIGENCIA, [dbo].[FNC_AHORA]()),
         @IP,
         @USUARIO_ID,
         [dbo].[FNC_AHORA]())

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        RETURN(0)
    END

COMMIT TRANSACTION

SET @ENVIAR = 1
RETURN(0)
GO

-- ---------- INS_VALOR_UF (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_VALOR_UF (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   1. INS_VALOR_UF

      Una fila por dia. Si el dia ya esta cargado NO se duplica.

      La unica actualizacion permitida es reemplazar un ARRASTRE por el
      valor real: eso no es reescribir historia, es corregir un marcador de
      posicion que se escribio justamente porque la fuente no respondio.
      Un valor real jamas se pisa con otro.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_VALOR_UF]
@FECHA          DATE,
@VALOR          DECIMAL(18,4),
@ORIGEN_CODIGO  NVARCHAR(100) = N'API EXTERNA',
@RESPUESTA      NVARCHAR(500) = NULL,
@USUARIO        INT = 1,
@ESCRITO        BIT = 0 OUTPUT

AS
SET NOCOUNT ON

SET @ESCRITO = 0

DECLARE @ORIGEN INT, @ORIGEN_ARRASTRE INT, @ORIGEN_ACTUAL INT

SELECT @ORIGEN = ufo_id FROM [dbo].[Uf_Origen]
 WHERE ufo_codigo COLLATE DATABASE_DEFAULT = @ORIGEN_CODIGO COLLATE DATABASE_DEFAULT

SELECT @ORIGEN_ARRASTRE = ufo_id FROM [dbo].[Uf_Origen] WHERE ufo_codigo = N'ARRASTRE'

BEGIN
    IF @ORIGEN IS NULL
    BEGIN
        RAISERROR('1.- EL ORIGEN "%s" NO ESTÁ EN EL CATÁLOGO Uf_Origen.', 16, 1, @ORIGEN_CODIGO)
        RETURN -1
    END

    IF @VALOR IS NULL OR @VALOR <= 0
    BEGIN
        RAISERROR('2.- EL VALOR DE LA UF DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END
END

SELECT @ORIGEN_ACTUAL = vuf_uf_origen FROM [dbo].[Valor_Uf] WHERE vuf_fecha = @FECHA

IF @ORIGEN_ACTUAL IS NULL
BEGIN
    INSERT [dbo].[Valor_Uf]
        (vuf_fecha, vuf_valor, vuf_uf_origen, vuf_fecha_obtencion_utc,
         vuf_respuesta_cruda, vuf_usuario_creacion, vuf_fecha_creacion)
    VALUES
        (@FECHA, @VALOR, @ORIGEN, GETUTCDATE(), @RESPUESTA, @USUARIO, [dbo].[FNC_AHORA]())

    SET @ESCRITO = 1
    RETURN(0)
END

-- Solo se corrige un arrastre con un valor de verdad.
IF @ORIGEN_ACTUAL = @ORIGEN_ARRASTRE AND @ORIGEN <> @ORIGEN_ARRASTRE
BEGIN
    UPDATE [dbo].[Valor_Uf]
       SET vuf_valor               = @VALOR,
           vuf_uf_origen           = @ORIGEN,
           vuf_fecha_obtencion_utc = GETUTCDATE(),
           vuf_respuesta_cruda     = @RESPUESTA
     WHERE vuf_fecha = @FECHA

    SET @ESCRITO = 1
END

RETURN(0)
GO

-- ---------- INS_VALOR_UF_ARRASTRE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- INS_VALOR_UF_ARRASTRE (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   2. INS_VALOR_UF_ARRASTRE

      Lo llama el alimentador cuando la fuente no responde. Copia el ultimo
      valor conocido al dia pedido y lo marca.

      Si no hay NINGUN valor previo no inventa nada: devuelve -1 y el
      llamador avisa. Un arrastre sin nada que arrastrar seria un numero
      inventado, y con numeros inventados se emiten cobros.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[INS_VALOR_UF_ARRASTRE]
@FECHA    DATE = NULL,
@USUARIO  INT = 1,
@ESCRITO  BIT = 0 OUTPUT

AS
SET NOCOUNT ON

SET @ESCRITO = 0
SET @FECHA = ISNULL(@FECHA, CAST([dbo].[FNC_AHORA]() AS DATE))

DECLARE @ULTIMO DECIMAL(18,4), @FECHA_ULTIMO DATE

SELECT TOP 1 @ULTIMO = vuf_valor, @FECHA_ULTIMO = vuf_fecha
FROM   [dbo].[Valor_Uf]
WHERE  vuf_fecha < @FECHA
ORDER BY vuf_fecha DESC

IF @ULTIMO IS NULL
BEGIN
    RAISERROR('1.- NO HAY NINGÚN VALOR DE UF ANTERIOR QUE ARRASTRAR.', 16, 1)
    RETURN -1
END

DECLARE @NOTA NVARCHAR(500) =
    N'Arrastre del valor del ' + CONVERT(NVARCHAR(10), @FECHA_ULTIMO, 103) +
    N' porque la fuente no respondió.'

EXEC [dbo].[INS_VALOR_UF]
     @FECHA         = @FECHA,
     @VALOR         = @ULTIMO,
     @ORIGEN_CODIGO = N'ARRASTRE',
     @RESPUESTA     = @NOTA,
     @USUARIO       = @USUARIO,
     @ESCRITO       = @ESCRITO OUTPUT

RETURN(0)
GO

-- ---------- RPT_INFORME_INGRESOS (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- RPT_INFORME_INGRESOS (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- DEVUELVE INFORME INGRESOS
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[RPT_INFORME_INGRESOS]
@ID INT = NULL,
@CLIENTE INT = NULL,
@INSTALACION INT = NULL,
@FECHA_DESDE DATETIME = NULL,
@FECHA_HASTA DATETIME = NULL,
@FILTRO VARCHAR(MAX) = NULL,
@EXCEL BIT = 0,
@USUARIO INT = NULL

AS

SET NOCOUNT ON 

DECLARE @SELECT NVARCHAR(MAX),
        @FROM NVARCHAR(MAX),
        @WHERE NVARCHAR(MAX) 

IF (@EXCEL = 0) BEGIN

    SET @SELECT = '
       SELECT   MAR_ID
				,USU_NOMBRE + '' '' +
				 USU_APELLIDO_PATERNO + '' '' +
				 USU_APELLIDO_MATERNO										[NOMBRE]
				,CASE MAR_TIPO_MARCACION
						WHEN  1 THEN ''Entrada'' 
						WHEN 2 THEN ''Salida''
					END														[TIPO]
				,CONVERT(VARCHAR(10), MAR_FECHA_HORA_MARCACION, 105)		[FECHA]
				,CONVERT(VARCHAR(10), MAR_FECHA_HORA_MARCACION, 108)		[HORA]
				,MAR_FECHA_HORA_MARCACION
				,MAR_LATITUD
				,MAR_LONGITUD
		' 

END ELSE BEGIN

    SET @SELECT = '
       SELECT    CONVERT(VARCHAR(10), [dbo].[FNC_AHORA](), 105) + '' '' +
				 CONVERT(VARCHAR(10), [dbo].[FNC_AHORA](), 108)						[FECHA DESCARGA]
				,USU_NOMBRE + '' '' +
				 USU_APELLIDO_PATERNO + '' '' +
				 USU_APELLIDO_MATERNO										[NOMBRE]
				,CASE MAR_TIPO_MARCACION
						WHEN  1 THEN ''Entrada'' 
						WHEN 2 THEN ''Salida''
					END														[TIPO]
				,CONVERT(VARCHAR(10), MAR_FECHA_HORA_MARCACION, 105)		[FECHA]
				,CONVERT(VARCHAR(10), MAR_FECHA_HORA_MARCACION, 108)		[HORA]	
		' 
END

IF (@ID IS NOT NULL) BEGIN
    SET @SELECT += ' ,MAB_BINARIO
					 ,MAB_ID '
END

SET @FROM = '	FROM	MARCACION
						INNER JOIN USUARIO ON USU_ID = MAR_ID_USUARIO
						INNER JOIN CLIENTE_USUARIO ON UCL_ID_USUARIO = USU_ID
						INNER JOIN CLIENTE ON CLI_ID = UCL_ID_CLIENTE

			' 

IF (@ID IS NOT NULL) BEGIN
    SET @FROM += ' LEFT JOIN MARCACION_BINARIO ON MAB_ID = MAR_ARCHIVO '
END

SET @WHERE = ' WHERE	1=1 ' 

IF (@ID IS NOT NULL) BEGIN
    SET @WHERE += ' AND MAR_ID = ' + LTRIM(@ID)
END

IF (@USUARIO IS NOT NULL) BEGIN
    SET @WHERE += ' AND MAR_ID_USUARIO = ' + LTRIM(@USUARIO)
END

IF (@CLIENTE IS NOT NULL) BEGIN
    SET @WHERE += ' AND CLI_ID = ' + LTRIM(@CLIENTE) -- ** DE MOMENTO NO ESTAN
END

IF (@INSTALACION IS NOT NULL) BEGIN
    SET @WHERE += ' AND CIN_ID = ' + LTRIM(@INSTALACION) -- ** DE MOMENTO NO ESTAN
END

IF (@FECHA_DESDE IS NOT NULL AND @FECHA_HASTA IS NOT NULL) BEGIN
	SET @WHERE += ' AND MAR_FECHA_HORA_MARCACION BETWEEN ''' + CONVERT(VARCHAR(10), @FECHA_DESDE, 5) + ''' AND ''' + CONVERT(VARCHAR(10), @FECHA_HASTA, 5) + ' 23:59:59''' 
END

IF (@FECHA_DESDE IS NOT NULL AND @FECHA_HASTA IS NULL) BEGIN
	SET @WHERE += ' AND MAR_FECHA_HORA_MARCACION >= ''' + CONVERT(VARCHAR(10), @FECHA_DESDE, 5) + '''' 
END

IF (@FECHA_DESDE IS NULL AND @FECHA_HASTA IS NOT NULL) BEGIN
	SET @WHERE += ' AND MAR_FECHA_HORA_MARCACION <= ''' + CONVERT(VARCHAR(10), @FECHA_HASTA, 5) + ' 23:59:59''' 
END

IF (@FILTRO IS NOT NULL) BEGIN
    SET @WHERE += ' AND (USU_NOMBRE LIKE ''%' + @FILTRO + '%'' OR
						 USU_APELLIDO_PATERNO LIKE ''%' + @FILTRO + '%'' OR
						 USU_APELLIDO_MATERNO LIKE ''%' + @FILTRO + '%''
						 )'
END

BEGIN
	DECLARE @ORDERBY VARCHAR(MAX)
	SET @ORDERBY += ' ORDER BY MAR_ID DESC'
END
PRINT(@SELECT + @FROM + @WHERE + @ORDERBY) 
EXEC(@SELECT + @FROM + @WHERE + @ORDERBY)
GO

-- ---------- SEGURIDAD_INS_MENU_PERFIL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEGURIDAD_INS_MENU_PERFIL (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:			Sebastian Leon
-- Fecha creación:	02-03-2012
-- Description:		Inserta MENUS PERFIL
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[SEGURIDAD_INS_MENU_PERFIL]
@PERFIL INT,
@MENU INT,
@HABILITADO BIT,
@HOST VARCHAR(50) = NULL,
@USUARIO INT = NULL

AS
SET NOCOUNT ON

BEGIN TRANSACTION

	IF EXISTS(SELECT 1 FROM	MENU_PERFIL WHERE MPE_PERFIL = @PERFIL AND MPE_MENU = @MENU)BEGIN
		
		UPDATE	MENU_PERFIL
		SET		MPE_HABILITADO = @HABILITADO
		WHERE	MPE_PERFIL = @PERFIL 
		AND		MPE_MENU = @MENU
		
		IF @@ROWCOUNT = 0 BEGIN
			ROLLBACK TRANSACTION
			DECLARE @VARIABLES VARCHAR(MAX)
			SET @VARIABLES = 'INS_MENU_PERFIL ' + ',' +
							  LTRIM(STR(@PERFIL)) + ',' + 
							  LTRIM(STR(@MENU)) + ',' +
							  LTRIM(STR(@HABILITADO)) 
			
			EXEC INS_EXCEPCION 
				@MSG = '1.- No fue posible Actualizar la Relacion menu perfil.',
				@VARIABLES = @VARIABLES
			RETURN -1  
		END
		
	END ELSE BEGIN 
	
		INSERT MENU_PERFIL
			(
				MPE_PERFIL
				,MPE_MENU 
				,MPE_HABILITADO
				,mpe_host_creacion
				,mpe_usuario_creacion
				,mpe_fecha_creacion
				,mpe_usuario_act
				,mpe_fecha_act
			)
		VALUES
			(
				@PERFIL
				,@MENU
				,@HABILITADO
				,@HOST
				,@USUARIO
				,[dbo].[FNC_AHORA]()
				,@USUARIO
				,[dbo].[FNC_AHORA]()
			)
	

		IF @@ROWCOUNT = 0 BEGIN
			ROLLBACK TRANSACTION
			SET @VARIABLES = 'INS_MENU_PERFIL ' + ',' +
							  LTRIM(STR(@PERFIL)) + ',' + 
							  LTRIM(STR(@MENU)) + ',' +
							  LTRIM(STR(@HABILITADO)) 
			
			EXEC INS_EXCEPCION 
				@MSG = '1.- No fue posible Actualizar la Relacion menu perfil.',
				@VARIABLES = @VARIABLES
			RETURN -1  
		END
		
	END
	
COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- SEL_BODEGA_DESGLOSE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_BODEGA_DESGLOSE (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_BODEGA_DESGLOSE]
    @CLIENTE INT,
    @BODEGA  INT
AS
SET NOCOUNT ON

    SELECT  b.bod_id, b.bod_codigo, b.bod_nombre, b.bod_habilitado,
            ISNULL(b.bod_descripcion, '') AS bod_descripcion,
            ISNULL(ci.cin_nombre, '')     AS PLANTA
    FROM    [dbo].[Bodega] b
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   b.bod_id = @BODEGA AND b.bod_cliente = @CLIENTE

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO,
            ISNULL(l.rlo_codigo, '')     AS LOTE_CODIGO,
            l.rlo_fecha_vencimiento      AS LOTE_VENCE,
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), l.rlo_fecha_vencimiento)
            END                          AS DIAS_PARA_VENCER,
            ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            ISNULL(ub.bub_nombre, '')    AS UBICACION_NOMBRE,
            ''                           AS BODEGA
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Usuario] u       ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega  = @BODEGA
      AND   s.isa_cantidad <> 0
    ORDER BY UBICACION, r.rep_codigo, l.rlo_fecha_vencimiento
GO

-- ---------- SEL_CLIENTE_USUARIO_PERMISO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_CLIENTE_USUARIO_PERMISO (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   12. SEL_CLIENTE_USUARIO_PERMISO                                  HU-007

       El listado de excepciones vigentes e historicas de un cliente.
       Trae quien la concedio y cuando, que es lo que el escenario 1 pide
       que quede registrado.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_PERMISO]
@ID                  INT = NULL,
@CLIENTE             INT = NULL,
@CLIENTE_USUARIO     INT = NULL,
@USUARIO             INT = NULL,
@CLIENTE_INSTALACION INT = NULL,
@SOLO_VIGENTES       BIT = NULL,
@HABILITADO          BIT = NULL,
@FILTRO              VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT cpm.cpm_id                   AS CPM_ID
                                 ,cpm.cpm_cliente_usuario       AS CPM_CLIENTE_USUARIO
                                 ,cpm.cpm_permiso               AS CPM_PERMISO
                                 ,cpm.cpm_cliente_instalacion   AS CPM_CLIENTE_INSTALACION
                                 ,cpm.cpm_instalacion_area      AS CPM_INSTALACION_AREA
                                 ,cpm.cpm_otorgado              AS CPM_OTORGADO
                                 ,cpm.cpm_fecha_inicio          AS CPM_FECHA_INICIO
                                 ,cpm.cpm_fecha_fin             AS CPM_FECHA_FIN
                                 ,cpm.cpm_motivo                AS CPM_MOTIVO
                                 ,cpm.cpm_habilitado            AS CPM_HABILITADO
                                 ,cpm.cpm_usuario_creacion      AS CPM_USUARIO_CREACION
                                 ,cpm.cpm_fecha_creacion        AS CPM_FECHA_CREACION
                                 ,cu.ucl_id_usuario             AS USU_ID
                                 ,dest.usu_nombre + SPACE(1) + dest.usu_apellido_paterno AS USU_NOMBRE
                                 ,dest.usu_correo               AS USU_CORREO
                                 ,p.prm_codigo                  AS PRM_CODIGO
                                 ,p.prm_nombre                  AS PRM_NOMBRE
                                 ,p.prm_modulo                  AS PRM_MODULO
                                 ,ci.cin_nombre                 AS CIN_NOMBRE
                                 ,ia.iar_nombre                 AS IAR_NOMBRE
                                 ,otor.usu_nombre + SPACE(1) + otor.usu_apellido_paterno AS OTORGADO_POR
                                 ,CASE WHEN cpm.cpm_habilitado = 0 THEN ''REVOCADO''
                                       WHEN cpm.cpm_fecha_fin IS NOT NULL
                                        AND cpm.cpm_fecha_fin < CAST([dbo].[FNC_AHORA]() AS DATE) THEN ''VENCIDO''
                                       WHEN cpm.cpm_fecha_inicio IS NOT NULL
                                        AND cpm.cpm_fecha_inicio > CAST([dbo].[FNC_AHORA]() AS DATE) THEN ''PENDIENTE''
                                       ELSE ''VIGENTE'' END     AS ESTADO
                                 ,CASE WHEN cpm.cpm_instalacion_area IS NOT NULL THEN ''Área''
                                       WHEN cpm.cpm_cliente_instalacion IS NOT NULL THEN ''Planta''
                                       ELSE ''Cliente'' END      AS AMBITO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Cliente_Usuario_Permiso cpm
                       INNER JOIN Cliente_Usuario cu   ON cu.ucl_id = cpm.cpm_cliente_usuario
                       INNER JOIN Usuario dest         ON dest.usu_id = cu.ucl_id_usuario
                       INNER JOIN Permiso p            ON p.prm_id = cpm.cpm_permiso
                       LEFT  JOIN Cliente_Instalacion ci ON ci.cin_id = cpm.cpm_cliente_instalacion
                       LEFT  JOIN Instalacion_Area ia  ON ia.iar_id = cpm.cpm_instalacion_area
                       LEFT  JOIN Usuario otor         ON otor.usu_id = cpm.cpm_usuario_creacion
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cu.ucl_id_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@CLIENTE_USUARIO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_cliente_usuario = ' + LTRIM(@CLIENTE_USUARIO)
    END

    IF (@USUARIO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cu.ucl_id_usuario = ' + LTRIM(@USUARIO)
    END

    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@SOLO_VIGENTES = 1) BEGIN
        SET @WHERE = @WHERE + ' AND cpm.cpm_habilitado = 1
                                AND (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE))
                                AND (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= CAST([dbo].[FNC_AHORA]() AS DATE)) '
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (dest.usu_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR dest.usu_apellido_paterno LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR dest.usu_correo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR p.prm_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY cpm.cpm_fecha_creacion DESC '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------- SEL_CLIENTE_USUARIO_PLANTA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_CLIENTE_USUARIO_PLANTA (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   10. SEL_CLIENTE_USUARIO_PLANTA                                   HU-014

       Las plantas de una persona dentro de un cliente, con su estado de
       vigencia. VIGENTE es lo que evalua FNC_USUARIO_TIENE_PERMISO en su
       paso 4, asi que esta vista y el motor de permisos dicen lo mismo.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_PLANTA]
@USUARIO_DESTINO INT = NULL,
@CLIENTE         INT = NULL,
@INSTALACION     INT = NULL,
@SOLO_VIGENTES   BIT = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT ciu.ciu_id             AS CIU_ID
                                 ,ciu.ciu_id_instalacion  AS CIU_ID_INSTALACION
                                 ,ciu.ciu_id_usuario      AS CIU_ID_USUARIO
                                 ,ciu.ciu_habilitado      AS CIU_HABILITADO
                                 ,ciu.ciu_fecha_inicio    AS CIU_FECHA_INICIO
                                 ,ciu.ciu_fecha_fin       AS CIU_FECHA_FIN
                                 ,ci.cin_cliente          AS CIN_CLIENTE
                                 ,ci.cin_codigo           AS CIN_CODIGO
                                 ,ci.cin_nombre           AS CIN_NOMBRE
                                 ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE
                                 ,CASE WHEN ciu.ciu_habilitado = 0 THEN ''REVOCADA''
                                       WHEN ciu.ciu_fecha_inicio IS NOT NULL
                                        AND ciu.ciu_fecha_inicio > CAST([dbo].[FNC_AHORA]() AS DATE) THEN ''PENDIENTE''
                                       WHEN ciu.ciu_fecha_fin IS NOT NULL
                                        AND ciu.ciu_fecha_fin < CAST([dbo].[FNC_AHORA]() AS DATE) THEN ''VENCIDA''
                                       ELSE ''VIGENTE'' END AS ESTADO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Cliente_Instalacion_Usuario ciu
                       INNER JOIN Cliente_Instalacion ci ON ci.cin_id = ciu.ciu_id_instalacion
                       INNER JOIN Usuario u              ON u.usu_id = ciu.ciu_id_usuario
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@USUARIO_DESTINO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ciu.ciu_id_usuario = ' + LTRIM(@USUARIO_DESTINO)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ci.cin_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ciu.ciu_id_instalacion = ' + LTRIM(@INSTALACION)
    END

    IF (@SOLO_VIGENTES = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ciu.ciu_habilitado = 1
                                AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE))
                                AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= CAST([dbo].[FNC_AHORA]() AS DATE)) '
    END

    SET @WHERE = @WHERE + ' ORDER BY ci.cin_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------- SEL_GRUPO_TRABAJO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_GRUPO_TRABAJO (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   SEL_GRUPO_TRABAJO

   Trae el lider vigente y cuantos integrantes vigentes tiene el grupo: son
   las dos columnas que la grilla necesita y evitan una consulta por fila.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO]
@ID                   INT = NULL,
@CLIENTE              INT = NULL,
@CLIENTE_INSTALACION  INT = NULL,
@ESPECIALIDAD         INT = NULL,
@HABILITADO           BIT = NULL,
@FILTRO               VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT gtr.gtr_id                  AS GTR_ID
                                 ,gtr.gtr_cliente              AS GTR_CLIENTE
                                 ,gtr.gtr_cliente_instalacion  AS GTR_CLIENTE_INSTALACION
                                 ,gtr.gtr_codigo               AS GTR_CODIGO
                                 ,gtr.gtr_nombre               AS GTR_NOMBRE
                                 ,gtr.gtr_especialidad         AS GTR_ESPECIALIDAD
                                 ,gtr.gtr_descripcion          AS GTR_DESCRIPCION
                                 ,gtr.gtr_habilitado           AS GTR_HABILITADO
                                 ,gtr.gtr_usuario_creacion     AS GTR_USUARIO_CREACION
                                 ,gtr.gtr_fecha_creacion       AS GTR_FECHA_CREACION
                                 ,gtr.gtr_usuario_actualizacion AS GTR_USUARIO_ACTUALIZACION
                                 ,gtr.gtr_fecha_actualizacion  AS GTR_FECHA_ACTUALIZACION
                                 ,ISNULL(cin.cin_nombre, ''Todas las plantas'') AS CIN_NOMBRE
                                 ,esp.esp_nombre               AS ESP_NOMBRE
                                 ,(SELECT COUNT(*) FROM Grupo_Trabajo_Usuario gtu
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST([dbo].[FNC_AHORA]() AS DATE))
                                  )                            AS INTEGRANTES
                                 ,(SELECT TOP 1 ul.usu_nombre + SPACE(1) + ul.usu_apellido_paterno
                                     FROM Grupo_Trabajo_Usuario gtu
                                     INNER JOIN Usuario ul ON ul.usu_id = gtu.gtu_usuario
                                    WHERE gtu.gtu_grupo_trabajo = gtr.gtr_id
                                      AND gtu.gtu_es_lider = 1
                                      AND gtu.gtu_fecha_inicio <= CAST([dbo].[FNC_AHORA]() AS DATE)
                                      AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= CAST([dbo].[FNC_AHORA]() AS DATE))
                                  )                            AS LIDER
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Grupo_Trabajo gtr
                       LEFT JOIN Cliente_Instalacion cin ON cin.cin_id = gtr.gtr_cliente_instalacion
                       LEFT JOIN Especialidad esp        ON esp.esp_id = gtr.gtr_especialidad
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_id = ' + LTRIM(@ID)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_cliente = ' + LTRIM(@CLIENTE)
    END

    /* Un grupo transversal (sin planta) aparece tambien cuando se filtra
       por una planta: es asignable en todas. */
    IF (@CLIENTE_INSTALACION IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND (gtr.gtr_cliente_instalacion = ' + LTRIM(@CLIENTE_INSTALACION) +
                                  ' OR gtr.gtr_cliente_instalacion IS NULL) '
    END

    IF (@ESPECIALIDAD IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_especialidad = ' + LTRIM(@ESPECIALIDAD)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND gtr.gtr_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (gtr.gtr_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR gtr.gtr_codigo LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR gtr.gtr_descripcion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY gtr.gtr_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------- SEL_GRUPO_TRABAJO_USUARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_GRUPO_TRABAJO_USUARIO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_GRUPO_TRABAJO_USUARIO]
    @ID              INT = NULL,
    @GRUPO_TRABAJO   INT = NULL,
    @USUARIO_DESTINO INT = NULL,
    @SOLO_VIGENTES   BIT = NULL,
    @FILTRO          VARCHAR(MAX) = NULL
AS
SET NOCOUNT ON

SELECT  gtu.gtu_id               AS GTU_ID,
        gtu.gtu_grupo_trabajo    AS GTU_GRUPO_TRABAJO,
        gtu.gtu_usuario          AS GTU_USUARIO,
        gtu.gtu_es_lider         AS GTU_ES_LIDER,
        gtu.gtu_fecha_inicio     AS GTU_FECHA_INICIO,
        gtu.gtu_fecha_fin        AS GTU_FECHA_FIN,
        gtu.gtu_usuario_creacion AS GTU_USUARIO_CREACION,
        gtu.gtu_fecha_creacion   AS GTU_FECHA_CREACION,
        u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE,
        u.usu_apellido_paterno   AS USU_APELLIDO_PATERNO,
        u.usu_correo             AS USU_CORREO,
        u.usu_identificador      AS USU_IDENTIFICADOR,

        /* La lista dibuja la cara de cada integrante. Necesita la foto si la
           subio; si no, las iniciales sobre el color que le toca por id. Ver
           `SitioBase.Avatar`. */
        ISNULL(u.usu_archivo_foto, 0) AS USU_ARCHIVO_FOTO,
        gtr.gtr_nombre           AS GTR_NOMBRE,
        ISNULL(esp.ESPECIALIDADES, '') AS ESPECIALIDADES,
        CASE WHEN gtu.gtu_fecha_inicio > h.HOY THEN 'PENDIENTE'
             WHEN gtu.gtu_fecha_fin IS NOT NULL
              AND gtu.gtu_fecha_fin < h.HOY THEN 'TERMINADO'
             ELSE 'VIGENTE' END AS ESTADO
FROM    [dbo].[Grupo_Trabajo_Usuario] gtu
JOIN    [dbo].[Usuario] u ON u.usu_id = gtu.gtu_usuario
JOIN    [dbo].[Grupo_Trabajo] gtr ON gtr.gtr_id = gtu.gtu_grupo_trabajo
JOIN    [dbo].[Cliente] cli ON cli.cli_id = gtr.gtr_cliente
/* ----------------------------------------------------------------------
   EL "HOY" ES EL DEL CLIENTE, NO EL DEL SERVIDOR

   El servidor de base de datos esta alojado fuera del pais del cliente:
   su reloj va casi tres horas atras. Con [dbo].[FNC_AHORA](), alguien que en Chile
   agregaba a un integrante "desde hoy" a las 00:30 lo veia PENDIENTE,
   porque para el servidor todavia era ayer. El resumen decia "Sin lider
   vigente" mientras la fila mostraba el chip LIDER: la pantalla se
   contradecia sola.

   La fecha que elige la persona es del calendario de SU pantalla, asi que
   contra esa hay que compararla. FNC_PAIS_HORA hace justo eso, y es lo
   que ya usaban REC_GRUPO_TRABAJO_ESPECIALIDAD y el resto del bloque; la
   vigencia se habia quedado fuera.
   ---------------------------------------------------------------------- */
CROSS APPLY (SELECT CAST([dbo].[FNC_PAIS_HORA](cli.cli_pais) AS DATE) AS HOY) h
OUTER APPLY
(
    SELECT STRING_AGG(e.esp_nombre, ', ') WITHIN GROUP (ORDER BY e.esp_nombre) AS ESPECIALIDADES
    FROM
    (
        SELECT DISTINCT e2.esp_nombre
        FROM   [dbo].[Usuario_Especialidad] ue
        JOIN   [dbo].[Especialidad] e2 ON e2.esp_id = ue.ues_especialidad
        WHERE  ue.ues_usuario = gtu.gtu_usuario
          AND  ue.ues_cliente = gtr.gtr_cliente
          AND  ue.ues_habilitado = 1
          AND  e2.esp_habilitado = 1
    ) e
) esp
WHERE  (@ID IS NULL OR gtu.gtu_id = @ID)
  AND  (@GRUPO_TRABAJO IS NULL OR gtu.gtu_grupo_trabajo = @GRUPO_TRABAJO)
  AND  (@USUARIO_DESTINO IS NULL OR gtu.gtu_usuario = @USUARIO_DESTINO)
  AND  (@SOLO_VIGENTES IS NULL OR @SOLO_VIGENTES = 0
        OR (gtu.gtu_fecha_inicio <= h.HOY
            AND (gtu.gtu_fecha_fin IS NULL OR gtu.gtu_fecha_fin >= h.HOY)))
  AND  (@FILTRO IS NULL
        OR u.usu_nombre LIKE '%' + @FILTRO + '%'
        OR u.usu_apellido_paterno LIKE '%' + @FILTRO + '%'
        OR u.usu_identificador LIKE '%' + @FILTRO + '%'
        OR EXISTS
           (
               SELECT 1
               FROM   [dbo].[Usuario_Especialidad] uf
               JOIN   [dbo].[Especialidad] ef ON ef.esp_id = uf.ues_especialidad
               WHERE  uf.ues_usuario = gtu.gtu_usuario
                 AND  uf.ues_cliente = gtr.gtr_cliente
                 AND  uf.ues_habilitado = 1
                 AND  ef.esp_nombre LIKE '%' + @FILTRO + '%'
           ))
ORDER BY gtu.gtu_es_lider DESC, u.usu_apellido_paterno, u.usu_nombre
GO

-- ---------- SEL_INVENTARIO_ORIGEN (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_INVENTARIO_ORIGEN (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_INVENTARIO_ORIGEN]
    @CLIENTE         INT,
    @REPUESTO        INT,
    @BODEGA          INT,
    @SOLO_CON_SALDO  BIT = 1
AS
SET NOCOUNT ON

    SELECT  s.isa_bodega_ubicacion                              AS UBICACION_ID,
            ISNULL(ub.bub_codigo, '')                           AS UBICACION_CODIGO,
            ISNULL(ub.bub_nombre, '')                           AS UBICACION_NOMBRE,
            s.isa_repuesto_lote                                 AS LOTE_ID,
            ISNULL(lo.rlo_codigo, '')                           AS LOTE_CODIGO,
            lo.rlo_fecha_vencimiento                            AS LOTE_VENCE,
            CAST(CASE WHEN lo.rlo_fecha_vencimiento IS NOT NULL
                       AND lo.rlo_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE)
                      THEN 1 ELSE 0 END AS BIT)                 AS LOTE_VENCIDO,
            s.isa_cantidad                                      AS CANTIDAD,
            ISNULL(ume.ume_simbolo, '')                         AS UNIDAD
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r
            ON  r.rep_id = s.isa_repuesto
    LEFT JOIN [dbo].[Unidad_Medida] ume
            ON  ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub
            ON  ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] lo
            ON  lo.rlo_id = s.isa_repuesto_lote
    WHERE   s.isa_cliente  = @CLIENTE
      AND   s.isa_repuesto = @REPUESTO
      AND   s.isa_bodega   = @BODEGA
      AND   (@SOLO_CON_SALDO = 0 OR s.isa_cantidad > 0)
    /* El lote que vence primero, primero: es el que hay que consumir antes.
       Dentro de la misma fecha, el estante en orden alfabetico. */
    ORDER BY CASE WHEN lo.rlo_fecha_vencimiento IS NULL THEN 1 ELSE 0 END,
             lo.rlo_fecha_vencimiento,
             ub.bub_codigo,
             s.isa_repuesto_lote
GO

-- ---------- SEL_LOGIN (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_LOGIN (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  15-09-2026
-- DESCRIPTION:     SEL_LOGIN NO APAGA A LAS CUENTAS DE PLATAFORMA CUANDO
--                  SU UNICO CLIENTE AFILIADO ESTA DESHABILITADO.
-- =============================================
-- DEFECTO (encontrado en la evidencia de HU-010 #2, 15-09-2026)
--   INS_CLIENTE (bloque 39) afilia en Cliente_Usuario a quien crea el
--   cliente. Catalina (Root) creo un cliente de prueba, lo deshabilito
--   (baja logica) y al volver a entrar SEL_LOGIN respondio «Su cuenta no
--   esta habilitada. Contacte al administrador»: tenia UNA afiliacion y era
--   a un cliente apagado, y la regla de @TIENE_CLIENTE solo eximia a quien
--   no tiene ninguna. Es decir: dar de baja a un cliente dejaba fuera a la
--   persona que administra la plataforma.
--
-- LO QUE CAMBIA
--   @TIENE_CLIENTE es 1 para quien tenga algun perfil de tipo Sistema
--   (Perfiles.per_tipo = 1). El resto de SEL_LOGIN (bloque 58) queda igual:
--   ambito, bloqueo por intentos, suscripcion.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_LOGIN]
@LOGIN    VARCHAR(2000),
@PASSWORD VARCHAR(500),
@AMBITO   INT = 1

AS
SET NOCOUNT ON

DECLARE @ID                 INT
       ,@PASSWORD_GUARDADA  VARCHAR(500)
       ,@SALT               VARCHAR(50)
       ,@HABILITADO         BIT
       ,@BLOQUEADO_HASTA    DATETIME
       ,@INTENTOS           INT
       ,@PRIMER_FALLO       DATETIME
       ,@TIENE_CLIENTE      BIT
       ,@AHORA              DATETIME = [dbo].[FNC_AHORA]()
       ,@MINUTOS_RESTANTES  INT
       ,@MENSAJE_GENERICO   VARCHAR(200) = 'Correo o contraseña incorrectos.'

DECLARE @MAX_INTENTOS   INT = 5
       ,@VENTANA_MIN    INT = 15
       ,@BLOQUEO_MIN    INT = 15

SELECT  TOP 1
        @ID                = usu_id
       ,@PASSWORD_GUARDADA = usu_password
       ,@SALT              = usu_password_salt
       ,@HABILITADO        = usu_habilitado
       ,@BLOQUEADO_HASTA   = usu_bloqueado_hasta
       ,@INTENTOS          = ISNULL(usu_intentos_fallidos, 0)
       ,@PRIMER_FALLO      = usu_primer_intento_fallido
FROM    [dbo].[Usuario]
WHERE   usu_login = @LOGIN
   OR   usu_correo = @LOGIN
ORDER BY CASE WHEN usu_correo = @LOGIN THEN 0 ELSE 1 END


IF (@ID IS NULL)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''), 'INTENTO DE ACCESO CON CUENTA INEXISTENTE.', @AHORA)

    SELECT 0 [ID], '404' [CODE], @MENSAJE_GENERICO [MENSAJE]
    RETURN -1
END


IF (@BLOQUEADO_HASTA IS NOT NULL AND @BLOQUEADO_HASTA > @AHORA)
BEGIN
    SET @MINUTOS_RESTANTES = DATEDIFF(MINUTE, @AHORA, @BLOQUEADO_HASTA) + 1

    SELECT 0     [ID]
          ,'423' [CODE]
          ,'Su cuenta está bloqueada por intentos fallidos. Vuelva a intentar en '
           + LTRIM(STR(@MINUTOS_RESTANTES)) + ' minuto(s).' [MENSAJE]
    RETURN -5
END


DECLARE @AFILIACIONES INT

SELECT  @AFILIACIONES = COUNT(*)
FROM    [dbo].[Cliente_Usuario]
WHERE   ucl_id_usuario = @ID

/* Las cuentas de plataforma (algun perfil de tipo Sistema: Root, Gerente
   Comercial) no dependen de ningun cliente para entrar. INS_CLIENTE afilia
   a quien crea el cliente, asi que un Root que da de alta una empresa y
   despues la deshabilita quedaba con una sola afiliacion, a un cliente
   apagado, y SEL_LOGIN lo rechazaba con «Su cuenta no esta habilitada»
   (visto en las pruebas de HU-010 #2, 15-09-2026). La baja logica es del
   cliente; quien administra la plataforma no se apaga con el. */
DECLARE @ES_PLATAFORMA BIT = CASE
    WHEN EXISTS (SELECT 1
                 FROM   [dbo].[Usuario_Perfil] up
                 INNER JOIN [dbo].[Perfiles] p ON p.per_id = up.upe_perfil
                 WHERE  up.upe_usuario = @ID
                   AND  p.per_tipo = 1) THEN 1
    ELSE 0 END

SET @TIENE_CLIENTE = CASE
    WHEN @ES_PLATAFORMA = 1 THEN 1
    WHEN @AFILIACIONES = 0 THEN 1
    WHEN EXISTS (SELECT 1 FROM [dbo].[Cliente_Usuario] cu
                 INNER JOIN [dbo].[Cliente] c ON c.cli_id = cu.ucl_id_cliente
                 WHERE cu.ucl_id_usuario = @ID
                   AND ISNULL(cu.ucl_habilitado, 0) = 1
                   AND ISNULL(c.cli_habilitado, 0) = 1) THEN 1
    ELSE 0 END

IF (@HABILITADO = 0 OR @TIENE_CLIENTE = 0)
BEGIN
    SELECT 0     [ID]
          ,'401' [CODE]
          ,'Su cuenta no está habilitada. Contacte al administrador.' [MENSAJE]
    RETURN -2
END


DECLARE @CLAVE_OK BIT = 0

IF (@SALT IS NULL)
BEGIN
    IF (@PASSWORD_GUARDADA = @PASSWORD) SET @CLAVE_OK = 1
END
ELSE
BEGIN
    IF (@PASSWORD_GUARDADA = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT)) SET @CLAVE_OK = 1
END


IF (@CLAVE_OK = 0)
BEGIN
    IF (@PRIMER_FALLO IS NULL OR DATEDIFF(MINUTE, @PRIMER_FALLO, @AHORA) > @VENTANA_MIN)
    BEGIN
        SET @INTENTOS     = 1
        SET @PRIMER_FALLO = @AHORA
    END
    ELSE
        SET @INTENTOS = @INTENTOS + 1

    UPDATE  [dbo].[Usuario]
    SET     usu_intentos_fallidos      = @INTENTOS
           ,usu_primer_intento_fallido = @PRIMER_FALLO
           ,usu_bloqueado_hasta        = CASE WHEN @INTENTOS >= @MAX_INTENTOS
                                              THEN DATEADD(MINUTE, @BLOQUEO_MIN, @AHORA)
                                              ELSE usu_bloqueado_hasta END
    WHERE   usu_id = @ID

    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, '') + ', INTENTO ' + LTRIM(STR(@INTENTOS)),
            'CONTRASEÑA INCORRECTA.', @AHORA)

    IF (@INTENTOS >= @MAX_INTENTOS)
    BEGIN
        SELECT 0     [ID]
              ,'423' [CODE]
              ,'Su cuenta está bloqueada por intentos fallidos. Vuelva a intentar en '
               + LTRIM(STR(@BLOQUEO_MIN)) + ' minuto(s).' [MENSAJE]
        RETURN -5
    END

    SELECT 0 [ID], '404' [CODE], @MENSAJE_GENERICO [MENSAJE]
    RETURN -3
END


IF (@SALT IS NULL)
BEGIN
    SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

    UPDATE  [dbo].[Usuario]
    SET     usu_password_salt = @SALT
           ,usu_password      = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT)
    WHERE   usu_id = @ID
END

UPDATE  [dbo].[Usuario]
SET     usu_intentos_fallidos      = 0
       ,usu_primer_intento_fallido = NULL
       ,usu_bloqueado_hasta        = NULL
WHERE   usu_id = @ID


/* ---- Sin perfil no se entra ---- */
IF NOT EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] WHERE upe_usuario = @ID)
   AND NOT EXISTS (SELECT 1
                     FROM [dbo].[Cliente_Usuario] cu
                     JOIN [dbo].[Cliente_Usuario_Perfil] cup ON cup.cup_id_cliente_usuario = cu.ucl_id
                    WHERE cu.ucl_id_usuario = @ID)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''), 'ACCESO DENEGADO: CUENTA SIN PERFIL.', @AHORA)

    SELECT 0     [ID]
          ,'403' [CODE]
          ,'Tu cuenta todavía no tiene un perfil asignado. '
         + 'Contacta al administrador de tu empresa.' [MENSAJE]
    RETURN -7
END


/* ---- Ambito: web o app (bloque 58) ---- */
IF ([dbo].[FNC_USUARIO_OPERA_AMBITO](@ID, @AMBITO) = 0)
BEGIN
    INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
    VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, '') + ', AMBITO ' + LTRIM(STR(@AMBITO)),
            'ACCESO DENEGADO POR AMBITO DEL PERFIL.', @AHORA)

    SELECT 0     [ID]
          ,'403' [CODE]
          ,CASE WHEN @AMBITO = 1
                THEN 'Tu perfil trabaja desde la aplicación móvil de SIGMA, no desde la web. '
                   + 'Ingresa desde la app.'
                ELSE 'Tu perfil trabaja desde la web de SIGMA, no desde la aplicación móvil.'
           END [MENSAJE]
    RETURN -8
END


/* ---- Suscripcion de la empresa (ANEXO F §6.6) ---- */
IF (@AFILIACIONES > 0)
BEGIN
    IF NOT EXISTS (SELECT 1
                     FROM [dbo].[Cliente_Usuario] cu
                    WHERE cu.ucl_id_usuario = @ID
                      AND ISNULL(cu.ucl_habilitado, 0) = 1
                      AND [dbo].[FNC_CLIENTE_PUEDE_OPERAR](cu.ucl_id_cliente) = 1)
    BEGIN
        IF ([dbo].[FNC_USUARIO_PUEDE_RENOVAR](@ID) = 0)
        BEGIN
            INSERT [dbo].[Sis_Excepcion] (LGE_TEXTO, LGE_ERROR, LGE_FECHA_ACT)
            VALUES ('SEL_LOGIN @LOGIN = ' + ISNULL(@LOGIN, ''),
                    'ACCESO DENEGADO POR SUSCRIPCION NO VIGENTE.', @AHORA)

            SELECT 0     [ID]
                  ,'402' [CODE]
                  ,'La suscripción de tu empresa no está vigente. '
                 + 'Contacta al administrador de tu empresa para regularizarla.' [MENSAJE]
            RETURN -6
        END
    END
END


UPDATE  [dbo].[Usuario]
SET     usu_ultimo_acceso = @AHORA
WHERE   usu_id = @ID

SELECT @ID [ID], '200' [CODE], 'OK' [MENSAJE]
RETURN 0
GO

-- ---------- SEL_PLAN_COMERCIAL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_PLAN_COMERCIAL (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  14-09-2026
-- DESCRIPTION:     UN PLAN COMERCIAL RECIEN CREADO, SIN PRECIO, TIENE QUE
--                  VERSE EN EL LISTADO PARA PODER FIJARLE EL PRECIO.
-- =============================================
-- DEFECTO (encontrado en la evidencia de HU-190 #1, 14-09-2026)
--   SEL_PLAN_COMERCIAL unia Plan_Comercial con Plan_Comercial_Precio por
--   INNER JOIN: una fila por plan y periodicidad CON precio vigente. Un plan
--   recien creado no tiene precio, asi que no aparecia en Planes.aspx, y
--   como la ficha cierra al guardar, no habia camino para fijarle el
--   precio: el plan quedaba invisible para siempre.
--
-- LO QUE CAMBIA
--   LEFT JOIN a precio y periodicidad, con la condicion de vigencia dentro
--   del JOIN (en el WHERE anularia el LEFT). Un plan sin precio sale con
--   una fila y PCB/PCP en NULL; la pantalla lo muestra como «sin precio».
--   El filtro @PERIODICIDAD sigue exigiendo el precio, porque esa pregunta
--   («que se vende mensual») solo tiene sentido con precio.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL]
@ID             INT = NULL,
@PERIODICIDAD   INT = NULL,
@FECHA          DATE = NULL,
@SOLO_PUBLICOS  BIT = NULL,
@HABILITADO     BIT = NULL

AS
SET NOCOUNT ON

SET @FECHA = ISNULL(@FECHA, CAST([dbo].[FNC_AHORA]() AS DATE))

    SELECT  p.plc_id                      AS PLC_ID,
            p.plc_codigo                  AS PLC_CODIGO,
            p.plc_nombre                  AS PLC_NOMBRE,
            p.plc_descripcion             AS PLC_DESCRIPCION,
            p.plc_dias_gracia             AS PLC_DIAS_GRACIA,
            p.plc_publico                 AS PLC_PUBLICO,
            p.plc_orden                   AS PLC_ORDEN,
            p.plc_habilitado              AS PLC_HABILITADO,
            pc.pcb_id                     AS PCB_ID,
            pc.pcb_codigo                 AS PCB_CODIGO,
            pc.pcb_nombre                 AS PCB_NOMBRE,
            pr.pcp_id                     AS PCP_ID,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            -- Lo que costaria hoy, para mostrarlo en pantalla. NO es lo que
            -- se cobra: eso se congela recien al emitir el periodo.
            CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@FECHA), 0), 0) AS DECIMAL(18,0))
                                          AS MONTO_CLP_REFERENCIAL,
            [dbo].[FNC_VALOR_UF](@FECHA)  AS VALOR_UF_DIA
    FROM    [dbo].[Plan_Comercial] p
    LEFT JOIN [dbo].[Plan_Comercial_Precio] pr
           ON pr.pcp_plan_comercial = p.plc_id
          AND pr.pcp_habilitado = 1
          AND pr.pcp_vigencia_desde <= @FECHA
          AND (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @FECHA)
    LEFT JOIN [dbo].[Periodicidad_Cobro] pc ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR p.plc_id = @ID)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@SOLO_PUBLICOS IS NULL OR @SOLO_PUBLICOS = 0 OR p.plc_publico = 1)
      AND   (@HABILITADO IS NULL OR p.plc_habilitado = @HABILITADO)
    ORDER BY p.plc_orden, pc.pcb_orden

RETURN(0)
GO

-- ---------- SEL_PLAN_COMERCIAL_PRECIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_PLAN_COMERCIAL_PRECIO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   5. SEL_PLAN_COMERCIAL_PRECIO

      Todos los precios de un plan, vigentes e historicos. Es lo que
      alimenta la ficha: la lista de arriba muestra lo que se vende hoy, y
      el historial de abajo responde "con que precio se cobro en marzo".
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_COMERCIAL_PRECIO]
@ID            INT = NULL,
@PLAN          INT = NULL,
@PERIODICIDAD  INT = NULL,
@SOLO_VIGENTES BIT = NULL

AS
SET NOCOUNT ON

DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    SELECT  pr.pcp_id                     AS PCP_ID,
            pr.pcp_plan_comercial         AS PCP_PLAN_COMERCIAL,
            p.plc_codigo                  AS PLC_CODIGO,
            p.plc_nombre                  AS PLC_NOMBRE,
            pr.pcp_periodicidad_cobro     AS PCP_PERIODICIDAD_COBRO,
            pc.pcb_codigo                 AS PCB_CODIGO,
            pc.pcb_nombre                 AS PCB_NOMBRE,
            pr.pcp_valor_uf               AS PCP_VALOR_UF,
            pr.pcp_descuento_porcentaje   AS PCP_DESCUENTO_PORCENTAJE,
            pr.pcp_vigencia_desde         AS PCP_VIGENCIA_DESDE,
            pr.pcp_vigencia_hasta         AS PCP_VIGENCIA_HASTA,
            pr.pcp_habilitado             AS PCP_HABILITADO,
            CAST(ROUND(pr.pcp_valor_uf * ISNULL([dbo].[FNC_VALOR_UF](@HOY), 0), 0) AS DECIMAL(18,0))
                                          AS MONTO_CLP_REFERENCIAL,
            /* Tres estados y no un si/no: un precio cargado para el proximo
               mes no es lo mismo que uno que ya caduco, y en una lista
               ordenada por fecha los dos se ven igual de "no vigente". */
            CASE WHEN pr.pcp_habilitado = 0 THEN N'RETIRADO'
                 WHEN pr.pcp_vigencia_desde > @HOY THEN N'PROGRAMADO'
                 WHEN pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @HOY THEN N'VIGENTE'
                 ELSE N'HISTÓRICO' END    AS ESTADO
    FROM    [dbo].[Plan_Comercial_Precio] pr
    INNER JOIN [dbo].[Plan_Comercial] p       ON p.plc_id  = pr.pcp_plan_comercial
    INNER JOIN [dbo].[Periodicidad_Cobro] pc  ON pc.pcb_id = pr.pcp_periodicidad_cobro
    WHERE   (@ID IS NULL OR pr.pcp_id = @ID)
      AND   (@PLAN IS NULL OR pr.pcp_plan_comercial = @PLAN)
      AND   (@PERIODICIDAD IS NULL OR pr.pcp_periodicidad_cobro = @PERIODICIDAD)
      AND   (@SOLO_VIGENTES IS NULL OR @SOLO_VIGENTES = 0
             OR (pr.pcp_habilitado = 1
                 AND pr.pcp_vigencia_desde <= @HOY
                 AND (pr.pcp_vigencia_hasta IS NULL OR pr.pcp_vigencia_hasta >= @HOY)))
    ORDER BY pc.pcb_orden, pr.pcp_vigencia_desde DESC

RETURN(0)
GO

-- ---------- SEL_PLAN_FUNCIONALIDAD (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_PLAN_FUNCIONALIDAD (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   1. SEL_PLAN_FUNCIONALIDAD

      La matriz completa de un plan: TODAS las funcionalidades, tengan o no
      fila. Devolver solo las que tienen fila obligaria a la pantalla a
      cruzar contra el catalogo para saber que falta, y lo que falta es
      justamente lo interesante: una funcionalidad sin fila esta NEGADA, y
      hay que verla para poder concederla.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_PLAN_FUNCIONALIDAD]
@PLAN     INT,
@CLIENTE  INT = NULL

AS
SET NOCOUNT ON

DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    SELECT  f.fun_id                      AS FUN_ID,
            f.fun_codigo                  AS FUN_CODIGO,
            f.fun_nombre                  AS FUN_NOMBRE,
            f.fun_orden                   AS FUN_ORDEN,

            /* El tipo sale de la fila si existe, y si no del catalogo: las
               cuatro que empiezan con LIMITE son topes, el resto inclusion.
               Asi una funcionalidad sin fila igual se pinta con el control
               que le corresponde. */
            ISNULL(pcf.pcf_funcionalidad_tipo,
                   CASE WHEN f.fun_codigo LIKE N'LIMITE%' THEN 2 ELSE 1 END)
                                          AS PCF_TIPO,
            ft.fnt_codigo                 AS FNT_CODIGO,

            pcf.pcf_id                    AS PCF_ID,
            ISNULL(pcf.pcf_incluida, 0)   AS PCF_INCLUIDA,
            pcf.pcf_limite                AS PCF_LIMITE,
            pcf.pcf_cliente               AS PCF_CLIENTE,
            pcf.pcf_vigencia_hasta        AS PCF_VIGENCIA_HASTA,
            pcf.pcf_observacion           AS PCF_OBSERVACION,

            /* De donde sale lo que se muestra. Sin esto, quien mire la
               matriz de un cliente no sabria si un "si" es del plan o una
               excepcion que alguien le concedio. */
            CASE WHEN pcf.pcf_id IS NULL              THEN N'SIN DEFINIR'
                 WHEN pcf.pcf_cliente IS NOT NULL     THEN N'EXCEPCIÓN'
                 ELSE N'PLAN' END         AS ORIGEN,

            CASE WHEN pcf.pcf_vigencia_hasta IS NOT NULL AND pcf.pcf_vigencia_hasta < @HOY
                 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
                                          AS CADUCADA

    FROM    [dbo].[Funcionalidad] f
    LEFT JOIN [dbo].[Plan_Comercial_Funcionalidad] pcf
           ON pcf.pcf_funcionalidad = f.fun_id
          AND pcf.pcf_plan_comercial = @PLAN
          AND pcf.pcf_habilitado = 1
          /* La excepcion del cliente gana: cuando se pide un cliente se
             prefiere su fila, y si no la tiene cae en la del plan. */
          AND (pcf.pcf_cliente IS NULL OR pcf.pcf_cliente = @CLIENTE)
          AND (@CLIENTE IS NOT NULL OR pcf.pcf_cliente IS NULL)
    LEFT JOIN [dbo].[Funcionalidad_Tipo] ft
           ON ft.fnt_id = ISNULL(pcf.pcf_funcionalidad_tipo,
                                 CASE WHEN f.fun_codigo LIKE N'LIMITE%' THEN 2 ELSE 1 END)
    WHERE   f.fun_habilitado = 1
    ORDER BY f.fun_orden

RETURN(0)
GO

-- ---------- SEL_PROGRAMACION_CATALOGO_GRUPO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_PROGRAMACION_CATALOGO_GRUPO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO_GRUPO]
    @CLIENTE    INT,
    @PADRE      INT = NULL
AS
SET NOCOUNT ON

    /* El nombre lleva la especialidad y cuanta gente tiene: "Cuadrilla A" no
       dice si son dos personas o doce, y esa es justo la diferencia entre
       poder tomar el trabajo o no. */
    SELECT  ID = g.gtr_id,
            CODIGO = ISNULL(g.gtr_codigo, CAST(g.gtr_id AS NVARCHAR(100))),
            NOMBRE = g.gtr_nombre
                   + ISNULL(N'  Â·  ' + e.esp_nombre, N'')
                   + N'  Â·  ' + CAST(x.CUANTOS AS NVARCHAR(10))
                   + CASE WHEN x.CUANTOS = 1 THEN N' integrante' ELSE N' integrantes' END,
            ORDEN = 0
    FROM    [dbo].[Grupo_Trabajo] g
    LEFT JOIN [dbo].[Especialidad] e ON e.esp_id = g.gtr_especialidad
    OUTER APPLY (
        SELECT CUANTOS = COUNT(*)
        FROM   [dbo].[Grupo_Trabajo_Usuario] u
        WHERE  u.gtu_grupo_trabajo = g.gtr_id
          AND  (u.gtu_fecha_fin IS NULL OR u.gtu_fecha_fin >= CAST([dbo].[FNC_AHORA]() AS DATE))
    ) x
    WHERE   g.gtr_cliente = @CLIENTE
      AND   g.gtr_habilitado = 1
      /* Sin instalacion elegida se muestran todos; con una elegida, los de
         esa planta y los que no estan amarrados a ninguna. */
      AND   (@PADRE IS NULL
             OR g.gtr_cliente_instalacion IS NULL
             OR g.gtr_cliente_instalacion = @PADRE)
    ORDER BY g.gtr_nombre
GO

-- ---------- SEL_REPUESTO_DESGLOSE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_REPUESTO_DESGLOSE (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_DESGLOSE]
    @CLIENTE  INT,
    @REPUESTO INT
AS
SET NOCOUNT ON

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre, r.rep_habilitado,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            r.rep_controla_lote,
            ume.ume_simbolo              AS UNIDAD,
            ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s
                     WHERE s.isa_repuesto = r.rep_id AND s.isa_cliente = @CLIENTE), 0) AS TOTAL
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    WHERE   r.rep_id = @REPUESTO AND r.rep_cliente = @CLIENTE

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO,
            ISNULL(l.rlo_codigo, '')     AS LOTE_CODIGO,
            l.rlo_fecha_vencimiento      AS LOTE_VENCE,
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), l.rlo_fecha_vencimiento)
            END                          AS DIAS_PARA_VENCER,
            ISNULL(ub.bub_codigo, '(sin ubicación)') AS UBICACION,
            ISNULL(ub.bub_nombre, '')    AS UBICACION_NOMBRE,
            b.bod_codigo + ' · ' + b.bod_nombre AS BODEGA
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    JOIN    [dbo].[Bodega] b          ON b.bod_id = s.isa_bodega
    LEFT JOIN [dbo].[Bodega_Ubicacion] ub ON ub.bub_id = s.isa_bodega_ubicacion
    LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Usuario] u       ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_repuesto = @REPUESTO
      AND   s.isa_cantidad <> 0
    ORDER BY b.bod_codigo, UBICACION, l.rlo_fecha_vencimiento
GO

-- ---------- SEL_REPUESTO_LOTE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_REPUESTO_LOTE (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_LOTE]
    @ID       INT = NULL,
    @CLIENTE  INT,
    @REPUESTO INT = NULL,
    @VIGENTES BIT = 0
AS
SET NOCOUNT ON

    SELECT  l.rlo_id, l.rlo_repuesto, l.rlo_codigo, l.rlo_fecha_ingreso,
            l.rlo_fecha_vencimiento, l.rlo_proveedor, l.rlo_costo_unitario,
            l.rlo_moneda, l.rlo_observacion, l.rlo_habilitado,
            l.rlo_usuario_creacion, l.rlo_fecha_creacion,
            l.rlo_usuario_actualizacion, l.rlo_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
            r.rep_codigo AS REPUESTO_CODIGO,
            CASE WHEN l.rlo_fecha_vencimiento IS NOT NULL
                  AND l.rlo_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE)
                 THEN 1 ELSE 0 END AS VENCIDO
    FROM    [dbo].[Repuesto_Lote] l
    JOIN    [dbo].[Repuesto] r ON r.rep_id = l.rlo_repuesto
    LEFT JOIN [dbo].[Usuario] uc ON uc.usu_id = l.rlo_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua ON ua.usu_id = l.rlo_usuario_actualizacion
    WHERE   l.rlo_cliente = @CLIENTE
      AND   (@ID IS NULL OR l.rlo_id = @ID)
      AND   (@REPUESTO IS NULL OR l.rlo_repuesto = @REPUESTO)
      AND   (@VIGENTES = 0 OR (l.rlo_habilitado = 1
             AND (l.rlo_fecha_vencimiento IS NULL
                  OR l.rlo_fecha_vencimiento >= CAST([dbo].[FNC_AHORA]() AS DATE))))
    ORDER BY l.rlo_fecha_vencimiento, l.rlo_codigo
GO

-- ---------- SEL_REPUESTO_LOTE_SALDO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_REPUESTO_LOTE_SALDO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO_LOTE_SALDO]
    @CLIENTE  INT,
    @REPUESTO INT = NULL,
    @LOTE     INT = NULL
AS
SET NOCOUNT ON

    SELECT  l.rlo_id,
            l.rlo_codigo,
            l.rlo_fecha_ingreso,
            l.rlo_fecha_vencimiento,
            l.rlo_habilitado,
            r.rep_id,
            r.rep_codigo,
            r.rep_nombre,
            ume.ume_simbolo AS UNIDAD,

            /* Lo que entro con este lote. */
            ISNULL((SELECT SUM(m.imo_cantidad)
                    FROM   [dbo].[Inventario_Movimiento] m
                    WHERE  m.imo_repuesto_lote = l.rlo_id
                      AND  m.imo_inventario_movimiento_tipo IN (1, 3, 4, 7)), 0) AS RECIBIDO,

            /* Lo que salio. */
            ISNULL((SELECT SUM(m.imo_cantidad)
                    FROM   [dbo].[Inventario_Movimiento] m
                    WHERE  m.imo_repuesto_lote = l.rlo_id
                      AND  m.imo_inventario_movimiento_tipo IN (2, 5, 6, 8)), 0) AS CONSUMIDO,

            /* Lo que queda, tomado del saldo y no de la resta. */
            ISNULL((SELECT SUM(s.isa_cantidad)
                    FROM   [dbo].[Inventario_Saldo] s
                    WHERE  s.isa_repuesto_lote = l.rlo_id), 0) AS QUEDA,

            /* En cuantas ubicaciones esta repartido lo que queda. */
            ISNULL((SELECT COUNT(*)
                    FROM   [dbo].[Inventario_Saldo] s
                    WHERE  s.isa_repuesto_lote = l.rlo_id
                      AND  s.isa_cantidad <> 0), 0) AS UBICACIONES,

            /* Cuando vence, en dias. Negativo quiere decir vencido. */
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), l.rlo_fecha_vencimiento)
            END AS DIAS_PARA_VENCER,

            LTRIM(RTRIM(ISNULL(uc.usu_nombre, '') + ' '
                      + ISNULL(uc.usu_apellido_paterno, ''))) AS USUARIO_CREACION,
            l.rlo_fecha_creacion,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre, '') + ' '
                      + ISNULL(ua.usu_apellido_paterno, ''))) AS USUARIO_ACTUALIZACION,
            l.rlo_fecha_actualizacion
    FROM    [dbo].[Repuesto_Lote] l
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = l.rlo_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Usuario] uc      ON uc.usu_id = l.rlo_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua      ON ua.usu_id = l.rlo_usuario_actualizacion
    WHERE   l.rlo_cliente = @CLIENTE
      AND   (@REPUESTO IS NULL OR l.rlo_repuesto = @REPUESTO)
      AND   (@LOTE     IS NULL OR l.rlo_id       = @LOTE)
    ORDER BY r.rep_codigo, l.rlo_fecha_ingreso DESC, l.rlo_codigo
GO

-- ---------- SEL_UBICACION_DESGLOSE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_UBICACION_DESGLOSE (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[SEL_UBICACION_DESGLOSE]
    @CLIENTE   INT,
    @UBICACION INT
AS
SET NOCOUNT ON

    SELECT  ub.bub_id, ub.bub_codigo, ub.bub_nombre, ub.bub_habilitado,
            b.bod_id, b.bod_codigo, b.bod_nombre,
            ISNULL(ci.cin_nombre, '') AS PLANTA
    FROM    [dbo].[Bodega_Ubicacion] ub
    JOIN    [dbo].[Bodega] b ON b.bod_id = ub.bub_bodega
    LEFT JOIN [dbo].[Cliente_Instalacion] ci ON ci.cin_id = b.bod_cliente_instalacion
    WHERE   ub.bub_id = @UBICACION AND b.bod_cliente = @CLIENTE

    SELECT  r.rep_id, r.rep_codigo, r.rep_nombre,
            ISNULL(r.rep_fabricante, '') AS rep_fabricante,
            ISNULL(r.rep_modelo, '')     AS rep_modelo,
            ume.ume_simbolo              AS UNIDAD,
            s.isa_cantidad               AS CANTIDAD,
            s.isa_costo_promedio         AS COSTO_PROMEDIO,
            s.isa_fecha_ultimo_movimiento AS ULTIMO_MOVIMIENTO,
            LTRIM(RTRIM(ISNULL(u.usu_nombre, '') + ' '
                      + ISNULL(u.usu_apellido_paterno, ''))) AS ULTIMO_USUARIO,
            ISNULL(l.rlo_codigo, '')     AS LOTE_CODIGO,
            l.rlo_fecha_vencimiento      AS LOTE_VENCE,
            CASE WHEN l.rlo_fecha_vencimiento IS NULL THEN NULL
                 ELSE DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), l.rlo_fecha_vencimiento)
            END                          AS DIAS_PARA_VENCER,
            ''                           AS UBICACION,
            ''                           AS UBICACION_NOMBRE,
            ''                           AS BODEGA
    FROM    [dbo].[Inventario_Saldo] s
    JOIN    [dbo].[Repuesto] r        ON r.rep_id = s.isa_repuesto
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Repuesto_Lote] l ON l.rlo_id = s.isa_repuesto_lote
    LEFT JOIN [dbo].[Usuario] u       ON u.usu_id = s.isa_usuario_actualizacion
    WHERE   s.isa_cliente = @CLIENTE
      AND   s.isa_bodega_ubicacion = @UBICACION
      AND   s.isa_cantidad <> 0
    ORDER BY r.rep_codigo, l.rlo_fecha_vencimiento
GO

-- ---------- SEL_USUARIO_ESPECIALIDAD (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_USUARIO_ESPECIALIDAD (P) · 6 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   SEL_USUARIO_ESPECIALIDAD

   Devuelve ESTADO y DIAS_PARA_VENCER porque de ahi salen los tres
   escenarios de HU-017 sin que la pantalla tenga que calcular fechas:

     VIGENTE      certificacion al dia, o sin vencimiento
     POR_VENCER   vence en menos de 30 dias  -> panel de alertas (escenario 3)
     VENCIDA      ya vencio                  -> advertencia (escenario 2)
     SIN_CERTIFICACION  la especialidad no exige certificado

   @SOLO_VENCIDAS y @SOLO_POR_VENCER alimentan directamente ese panel.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_ESPECIALIDAD]
@ID                INT = NULL,
@USUARIO_DESTINO   INT = NULL,
@CLIENTE           INT = NULL,
@ESPECIALIDAD      INT = NULL,
@SOLO_VENCIDAS     BIT = NULL,
@SOLO_POR_VENCER   BIT = NULL,
@HABILITADO        BIT = NULL,
@FILTRO            VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

DECLARE @DIAS_AVISO INT = 30

--SELECT
BEGIN
    DECLARE @SELECT VARCHAR(MAX)
    SET @SELECT = 'SELECT DISTINCT ues.ues_id                AS UES_ID
                                 ,ues.ues_usuario            AS UES_USUARIO
                                 ,ues.ues_cliente            AS UES_CLIENTE
                                 ,ues.ues_especialidad       AS UES_ESPECIALIDAD
                                 ,ues.ues_especialidad_nivel AS UES_ESPECIALIDAD_NIVEL
                                 ,ues.ues_certificacion      AS UES_CERTIFICACION
                                 ,ues.ues_fecha_vencimiento  AS UES_FECHA_VENCIMIENTO
                                 ,ues.ues_habilitado         AS UES_HABILITADO
                                 ,ues.ues_usuario_creacion   AS UES_USUARIO_CREACION
                                 ,ues.ues_fecha_creacion     AS UES_FECHA_CREACION
                                 ,esp.esp_codigo             AS ESP_CODIGO
                                 ,esp.esp_nombre             AS ESP_NOMBRE
                                 ,enl.enl_nombre             AS ENL_NOMBRE
                                 ,u.usu_nombre + SPACE(1) + u.usu_apellido_paterno AS USU_NOMBRE
                                 ,u.usu_correo               AS USU_CORREO
                                 ,CASE WHEN ues.ues_fecha_vencimiento IS NULL THEN NULL
                                       ELSE DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), ues.ues_fecha_vencimiento)
                                  END                        AS DIAS_PARA_VENCER
                                 ,CASE WHEN ues.ues_certificacion IS NULL
                                        AND ues.ues_fecha_vencimiento IS NULL THEN ''SIN_CERTIFICACION''
                                       WHEN ues.ues_fecha_vencimiento IS NULL THEN ''VIGENTE''
                                       WHEN ues.ues_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE) THEN ''VENCIDA''
                                       WHEN DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), ues.ues_fecha_vencimiento) <= '
                                       + LTRIM(STR(@DIAS_AVISO)) + ' THEN ''POR_VENCER''
                                       ELSE ''VIGENTE'' END  AS ESTADO
                  '
END

--FROM
BEGIN
    DECLARE @FROM VARCHAR(MAX)
    SET @FROM = ' FROM Usuario_Especialidad ues
                       INNER JOIN Especialidad esp      ON esp.esp_id = ues.ues_especialidad
                       INNER JOIN Usuario u             ON u.usu_id = ues.ues_usuario
                       LEFT  JOIN Especialidad_Nivel enl ON enl.enl_id = ues.ues_especialidad_nivel
                '
END

--WHERE
BEGIN
    DECLARE @WHERE VARCHAR(MAX)
    SET @WHERE = ' WHERE 1=1 '

    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_id = ' + LTRIM(@ID)
    END

    IF (@USUARIO_DESTINO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_usuario = ' + LTRIM(@USUARIO_DESTINO)
    END

    IF (@CLIENTE IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_cliente = ' + LTRIM(@CLIENTE)
    END

    IF (@ESPECIALIDAD IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_especialidad = ' + LTRIM(@ESPECIALIDAD)
    END

    IF (@HABILITADO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_habilitado = ' + LTRIM(@HABILITADO)
    END

    IF (@SOLO_VENCIDAS = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_fecha_vencimiento IS NOT NULL
                                AND ues.ues_fecha_vencimiento < CAST([dbo].[FNC_AHORA]() AS DATE) '
    END

    IF (@SOLO_POR_VENCER = 1) BEGIN
        SET @WHERE = @WHERE + ' AND ues.ues_fecha_vencimiento IS NOT NULL
                                AND ues.ues_fecha_vencimiento >= CAST([dbo].[FNC_AHORA]() AS DATE)
                                AND DATEDIFF(DAY, CAST([dbo].[FNC_AHORA]() AS DATE), ues.ues_fecha_vencimiento) <= '
                                + LTRIM(STR(@DIAS_AVISO)) + ' '
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @FILTRO = REPLACE(@FILTRO, '''', '''''')
        SET @WHERE = @WHERE + ' AND (esp.esp_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR ues.ues_certificacion LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR u.usu_nombre LIKE ''%' + LTRIM(@FILTRO) + '%''
                                  OR u.usu_apellido_paterno LIKE ''%' + LTRIM(@FILTRO) + '%''
                                ) '
    END

    SET @WHERE = @WHERE + ' ORDER BY esp.esp_nombre '
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)
GO

-- ---------- SEL_USUARIO_PERMISOS (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_USUARIO_PERMISOS (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   2. EL PROCEDIMIENTO

      Misma regla, en conjunto. Se separan los permisos que vienen de
      plataforma de los que vienen del cliente, porque la autorizacion de
      planta solo alcanza a los segundos.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_PERMISOS]
    @USUARIO     INT,
    @CLIENTE     INT = NULL,
    @INSTALACION INT = NULL
AS
SET NOCOUNT ON

    DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

    -- Root ve todo. Se resuelve aqui y no en el codigo.
    IF EXISTS (SELECT 1 FROM [dbo].[Usuario_Perfil] WHERE upe_usuario = @USUARIO AND upe_perfil = 1)
    BEGIN
        SELECT prm_codigo FROM [dbo].[Permiso] WHERE prm_habilitado = 1
        RETURN
    END

    /* ---- Lo que entrega el perfil de PLATAFORMA ----
       Solo per_tipo = 1. Los de tipo Cliente que hay en Usuario_Perfil son
       el espejo del bloque 49: una copia para las pantallas heredadas, no
       una fuente de permisos. Contarlos hacia que el perfil de alguien en su
       empresa lo siguiera a cualquier otra -34 permisos en un cliente ajeno,
       medido antes de este bloque-. */
    DECLARE @POR_PLATAFORMA TABLE (permiso INT PRIMARY KEY)

    INSERT INTO @POR_PLATAFORMA (permiso)
    SELECT DISTINCT ppe.ppe_permiso
    FROM   [dbo].[Usuario_Perfil] up
    JOIN   [dbo].[Perfiles]       per ON per.per_id = up.upe_perfil
                                     AND per.per_tipo = 1
                                     AND per.per_habilitado = 1
    JOIN   [dbo].[Perfil_Permiso] ppe ON ppe.ppe_perfil = up.upe_perfil
    WHERE  up.upe_usuario = @USUARIO

    /* ---- Lo que entrega el perfil DENTRO del cliente ---- */
    DECLARE @POR_CLIENTE TABLE (permiso INT PRIMARY KEY)

    IF @CLIENTE IS NOT NULL
        INSERT INTO @POR_CLIENTE (permiso)
        SELECT DISTINCT ppe.ppe_permiso
        FROM   [dbo].[Cliente_Usuario_Perfil] cup
        JOIN   [dbo].[Cliente_Usuario]        ucl ON ucl.ucl_id = cup.cup_id_cliente_usuario
        JOIN   [dbo].[Perfiles]               per ON per.per_id = cup.cup_id_perfil
                                                 AND per.per_habilitado = 1
        JOIN   [dbo].[Perfil_Permiso]         ppe ON ppe.ppe_perfil = cup.cup_id_perfil
        WHERE  ucl.ucl_id_usuario = @USUARIO
          AND  ucl.ucl_id_cliente = @CLIENTE
          AND  ISNULL(ucl.ucl_habilitado, 0) = 1

    -- La regla puntual del usuario: la de la planta gana sobre la global
    DECLARE @PUNTUAL TABLE (permiso INT PRIMARY KEY, otorgado BIT)

    IF @CLIENTE IS NOT NULL
        INSERT INTO @PUNTUAL (permiso, otorgado)
        SELECT x.cpm_permiso, x.cpm_otorgado
        FROM (
            SELECT cpm.cpm_permiso, cpm.cpm_otorgado,
                   ROW_NUMBER() OVER (PARTITION BY cpm.cpm_permiso
                                      ORDER BY CASE WHEN cpm.cpm_cliente_instalacion IS NULL THEN 1 ELSE 0 END) rn
            FROM   [dbo].[Cliente_Usuario_Permiso] cpm
            JOIN   [dbo].[Cliente_Usuario]         ucl ON ucl.ucl_id = cpm.cpm_cliente_usuario
            WHERE  ucl.ucl_id_usuario = @USUARIO
              AND  ucl.ucl_id_cliente = @CLIENTE
              AND  ISNULL(ucl.ucl_habilitado,0) = 1
              AND  cpm.cpm_habilitado = 1
              AND  cpm.cpm_instalacion_area IS NULL
              AND  (cpm.cpm_cliente_instalacion IS NULL OR cpm.cpm_cliente_instalacion = @INSTALACION)
              AND  (cpm.cpm_fecha_inicio IS NULL OR cpm.cpm_fecha_inicio <= @HOY)
              AND  (cpm.cpm_fecha_fin    IS NULL OR cpm.cpm_fecha_fin    >= @HOY)
        ) x
        WHERE x.rn = 1

    /* Sin autorizacion vigente en la planta, lo del cliente no vale. Es el
       paso 4 de la funcion, que aqui faltaba. Hoy no cambia nada porque
       todos los llamadores pasan @INSTALACION en NULL; el dia que la app
       pase la planta, las dos implementaciones diran lo mismo. */
    DECLARE @PLANTA_OK BIT = 1

    IF @INSTALACION IS NOT NULL
       AND NOT EXISTS (SELECT 1
                         FROM [dbo].[Cliente_Instalacion_Usuario] ciu
                        WHERE ciu.ciu_id_usuario     = @USUARIO
                          AND ciu.ciu_id_instalacion = @INSTALACION
                          AND ciu.ciu_habilitado     = 1
                          AND (ciu.ciu_fecha_inicio IS NULL OR ciu.ciu_fecha_inicio <= @HOY)
                          AND (ciu.ciu_fecha_fin    IS NULL OR ciu.ciu_fecha_fin    >= @HOY))
        SET @PLANTA_OK = 0

    SELECT DISTINCT p.prm_codigo
    FROM   [dbo].[Permiso] p
    WHERE  p.prm_habilitado = 1
      AND  (
              -- lo de plataforma no depende de planta ni de regla puntual
              EXISTS (SELECT 1 FROM @POR_PLATAFORMA pl WHERE pl.permiso = p.prm_id)

              OR ( @PLANTA_OK = 1
                   AND (
                          EXISTS (SELECT 1 FROM @PUNTUAL q WHERE q.permiso = p.prm_id AND q.otorgado = 1)
                          OR ( EXISTS (SELECT 1 FROM @POR_CLIENTE r WHERE r.permiso = p.prm_id)
                               AND NOT EXISTS (SELECT 1 FROM @PUNTUAL q WHERE q.permiso = p.prm_id AND q.otorgado = 0) )
                       ) )
           )
GO

-- ---------- SEL_USUARIO_RECUPERACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- SEL_USUARIO_RECUPERACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   6. SEL_USUARIO_RECUPERACION                                      HU-004

      Responde si el enlace sirve, sin consumirlo: la pantalla que pide la
      contrasena nueva necesita saberlo ANTES de mostrar el formulario.

      ESTADO:  VIGENTE / USADO / VENCIDO / INVALIDO
      El escenario 3 distingue vencido de invalido, por eso no se colapsan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_RECUPERACION]
@TOKEN VARCHAR(200)

AS
SET NOCOUNT ON

SELECT  TOP 1
        ure.ure_id                                          AS URE_ID
       ,ure.ure_usuario                                     AS URE_USUARIO
       ,u.usu_correo                                        AS USU_CORREO
       ,ure.ure_fecha_expiracion                            AS URE_FECHA_EXPIRACION
       ,CASE WHEN ure.ure_fecha_uso IS NOT NULL          THEN 'USADO'
             WHEN ure.ure_fecha_expiracion <= [dbo].[FNC_AHORA]()  THEN 'VENCIDO'
             ELSE 'VIGENTE' END                            AS ESTADO
FROM    [dbo].[Usuario_Recuperacion] ure
INNER JOIN [dbo].[Usuario] u ON u.usu_id = ure.ure_usuario
WHERE   ure.ure_token_hash = HASHBYTES('SHA2_256', @TOKEN)

/* Sin filas: el token no existe. Se devuelve una fila sintetica para que el
   C# tenga siempre la misma forma de respuesta que leer. */
IF @@ROWCOUNT = 0
    SELECT 0 AS URE_ID, 0 AS URE_USUARIO, CAST(NULL AS VARCHAR(200)) AS USU_CORREO,
           CAST(NULL AS DATETIME) AS URE_FECHA_EXPIRACION, 'INVALIDO' AS ESTADO

RETURN(0)
GO

-- ---------- UPD_ALERTA_LEER (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_ALERTA_LEER (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_ALERTA_LEER]
    @CLIENTE INT,
    @USUARIO INT,
    @ALERTA  INT = NULL
AS
SET NOCOUNT ON

    INSERT INTO [dbo].[Alerta_Lectura] (alr_alerta, alr_usuario, alr_fecha)
    SELECT  a.ale_id, @USUARIO, [dbo].[FNC_AHORA]()
    FROM    [dbo].[Alerta] a
    JOIN    [dbo].[Alerta_Tipo] t   ON t.alt_id = a.ale_alerta_tipo
    JOIN    [dbo].[Alerta_Estado] e ON e.aet_id = a.ale_alerta_estado
    LEFT JOIN [dbo].[Permiso] pm    ON pm.prm_id = t.alt_permiso
    WHERE   a.ale_cliente = @CLIENTE
      AND   a.ale_habilitado = 1
      AND   (@ALERTA IS NULL OR a.ale_id = @ALERTA)
      AND   e.aet_codigo NOT IN ('RESUELTA', 'DESCARTADA')
      AND   (t.alt_permiso IS NULL
             OR [dbo].[FNC_USUARIO_TIENE_PERMISO](@USUARIO, @CLIENTE, NULL, pm.prm_codigo) = 1)
      /* Sin esto el UNIQUE reventaria al marcar dos veces, y marcar dos veces
         es lo normal: se abre el panel, se cierra y se vuelve a abrir. */
      AND   NOT EXISTS (SELECT 1 FROM [dbo].[Alerta_Lectura] l
                         WHERE l.alr_alerta = a.ale_id AND l.alr_usuario = @USUARIO)

    SELECT @@ROWCOUNT AS MARCADAS
GO

-- ---------- UPD_BODEGA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_BODEGA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_BODEGA]
    @ID          INT,
    @CLIENTE     INT,
    @INSTALACION INT = NULL,
    @NOMBRE      NVARCHAR(400) = NULL,
    @DESCRIPCION NVARCHAR(1000) = NULL,
    @HABILITADO  BIT = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

    /* El CODIGO no viaja: no se edita. Es con lo que se identifica la
       bodega en cualquier carga de datos, y renombrarlo desde un formulario
       rompe en silencio lo que lo referencie. */

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @ID AND bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA BODEGA NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF (@INSTALACION IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente_Instalacion]
                         WHERE cin_id = @INSTALACION AND cin_cliente = @CLIENTE))
    BEGIN
        RAISERROR('2.- LA PLANTA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    /* Deshabilitar una bodega con saldo esconderia existencia real: el
       repuesto sigue en la estanteria y deja de verse en las consultas. */
    IF (@HABILITADO = 0
        AND EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                     WHERE isa_bodega = @ID AND isa_cantidad > 0))
    BEGIN
        DECLARE @MSG_BOD NVARCHAR(400) =
            '3.- NO SE PUEDE DESHABILITAR UNA BODEGA CON EXISTENCIA. '
          + 'TRASLADE O AJUSTE SUS REPUESTOS PRIMERO.'
        RAISERROR(@MSG_BOD, 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    -- ISNULL en todo lo opcional: lo que no viaja no se borra (bloque 51).
    UPDATE  [dbo].[Bodega]
    SET     bod_cliente_instalacion    = ISNULL(@INSTALACION, bod_cliente_instalacion)
           ,bod_nombre                 = ISNULL(@NOMBRE,      bod_nombre)
           ,bod_descripcion            = ISNULL(@DESCRIPCION, bod_descripcion)
           ,bod_habilitado             = ISNULL(@HABILITADO,  bod_habilitado)
           ,bod_usuario_actualizacion  = @USUARIO
           ,bod_fecha_actualizacion    = [dbo].[FNC_AHORA]()
    WHERE   bod_id = @ID

COMMIT TRANSACTION
RETURN 0
GO

-- ---------- UPD_BODEGA_UBICACION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_BODEGA_UBICACION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_BODEGA_UBICACION]
    @ID         INT,
    @CLIENTE    INT,
    @NOMBRE     NVARCHAR(400) = NULL,
    @HABILITADO BIT = NULL,
    @USUARIO    INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega_Ubicacion] u
                    JOIN [dbo].[Bodega] b ON b.bod_id = u.bub_bodega
                   WHERE u.bub_id = @ID AND b.bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- LA UBICACION NO EXISTE.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Bodega_Ubicacion]
    SET     bub_nombre                = ISNULL(@NOMBRE,     bub_nombre)
           ,bub_habilitado            = ISNULL(@HABILITADO, bub_habilitado)
           ,bub_usuario_actualizacion = @USUARIO
           ,bub_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   bub_id = @ID

COMMIT TRANSACTION
RETURN 0
GO

-- ---------- UPD_CATALOGO_VALOR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_CATALOGO_VALOR (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   6. UPD_CATALOGO_VALOR                                            HU-021

      Solo toca valores PROPIOS del cliente. Los del sistema son de solo
      lectura (HU-020 escenario 1: "no puedo modificar ni eliminar sus
      valores"), y esa regla se hace cumplir aqui y no solo escondiendo un
      boton en la pantalla.

      Deshabilitar y no borrar es lo que pide el escenario 3: "el valor deja
      de ofrecerse pero los registros existentes lo conservan". Un DELETE
      dejaria esos registros sin poder resolver su propio valor.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CATALOGO_VALOR]
@CATALOGO     INT,
@VALOR_ID     INT,
@CLIENTE      INT,
@NOMBRE       NVARCHAR(400) = NULL,
@DESCRIPCION  NVARCHAR(1000) = NULL,
@ORDEN        INT = NULL,
@HABILITADO   BIT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @TABLA NVARCHAR(128), @PFX NVARCHAR(10), @AMPLIABLE BIT
DECLARE @OBJETO INT, @SQL NVARCHAR(MAX), @SETS NVARCHAR(MAX) = '', @DUENO INT

SELECT  @TABLA = ctl_tabla, @PFX = ctl_prefijo, @AMPLIABLE = ctl_ampliable
FROM    [dbo].[Catalogo] WHERE ctl_id = @CATALOGO

BEGIN
    IF @TABLA IS NULL
    BEGIN
        RAISERROR('1.- EL CATÁLOGO NO ESTÁ REGISTRADO.', 16, 1)
        RETURN -1
    END

    IF @AMPLIABLE = 0
    BEGIN
        RAISERROR('2.- ESTE CATÁLOGO ES DE SÓLO LECTURA.', 16, 1)
        RETURN -1
    END

    SET @OBJETO = OBJECT_ID(N'[dbo].' + QUOTENAME(@TABLA))
    IF @OBJETO IS NULL
    BEGIN
        RAISERROR('3.- LA TABLA DEL CATÁLOGO NO EXISTE EN LA BASE.', 16, 1)
        RETURN -1
    END

    -- De quien es el valor
    SET @SQL = N'SELECT @P_OUT = ' + QUOTENAME(@PFX + '_cliente') +
               N' FROM [dbo].' + QUOTENAME(@TABLA) +
               N' WHERE ' + QUOTENAME(@PFX + '_id') + N' = @P_VALOR'

    EXEC sp_executesql @SQL, N'@P_VALOR INT, @P_OUT INT OUTPUT',
         @P_VALOR = @VALOR_ID, @P_OUT = @DUENO OUTPUT

    IF @DUENO IS NULL
    BEGIN
        RAISERROR('4.- ES UN VALOR DEL SISTEMA Y NO PUEDE MODIFICARSE.', 16, 1)
        RETURN -1
    END

    IF @DUENO <> @CLIENTE
    BEGIN
        RAISERROR('5.- ESE VALOR PERTENECE A OTRO CLIENTE.', 16, 1)
        RETURN -1
    END
END

SET @SETS = QUOTENAME(@PFX + '_nombre') + N' = ISNULL(@P_NOMBRE, ' + QUOTENAME(@PFX + '_nombre') + N')'
SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_habilitado') + N' = ISNULL(@P_HABILITADO, ' + QUOTENAME(@PFX + '_habilitado') + N')'

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_descripcion')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_descripcion') + N' = @P_DESCRIPCION'

/* El orden va con ISNULL y no por asignacion directa. Todos los parametros
   de este SP son opcionales, asi que una llamada que solo cambie el nombre
   dejaria el orden en NULL y el valor se iria al principio de todas las
   listas donde aparece. La descripcion si va directa: es un campo que el
   usuario tiene derecho a dejar en blanco (PATRON_SP §5). */
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_orden')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_orden') + N' = ISNULL(@P_ORDEN, ' + QUOTENAME(@PFX + '_orden') + N')'

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_usuario_actualizacion')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_usuario_actualizacion') + N' = @P_USUARIO'

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @OBJETO AND name = @PFX + '_fecha_actualizacion')
    SET @SETS = @SETS + N',' + QUOTENAME(@PFX + '_fecha_actualizacion') + N' = [dbo].[FNC_AHORA]()'

SET @SQL = N'UPDATE [dbo].' + QUOTENAME(@TABLA) + N' SET ' + @SETS +
           N' WHERE ' + QUOTENAME(@PFX + '_id') + N' = @P_VALOR'

BEGIN TRANSACTION

    EXEC sp_executesql @SQL,
         N'@P_NOMBRE NVARCHAR(400), @P_DESCRIPCION NVARCHAR(1000), @P_ORDEN INT,
           @P_HABILITADO BIT, @P_USUARIO INT, @P_VALOR INT',
         @P_NOMBRE = @NOMBRE, @P_DESCRIPCION = @DESCRIPCION, @P_ORDEN = @ORDEN,
         @P_HABILITADO = @HABILITADO, @P_USUARIO = @USUARIO, @P_VALOR = @VALOR_ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CATALOGO_VALOR @CATALOGO = ' + LTRIM(STR(@CATALOGO)) +
                                          ',@VALOR_ID = ' + LTRIM(STR(@VALOR_ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '6.- NO FUE POSIBLE ACTUALIZAR EL VALOR DEL CATÁLOGO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_CLIENTE_USUARIO_PERMISO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_CLIENTE_USUARIO_PERMISO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   13. UPD_CLIENTE_USUARIO_PERMISO                                  HU-007

       Revocar es baja LOGICA, no borrado: el escenario 2 pide que la
       revocacion quede registrada, y una fila borrada no registra nada.
       Al quedar cpm_habilitado = 0 la funcion deja de verla y la persona
       vuelve a lo que dice su perfil, que es justo lo pedido.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_CLIENTE_USUARIO_PERMISO]
@ID            INT,
@OTORGADO      BIT = NULL,
@FECHA_INICIO  DATE = NULL,
@FECHA_FIN     DATE = NULL,
@MOTIVO        NVARCHAR(500) = NULL,
@HABILITADO    BIT = NULL,
@USUARIO       INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Cliente_Usuario_Permiso]
    SET     cpm_otorgado     = ISNULL(@OTORGADO, cpm_otorgado)
           ,cpm_fecha_inicio = @FECHA_INICIO
           ,cpm_fecha_fin    = @FECHA_FIN
           ,cpm_motivo       = ISNULL(@MOTIVO, cpm_motivo)
           ,cpm_habilitado   = ISNULL(@HABILITADO, cpm_habilitado)
           ,cpm_usuario_actualizacion = @USUARIO
           ,cpm_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   cpm_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_CLIENTE_USUARIO_PERMISO @ID = ' + LTRIM(STR(@ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL PERMISO DEL USUARIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_MODULOS_SISTEMA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_MODULOS_SISTEMA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:		BRYAN CHAVEZ
-- Fecha creación: 02-06-2026
-- Description: Actualiza un módulo del sistema
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_MODULOS_SISTEMA]
    @ID         INT,
    @NOMBRE     VARCHAR(200),
    @HABILITADO BIT,
    @USUARIO    INT
AS
SET NOCOUNT ON

IF EXISTS (SELECT 1 FROM MODULOS_SISTEMA WHERE mds_nombre = @NOMBRE AND mds_id <> @ID)
BEGIN
    RAISERROR('1.- Ya existe otro módulo con ese nombre.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE MODULOS_SISTEMA
    SET    mds_nombre      = @NOMBRE,
           mds_habilitado  = @HABILITADO,
           mds_usuario_act = @USUARIO,
           mds_fecha_act   = [dbo].[FNC_AHORA]()
    WHERE  mds_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_MODULOS_SISTEMA ' + STR(@ID) + ',' + ISNULL(@NOMBRE, '') + ',' + STR(@USUARIO)
        EXEC INS_EXCEPCION
            @MSG       = '1.- NO FUE POSIBLE ACTUALIZAR EL MÓDULO DEL SISTEMA.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- UPD_ORDEN_TRABAJO_CERRAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_ORDEN_TRABAJO_CERRAR (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   UPD_ORDEN_TRABAJO_CERRAR
      Lo que hace el planificador, el supervisor o el jefe. Nadie mas.
      Ahora idempotente por uuid, para poder encolarse desde el telefono.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_CERRAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @CIERRE_MOTIVO  INT,
    @OBSERVACION    NVARCHAR(500) = NULL,
    /* Nace en el telefono AL ENCOLAR. Opcional: la web no lo manda. */
    @UUID           UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON

    /* ---- Idempotencia: si el uuid ya cerro una OT, se responde lo mismo ----
       Va ANTES de toda validacion. Sin esto, el reintento de un cierre que ya
       entro respondia "La OT no esta en espera de cierre" -porque este mismo
       uuid la dejo en 4-, y la cola marcaba rechazado un cierre correcto. */
    IF (@UUID IS NOT NULL)
    BEGIN
        DECLARE @YA INT = NULL

        SELECT @YA = [otr_id] FROM [dbo].[Orden_Trabajo]
         WHERE [otr_cierre_uuid] = @UUID

        IF (@YA IS NOT NULL)
        BEGIN
            SELECT @YA AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
            RETURN
        END
    END

    DECLARE @CLIENTE INT
    SELECT @CLIENTE = otr_cliente FROM [dbo].[Orden_Trabajo] WHERE otr_id = @ORDEN_TRABAJO

    IF @CLIENTE IS NULL
    BEGIN
        RAISERROR('La orden de trabajo no existe.', 16, 1)
        RETURN
    END

    -- La regla de jerarquia. El tecnico finaliza; cerrar es de otros.
    IF [dbo].[FNC_USUARIO_PUEDE_CERRAR_OT](@CLIENTE, @USUARIO) = 0
    BEGIN
        RAISERROR('Este usuario no puede cerrar ordenes de trabajo. El cierre es del planificador, el supervisor o el jefe de mantenimiento.', 16, 1)
        RETURN
    END

    /* El texto NO dice "no existe" a proposito: `ErrorSql` traduce a 404 todo
       mensaje que contenga esa frase, y un 404 sobre /ordenes-trabajo/{id}/cerrar
       le dice a la app que la ORDEN no existe cuando lo que no sirve es un campo
       del cuerpo. Redactado asi cae en el 400 que le corresponde a un valor
       invalido. Arreglarlo en ErrorSql habria cambiado el codigo de los ~150 SP
       que comparten ese traductor. */
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Cierre_Motivo] WHERE ocm_id = @CIERRE_MOTIVO AND ocm_habilitado = 1)
    BEGIN
        RAISERROR('El motivo de cierre no es valido o fue deshabilitado.', 16, 1)
        RETURN
    END

    -- Un permiso de trabajo exigido y no autorizado bloquea el cierre.
    -- Cerrar una OT cuyo permiso nunca se firmo es documentar una mentira.
    IF EXISTS (SELECT 1 FROM [dbo].[Permiso_Trabajo]
                WHERE ptr_orden_trabajo = @ORDEN_TRABAJO
                  AND ptr_permiso_trabajo_estado NOT IN (2, 5))   -- AUTORIZADO o CERRADO
    BEGIN
        RAISERROR('Hay permisos de trabajo sin autorizar. No se puede cerrar la OT.', 16, 1)
        RETURN
    END

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 4,      -- CERRADA
           otr_cierre_motivo         = @CIERRE_MOTIVO,
           otr_usuario_cierre        = @USUARIO,
           otr_fecha_cierre          = [dbo].[FNC_AHORA](),
           otr_cierre_uuid           = @UUID,
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = [dbo].[FNC_AHORA]()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado = 3        -- solo desde EN ESPERA DE CIERRE

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La OT no esta en espera de cierre. El tecnico tiene que finalizarla primero.', 16, 1)
        RETURN
    END

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_estado_nuevo], [oeh_motivo], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 4, @OBSERVACION, @USUARIO)

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 4 AS ESTADO, N'CERRADA' AS ESTADO_NOMBRE
END
GO

-- ---------- UPD_ORDEN_TRABAJO_FINALIZAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_ORDEN_TRABAJO_FINALIZAR (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  14-09-2026
-- DESCRIPTION:     FINALIZAR UNA OT DESDE EL TELEFONO CON LAS REGLAS DE
--                  HU-119 EN EL SP, NO EN LA PANTALLA.
-- =============================================
-- LO QUE HABIA
--   UPD_ORDEN_TRABAJO_FINALIZAR (bloque 10) solo cambiaba el estado 1/2 -> 3
--   y dejaba historial. La app impedia finalizar con obligatorios pendientes
--   desde el boton, pero el endpoint dejaba pasar: probado el 14-09-2026, una
--   OT con dos pasos obligatorios PENDIENTES quedo EN ESPERA DE CIERRE por
--   HTTP. Una regla que solo vive en Dart no es una regla.
--
-- LO QUE HACE AHORA
--   · HU-119 #2: si hay pasos obligatorios sin resolver, rechaza y DICE
--     CUALES (los nombres, hasta 400 caracteres). La app puede seguir
--     apagando el boton; el servidor es el que decide.
--   · HU-119 #1: guarda otr_resultado (lo que el tecnico escribio) y
--     otr_fecha_fin_real_utc; el estado pasa a 3 y ya no se modifica
--     (los pasos ya lo exigen: «tomala antes de completar pasos»).
--   · HU-119 #3: sin ningun tramo de mano de obra se PERMITE finalizar y
--     vuelve ADVERTENCIA en el result set; la API la devuelve y la app la
--     muestra. La advertencia queda ademas en el historial de estado.
--   · Misma firma que antes (@ORDEN_TRABAJO, @USUARIO, @OBSERVACION): la
--     API no cambia de llamada, solo lee la advertencia.
-- =============================================

CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_FINALIZAR]
    @ORDEN_TRABAJO  INT,
    @USUARIO        INT,
    @OBSERVACION    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @FALTAN NVARCHAR(400) = NULL, @ADVERTENCIA NVARCHAR(400) = NULL

    -- HU-119 #2: los obligatorios pendientes (resultado 4 PENDIENTE) impiden finalizar, y se nombran.
    SELECT @FALTAN = STUFF((
        SELECT N', ' + p.otp_nombre
          FROM [dbo].[Orden_Trabajo_Paso] p
         WHERE p.otp_orden_trabajo = @ORDEN_TRABAJO
           AND p.otp_habilitado = 1
           AND p.otp_obligatorio = 1
           AND p.otp_resultado_paso = 4
         ORDER BY p.otp_orden
           FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'')

    IF @FALTAN IS NOT NULL
    BEGIN
        RAISERROR('Faltan pasos obligatorios por resolver: %s', 16, 1, @FALTAN)
        RETURN
    END

    UPDATE [dbo].[Orden_Trabajo]
       SET otr_orden_trabajo_estado  = 3,      -- EN ESPERA DE CIERRE
           otr_resultado             = ISNULL(NULLIF(LTRIM(RTRIM(@OBSERVACION)), N''), otr_resultado),
           otr_fecha_fin_real_utc    = ISNULL(otr_fecha_fin_real_utc, GETUTCDATE()),
           otr_usuario_actualizacion = @USUARIO,
           otr_fecha_actualizacion   = [dbo].[FNC_AHORA]()
     WHERE otr_id = @ORDEN_TRABAJO
       AND otr_orden_trabajo_estado IN (1, 2)  -- ABIERTA o EN EJECUCION

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La orden de trabajo no esta abierta ni en ejecucion. Alguien mas la movio.', 16, 1)
        RETURN
    END

    -- HU-119 #3: sin mano de obra se advierte y se deja continuar.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Orden_Trabajo_Mano_Obra] WHERE omo_orden_trabajo = @ORDEN_TRABAJO)
        SET @ADVERTENCIA = N'Finalizada sin ningún bloque de mano de obra: no habrá duración real ni carga por persona.'

    INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
        ([oeh_orden_trabajo], [oeh_estado_nuevo], [oeh_motivo], [oeh_usuario_creacion])
    VALUES (@ORDEN_TRABAJO, 3, LEFT(ISNULL(@OBSERVACION, N'') + ISNULL(N' · ' + @ADVERTENCIA, N''), 500), @USUARIO)

    SELECT @ORDEN_TRABAJO AS ORDEN_TRABAJO, 3 AS ESTADO, N'EN ESPERA DE CIERRE' AS ESTADO_NOMBRE, @ADVERTENCIA AS ADVERTENCIA
END
GO

-- ---------- UPD_ORDEN_TRABAJO_TOMAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_ORDEN_TRABAJO_TOMAR (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     ORDENES DE TRABAJO PARA LA APP MOVIL.
--                  HU-121 (bandeja), HU-113 (tomar), HU-114 (ejecutar
--                  pasos) y HU-119 (finalizar) del Sprint 5.
-- =============================================
-- POR QUE ESTE BLOQUE
--
--   El modelo de ordenes ya estaba completo: Orden_Trabajo con sus quince
--   tablas satelite. Lo que faltaba eran los procedimientos: de los cinco que
--   existian, tres eran de cierre y ninguno sabia LISTAR.
--
--   Sin un SELECT no hay bandeja, y sin bandeja la app no tiene por donde
--   empezar el turno.
--
-- DOS DEFECTOS CORREGIDOS EN UPD_ORDEN_TRABAJO_TOMAR
--
--   (1) La transicion estaba al reves. El catalogo es
--       1 ABIERTA, 2 EN EJECUCION, 3 EN ESPERA DE CIERRE, 4 CERRADA,
--       y el SP hacia 2 -> 3 con el comentario "-- EN EJECUCION" sobre el 3.
--       O sea: tomar una orden ABIERTA no hacia nada (0 filas, y el RAISERROR
--       decia "ya fue tomada por otro"), y una orden ya en ejecucion saltaba
--       a espera de cierre SIN QUE NADIE HICIERA EL TRABAJO.
--       Lo correcto es 1 -> 2, y asi queda.
--
--       Se comprueba contra UPD_ORDEN_TRABAJO_FINALIZAR, que si estaba bien:
--       ese va de IN (1,2) a 3 "EN ESPERA DE CIERRE".
--
--   (2) ota_rol_ejecucion es un INT con FK a Rol_Ejecucion, y el SP insertaba
--       N'EJECUTOR'. Conversion imposible. El valor correcto es 1
--       (EJECUTOR PRINCIPAL).
--
--   Con los dos defectos, este SP nunca pudo ejecutarse con exito.
--
-- LA SEGURIDAD VA ADENTRO
--
--   Igual que en el bloque 140: cliente y plantas autorizadas se resuelven en
--   el propio SP contra Cliente_Instalacion_Usuario. Un filtro en el
--   controller se salta cambiando un parametro; uno aca, no.
--
-- ORDER BY EXPLICITO
--
--   SQLite no conserva el orden de insercion. El orden se define donde se
--   define el dato.
-- =============================================


-- ---------------------------------------------------------------------------
-- 1 - CORRECCION: tomar una orden es pasar de ABIERTA a EN EJECUCION
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[UPD_ORDEN_TRABAJO_TOMAR]
     @OTR_ID   INT
    ,@USUARIO  INT
AS
SET NOCOUNT ON

BEGIN

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @ESTADO_ANTERIOR INT

        SELECT @ESTADO_ANTERIOR = [otr_orden_trabajo_estado]
          FROM [dbo].[Orden_Trabajo]
         WHERE [otr_id] = @OTR_ID

        IF @ESTADO_ANTERIOR IS NULL
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden de trabajo no existe.', 16, 1)
            RETURN
        END

        /* La carrera se decide en el WHERE: dos tecnicos que tocan "Tomar" al
           mismo tiempo llegan los dos aca, y solo uno encuentra la fila en
           estado 1. El otro recibe el mensaje, no un duplicado. */
        UPDATE [dbo].[Orden_Trabajo]
           SET [otr_orden_trabajo_estado]  = 2                   -- EN EJECUCION
              ,[otr_usuario_responsable]   = @USUARIO
              ,[otr_fecha_inicio_real_utc] = ISNULL([otr_fecha_inicio_real_utc], GETUTCDATE())
              ,[otr_usuario_actualizacion] = @USUARIO
              ,[otr_fecha_actualizacion]   = [dbo].[FNC_AHORA]()
         WHERE [otr_id]                   = @OTR_ID
           AND [otr_orden_trabajo_estado] = 1                    -- ABIERTA
           AND [otr_habilitado]           = 1

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La orden ya fue tomada por otro usuario o no esta abierta.', 16, 1)
            RETURN
        END

        /* El que la tomo queda como responsable. Puede sumar a otros despues.
           El rol es 1 = EJECUTOR PRINCIPAL, del catalogo Rol_Ejecucion. */
        IF NOT EXISTS (SELECT 1
                         FROM [dbo].[Orden_Trabajo_Asignacion]
                        WHERE [ota_orden_trabajo]  = @OTR_ID
                          AND [ota_es_responsable] = 1
                          AND [ota_habilitado]     = 1)
            INSERT INTO [dbo].[Orden_Trabajo_Asignacion]
                ([ota_orden_trabajo], [ota_usuario], [ota_es_responsable]
                ,[ota_rol_ejecucion], [ota_fecha_asignacion_utc]
                ,[ota_fecha_aceptacion_utc], [ota_usuario_creacion], [ota_asignado_por])
            VALUES
                (@OTR_ID, @USUARIO, 1, 1, GETUTCDATE(), GETUTCDATE(), @USUARIO, @USUARIO)

        INSERT INTO [dbo].[Orden_Trabajo_Estado_Historial]
            ([oeh_orden_trabajo], [oeh_estado_anterior], [oeh_estado_nuevo]
            ,[oeh_motivo], [oeh_usuario_creacion])
        VALUES
            (@OTR_ID, @ESTADO_ANTERIOR, 2, N'Tomada por el ejecutante', @USUARIO)

        COMMIT TRANSACTION
        SELECT @OTR_ID AS [otr_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH

END
GO

-- ---------- UPD_PAISES (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_PAISES (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- Author:			Diego Castillo
-- Fecha creación:	15-03-2023
-- Description:		Actualiza PAISES
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_PAISES]
@ID INT,
@NOMBRE VARCHAR(200),
@SUMA_RESTA VARCHAR(1),
@HORA VARCHAR(200),
@HABILITADO BIT,
@USUARIO INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

	UPDATE	PAISES
	SET		PAI_NOMBRE = @NOMBRE,
			PAI_SUMA_RESTA = @SUMA_RESTA,
			PAI_HORA = @HORA,
			PAI_HABILITADO = @HABILITADO,
			PAI_USUARIO_ACTUALIZACION = @HABILITADO,
			PAI_FECHA_ACTUALIZACION = [dbo].[FNC_AHORA]()

	WHERE	PAI_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'UPD_PAISES ' + LTRIM(STR(@ID)) + ',' + @NOMBRE 
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Actualizar el PAISES.',
			@VARIABLES = @VARIABLES
		RETURN -1 
	END

	

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_PERFIL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_PERFIL (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   3. UPD_PERFIL                                                    HU-015
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_PERFIL]
@ID               INT,
@NOMBRE           VARCHAR(200),
@TIPO             INT,
@DESCRIPCION      VARCHAR(8000) = NULL,
@CLIENTE          INT = NULL,
@SOLO_EJECUCION   BIT = NULL,
@HABILITADO       BIT,
@USUARIO          INT

AS
SET NOCOUNT ON

BEGIN
    IF EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                WHERE per_nombre = @NOMBRE
                  AND ISNULL(per_cliente, 0) = ISNULL(@CLIENTE, 0)
                  AND per_id <> @ID)
    BEGIN
        RAISERROR('1.- El perfil con el nombre "%s" ya existe.', 16, 1, @NOMBRE)
        RETURN -1
    END

    /* Marcar un perfil como "solo ejecucion" cuando ya tiene el permiso de
       cerrar OT dejaria un estado contradictorio: la bandera diria que no
       puede y Perfil_Permiso diria que si. Se obliga a quitar el permiso
       primero, para que el cambio sea explicito y quede a la vista. */
    IF @SOLO_EJECUCION = 1
       AND EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                   INNER JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
                   WHERE pp.ppe_perfil = @ID AND p.prm_codigo = N'CERRAR OT')
    BEGIN
        RAISERROR('2.- ESTE PERFIL TIENE EL PERMISO DE CERRAR ÓRDENES. QUÍTESELO ANTES DE MARCARLO COMO SÓLO EJECUCIÓN.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Perfiles]
    SET     per_nombre         = @NOMBRE,
            per_tipo           = @TIPO,
            per_descripcion    = @DESCRIPCION,
            per_cliente        = @CLIENTE,
            per_solo_ejecucion = ISNULL(@SOLO_EJECUCION, per_solo_ejecucion),
            per_habilitado     = @HABILITADO,
            per_usuario_act    = @USUARIO,
            per_fecha_act      = [dbo].[FNC_AHORA]()
    WHERE   per_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_PERFIL ' + LTRIM(STR(@ID)) + ',' + ISNULL(@NOMBRE, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '3.- NO FUE POSIBLE ACTUALIZAR EL PERFIL.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_PLAN_COMERCIAL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_PLAN_COMERCIAL (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   2. UPD_PLAN_COMERCIAL

      El CODIGO no se edita. Es la llave con la que los scripts de datos y
      cualquier integracion futura identifican al plan; renombrarlo desde un
      formulario romperia silenciosamente lo que lo referencie por codigo.
      Para eso esta el nombre, que si se edita y es lo que se muestra.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_COMERCIAL]
@ID           INT,
@NOMBRE       NVARCHAR(100),
@DESCRIPCION  NVARCHAR(500) = NULL,
@ORDEN        INT = NULL,
@DIAS_GRACIA  INT = NULL,
@PUBLICO      BIT = NULL,
@HABILITADO   BIT = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @ID)
    BEGIN
        RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @ORDEN IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_orden = @ORDEN AND plc_id <> @ID)
    BEGIN
        RAISERROR('2.- YA HAY OTRO PLAN CON EL ORDEN %d. EL ORDEN DEBE SER ÚNICO.', 16, 1, @ORDEN)
        RETURN -1
    END

    /* Deshabilitar un plan que alguien esta usando deja a ese cliente con
       una suscripcion apuntando a un plan que ya no se vende. No se
       prohibe -es exactamente lo que se hace al retirar un plan del
       catalogo- pero avisar en silencio no sirve: se rechaza y quien
       quiera retirarlo tiene que migrar antes a esos clientes. */
    IF @HABILITADO = 0
       AND EXISTS (SELECT 1 FROM [dbo].[Suscripcion]
                    WHERE sus_plan_comercial = @ID AND sus_habilitado = 1)
    BEGIN
        RAISERROR('3.- HAY SUSCRIPCIONES VIGENTES EN ESTE PLAN. CÁMBIELAS DE PLAN ANTES DE DESHABILITARLO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Plan_Comercial]
    SET     plc_nombre                = @NOMBRE,
            plc_descripcion           = @DESCRIPCION,
            plc_orden                 = ISNULL(@ORDEN, plc_orden),
            plc_dias_gracia           = ISNULL(@DIAS_GRACIA, plc_dias_gracia),
            plc_publico               = ISNULL(@PUBLICO, plc_publico),
            plc_habilitado            = ISNULL(@HABILITADO, plc_habilitado),
            plc_usuario_actualizacion = @USUARIO,
            plc_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   plc_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_PLAN_COMERCIAL @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '4.- NO FUE POSIBLE ACTUALIZAR EL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_PLAN_MANTENIMIENTO_VERSION_PUBLICAR]
    @PMV_ID     INT,
    @USUARIO    INT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @PLAN INT

    SELECT @PLAN = [pmv_plan_mantenimiento]
      FROM [dbo].[Plan_Mantenimiento_Version]
     WHERE [pmv_id] = @PMV_ID

    IF @PLAN IS NULL
    BEGIN
        RAISERROR('La version indicada no existe.', 16, 1)
        RETURN
    END

    -- Un plan sin hitos no se publica: no generaria nada nunca.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Hito]
                    WHERE [pmh_plan_mantenimiento_version] = @PMV_ID AND [pmh_habilitado] = 1)
    BEGIN
        RAISERROR('No se puede publicar una version sin hitos.', 16, 1)
        RETURN
    END

    -- Un plan sin activos tampoco: no habria para que maquina generar.
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Mantenimiento_Activo]
                    WHERE [pac_plan_mantenimiento_version] = @PMV_ID)
    BEGIN
        RAISERROR('No se puede publicar una version sin activos asociados.', 16, 1)
        RETURN
    END

    BEGIN TRY
        BEGIN TRANSACTION

        -- Retira la publicada anterior del mismo plan.
        UPDATE [dbo].[Plan_Mantenimiento_Version]
           SET [pmv_plan_version_estado]  = 3,          -- RETIRADO
               [pmv_fecha_retiro]         = [dbo].[FNC_AHORA](),
               [pmv_usuario_actualizacion]= @USUARIO,
               [pmv_fecha_actualizacion]  = [dbo].[FNC_AHORA]()
         WHERE [pmv_plan_mantenimiento]   = @PLAN
           AND [pmv_plan_version_estado]  = 2
           AND [pmv_id]                  <> @PMV_ID

        UPDATE [dbo].[Plan_Mantenimiento_Version]
           SET [pmv_plan_version_estado]  = 2,          -- PUBLICADO
               [pmv_fecha_publicacion]    = [dbo].[FNC_AHORA](),
               [pmv_usuario_publicacion]  = @USUARIO,
               [pmv_usuario_actualizacion]= @USUARIO,
               [pmv_fecha_actualizacion]  = [dbo].[FNC_AHORA]()
         WHERE [pmv_id]                   = @PMV_ID
           AND [pmv_plan_version_estado]  = 1           -- <- la carrera se decide aqui

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            RAISERROR('La version ya no estaba en BORRADOR. Otro usuario la publico o la retiro.', 16, 1)
            RETURN
        END

        COMMIT TRANSACTION
        SELECT @PMV_ID AS [pmv_id]
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
        DECLARE @MENSAJE NVARCHAR(4000) = ERROR_MESSAGE()
        RAISERROR(@MENSAJE, 16, 1)
    END CATCH
END
GO

-- ---------- UPD_PRIVACIDAD_MODULOS_SISTEMA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_PRIVACIDAD_MODULOS_SISTEMA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
-- =============================================
-- AUTHOR:         BRYAN CHAVEZ
-- FECHA CREACIÓN: 08-06-2026
-- DESCRIPTION:    UPDATE PRIVACIDAD MODULO SISTEMA
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[UPD_PRIVACIDAD_MODULOS_SISTEMA]
    @ID          INT,
    @ID_MODULO   INT           = NULL,
    @DESCRIPCION NVARCHAR(MAX) = NULL,
    @USUARIO     INT
AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE PRIVACIDAD_MODULOS_SISTEMA
    SET    PMS_ID_MODULO   = ISNULL(@ID_MODULO,   PMS_ID_MODULO),
           PMS_DESCRIPCION = ISNULL(@DESCRIPCION, PMS_DESCRIPCION),
           PMS_USUARIO_ACT = @USUARIO,
           PMS_FECHA_ACT   = [dbo].[FNC_AHORA]()
    WHERE  PMS_ID = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES_UPD VARCHAR(MAX)
        SET @VARIABLES_UPD = 'UPD_PRIVACIDAD_MODULOS_SISTEMA ' +
                             '@ID = '      + LTRIM(STR(@ID))      + ', ' +
                             '@USUARIO = ' + LTRIM(STR(@USUARIO))
        EXEC INS_EXCEPCION
            @MSG       = '1.- NO FUE POSIBLE ACTUALIZAR EL REGISTRO DE PRIVACIDAD.',
            @VARIABLES = @VARIABLES_UPD
        RETURN -1
    END

COMMIT TRANSACTION
RETURN(0)
GO

-- ---------- UPD_REPUESTO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_REPUESTO (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ============================ UPD_REPUESTO, con @REPUESTO_TIPO ============ */
CREATE OR ALTER PROCEDURE [dbo].[UPD_REPUESTO]
    @ID               INT,
    @CLIENTE          INT,
    @NOMBRE           NVARCHAR(400) = NULL,
    @UNIDAD_MEDIDA    INT = NULL,
    @FABRICANTE       NVARCHAR(400) = NULL,
    @MODELO           NVARCHAR(400) = NULL,
    @DESCRIPCION      NVARCHAR(1000) = NULL,
    @ES_REPARABLE     BIT = NULL,
    @ES_CONSUMIBLE    BIT = NULL,
    @CONTROLA_LOTE    BIT = NULL,
    @COSTO_REFERENCIA DECIMAL(18,4) = NULL,
    @MONEDA           INT = NULL,
    @VIDA_UTIL_HORA   DECIMAL(18,4) = NULL,
    @VIDA_UTIL_DIA    INT = NULL,
    @VIDA_UTIL_CICLO  DECIMAL(18,4) = NULL,
    @REPUESTO_TIPO    INT = NULL,
    @LIMPIA_VIDA_UTIL BIT = 0,
    @HABILITADO       BIT = NULL,
    @USUARIO          INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @ID AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF (@UNIDAD_MEDIDA IS NOT NULL
        AND @UNIDAD_MEDIDA <> (SELECT rep_unidad_medida FROM [dbo].[Repuesto] WHERE rep_id = @ID)
        AND EXISTS (SELECT 1 FROM [dbo].[Inventario_Saldo]
                     WHERE isa_repuesto = @ID AND isa_cantidad <> 0))
    BEGIN
        DECLARE @MSG_UME NVARCHAR(400) =
            '2.- NO SE PUEDE CAMBIAR LA UNIDAD DE MEDIDA: EL REPUESTO TIENE EXISTENCIA. '
          + 'EL SALDO PASARIA A ESTAR EN OTRA UNIDAD SIN QUE NADIE LO CONVIRTIERA.'
        RAISERROR(@MSG_UME, 16, 1)
        RETURN -1
    END

    IF (@VIDA_UTIL_HORA IS NOT NULL AND @VIDA_UTIL_HORA <= 0)
     OR (@VIDA_UTIL_DIA IS NOT NULL AND @VIDA_UTIL_DIA <= 0)
     OR (@VIDA_UTIL_CICLO IS NOT NULL AND @VIDA_UTIL_CICLO <= 0)
    BEGIN
        RAISERROR('3.- LA VIDA UTIL DEBE SER MAYOR QUE CERO. DEJELA VACIA SI NO SE CONOCE.', 16, 1)
        RETURN -1
    END

SET XACT_ABORT ON

BEGIN TRANSACTION

    /* @LIMPIA_VIDA_UTIL: el problema de ISNULL

       Con ISNULL(@X, columna), un campo que llega vacio significa "no lo
       toques". Eso es lo correcto para casi todo —es lo que evito que
       UPD_CLIENTE_INSTALACION borrara la zona horaria (bloque 51)—, pero
       hace imposible BORRAR un valor: quien se dio cuenta de que la vida
       util estaba mal cargada y limpia el campo, lo ve volver.

       Por eso la bandera. Es explicita a proposito: quien borra tiene que
       decir que esta borrando. */
    UPDATE  [dbo].[Repuesto]
    SET     rep_nombre                = ISNULL(@NOMBRE,           rep_nombre)
           ,rep_unidad_medida         = ISNULL(@UNIDAD_MEDIDA,    rep_unidad_medida)
           ,rep_fabricante            = ISNULL(@FABRICANTE,       rep_fabricante)
           ,rep_modelo                = ISNULL(@MODELO,           rep_modelo)
           ,rep_descripcion           = ISNULL(@DESCRIPCION,      rep_descripcion)
           ,rep_es_reparable          = ISNULL(@ES_REPARABLE,     rep_es_reparable)
           ,rep_es_consumible         = ISNULL(@ES_CONSUMIBLE,    rep_es_consumible)
           ,rep_controla_lote         = ISNULL(@CONTROLA_LOTE,    rep_controla_lote)
           ,rep_repuesto_tipo         = ISNULL(@REPUESTO_TIPO,    rep_repuesto_tipo)
           ,rep_costo_referencia      = ISNULL(@COSTO_REFERENCIA, rep_costo_referencia)
           ,rep_moneda                = ISNULL(@MONEDA,           rep_moneda)
           ,rep_vida_util_hora        = CASE WHEN @LIMPIA_VIDA_UTIL = 1 THEN @VIDA_UTIL_HORA
                                             ELSE ISNULL(@VIDA_UTIL_HORA,  rep_vida_util_hora) END
           ,rep_vida_util_dia         = CASE WHEN @LIMPIA_VIDA_UTIL = 1 THEN @VIDA_UTIL_DIA
                                             ELSE ISNULL(@VIDA_UTIL_DIA,   rep_vida_util_dia) END
           ,rep_vida_util_ciclo       = CASE WHEN @LIMPIA_VIDA_UTIL = 1 THEN @VIDA_UTIL_CICLO
                                             ELSE ISNULL(@VIDA_UTIL_CICLO, rep_vida_util_ciclo) END
           ,rep_habilitado            = ISNULL(@HABILITADO,       rep_habilitado)
           ,rep_usuario_actualizacion = @USUARIO
           ,rep_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   rep_id = @ID

COMMIT TRANSACTION
RETURN 0
GO

-- ---------- UPD_REPUESTO_LOTE (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_REPUESTO_LOTE (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_REPUESTO_LOTE]
    @ID                INT,
    @CLIENTE           INT,
    @FECHA_INGRESO     DATE = NULL,
    @FECHA_VENCIMIENTO DATE = NULL,
    @LIMPIA_VENCIMIENTO BIT = 0,
    @PROVEEDOR         INT = NULL,
    @COSTO_UNITARIO    DECIMAL(18,4) = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @HABILITADO        BIT = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

DECLARE @INGRESO DATE

SELECT @INGRESO = rlo_fecha_ingreso
FROM   [dbo].[Repuesto_Lote]
WHERE  rlo_id = @ID AND rlo_cliente = @CLIENTE

IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto_Lote] WHERE rlo_id = @ID AND rlo_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL LOTE NO EXISTE.', 16, 1)
    RETURN -1
END

/* Vencer antes de haber llegado no es un lote, es un error de tipeo. */
IF (@FECHA_VENCIMIENTO IS NOT NULL
    AND ISNULL(@FECHA_INGRESO, @INGRESO) IS NOT NULL
    AND @FECHA_VENCIMIENTO < ISNULL(@FECHA_INGRESO, @INGRESO))
BEGIN
    RAISERROR('2.- LA FECHA DE VENCIMIENTO NO PUEDE SER ANTERIOR A LA DE INGRESO.', 16, 1)
    RETURN -1
END

/* Deshabilitar un lote con existencia esconderia unidades que siguen en la
   estanteria. Los movimientos guardan el lote del que salieron, asi que
   basta mirar si alguno sigue sumando. */
IF (@HABILITADO = 0)
BEGIN
    DECLARE @SALDO DECIMAL(18,4)

    SELECT @SALDO = ISNULL(SUM(CASE WHEN imo_inventario_movimiento_tipo IN (1,3,4,7)
                                    THEN imo_cantidad ELSE -imo_cantidad END), 0)
    FROM   [dbo].[Inventario_Movimiento]
    WHERE  imo_repuesto_lote = @ID

    IF (@SALDO > 0)
    BEGIN
        DECLARE @MSG NVARCHAR(400) =
            '3.- NO SE PUEDE DESHABILITAR EL LOTE: QUEDAN '
          + LTRIM(STR(CAST(@SALDO AS DECIMAL(18,2)), 18, 2)) + ' UNIDAD(ES) SUYAS EN BODEGA.'
        RAISERROR(@MSG, 16, 1)
        RETURN -1
    END
END

/* XACT_ABORT aca y no arriba: un rechazo de validacion no tiene por que
   condenar la transaccion de quien llama (bloque 61). */
SET XACT_ABORT ON

BEGIN TRANSACTION

    /* @LIMPIA_VENCIMIENTO: con ISNULL, un campo vacio significa "no lo
       toques", y eso hace imposible BORRAR una fecha mal puesta. La bandera
       separa "no lo mande" de "quiero borrarlo" (bloque 63). */
    UPDATE  [dbo].[Repuesto_Lote]
    SET     rlo_fecha_ingreso        = ISNULL(@FECHA_INGRESO, rlo_fecha_ingreso)
           ,rlo_fecha_vencimiento    = CASE WHEN @LIMPIA_VENCIMIENTO = 1 THEN @FECHA_VENCIMIENTO
                                            ELSE ISNULL(@FECHA_VENCIMIENTO, rlo_fecha_vencimiento) END
           ,rlo_proveedor            = ISNULL(@PROVEEDOR,      rlo_proveedor)
           ,rlo_costo_unitario       = ISNULL(@COSTO_UNITARIO, rlo_costo_unitario)
           ,rlo_observacion          = ISNULL(@OBSERVACION,    rlo_observacion)
           ,rlo_habilitado           = ISNULL(@HABILITADO,     rlo_habilitado)
           ,rlo_usuario_actualizacion = @USUARIO
           ,rlo_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   rlo_id = @ID

COMMIT TRANSACTION

SELECT @ID [ID], '200' [CODE], 'Lote actualizado.' [MENSAJE]
RETURN 0
GO

-- ---------- UPD_SUSCRIPCION (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_SUSCRIPCION (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   4. UPD_SUSCRIPCION

      Suspender, reactivar, cancelar y mantener el contacto. El plan NO se
      cambia por aqui: eso tiene consecuencias de cobro y va por
      UPS_SUSCRIPCION_PLAN.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SUSCRIPCION]
@ID                INT,
@ESTADO            INT = NULL,
@CONTACTO_NOMBRE   NVARCHAR(200) = NULL,
@CONTACTO_EMAIL    NVARCHAR(200) = NULL,
@CONTACTO_TELEFONO NVARCHAR(50) = NULL,
@OBSERVACION       NVARCHAR(1000) = NULL,
@HABILITADO        BIT = NULL,
@USUARIO           INT

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Suscripcion]
    SET     sus_suscripcion_estado    = ISNULL(@ESTADO, sus_suscripcion_estado),
            sus_contacto_nombre       = @CONTACTO_NOMBRE,
            sus_contacto_email        = @CONTACTO_EMAIL,
            sus_contacto_telefono     = @CONTACTO_TELEFONO,
            sus_observacion           = @OBSERVACION,
            sus_habilitado            = ISNULL(@HABILITADO, sus_habilitado),
            sus_usuario_actualizacion = @USUARIO,
            sus_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   sus_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '1.- NO FUE POSIBLE ACTUALIZAR LA SUSCRIPCIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_SUSCRIPCION_KEY (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_SUSCRIPCION_KEY (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
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
                                        N'[' + CONVERT(NVARCHAR(10), [dbo].[FNC_AHORA](), 103) + N'] ' +
                                        N'Clave reemitida (' + ISNULL(@PREFIJO_ANTERIOR, N'sin prefijo') +
                                        N' → ' + @KEY_PREFIJO + N'). Motivo: ' + @MOTIVO,
            sus_usuario_actualizacion = @USUARIO,
            sus_fecha_actualizacion   = [dbo].[FNC_AHORA]()
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

-- ---------- UPD_SUSCRIPCION_PAGO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_SUSCRIPCION_PAGO (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_SUSCRIPCION_PAGO]
@ID                  INT,
@MONTO_DECLARADO     DECIMAL(18,2) = NULL,
@FECHA_TRANSFERENCIA DATE          = NULL,
@BANCO               NVARCHAR(200) = NULL,
@NUMERO_OPERACION    NVARCHAR(200) = NULL,
@ARCHIVO             INT           = NULL,
@USUARIO             INT

AS
SET NOCOUNT ON

DECLARE @ESTADO INT
       ,@HOY    DATE = CAST([dbo].[FNC_AHORA]() AS DATE)

SELECT  @ESTADO = spa_suscripcion_pago_estado
FROM    [dbo].[Suscripcion_Pago]
WHERE   spa_id = @ID
  AND   ISNULL(spa_habilitado, 0) = 1

IF (@ESTADO IS NULL)
BEGIN
    RAISERROR('1.- EL PAGO NO EXISTE.', 16, 1)
    RETURN -1
END

IF (@ESTADO = 3)
BEGIN
    /* RAISERROR no acepta una expresion como mensaje: solo un literal o una
       variable. Concatenar ahi mismo es un error de sintaxis. */
    DECLARE @MSG_VERIFICADO NVARCHAR(400) =
        '2.- EL PAGO YA ESTA VERIFICADO Y NO SE PUEDE CORREGIR. '
      + 'SU MONTO YA SUMO AL PERIODO Y PUDO EXTENDER LA VIGENCIA DE LA SUSCRIPCION.'

    RAISERROR(@MSG_VERIFICADO, 16, 1)
    RETURN -1
END

/* Un monto en cero o negativo no es una correccion, es un dato roto: la
   suma del periodo lo tomaria igual. */
IF (@MONTO_DECLARADO IS NOT NULL AND @MONTO_DECLARADO <= 0)
BEGIN
    RAISERROR('3.- EL MONTO DECLARADO DEBE SER MAYOR QUE CERO.', 16, 1)
    RETURN -1
END

/* Una transferencia con fecha futura no ocurrio. */
IF (@FECHA_TRANSFERENCIA IS NOT NULL AND @FECHA_TRANSFERENCIA > @HOY)
BEGIN
    RAISERROR('4.- LA FECHA DE TRANSFERENCIA NO PUEDE SER FUTURA.', 16, 1)
    RETURN -1
END

IF (@ARCHIVO IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM [dbo].[Archivo]
                     WHERE arc_id = @ARCHIVO AND ISNULL(arc_habilitado, 0) = 1))
BEGIN
    RAISERROR('5.- EL COMPROBANTE INDICADO NO EXISTE.', 16, 1)
    RETURN -1
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Suscripcion_Pago]
    SET     spa_monto_declarado_clp    = ISNULL(@MONTO_DECLARADO,     spa_monto_declarado_clp)
           ,spa_fecha_transferencia    = ISNULL(@FECHA_TRANSFERENCIA, spa_fecha_transferencia)
           ,spa_banco                  = ISNULL(@BANCO,               spa_banco)
           ,spa_numero_operacion       = ISNULL(@NUMERO_OPERACION,    spa_numero_operacion)
           ,spa_archivo                = ISNULL(@ARCHIVO,             spa_archivo)

            -- Un rechazado corregido vuelve a la cola. El resto no se mueve.
           ,spa_suscripcion_pago_estado = CASE WHEN @ESTADO = 4 THEN 1 ELSE spa_suscripcion_pago_estado END
           ,spa_motivo_rechazo          = CASE WHEN @ESTADO = 4 THEN NULL ELSE spa_motivo_rechazo END
           ,spa_usuario_verificador     = CASE WHEN @ESTADO = 4 THEN NULL ELSE spa_usuario_verificador END
           ,spa_fecha_verificacion_utc  = CASE WHEN @ESTADO = 4 THEN NULL ELSE spa_fecha_verificacion_utc END

           ,spa_usuario_actualizacion  = @USUARIO
           ,spa_fecha_actualizacion    = [dbo].[FNC_AHORA]()
    WHERE   spa_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION

        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION_PAGO @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE CORREGIR EL PAGO.'
        RETURN -1
    END

COMMIT TRANSACTION

SELECT  @ID [ID], '200' [CODE]
       ,CASE WHEN @ESTADO = 4
             THEN 'Pago corregido. Vuelve a quedar declarado, a la espera de verificación.'
             ELSE 'Pago corregido.' END [MENSAJE]
RETURN 0
GO

-- ---------- UPD_SUSCRIPCION_PAGO_VERIFICAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_SUSCRIPCION_PAGO_VERIFICAR (P) · 3 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   8. UPD_SUSCRIPCION_PAGO_VERIFICAR

      Aqui es donde un pago se vuelve real. Hace cuatro cosas en una sola
      transaccion, porque a medias dejarian la cuenta descuadrada:

        1. Marca el pago verificado o rechazado.
        2. Recalcula lo pagado del periodo sumando SOLO los verificados.
        3. Mueve el estado del periodo segun ese total.
        4. Si quedo cubierto, extiende sus_fecha_fin de la suscripcion.

      LA TOLERANCIA. Una transferencia rara vez calza al peso: hay
      comisiones y redondeos. Sys_Parametros define cuanto se acepta de
      diferencia, en pesos y en porcentaje, y se toma la mayor de las dos.
      Sin esto, un periodo de $370.000 pagado con $369.998 quedaria
      eternamente impago por dos pesos.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_SUSCRIPCION_PAGO_VERIFICAR]
@ID               INT,
@VERIFICADO       BIT,
@MONTO_VERIFICADO DECIMAL(18,2) = NULL,
@MOTIVO_RECHAZO   NVARCHAR(500) = NULL,
@USUARIO          INT

AS
SET NOCOUNT ON

DECLARE @PERIODO INT, @SUSCRIPCION INT, @FECHA_FIN DATE,
        @MONTO DECIMAL(18,2), @PAGADO DECIMAL(18,2),
        @TOL_CLP DECIMAL(18,2), @TOL_PCT DECIMAL(18,4), @TOLERANCIA DECIMAL(18,2)

BEGIN
    SELECT @PERIODO = spa_suscripcion_periodo
      FROM [dbo].[Suscripcion_Pago] WHERE spa_id = @ID

    IF @PERIODO IS NULL
    BEGIN
        RAISERROR('1.- EL PAGO NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @VERIFICADO = 0 AND (@MOTIVO_RECHAZO IS NULL OR LEN(LTRIM(@MOTIVO_RECHAZO)) < 5)
    BEGIN
        RAISERROR('2.- INDIQUE EL MOTIVO DEL RECHAZO.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    -- 1. El pago
    UPDATE  [dbo].[Suscripcion_Pago]
    SET     spa_suscripcion_pago_estado = CASE WHEN @VERIFICADO = 1 THEN 3 ELSE 4 END,
            spa_monto_verificado_clp    = CASE WHEN @VERIFICADO = 1
                                               THEN ISNULL(@MONTO_VERIFICADO, spa_monto_declarado_clp)
                                               ELSE NULL END,
            spa_usuario_verificador     = @USUARIO,
            spa_fecha_verificacion_utc  = GETUTCDATE(),
            spa_motivo_rechazo          = @MOTIVO_RECHAZO,
            spa_usuario_actualizacion   = @USUARIO,
            spa_fecha_actualizacion     = [dbo].[FNC_AHORA]()
    WHERE   spa_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_SUSCRIPCION_PAGO_VERIFICAR @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '3.- NO FUE POSIBLE VERIFICAR EL PAGO.'
        RETURN -1
    END

    /* 2. Lo pagado se RECALCULA sumando los verificados, no se incrementa.
          Sumar sobre lo que ya habia dejaria el total mal en cuanto
          alguien corrija o revierta una verificacion. */
    SELECT @PAGADO = ISNULL(SUM(ISNULL(spa_monto_verificado_clp, 0)), 0)
      FROM [dbo].[Suscripcion_Pago]
     WHERE spa_suscripcion_periodo = @PERIODO
       AND spa_suscripcion_pago_estado = 3
       AND spa_habilitado = 1

    SELECT @MONTO = spe_monto_clp, @SUSCRIPCION = spe_suscripcion, @FECHA_FIN = spe_fecha_fin
      FROM [dbo].[Suscripcion_Periodo] WHERE spe_id = @PERIODO

    -- Tolerancia: la mayor entre el monto fijo y el porcentaje.
    SELECT @TOL_CLP = TRY_CAST(par_valor AS DECIMAL(18,2))
      FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'SUSCRIPCION_TOLERANCIA_CLP'
    SELECT @TOL_PCT = TRY_CAST(par_valor AS DECIMAL(18,4))
      FROM [dbo].[Sys_Parametros] WHERE par_codigo = 'SUSCRIPCION_TOLERANCIA_PORCENTAJE'

    SET @TOLERANCIA = CASE
        WHEN ISNULL(@TOL_CLP, 0) > (@MONTO * ISNULL(@TOL_PCT, 0) / 100.0)
        THEN ISNULL(@TOL_CLP, 0)
        ELSE (@MONTO * ISNULL(@TOL_PCT, 0) / 100.0) END

    DECLARE @CUBIERTO BIT = CASE WHEN @PAGADO >= (@MONTO - @TOLERANCIA) THEN 1 ELSE 0 END

    -- 3. El estado del periodo
    UPDATE  [dbo].[Suscripcion_Periodo]
    SET     spe_monto_pagado_clp          = @PAGADO,
            spe_suscripcion_periodo_estado = CASE
                                                WHEN @CUBIERTO = 1  THEN 3   -- VIGENTE
                                                WHEN @PAGADO > 0    THEN 2   -- PAGO PARCIAL
                                                ELSE 1                       -- PENDIENTE PAGO
                                             END,
            spe_usuario_actualizacion     = @USUARIO,
            spe_fecha_actualizacion       = [dbo].[FNC_AHORA]()
    WHERE   spe_id = @PERIODO

    /* 4. Recien con el periodo cubierto la suscripcion se extiende.
          Se toma la fecha mayor entre la que ya tenia y la del periodo:
          verificar un pago atrasado no debe ACORTAR una vigencia. */
    IF @CUBIERTO = 1
        UPDATE  [dbo].[Suscripcion]
        SET     sus_fecha_fin             = CASE WHEN sus_fecha_fin IS NULL OR sus_fecha_fin < @FECHA_FIN
                                                 THEN @FECHA_FIN ELSE sus_fecha_fin END,
                sus_usuario_actualizacion = @USUARIO,
                sus_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   sus_id = @SUSCRIPCION

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_UNIDAD_MEDIDA (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_UNIDAD_MEDIDA (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   T-2282 - UPD_UNIDAD_MEDIDA
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_UNIDAD_MEDIDA]
@ID             INT,
@MAGNITUD       INT = NULL,
@UNIDAD_BASE    INT = NULL,
@CODIGO         NVARCHAR(20) = NULL,
@NOMBRE         NVARCHAR(100) = NULL,
@SIMBOLO        NVARCHAR(20) = NULL,
@FACTOR         DECIMAL(18,6) = NULL,
@OFFSET         DECIMAL(18,6) = NULL,
@HABILITADO     BIT = NULL,
@QUITA_BASE     BIT = 0,
@USUARIO        INT

AS
SET NOCOUNT ON

IF NOT EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_id = @ID)
BEGIN
    RAISERROR('1.- LA UNIDAD NO EXISTE.', 16, 1)
    RETURN -1
END

IF @CODIGO IS NOT NULL SET @CODIGO = UPPER(LTRIM(RTRIM(@CODIGO)))

BEGIN
    IF @CODIGO IS NOT NULL
       AND EXISTS (SELECT 1 FROM [dbo].[Unidad_Medida] WHERE ume_codigo = @CODIGO AND ume_id <> @ID)
    BEGIN
        RAISERROR('2.- YA EXISTE UNA UNIDAD CON EL CODIGO "%s".', 16, 1, @CODIGO)
        RETURN -1
    END

    IF @UNIDAD_BASE IS NOT NULL AND @UNIDAD_BASE = @ID
    BEGIN
        RAISERROR('3.- UNA UNIDAD NO PUEDE SER SU PROPIA BASE.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Unidad_Medida]
    SET     ume_magnitud              = ISNULL(@MAGNITUD, ume_magnitud)
           ,ume_unidad_base           = CASE WHEN @QUITA_BASE = 1 THEN NULL
                                             ELSE ISNULL(@UNIDAD_BASE, ume_unidad_base) END
           ,ume_codigo                = ISNULL(@CODIGO, ume_codigo)
           ,ume_nombre                = ISNULL(@NOMBRE, ume_nombre)
           ,ume_simbolo               = ISNULL(@SIMBOLO, ume_simbolo)
           ,ume_factor                = ISNULL(@FACTOR, ume_factor)
           ,ume_offset                = ISNULL(@OFFSET, ume_offset)
           ,ume_habilitado            = ISNULL(@HABILITADO, ume_habilitado)
           ,ume_usuario_actualizacion = @USUARIO
           ,ume_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   ume_id = @ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_UNIDAD_MEDIDA @ID = ' + LTRIM(STR(@ID))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES, @MSG = '4.- NO FUE POSIBLE ACTUALIZAR LA UNIDAD.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_USUARIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_USUARIO (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   8. UPD_USUARIO                                                   HU-014

      LA CONTRASENA SOLO SE TOCA CUANDO VIENE INFORMADA. Ver la nota del
      encabezado: el mantenedor manda @PASSWORD en cada guardado, asi que
      escribirla siempre destruiria el hash del usuario.

      Se agrega ademas la validacion de unicidad de correo, RUT y login
      contra OTROS usuarios, que la version anterior no hacia en absoluto:
      se podia dejar a dos personas con el mismo correo editando la ficha.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO]
@ID                INT,
@IDENTIFICADOR     VARCHAR(100),
@CLIENTE           INT = NULL,
@LOGIN             VARCHAR(200),
@PASSWORD          VARCHAR(100) = NULL,
@NOMBRES           VARCHAR(200),
@APELLIDO_PATERNO  VARCHAR(200),
@APELLIDO_MATERNO  VARCHAR(200) = NULL,
@FONO1             VARCHAR(50) = NULL,
@CORREO            VARCHAR(200),
@FOTO              VARBINARY(MAX) = NULL,
@EXTENSION         VARCHAR(10) = NULL,
@IDIOMA            INT = NULL,
@USUARIO           INT,
@HABILITADO        BIT

AS
SET NOCOUNT ON

DECLARE @PAIS_CHILE   INT
DECLARE @PAIS_CLIENTE INT
DECLARE @SALT         VARCHAR(50)
DECLARE @HASH_NUEVO   VARCHAR(500) = NULL

SELECT @PAIS_CHILE = pai_id FROM [dbo].[Paises] WHERE pai_nombre = 'Chile'

IF @CLIENTE IS NOT NULL
    SELECT @PAIS_CLIENTE = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE

--VALIDACIONES
BEGIN
    IF EXISTS(SELECT 1 FROM [dbo].[Usuario]
               WHERE usu_identificador = LTRIM(RTRIM(@IDENTIFICADOR)) AND usu_id <> @ID)
    BEGIN
        RAISERROR('1. Ya existe otro usuario registrado con el identificador indicado.', 16, 1)
        RETURN -1
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario]
               WHERE usu_login = LTRIM(RTRIM(@LOGIN)) AND usu_id <> @ID)
    BEGIN
        RAISERROR('2. Ya existe otro usuario registrado con el login indicado.', 16, 1)
        RETURN -2
    END

    IF EXISTS(SELECT 1 FROM [dbo].[Usuario]
               WHERE usu_correo = LTRIM(RTRIM(@CORREO)) AND usu_id <> @ID)
    BEGIN
        RAISERROR('3. Ya existe otro usuario registrado con el correo indicado.', 16, 1)
        RETURN -3
    END

    IF @CLIENTE IS NOT NULL AND [dbo].[FNC_IDENTIFICADOR_VALIDO](@PAIS_CLIENTE, @IDENTIFICADOR) = 0
    BEGIN
        RAISERROR('4. El identificador "%s" no es válido para el país del cliente.', 16, 1, @IDENTIFICADOR)
        RETURN -4
    END
END

/* Solo si el formulario mando una contrasena se prepara el hash nuevo. */
IF @PASSWORD IS NOT NULL AND LTRIM(RTRIM(@PASSWORD)) <> ''
BEGIN
    SELECT @SALT = usu_password_salt FROM [dbo].[Usuario] WHERE usu_id = @ID

    IF @SALT IS NULL
        SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

    SET @HASH_NUEVO = [dbo].[FNC_PASSWORD_HASH](@PASSWORD, @SALT)
END

BEGIN TRANSACTION

-- 1.- USUARIO
BEGIN
    UPDATE  [dbo].[Usuario]
    SET     usu_identificador    = @IDENTIFICADOR,
            usu_login            = @LOGIN,
            usu_password         = ISNULL(@HASH_NUEVO, usu_password),
            usu_password_salt    = CASE WHEN @HASH_NUEVO IS NULL THEN usu_password_salt ELSE @SALT END,
            usu_nombre           = @NOMBRES,
            usu_apellido_paterno = @APELLIDO_PATERNO,
            usu_apellido_materno = ISNULL(@APELLIDO_MATERNO, ''),
            usu_telefono         = @FONO1,
            usu_correo           = @CORREO,
            usu_idioma           = ISNULL(@IDIOMA, usu_idioma),
            usu_usuario_act      = @USUARIO,
            usu_fecha_act        = [dbo].[FNC_AHORA](),
            /* La foto tampoco se borra por guardar la ficha sin adjuntar
               una nueva: antes se asignaba @FOTO siempre. */
            usu_foto             = CASE WHEN @FOTO IS NULL THEN usu_foto ELSE @FOTO END,
            usu_habilitado       = @HABILITADO
    WHERE   usu_id = @ID

    IF @@ROWCOUNT = 0 BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX)
        SET @VARIABLES = 'UPD_USUARIO ' + LTRIM(STR(@ID)) + ',' + ISNULL(@LOGIN, '')

        EXEC [dbo].[INS_EXCEPCION]
            @MSG = '5.- NO FUE POSIBLE ACTUALIZAR EL USUARIO.',
            @VARIABLES = @VARIABLES
        RETURN -1
    END
END

-- 2.- HISTORIAL DE CONTRASENA
IF @HASH_NUEVO IS NOT NULL
BEGIN
    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES
        (@ID, @HASH_NUEVO, @USUARIO, [dbo].[FNC_AHORA]())
END

-- 3.- FOTOGRAFIA
BEGIN
    IF(@FOTO IS NOT NULL)BEGIN
        DELETE FROM [dbo].[Usuario_Foto] WHERE uft_usuario = @ID

        INSERT INTO [dbo].[Usuario_Foto]
            (uft_usuario, uft_binario, uft_extension, uft_fecha_creacion)
        VALUES
            (@ID, @FOTO, @EXTENSION, [dbo].[FNC_AHORA]())
    END
END

-- 4.- AL DESHABILITAR AL USUARIO SE DESHABILITAN SUS AFILIACIONES
BEGIN
    IF(@HABILITADO = 0) BEGIN
        UPDATE  [dbo].[Cliente_Usuario]
        SET     ucl_habilitado  = 0,
                ucl_usuario_act = @USUARIO,
                ucl_fecha_act   = [dbo].[FNC_AHORA]()
        WHERE   ucl_id_usuario = @ID
    END
END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_USUARIO_MI_PERFIL (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_USUARIO_MI_PERFIL (P) · 1 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_MI_PERFIL]
@USUARIO   INT,
@TELEFONO  VARCHAR(50) = NULL,
@IDIOMA    INT = NULL,
@FOTO      VARBINARY(MAX) = NULL,
@CAMBIA_FOTO BIT = 0

AS
SET NOCOUNT ON

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario]
    SET     usu_telefono   = ISNULL(@TELEFONO, usu_telefono)
           ,usu_idioma     = ISNULL(@IDIOMA, usu_idioma)
           ,usu_foto       = CASE WHEN @CAMBIA_FOTO = 1 THEN @FOTO ELSE usu_foto END
           ,usu_usuario_act = @USUARIO
           ,usu_fecha_act   = [dbo].[FNC_AHORA]()
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_MI_PERFIL @USUARIO = ' + LTRIM(STR(@USUARIO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL PERFIL.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_USUARIO_PASSWORD (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_USUARIO_PASSWORD (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   4. UPD_USUARIO_PASSWORD                                   HU-004, HU-005

      Un solo SP para los dos caminos, porque las reglas de la contrasena
      nueva son las mismas venga de donde venga:

        @EXIGE_ACTUAL = 1  el usuario cambia su clave estando dentro y debe
                           escribir la vigente (HU-005 escenario 1).
        @EXIGE_ACTUAL = 0  viene de un enlace de recuperacion ya validado,
                           donde por definicion no sabe la anterior.

      Las tres anteriores: el historial guarda cada clave que se fija, asi
      que las tres ultimas filas del historial SON las tres anteriores.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_PASSWORD]
@USUARIO          INT,
@PASSWORD_ACTUAL  VARCHAR(500) = NULL,
@PASSWORD_NUEVO   VARCHAR(500),
@EXIGE_ACTUAL     BIT = 1

AS
SET NOCOUNT ON

DECLARE @SALT              VARCHAR(50)
       ,@PASSWORD_GUARDADA VARCHAR(500)
       ,@HASH_NUEVO        VARCHAR(500)

BEGIN
    SELECT  @SALT              = usu_password_salt
           ,@PASSWORD_GUARDADA = usu_password
    FROM    [dbo].[Usuario]
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('1.- EL USUARIO NO EXISTE.', 16, 1)
        RETURN -1
    END

    /* Cuenta que aun no se migro: se le genera sal ahora. */
    IF @SALT IS NULL
    BEGIN
        SET @SALT = REPLACE(CONVERT(VARCHAR(50), NEWID()), '-', '')

        UPDATE  [dbo].[Usuario]
        SET     usu_password_salt = @SALT
               ,usu_password      = [dbo].[FNC_PASSWORD_HASH](@PASSWORD_GUARDADA, @SALT)
        WHERE   usu_id = @USUARIO

        SET @PASSWORD_GUARDADA = [dbo].[FNC_PASSWORD_HASH](@PASSWORD_GUARDADA, @SALT)
    END

    -- Contrasena actual
    IF @EXIGE_ACTUAL = 1
    BEGIN
        IF @PASSWORD_ACTUAL IS NULL
            OR [dbo].[FNC_PASSWORD_HASH](@PASSWORD_ACTUAL, @SALT) <> @PASSWORD_GUARDADA
        BEGIN
            RAISERROR('2.- LA CONTRASEÑA ACTUAL NO ES CORRECTA.', 16, 1)
            RETURN -1
        END
    END

    -- Largo minimo
    IF LEN(ISNULL(@PASSWORD_NUEVO, '')) < 8
    BEGIN
        RAISERROR('3.- LA CONTRASEÑA DEBE TENER AL MENOS 8 CARACTERES.', 16, 1)
        RETURN -1
    END

    /* Al menos una letra y un numero (HU-004). El BIN fuerza que el rango
       [A-Za-z] signifique letras inglesas y no dependa de la intercalacion
       de la base, que en Modern_Spanish incluiria acentuadas. */
    IF PATINDEX('%[0-9]%', @PASSWORD_NUEVO) = 0
       OR PATINDEX('%[A-Za-z]%', @PASSWORD_NUEVO COLLATE Latin1_General_BIN) = 0
    BEGIN
        RAISERROR('4.- LA CONTRASEÑA DEBE INCLUIR AL MENOS UNA LETRA Y UN NÚMERO.', 16, 1)
        RETURN -1
    END

    SET @HASH_NUEVO = [dbo].[FNC_PASSWORD_HASH](@PASSWORD_NUEVO, @SALT)

    -- Distinta de la vigente y de las tres anteriores
    IF @HASH_NUEVO = @PASSWORD_GUARDADA
       OR EXISTS (SELECT 1
                    FROM (SELECT TOP 3 uph_password
                            FROM [dbo].[Usuario_Password_Historial]
                           WHERE uph_usuario = @USUARIO
                           ORDER BY uph_fecha_creacion DESC) h
                   WHERE h.uph_password = @HASH_NUEVO)
    BEGIN
        RAISERROR('5.- LA CONTRASEÑA NO PUEDE SER IGUAL A NINGUNA DE LAS TRES ANTERIORES.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario]
    SET     usu_password              = @HASH_NUEVO
           ,usu_intentos_fallidos     = 0
           ,usu_primer_intento_fallido = NULL
           ,usu_bloqueado_hasta       = NULL
           ,usu_usuario_act           = @USUARIO
           ,usu_fecha_act             = [dbo].[FNC_AHORA]()
    WHERE   usu_id = @USUARIO

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_PASSWORD @USUARIO = ' + LTRIM(STR(@USUARIO))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '6.- NO FUE POSIBLE ACTUALIZAR LA CONTRASEÑA.'
        RETURN -1
    END

    INSERT [dbo].[Usuario_Password_Historial]
        (uph_usuario, uph_password, uph_usuario_creacion, uph_fecha_creacion)
    VALUES
        (@USUARIO, @HASH_NUEVO, @USUARIO, [dbo].[FNC_AHORA]())

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPD_USUARIO_RECUPERACION_USAR (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPD_USUARIO_RECUPERACION_USAR (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   7. UPD_USUARIO_RECUPERACION_USAR                                 HU-004

      Consume el enlace y fija la contrasena nueva.

      EL ORDEN IMPORTA. Primero se cambia la contrasena y solo despues se
      marca el enlace como usado.

      No se envuelve todo en una transaccion que abarque el EXEC:
      UPD_USUARIO_PASSWORD abre y cierra la suya, y sus rutas de error hacen
      ROLLBACK. Como SQL Server no tiene transacciones anidadas de verdad,
      ese ROLLBACK del SP interno desharia tambien la transaccion externa y
      el COMMIT posterior fallaria con "no corresponding BEGIN TRANSACTION".

      Ademas RAISERROR de severidad 16 NO aborta el lote: la ejecucion
      vuelve aqui. Por eso se lee el codigo de retorno con EXEC @RC = ...;
      sin esa comprobacion el enlace se marcaria como usado aunque la
      contrasena hubiera sido rechazada, y la persona se quedaria sin enlace
      y sin clave nueva.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPD_USUARIO_RECUPERACION_USAR]
@TOKEN           VARCHAR(200),
@PASSWORD_NUEVO  VARCHAR(500)

AS
SET NOCOUNT ON

DECLARE @URE_ID  INT
       ,@USUARIO INT
       ,@RC      INT

BEGIN
    SELECT  TOP 1 @URE_ID = ure_id, @USUARIO = ure_usuario
    FROM    [dbo].[Usuario_Recuperacion]
    WHERE   ure_token_hash = HASHBYTES('SHA2_256', @TOKEN)
      AND   ure_fecha_uso IS NULL
      AND   ure_fecha_expiracion > [dbo].[FNC_AHORA]()

    IF @URE_ID IS NULL
    BEGIN
        RAISERROR('1.- EL ENLACE NO ES VÁLIDO O YA EXPIRÓ. SOLICITE UNO NUEVO.', 16, 1)
        RETURN -1
    END
END

EXEC @RC = [dbo].[UPD_USUARIO_PASSWORD]
     @USUARIO        = @USUARIO,
     @PASSWORD_NUEVO = @PASSWORD_NUEVO,
     @EXIGE_ACTUAL   = 0

/* La contrasena fue rechazada. El enlace NO se consume: la persona corrige
   y vuelve a intentar con el mismo correo. */
IF (@RC <> 0) RETURN -1

BEGIN TRANSACTION

    UPDATE  [dbo].[Usuario_Recuperacion]
    SET     ure_fecha_uso = [dbo].[FNC_AHORA]()
    WHERE   ure_id = @URE_ID

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPD_USUARIO_RECUPERACION_USAR @URE_ID = ' + LTRIM(STR(@URE_ID))

        EXEC [dbo].[INS_EXCEPCION]
            @VARIABLES = @VARIABLES,
            @MSG = '2.- NO FUE POSIBLE INVALIDAR EL ENLACE DE RECUPERACIÓN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPS_PLAN_COMERCIAL_PRECIO (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPS_PLAN_COMERCIAL_PRECIO (P) · 5 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   3. UPS_PLAN_COMERCIAL_PRECIO                                       3.3

      FIJA el precio de un plan para una periodicidad. No lo edita: cierra
      el vigente y abre uno nuevo.

          precio vigente  ->  pcp_vigencia_hasta = @DESDE - 1 dia
          precio nuevo    ->  pcp_vigencia_desde = @DESDE, hasta NULL

      Por que asi y no con un UPDATE sobre pcp_valor_uf: el precio de ayer
      tiene que seguir siendo consultable. SEL_PLAN_COMERCIAL elige el que
      corresponde A UNA FECHA, no el ultimo cargado, y de eso depende que
      una cotizacion de la semana pasada siga diciendo lo mismo.

      @DESDE por defecto es hoy. Se acepta futuro -una lista de precios
      acordada para el proximo mes se carga hoy y entra sola-. NO se acepta
      pasado: reescribir hacia atras es justamente lo que el versionado
      existe para impedir.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_COMERCIAL_PRECIO]
@ID           INT = NULL OUTPUT,
@PLAN         INT,
@PERIODICIDAD INT,
@VALOR_UF     DECIMAL(18,4),
@DESCUENTO    DECIMAL(18,2) = NULL,
@DESDE        DATE = NULL,
@USUARIO      INT

AS
SET NOCOUNT ON

DECLARE @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE),
        @VIGENTE INT,
        @VALOR_VIGENTE DECIMAL(18,4),
        @DESDE_VIGENTE DATE

SET @DESDE = ISNULL(@DESDE, @HOY)

BEGIN
    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN)
    BEGIN
        RAISERROR('1.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Periodicidad_Cobro]
                    WHERE pcb_id = @PERIODICIDAD AND pcb_habilitado = 1)
    BEGIN
        RAISERROR('2.- LA PERIODICIDAD DE COBRO NO ES VÁLIDA.', 16, 1)
        RETURN -1
    END

    IF @VALOR_UF IS NULL OR @VALOR_UF <= 0
    BEGIN
        RAISERROR('3.- EL VALOR EN UF DEBE SER MAYOR QUE CERO.', 16, 1)
        RETURN -1
    END

    IF @DESCUENTO IS NOT NULL AND (@DESCUENTO < 0 OR @DESCUENTO > 100)
    BEGIN
        RAISERROR('4.- EL DESCUENTO DEBE ESTAR ENTRE 0 Y 100.', 16, 1)
        RETURN -1
    END

    IF @DESDE < @HOY
    BEGIN
        RAISERROR('5.- NO SE PUEDE FIJAR UN PRECIO CON FECHA PASADA: ALTERARÍA LO YA COTIZADO.', 16, 1)
        RETURN -1
    END

    SELECT  @VIGENTE = pcp_id,
            @VALOR_VIGENTE = pcp_valor_uf,
            @DESDE_VIGENTE = pcp_vigencia_desde
    FROM    [dbo].[Plan_Comercial_Precio]
    WHERE   pcp_plan_comercial = @PLAN
      AND   pcp_periodicidad_cobro = @PERIODICIDAD
      AND   pcp_vigencia_hasta IS NULL
      AND   pcp_habilitado = 1

    -- Mismo numero: no se versiona nada. Guardar una fila identica solo
    -- ensucia el historial con un cambio que no ocurrio.
    IF @VIGENTE IS NOT NULL AND @VALOR_VIGENTE = @VALOR_UF
    BEGIN
        SET @ID = @VIGENTE
        RETURN(0)
    END

    /* El precio vigente empezo hoy o despues: todavia no cubrio ningun dia,
       asi que cerrarlo con "ayer" produciria hasta < desde y el CHECK lo
       rechazaria. En ese caso se corrige la fila en vez de versionarla; no
       hay historia que preservar. */
    IF @VIGENTE IS NOT NULL AND @DESDE_VIGENTE >= @DESDE
    BEGIN
        BEGIN TRANSACTION
            UPDATE  [dbo].[Plan_Comercial_Precio]
            SET     pcp_valor_uf               = @VALOR_UF,
                    pcp_descuento_porcentaje   = @DESCUENTO,
                    pcp_vigencia_desde         = @DESDE,
                    pcp_usuario_actualizacion  = @USUARIO,
                    pcp_fecha_actualizacion    = [dbo].[FNC_AHORA]()
            WHERE   pcp_id = @VIGENTE
        COMMIT TRANSACTION

        SET @ID = @VIGENTE
        RETURN(0)
    END
END

BEGIN TRANSACTION

    IF @VIGENTE IS NOT NULL
        UPDATE  [dbo].[Plan_Comercial_Precio]
        SET     pcp_vigencia_hasta        = DATEADD(DAY, -1, @DESDE),
                pcp_usuario_actualizacion = @USUARIO,
                pcp_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   pcp_id = @VIGENTE

    INSERT [dbo].[Plan_Comercial_Precio]
        (pcp_plan_comercial, pcp_periodicidad_cobro, pcp_valor_uf,
         pcp_vigencia_desde, pcp_vigencia_hasta, pcp_descuento_porcentaje,
         pcp_usuario_creacion, pcp_fecha_creacion,
         pcp_usuario_actualizacion, pcp_fecha_actualizacion, pcp_habilitado)
    VALUES
        (@PLAN, @PERIODICIDAD, @VALOR_UF,
         @DESDE, NULL, @DESCUENTO,
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @ID = SCOPE_IDENTITY()

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PLAN_COMERCIAL_PRECIO @PLAN = ' + LTRIM(STR(@PLAN))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE FIJAR EL PRECIO.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPS_PLAN_FUNCIONALIDAD (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPS_PLAN_FUNCIONALIDAD (P) · 4 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   2. UPS_PLAN_FUNCIONALIDAD

      Concede o niega una funcionalidad en un plan, o le fija el tope.

      Es un UPSERT porque la matriz se edita fila por fila desde la
      pantalla y no interesa si esa combinacion ya existia: lo que interesa
      es como queda.

      @CLIENTE NULL  -> la regla del plan, para todos.
      @CLIENTE con id -> la excepcion de ese cliente, que gana sobre el plan.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_PLAN_FUNCIONALIDAD]
@ID              INT = NULL OUTPUT,
@PLAN            INT,
@FUNCIONALIDAD   INT,
@CLIENTE         INT = NULL,
@INCLUIDA        BIT,
@LIMITE          DECIMAL(18,2) = NULL,
@VIGENCIA_HASTA  DATE = NULL,
@OBSERVACION     NVARCHAR(500) = NULL,
@USUARIO         INT

AS
SET NOCOUNT ON

DECLARE @TIPO INT, @CODIGO NVARCHAR(50)

BEGIN
    SELECT @CODIGO = fun_codigo FROM [dbo].[Funcionalidad]
     WHERE fun_id = @FUNCIONALIDAD AND fun_habilitado = 1

    IF @CODIGO IS NULL
    BEGIN
        RAISERROR('1.- LA FUNCIONALIDAD NO EXISTE O ESTÁ DESHABILITADA.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN)
    BEGIN
        RAISERROR('2.- EL PLAN NO EXISTE.', 16, 1)
        RETURN -1
    END

    -- Las cuatro LIMITE son topes; el resto, inclusion.
    SET @TIPO = CASE WHEN @CODIGO LIKE N'LIMITE%' THEN 2 ELSE 1 END

    /* El CHECK de la tabla exige tope cuando el tipo es LIMITE. Se avisa
       aca para no devolver un error de constraint, que no le dice nada a
       quien esta llenando el formulario.

       Ojo: un tope VACIO no es lo mismo que negar la funcionalidad. En el
       plan FULL, "plantas" esta incluida y su tope es NULL = sin tope. Por
       eso solo se exige el numero cuando la funcionalidad esta incluida Y
       no se quiso dejar ilimitada, lo que se distingue con @INCLUIDA. */
    IF @TIPO = 2 AND @INCLUIDA = 1 AND @LIMITE IS NULL
    BEGIN
        /* Sin tope explicito, ilimitado. Se guarda un limite nulo con el
           tipo INCLUSION para no chocar con CK_PCF_LIMITE, que solo aplica
           al tipo LIMITE. Es la forma que el modelo tiene de decir
           "infinito", y es como esta cargado el plan FULL. */
        SET @TIPO = 1
    END

    IF @TIPO = 2 AND @LIMITE < 0
    BEGIN
        RAISERROR('3.- EL TOPE NO PUEDE SER NEGATIVO.', 16, 1)
        RETURN -1
    END

    IF @CLIENTE IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE)
    BEGIN
        RAISERROR('4.- EL CLIENTE DE LA EXCEPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @VIGENCIA_HASTA IS NOT NULL AND @VIGENCIA_HASTA < CAST([dbo].[FNC_AHORA]() AS DATE)
    BEGIN
        RAISERROR('5.- LA VIGENCIA NO PUEDE TERMINAR ANTES DE HOY.', 16, 1)
        RETURN -1
    END
END

BEGIN TRANSACTION

    SELECT @ID = pcf_id
      FROM [dbo].[Plan_Comercial_Funcionalidad]
     WHERE pcf_plan_comercial = @PLAN
       AND pcf_funcionalidad  = @FUNCIONALIDAD
       AND ((@CLIENTE IS NULL AND pcf_cliente IS NULL) OR pcf_cliente = @CLIENTE)

    IF @ID IS NULL
    BEGIN
        INSERT [dbo].[Plan_Comercial_Funcionalidad]
            (pcf_plan_comercial, pcf_funcionalidad, pcf_cliente, pcf_funcionalidad_tipo,
             pcf_incluida, pcf_limite, pcf_vigencia_hasta, pcf_observacion,
             pcf_usuario_creacion, pcf_fecha_creacion,
             pcf_usuario_actualizacion, pcf_fecha_actualizacion, pcf_habilitado)
        VALUES
            (@PLAN, @FUNCIONALIDAD, @CLIENTE, @TIPO,
             @INCLUIDA, CASE WHEN @TIPO = 2 THEN @LIMITE ELSE NULL END,
             @VIGENCIA_HASTA, @OBSERVACION,
             @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

        SET @ID = SCOPE_IDENTITY()
    END
    ELSE
    BEGIN
        UPDATE  [dbo].[Plan_Comercial_Funcionalidad]
        SET     pcf_funcionalidad_tipo    = @TIPO,
                pcf_incluida              = @INCLUIDA,
                pcf_limite                = CASE WHEN @TIPO = 2 THEN @LIMITE ELSE NULL END,
                pcf_vigencia_hasta        = @VIGENCIA_HASTA,
                pcf_observacion           = @OBSERVACION,
                pcf_habilitado            = 1,
                pcf_usuario_actualizacion = @USUARIO,
                pcf_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   pcf_id = @ID
    END

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION
        DECLARE @VARIABLES VARCHAR(MAX) = 'UPS_PLAN_FUNCIONALIDAD @PLAN = ' + LTRIM(STR(@PLAN))
        EXEC [dbo].[INS_EXCEPCION] @VARIABLES = @VARIABLES,
                                   @MSG = '6.- NO FUE POSIBLE GUARDAR LA FUNCIONALIDAD DEL PLAN.'
        RETURN -1
    END

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- UPS_REPUESTO_BODEGA_STOCK (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPS_REPUESTO_BODEGA_STOCK (P) · 2 [dbo].[FNC_AHORA]() reemplazado(s)
CREATE OR ALTER PROCEDURE [dbo].[UPS_REPUESTO_BODEGA_STOCK]
    @ID                INT OUTPUT,
    @CLIENTE           INT,
    @REPUESTO          INT,
    @BODEGA            INT,
    @STOCK_MINIMO      DECIMAL(18,4),
    @STOCK_MAXIMO      DECIMAL(18,4) = NULL,
    @PUNTO_REPOSICION  DECIMAL(18,4) = NULL,
    @OBSERVACION       NVARCHAR(1000) = NULL,
    @USUARIO           INT
AS
SET NOCOUNT ON

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Repuesto] WHERE rep_id = @REPUESTO AND rep_cliente = @CLIENTE)
    BEGIN
        RAISERROR('1.- EL REPUESTO NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Bodega] WHERE bod_id = @BODEGA AND bod_cliente = @CLIENTE)
    BEGIN
        RAISERROR('2.- LA BODEGA NO PERTENECE A ESTE CLIENTE.', 16, 1)
        RETURN -1
    END

    IF (@STOCK_MINIMO IS NULL OR @STOCK_MINIMO < 0)
    BEGIN
        RAISERROR('3.- EL STOCK MINIMO NO PUEDE SER NEGATIVO.', 16, 1)
        RETURN -1
    END

    -- Criterio 1 de HU-053, textual.
    IF (@STOCK_MAXIMO IS NOT NULL AND @STOCK_MAXIMO < @STOCK_MINIMO)
    BEGIN
        RAISERROR('4.- EL STOCK MAXIMO NO PUEDE SER MENOR QUE EL MINIMO.', 16, 1)
        RETURN -1
    END

    /* El punto de reposicion es "cuando pedir": tiene que caer entre el
       minimo y el maximo. Bajo el minimo se avisaria cuando ya es tarde;
       sobre el maximo se pediria siempre. */
    IF (@PUNTO_REPOSICION IS NOT NULL AND @PUNTO_REPOSICION < @STOCK_MINIMO)
    BEGIN
        RAISERROR('5.- EL PUNTO DE REPOSICION NO PUEDE SER MENOR QUE EL STOCK MINIMO.', 16, 1)
        RETURN -1
    END

    IF (@PUNTO_REPOSICION IS NOT NULL AND @STOCK_MAXIMO IS NOT NULL
        AND @PUNTO_REPOSICION > @STOCK_MAXIMO)
    BEGIN
        RAISERROR('6.- EL PUNTO DE REPOSICION NO PUEDE SER MAYOR QUE EL STOCK MAXIMO.', 16, 1)
        RETURN -1
    END

/* XACT_ABORT va aca y no al inicio del procedimiento.

   Arriba, un RAISERROR de validacion -que es una regla de negocio, no una
   falla- CONDENA la transaccion de quien llama: queda uncommittable y
   cualquier escritura posterior revienta con "cannot support operations
   that write to the log file". Se nota en cuanto alguien encadena dos
   llamadas dentro de una misma transaccion.

   Puesto aca protege lo que tiene que proteger -que un error a mitad de la
   escritura no deje datos a medias- sin castigar al que solo recibio un
   "no". */
SET XACT_ABORT ON

BEGIN TRANSACTION

    /* NULL a la fuerza: un SELECT que no encuentra filas NO toca la
           variable, y el llamador manda 0. Sin esta linea, el ELSE de mas
           abajo hace UPDATE ... WHERE rbs_id = 0 y no guarda nada. */
        SET @ID = NULL

        SELECT @ID = rbs_id FROM [dbo].[Repuesto_Bodega_Stock]
     WHERE rbs_repuesto = @REPUESTO AND rbs_bodega = @BODEGA

    IF (@ID IS NULL)
    BEGIN
        INSERT INTO [dbo].[Repuesto_Bodega_Stock]
            (rbs_cliente, rbs_repuesto, rbs_bodega, rbs_stock_minimo, rbs_stock_maximo,
             rbs_punto_reposicion, rbs_observacion, rbs_usuario_creacion,
             rbs_fecha_creacion, rbs_habilitado)
        VALUES (@CLIENTE, @REPUESTO, @BODEGA, @STOCK_MINIMO, @STOCK_MAXIMO,
                @PUNTO_REPOSICION, @OBSERVACION, @USUARIO, [dbo].[FNC_AHORA](), 1)

        SET @ID = SCOPE_IDENTITY()
    END
    ELSE
    BEGIN
        UPDATE  [dbo].[Repuesto_Bodega_Stock]
        SET     rbs_stock_minimo          = @STOCK_MINIMO
               ,rbs_stock_maximo          = @STOCK_MAXIMO
               ,rbs_punto_reposicion      = @PUNTO_REPOSICION
               ,rbs_observacion           = ISNULL(@OBSERVACION, rbs_observacion)
               ,rbs_habilitado            = 1
               ,rbs_usuario_actualizacion = @USUARIO
               ,rbs_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   rbs_id = @ID
    END

COMMIT TRANSACTION
RETURN 0
GO

-- ---------- UPS_SUSCRIPCION_PLAN (P) · 1 llamada(s) al reloj del servidor reemplazada(s) por FNC_AHORA
-- ---------- UPS_SUSCRIPCION_PLAN (P) · 7 [dbo].[FNC_AHORA]() reemplazado(s)
/* ========================================================================
   10. UPS_SUSCRIPCION_PLAN                                          §8

       Upgrade  -> inmediato. Se cierra el periodo actual y se emite uno
                   nuevo por los dias que faltaban, cobrando la DIFERENCIA
                   prorrateada. El cliente usa lo nuevo el mismo dia.

       Downgrade -> al cierre. No hay devolucion: evita el ciclo de subir
                   un mes, usar el predictivo y bajar.

       Lo que excede los limites del plan nuevo NO se borra (§8): queda en
       solo lectura. Este SP no borra nada; de mostrarlo se encarga la
       pantalla leyendo FNC_CLIENTE_LIMITE.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[UPS_SUSCRIPCION_PLAN]
@SUSCRIPCION     INT,
@PLAN_NUEVO      INT,
@PERIODICIDAD    INT = NULL,
@USUARIO         INT,
@PERIODO_NUEVO   INT = NULL OUTPUT,
@MOVIMIENTO      NVARCHAR(20) = NULL OUTPUT

AS
SET NOCOUNT ON

DECLARE @PLAN_ACTUAL INT, @UF_ACTUAL DECIMAL(18,4), @UF_NUEVO DECIMAL(18,4),
        @PERIODO INT, @INICIO DATE, @FIN DATE, @PERIODICIDAD_ACTUAL INT,
        @HOY DATE = CAST([dbo].[FNC_AHORA]() AS DATE),
        @DIAS_TOTAL INT, @DIAS_RESTAN INT,
        @UF_DIA DECIMAL(18,4), @UF_DIFERENCIA DECIMAL(18,4), @MONTO DECIMAL(18,2)

SET @PERIODO_NUEVO = NULL

BEGIN
    SELECT @PLAN_ACTUAL = sus_plan_comercial FROM [dbo].[Suscripcion] WHERE sus_id = @SUSCRIPCION

    IF @PLAN_ACTUAL IS NULL
    BEGIN
        RAISERROR('1.- LA SUSCRIPCIÓN NO EXISTE.', 16, 1)
        RETURN -1
    END

    IF @PLAN_ACTUAL = @PLAN_NUEVO
    BEGIN
        RAISERROR('2.- LA SUSCRIPCIÓN YA ESTÁ EN ESE PLAN.', 16, 1)
        RETURN -1
    END

    -- El periodo vigente: el que contiene el dia de hoy y esta pagado.
    SELECT TOP 1 @PERIODO = spe_id, @INICIO = spe_fecha_inicio, @FIN = spe_fecha_fin,
                 @PERIODICIDAD_ACTUAL = spe_periodicidad_cobro
      FROM [dbo].[Suscripcion_Periodo]
     WHERE spe_suscripcion = @SUSCRIPCION
       AND spe_habilitado = 1
       AND spe_fecha_inicio <= @HOY AND spe_fecha_fin >= @HOY
     ORDER BY spe_fecha_inicio DESC

    SET @PERIODICIDAD = ISNULL(@PERIODICIDAD, ISNULL(@PERIODICIDAD_ACTUAL, 1))

    /* El orden del plan define que es subir y que es bajar. Se compara por
       plc_orden y no por precio: el orden es la escalera declarada del
       modelo comercial. */
    IF (SELECT plc_orden FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_NUEVO) >
       (SELECT plc_orden FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_ACTUAL)
        SET @MOVIMIENTO = N'UPGRADE'
    ELSE
        SET @MOVIMIENTO = N'DOWNGRADE'
END

/* ---- DOWNGRADE: se anota y se aplica cuando termine el periodo ----
   No se toca el periodo vigente ni se devuelve nada. */
IF @MOVIMIENTO = N'DOWNGRADE'
BEGIN
    BEGIN TRANSACTION

        UPDATE  [dbo].[Suscripcion]
        SET     sus_observacion           = ISNULL(sus_observacion + N' | ', N'') +
                                            N'Downgrade a plan ' + LTRIM(STR(@PLAN_NUEVO)) +
                                            N' solicitado el ' + CONVERT(NVARCHAR(10), @HOY, 103) +
                                            N'; se aplica al cierre del período.',
                sus_usuario_actualizacion = @USUARIO,
                sus_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   sus_id = @SUSCRIPCION

    COMMIT TRANSACTION

    RETURN(0)
END

/* ---- UPGRADE: inmediato, cobrando la diferencia prorrateada ---- */
IF @PERIODO IS NULL
BEGIN
    -- Sin periodo vigente no hay nada que prorratear: se cambia el plan y
    -- el proximo periodo se emite ya con el nuevo.
    BEGIN TRANSACTION
        UPDATE  [dbo].[Suscripcion]
        SET     sus_plan_comercial        = @PLAN_NUEVO,
                sus_dias_gracia           = (SELECT plc_dias_gracia FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_NUEVO),
                sus_usuario_actualizacion = @USUARIO,
                sus_fecha_actualizacion   = [dbo].[FNC_AHORA]()
        WHERE   sus_id = @SUSCRIPCION
    COMMIT TRANSACTION

    RETURN(0)
END

SELECT TOP 1 @UF_ACTUAL = pcp_valor_uf FROM [dbo].[Plan_Comercial_Precio]
 WHERE pcp_plan_comercial = @PLAN_ACTUAL AND pcp_periodicidad_cobro = @PERIODICIDAD
   AND pcp_habilitado = 1 AND pcp_vigencia_desde <= @HOY
   AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @HOY)
 ORDER BY pcp_vigencia_desde DESC

SELECT TOP 1 @UF_NUEVO = pcp_valor_uf FROM [dbo].[Plan_Comercial_Precio]
 WHERE pcp_plan_comercial = @PLAN_NUEVO AND pcp_periodicidad_cobro = @PERIODICIDAD
   AND pcp_habilitado = 1 AND pcp_vigencia_desde <= @HOY
   AND (pcp_vigencia_hasta IS NULL OR pcp_vigencia_hasta >= @HOY)
 ORDER BY pcp_vigencia_desde DESC

IF @UF_NUEVO IS NULL OR @UF_ACTUAL IS NULL
BEGIN
    RAISERROR('3.- FALTA EL PRECIO VIGENTE DE ALGUNO DE LOS DOS PLANES PARA ESA PERIODICIDAD.', 16, 1)
    RETURN -1
END

SET @DIAS_TOTAL  = DATEDIFF(DAY, @INICIO, @FIN) + 1
SET @DIAS_RESTAN = DATEDIFF(DAY, @HOY, @FIN) + 1
SET @UF_DIA      = [dbo].[FNC_VALOR_UF](@HOY)

IF @UF_DIA IS NULL OR @UF_DIA <= 0
BEGIN
    RAISERROR('4.- NO HAY VALOR DE UF CARGADO. NO SE PUEDE PRORRATEAR EL CAMBIO DE PLAN.', 16, 1)
    RETURN -1
END

-- Solo los dias que faltaban, y solo la diferencia entre ambos planes.
SET @UF_DIFERENCIA = (@UF_NUEVO - @UF_ACTUAL) * (CAST(@DIAS_RESTAN AS DECIMAL(18,6)) / @DIAS_TOTAL)
SET @MONTO         = ROUND(@UF_DIFERENCIA * @UF_DIA, 0)

BEGIN TRANSACTION

    -- El periodo anterior se cierra hoy: deja de cubrir lo que viene.
    UPDATE  [dbo].[Suscripcion_Periodo]
    SET     spe_fecha_fin                  = @HOY,
            spe_suscripcion_periodo_estado = 4,          -- CERRADO
            spe_observacion                = ISNULL(spe_observacion + N' | ', N'') +
                                             N'Cerrado por upgrade de plan el ' + CONVERT(NVARCHAR(10), @HOY, 103) + N'.',
            spe_usuario_actualizacion      = @USUARIO,
            spe_fecha_actualizacion        = [dbo].[FNC_AHORA]()
    WHERE   spe_id = @PERIODO

    -- El periodo nuevo cubre los dias que quedaban, con la diferencia.
    INSERT [dbo].[Suscripcion_Periodo]
        (spe_suscripcion, spe_plan_comercial, spe_periodicidad_cobro,
         spe_fecha_inicio, spe_fecha_fin,
         spe_valor_uf_plan, spe_valor_uf_dia, spe_fecha_valor_uf,
         spe_monto_clp, spe_monto_pagado_clp, spe_suscripcion_periodo_estado,
         spe_es_implantacion, spe_observacion,
         spe_usuario_creacion, spe_fecha_creacion,
         spe_usuario_actualizacion, spe_fecha_actualizacion, spe_habilitado)
    VALUES
        (@SUSCRIPCION, @PLAN_NUEVO, @PERIODICIDAD,
         DATEADD(DAY, 1, @HOY), @FIN,
         @UF_DIFERENCIA, @UF_DIA, @HOY,
         @MONTO, 0,
         CASE WHEN @MONTO <= 0 THEN 3 ELSE 1 END,        -- sin diferencia, ya vigente
         0,
         N'Diferencia prorrateada por upgrade: ' + LTRIM(STR(@DIAS_RESTAN)) + N' de ' +
         LTRIM(STR(@DIAS_TOTAL)) + N' días.',
         @USUARIO, [dbo].[FNC_AHORA](), @USUARIO, [dbo].[FNC_AHORA](), 1)

    SET @PERIODO_NUEVO = SCOPE_IDENTITY()

    UPDATE  [dbo].[Suscripcion]
    SET     sus_plan_comercial        = @PLAN_NUEVO,
            sus_dias_gracia           = (SELECT plc_dias_gracia FROM [dbo].[Plan_Comercial] WHERE plc_id = @PLAN_NUEVO),
            sus_usuario_actualizacion = @USUARIO,
            sus_fecha_actualizacion   = [dbo].[FNC_AHORA]()
    WHERE   sus_id = @SUSCRIPCION

COMMIT TRANSACTION

RETURN(0)
GO

-- ---------- DEFAULT de auditoria
ALTER TABLE [dbo].[Activo] DROP CONSTRAINT [DF_ACT_FECHA_CREACION]
ALTER TABLE [dbo].[Activo] ADD CONSTRAINT [DF_ACT_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [act_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Atributo] DROP CONSTRAINT [DF_AAT_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Atributo] ADD CONSTRAINT [DF_AAT_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aat_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Componente] DROP CONSTRAINT [DF_ACO_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Componente] ADD CONSTRAINT [DF_ACO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aco_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Componente_Fusion] DROP CONSTRAINT [DF_ACF_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Componente_Fusion] ADD CONSTRAINT [DF_ACF_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [acf_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Estado_Historial] DROP CONSTRAINT [DF_AEH_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Estado_Historial] ADD CONSTRAINT [DF_AEH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aeh_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Fusion] DROP CONSTRAINT [DF_AFU_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Fusion] ADD CONSTRAINT [DF_AFU_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [afu_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Indisponibilidad] DROP CONSTRAINT [DF_AIN_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Indisponibilidad] ADD CONSTRAINT [DF_AIN_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ain_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Medicion] DROP CONSTRAINT [DF_AMD_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Medicion] ADD CONSTRAINT [DF_AMD_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [amd_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Medidor] DROP CONSTRAINT [DF_AME_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Medidor] ADD CONSTRAINT [DF_AME_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ame_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Medidor_Lectura] DROP CONSTRAINT [DF_AML_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Medidor_Lectura] ADD CONSTRAINT [DF_AML_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aml_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Modelo] DROP CONSTRAINT [DF_AMO_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Modelo] ADD CONSTRAINT [DF_AMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [amo_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Posicion] DROP CONSTRAINT [DF_APO_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Posicion] ADD CONSTRAINT [DF_APO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [apo_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Posicion_Historial] DROP CONSTRAINT [DF_APH_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Posicion_Historial] ADD CONSTRAINT [DF_APH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aph_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Tipo] DROP CONSTRAINT [DF_ATI_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Tipo] ADD CONSTRAINT [DF_ATI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ati_fecha_creacion]
GO
ALTER TABLE [dbo].[Activo_Variable] DROP CONSTRAINT [DF_AVA_FECHA_CREACION]
ALTER TABLE [dbo].[Activo_Variable] ADD CONSTRAINT [DF_AVA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ava_fecha_creacion]
GO
ALTER TABLE [dbo].[Alerta] DROP CONSTRAINT [DF_ALE_FECHA_CREACION]
ALTER TABLE [dbo].[Alerta] ADD CONSTRAINT [DF_ALE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ale_fecha_creacion]
GO
ALTER TABLE [dbo].[Alerta_Lectura] DROP CONSTRAINT [DF__Alerta_Le__alr_f__6C63F2D5]
ALTER TABLE [dbo].[Alerta_Lectura] ADD CONSTRAINT [DF__Alerta_Le__alr_f__6C63F2D5] DEFAULT ([dbo].[FNC_AHORA]()) FOR [alr_fecha]
GO
ALTER TABLE [dbo].[Analisis_Visual_Deteccion] DROP CONSTRAINT [DF_AVD_FECHA_CREACION]
ALTER TABLE [dbo].[Analisis_Visual_Deteccion] ADD CONSTRAINT [DF_AVD_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [avd_fecha_creacion]
GO
ALTER TABLE [dbo].[Analisis_Visual_Revision] DROP CONSTRAINT [DF_AVR_FECHA_CREACION]
ALTER TABLE [dbo].[Analisis_Visual_Revision] ADD CONSTRAINT [DF_AVR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [avr_fecha_creacion]
GO
ALTER TABLE [dbo].[Archivo] DROP CONSTRAINT [DF_ARC_FECHA_CREACION]
ALTER TABLE [dbo].[Archivo] ADD CONSTRAINT [DF_ARC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [arc_fecha_creacion]
GO
ALTER TABLE [dbo].[Archivo_Analisis_Visual] DROP CONSTRAINT [DF_AAV_FECHA_CREACION]
ALTER TABLE [dbo].[Archivo_Analisis_Visual] ADD CONSTRAINT [DF_AAV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aav_fecha_creacion]
GO
ALTER TABLE [dbo].[Archivo_Carga] DROP CONSTRAINT [DF_ACG_FECHA_CREACION]
ALTER TABLE [dbo].[Archivo_Carga] ADD CONSTRAINT [DF_ACG_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [acg_fecha_creacion]
GO
ALTER TABLE [dbo].[Archivo_Categoria] DROP CONSTRAINT [DF_ACA_FECHA_CREACION]
ALTER TABLE [dbo].[Archivo_Categoria] ADD CONSTRAINT [DF_ACA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [aca_fecha_creacion]
GO
ALTER TABLE [dbo].[Archivo_Vinculo] DROP CONSTRAINT [DF_AVI_FECHA_CREACION]
ALTER TABLE [dbo].[Archivo_Vinculo] ADD CONSTRAINT [DF_AVI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [avi_fecha_creacion]
GO
ALTER TABLE [dbo].[Atributo_Tecnico] DROP CONSTRAINT [DF_ATE_FECHA_CREACION]
ALTER TABLE [dbo].[Atributo_Tecnico] ADD CONSTRAINT [DF_ATE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ate_fecha_creacion]
GO
ALTER TABLE [dbo].[Bitacora] DROP CONSTRAINT [DF_BIT_FECHA_CREACION]
ALTER TABLE [dbo].[Bitacora] ADD CONSTRAINT [DF_BIT_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [bit_fecha_creacion]
GO
ALTER TABLE [dbo].[Bitacora_Comentario] DROP CONSTRAINT [DF_BCO_FECHA_CREACION]
ALTER TABLE [dbo].[Bitacora_Comentario] ADD CONSTRAINT [DF_BCO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [bco_fecha_creacion]
GO
ALTER TABLE [dbo].[Bitacora_Rectificacion] DROP CONSTRAINT [DF_BRE_FECHA_CREACION]
ALTER TABLE [dbo].[Bitacora_Rectificacion] ADD CONSTRAINT [DF_BRE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [bre_fecha_creacion]
GO
ALTER TABLE [dbo].[Bodega] DROP CONSTRAINT [DF_BOD_FECHA_CREACION]
ALTER TABLE [dbo].[Bodega] ADD CONSTRAINT [DF_BOD_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [bod_fecha_creacion]
GO
ALTER TABLE [dbo].[Bodega_Ubicacion] DROP CONSTRAINT [DF_BUB_FECHA_CREACION]
ALTER TABLE [dbo].[Bodega_Ubicacion] ADD CONSTRAINT [DF_BUB_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [bub_fecha_creacion]
GO
ALTER TABLE [dbo].[Caracteristica_Modelo] DROP CONSTRAINT [DF_CMO_FECHA_CREACION]
ALTER TABLE [dbo].[Caracteristica_Modelo] ADD CONSTRAINT [DF_CMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cmo_fecha_creacion]
GO
ALTER TABLE [dbo].[Centro_Costo] DROP CONSTRAINT [DF_CCO_FECHA_CREACION]
ALTER TABLE [dbo].[Centro_Costo] ADD CONSTRAINT [DF_CCO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cco_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Ejecucion] DROP CONSTRAINT [DF_CEJ_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Ejecucion] ADD CONSTRAINT [DF_CEJ_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cej_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Ejecucion_Respuesta] DROP CONSTRAINT [DF_CER_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Ejecucion_Respuesta] ADD CONSTRAINT [DF_CER_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cer_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Hallazgo] DROP CONSTRAINT [DF_CHA_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Hallazgo] ADD CONSTRAINT [DF_CHA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cha_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Item_Dependencia] DROP CONSTRAINT [DF_CID_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Item_Dependencia] ADD CONSTRAINT [DF_CID_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cid_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Item_Opcion] DROP CONSTRAINT [DF_CIO_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Item_Opcion] ADD CONSTRAINT [DF_CIO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cio_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Item_Validacion] DROP CONSTRAINT [DF_CIV_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Item_Validacion] ADD CONSTRAINT [DF_CIV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [civ_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Ocurrencia] DROP CONSTRAINT [DF_COC_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Ocurrencia] ADD CONSTRAINT [DF_COC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [coc_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Ocurrencia_Asignacion] DROP CONSTRAINT [DF_COA_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Ocurrencia_Asignacion] ADD CONSTRAINT [DF_COA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [coa_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Ocurrencia_Historial] DROP CONSTRAINT [DF_COH_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Ocurrencia_Historial] ADD CONSTRAINT [DF_COH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [coh_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Plantilla] DROP CONSTRAINT [DF_CPL_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Plantilla] ADD CONSTRAINT [DF_CPL_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cpl_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Plantilla_Item] DROP CONSTRAINT [DF_CPI_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Plantilla_Item] ADD CONSTRAINT [DF_CPI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cpi_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Plantilla_Seccion] DROP CONSTRAINT [DF_CPS_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Plantilla_Seccion] ADD CONSTRAINT [DF_CPS_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cps_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Plantilla_Version] DROP CONSTRAINT [DF_CPV_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Plantilla_Version] ADD CONSTRAINT [DF_CPV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cpv_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Programacion] DROP CONSTRAINT [DF_CPR_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Programacion] ADD CONSTRAINT [DF_CPR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cpr_fecha_creacion]
GO
ALTER TABLE [dbo].[Checklist_Respuesta_Opcion] DROP CONSTRAINT [DF_CRO_FECHA_CREACION]
ALTER TABLE [dbo].[Checklist_Respuesta_Opcion] ADD CONSTRAINT [DF_CRO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cro_fecha_creacion]
GO
ALTER TABLE [dbo].[Cliente_Binario] DROP CONSTRAINT [DF_CLB_FECHA_CREACION]
ALTER TABLE [dbo].[Cliente_Binario] ADD CONSTRAINT [DF_CLB_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [clb_fecha_creacion]
GO
ALTER TABLE [dbo].[Cliente_Contacto] DROP CONSTRAINT [DF_CCN_FECHA_CREACION]
ALTER TABLE [dbo].[Cliente_Contacto] ADD CONSTRAINT [DF_CCN_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ccn_fecha_creacion]
GO
ALTER TABLE [dbo].[Cliente_Usuario_Permiso] DROP CONSTRAINT [DF_CPM_FECHA_CREACION]
ALTER TABLE [dbo].[Cliente_Usuario_Permiso] ADD CONSTRAINT [DF_CPM_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cpm_fecha_creacion]
GO
ALTER TABLE [dbo].[Componente_Posicion] DROP CONSTRAINT [DF_CPN_FECHA_CREACION]
ALTER TABLE [dbo].[Componente_Posicion] ADD CONSTRAINT [DF_CPN_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cpn_fecha_creacion]
GO
ALTER TABLE [dbo].[Componente_Repuesto_Instalacion] DROP CONSTRAINT [DF_CRI_FECHA_CREACION]
ALTER TABLE [dbo].[Componente_Repuesto_Instalacion] ADD CONSTRAINT [DF_CRI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cri_fecha_creacion]
GO
ALTER TABLE [dbo].[Componente_Tipo] DROP CONSTRAINT [DF_CTO_FECHA_CREACION]
ALTER TABLE [dbo].[Componente_Tipo] ADD CONSTRAINT [DF_CTO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [cto_fecha_creacion]
GO
ALTER TABLE [dbo].[Dataset_Entrenamiento] DROP CONSTRAINT [DF_DEN_FECHA_CREACION]
ALTER TABLE [dbo].[Dataset_Entrenamiento] ADD CONSTRAINT [DF_DEN_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [den_fecha_creacion]
GO
ALTER TABLE [dbo].[Diagnostico_Metodo] DROP CONSTRAINT [DF_DME_FECHA_CREACION]
ALTER TABLE [dbo].[Diagnostico_Metodo] ADD CONSTRAINT [DF_DME_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [dme_fecha_creacion]
GO
ALTER TABLE [dbo].[Dictado_Voz] DROP CONSTRAINT [DF_DVO_FECHA_CREACION]
ALTER TABLE [dbo].[Dictado_Voz] ADD CONSTRAINT [DF_DVO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [dvo_fecha_creacion]
GO
ALTER TABLE [dbo].[Entrenamiento_Ejecucion] DROP CONSTRAINT [DF_EEJ_FECHA_CREACION]
ALTER TABLE [dbo].[Entrenamiento_Ejecucion] ADD CONSTRAINT [DF_EEJ_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [eej_fecha_creacion]
GO
ALTER TABLE [dbo].[Especialidad] DROP CONSTRAINT [DF_ESP_FECHA_CREACION]
ALTER TABLE [dbo].[Especialidad] ADD CONSTRAINT [DF_ESP_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [esp_fecha_creacion]
GO
ALTER TABLE [dbo].[Falla] DROP CONSTRAINT [DF_FAL_FECHA_CREACION]
ALTER TABLE [dbo].[Falla] ADD CONSTRAINT [DF_FAL_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [fal_fecha_creacion]
GO
ALTER TABLE [dbo].[Falla_Accion] DROP CONSTRAINT [DF_FAC_FECHA_CREACION]
ALTER TABLE [dbo].[Falla_Accion] ADD CONSTRAINT [DF_FAC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [fac_fecha_creacion]
GO
ALTER TABLE [dbo].[Falla_Causa] DROP CONSTRAINT [DF_FCA_FECHA_CREACION]
ALTER TABLE [dbo].[Falla_Causa] ADD CONSTRAINT [DF_FCA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [fca_fecha_creacion]
GO
ALTER TABLE [dbo].[Falla_Diagnostico] DROP CONSTRAINT [DF_FDI_FECHA_CREACION]
ALTER TABLE [dbo].[Falla_Diagnostico] ADD CONSTRAINT [DF_FDI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [fdi_fecha_creacion]
GO
ALTER TABLE [dbo].[Falla_Modo] DROP CONSTRAINT [DF_FMO_FECHA_CREACION]
ALTER TABLE [dbo].[Falla_Modo] ADD CONSTRAINT [DF_FMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [fmo_fecha_creacion]
GO
ALTER TABLE [dbo].[Falla_Sintoma] DROP CONSTRAINT [DF_FSI_FECHA_CREACION]
ALTER TABLE [dbo].[Falla_Sintoma] ADD CONSTRAINT [DF_FSI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [fsi_fecha_creacion]
GO
ALTER TABLE [dbo].[Grupo_Trabajo] DROP CONSTRAINT [DF_GTR_FECHA_CREACION]
ALTER TABLE [dbo].[Grupo_Trabajo] ADD CONSTRAINT [DF_GTR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [gtr_fecha_creacion]
GO
ALTER TABLE [dbo].[Grupo_Trabajo_Usuario] DROP CONSTRAINT [DF_GTU_FECHA_CREACION]
ALTER TABLE [dbo].[Grupo_Trabajo_Usuario] ADD CONSTRAINT [DF_GTU_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [gtu_fecha_creacion]
GO
ALTER TABLE [dbo].[Grupo_Trabajo_Usuario] DROP CONSTRAINT [DF_GTU_FECHA_INICIO]
ALTER TABLE [dbo].[Grupo_Trabajo_Usuario] ADD CONSTRAINT [DF_GTU_FECHA_INICIO] DEFAULT ([dbo].[FNC_AHORA]()) FOR [gtu_fecha_inicio]
GO
ALTER TABLE [dbo].[Idioma] DROP CONSTRAINT [DF_IDI_FECHA_CREACION]
ALTER TABLE [dbo].[Idioma] ADD CONSTRAINT [DF_IDI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [idi_fecha_creacion]
GO
ALTER TABLE [dbo].[Importacion_Carga] DROP CONSTRAINT [DF_ICA_FECHA_CREACION]
ALTER TABLE [dbo].[Importacion_Carga] ADD CONSTRAINT [DF_ICA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ica_fecha_creacion]
GO
ALTER TABLE [dbo].[Importacion_Carga_Celda] DROP CONSTRAINT [DF_ICC_FECHA_CREACION]
ALTER TABLE [dbo].[Importacion_Carga_Celda] ADD CONSTRAINT [DF_ICC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [icc_fecha_creacion]
GO
ALTER TABLE [dbo].[Indisponibilidad_Motivo] DROP CONSTRAINT [DF_INM_FECHA_CREACION]
ALTER TABLE [dbo].[Indisponibilidad_Motivo] ADD CONSTRAINT [DF_INM_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [inm_fecha_creacion]
GO
ALTER TABLE [dbo].[Instalacion_Area] DROP CONSTRAINT [DF_IAR_FECHA_CREACION]
ALTER TABLE [dbo].[Instalacion_Area] ADD CONSTRAINT [DF_IAR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [iar_fecha_creacion]
GO
ALTER TABLE [dbo].[Inventario_Movimiento] DROP CONSTRAINT [DF_IMO_FECHA_CREACION]
ALTER TABLE [dbo].[Inventario_Movimiento] ADD CONSTRAINT [DF_IMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [imo_fecha_creacion]
GO
ALTER TABLE [dbo].[Modelo_Monitoreo] DROP CONSTRAINT [DF_MMO_FECHA_CREACION]
ALTER TABLE [dbo].[Modelo_Monitoreo] ADD CONSTRAINT [DF_MMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [mmo_fecha_creacion]
GO
ALTER TABLE [dbo].[Modelo_Predictivo] DROP CONSTRAINT [DF_MPR_FECHA_CREACION]
ALTER TABLE [dbo].[Modelo_Predictivo] ADD CONSTRAINT [DF_MPR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [mpr_fecha_creacion]
GO
ALTER TABLE [dbo].[Modelo_Predictivo_Version] DROP CONSTRAINT [DF_MPV_FECHA_CREACION]
ALTER TABLE [dbo].[Modelo_Predictivo_Version] ADD CONSTRAINT [DF_MPV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [mpv_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo] DROP CONSTRAINT [DF_OTR_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo] ADD CONSTRAINT [DF_OTR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [otr_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Asignacion] DROP CONSTRAINT [DF_OTA_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Asignacion] ADD CONSTRAINT [DF_OTA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ota_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Checklist] DROP CONSTRAINT [DF_OTC_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Checklist] ADD CONSTRAINT [DF_OTC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [otc_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Especialidad] DROP CONSTRAINT [DF_OEP_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Especialidad] ADD CONSTRAINT [DF_OEP_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [oep_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Estado_Historial] DROP CONSTRAINT [DF_OEH_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Estado_Historial] ADD CONSTRAINT [DF_OEH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [oeh_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Mano_Obra] DROP CONSTRAINT [DF_OMO_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Mano_Obra] ADD CONSTRAINT [DF_OMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [omo_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Paso] DROP CONSTRAINT [DF_OTP_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Paso] ADD CONSTRAINT [DF_OTP_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [otp_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Repuesto] DROP CONSTRAINT [DF_ORE_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Repuesto] ADD CONSTRAINT [DF_ORE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ore_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Servicio] DROP CONSTRAINT [DF_OTS_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Servicio] ADD CONSTRAINT [DF_OTS_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ots_fecha_creacion]
GO
ALTER TABLE [dbo].[Orden_Trabajo_Validacion] DROP CONSTRAINT [DF_OTV_FECHA_CREACION]
ALTER TABLE [dbo].[Orden_Trabajo_Validacion] ADD CONSTRAINT [DF_OTV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [otv_fecha_creacion]
GO
ALTER TABLE [dbo].[Perfil_Permiso] DROP CONSTRAINT [DF_PPE_FECHA_CREACION]
ALTER TABLE [dbo].[Perfil_Permiso] ADD CONSTRAINT [DF_PPE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ppe_fecha_creacion]
GO
ALTER TABLE [dbo].[Permiso] DROP CONSTRAINT [DF_PRM_FECHA_CREACION]
ALTER TABLE [dbo].[Permiso] ADD CONSTRAINT [DF_PRM_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [prm_fecha_creacion]
GO
ALTER TABLE [dbo].[Permiso_Trabajo] DROP CONSTRAINT [DF_PTR_FECHA_CREACION]
ALTER TABLE [dbo].[Permiso_Trabajo] ADD CONSTRAINT [DF_PTR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ptr_fecha_creacion]
GO
ALTER TABLE [dbo].[Permiso_Trabajo_Tipo] DROP CONSTRAINT [DF_PTT_FECHA_CREACION]
ALTER TABLE [dbo].[Permiso_Trabajo_Tipo] ADD CONSTRAINT [DF_PTT_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ptt_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Actividad_Checklist] DROP CONSTRAINT [DF_PCK_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Actividad_Checklist] ADD CONSTRAINT [DF_PCK_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pck_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Actividad_Especialidad] DROP CONSTRAINT [DF_PAE_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Actividad_Especialidad] ADD CONSTRAINT [DF_PAE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pae_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Actividad_Repuesto] DROP CONSTRAINT [DF_PRA_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Actividad_Repuesto] ADD CONSTRAINT [DF_PRA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pra_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Comercial] DROP CONSTRAINT [DF_PLC_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Comercial] ADD CONSTRAINT [DF_PLC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [plc_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Comercial_Funcionalidad] DROP CONSTRAINT [DF_PCF_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Comercial_Funcionalidad] ADD CONSTRAINT [DF_PCF_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pcf_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Comercial_Precio] DROP CONSTRAINT [DF_PCP_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Comercial_Precio] ADD CONSTRAINT [DF_PCP_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pcp_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Mantenimiento] DROP CONSTRAINT [DF_PMA_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Mantenimiento] ADD CONSTRAINT [DF_PMA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pma_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Mantenimiento_Actividad] DROP CONSTRAINT [DF_PAA_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Mantenimiento_Actividad] ADD CONSTRAINT [DF_PAA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [paa_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Mantenimiento_Activo] DROP CONSTRAINT [DF_PAC_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Mantenimiento_Activo] ADD CONSTRAINT [DF_PAC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pac_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Mantenimiento_Hito] DROP CONSTRAINT [DF_PMH_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Mantenimiento_Hito] ADD CONSTRAINT [DF_PMH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pmh_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Mantenimiento_Ocurrencia] DROP CONSTRAINT [DF_PMO_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Mantenimiento_Ocurrencia] ADD CONSTRAINT [DF_PMO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pmo_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Mantenimiento_Version] DROP CONSTRAINT [DF_PMV_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Mantenimiento_Version] ADD CONSTRAINT [DF_PMV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pmv_fecha_creacion]
GO
ALTER TABLE [dbo].[Plan_Ocurrencia_Historial] DROP CONSTRAINT [DF_POH_FECHA_CREACION]
ALTER TABLE [dbo].[Plan_Ocurrencia_Historial] ADD CONSTRAINT [DF_POH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [poh_fecha_creacion]
GO
ALTER TABLE [dbo].[Prediccion] DROP CONSTRAINT [DF_PRE_FECHA_CREACION]
ALTER TABLE [dbo].[Prediccion] ADD CONSTRAINT [DF_PRE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pre_fecha_creacion]
GO
ALTER TABLE [dbo].[Prediccion_Caracteristica] DROP CONSTRAINT [DF_PCR_FECHA_CREACION]
ALTER TABLE [dbo].[Prediccion_Caracteristica] ADD CONSTRAINT [DF_PCR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pcr_fecha_creacion]
GO
ALTER TABLE [dbo].[Prediccion_Explicacion] DROP CONSTRAINT [DF_PEX_FECHA_CREACION]
ALTER TABLE [dbo].[Prediccion_Explicacion] ADD CONSTRAINT [DF_PEX_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pex_fecha_creacion]
GO
ALTER TABLE [dbo].[Prediccion_Resultado] DROP CONSTRAINT [DF_PRS_FECHA_CREACION]
ALTER TABLE [dbo].[Prediccion_Resultado] ADD CONSTRAINT [DF_PRS_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [prs_fecha_creacion]
GO
ALTER TABLE [dbo].[Privacidad_Modulos_Sistema] DROP CONSTRAINT [DF_PMS_FECHA_ACT]
ALTER TABLE [dbo].[Privacidad_Modulos_Sistema] ADD CONSTRAINT [DF_PMS_FECHA_ACT] DEFAULT ([dbo].[FNC_AHORA]()) FOR [PMS_FECHA_ACT]
GO
ALTER TABLE [dbo].[Privacidad_Modulos_Sistema] DROP CONSTRAINT [DF_PMS_FECHA_CREACION]
ALTER TABLE [dbo].[Privacidad_Modulos_Sistema] ADD CONSTRAINT [DF_PMS_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [PMS_FECHA_CREACION]
GO
ALTER TABLE [dbo].[Procedimiento] DROP CONSTRAINT [DF_PRC_FECHA_CREACION]
ALTER TABLE [dbo].[Procedimiento] ADD CONSTRAINT [DF_PRC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [prc_fecha_creacion]
GO
ALTER TABLE [dbo].[Procedimiento_Paso] DROP CONSTRAINT [DF_PPA_FECHA_CREACION]
ALTER TABLE [dbo].[Procedimiento_Paso] ADD CONSTRAINT [DF_PPA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ppa_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion] DROP CONSTRAINT [DF_PRO_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion] ADD CONSTRAINT [DF_PRO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pro_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Calendario] DROP CONSTRAINT [DF_PCA_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion_Calendario] ADD CONSTRAINT [DF_PCA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pca_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Condicion] DROP CONSTRAINT [DF_PCO_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion_Condicion] ADD CONSTRAINT [DF_PCO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pco_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Exclusion] DROP CONSTRAINT [DF_PXC_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion_Exclusion] ADD CONSTRAINT [DF_PXC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pxc_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Generacion] DROP CONSTRAINT [DF_PGE_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion_Generacion] ADD CONSTRAINT [DF_PGE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pge_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Intervalo] DROP CONSTRAINT [DF_PIN_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion_Intervalo] ADD CONSTRAINT [DF_PIN_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pin_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Medidor] DROP CONSTRAINT [DF_PME_FECHA_CREACION]
ALTER TABLE [dbo].[Programacion_Medidor] ADD CONSTRAINT [DF_PME_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [pme_fecha_creacion]
GO
ALTER TABLE [dbo].[Programacion_Responsable] DROP CONSTRAINT [DF_PRR_FECHA]
ALTER TABLE [dbo].[Programacion_Responsable] ADD CONSTRAINT [DF_PRR_FECHA] DEFAULT ([dbo].[FNC_AHORA]()) FOR [prr_fecha_creacion]
GO
ALTER TABLE [dbo].[Proveedor] DROP CONSTRAINT [DF_PRV_FECHA_CREACION]
ALTER TABLE [dbo].[Proveedor] ADD CONSTRAINT [DF_PRV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [prv_fecha_creacion]
GO
ALTER TABLE [dbo].[Registro_Descubrimiento] DROP CONSTRAINT [DF_RDE_FECHA_CREACION]
ALTER TABLE [dbo].[Registro_Descubrimiento] ADD CONSTRAINT [DF_RDE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rde_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto] DROP CONSTRAINT [DF_REP_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto] ADD CONSTRAINT [DF_REP_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rep_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Bodega_Stock] DROP CONSTRAINT [DF_RBS_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Bodega_Stock] ADD CONSTRAINT [DF_RBS_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rbs_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Compatibilidad] DROP CONSTRAINT [DF_RCO_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Compatibilidad] ADD CONSTRAINT [DF_RCO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rco_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Estado_Final] DROP CONSTRAINT [DF_REF_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Estado_Final] ADD CONSTRAINT [DF_REF_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ref_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Fusion] DROP CONSTRAINT [DF_RFU_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Fusion] ADD CONSTRAINT [DF_RFU_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rfu_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Lote] DROP CONSTRAINT [DF_RLO_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Lote] ADD CONSTRAINT [DF_RLO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rlo_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Retiro_Motivo] DROP CONSTRAINT [DF_RRM_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Retiro_Motivo] ADD CONSTRAINT [DF_RRM_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rrm_fecha_creacion]
GO
ALTER TABLE [dbo].[Repuesto_Tipo] DROP CONSTRAINT [DF_RTI_FECHA_CREACION]
ALTER TABLE [dbo].[Repuesto_Tipo] ADD CONSTRAINT [DF_RTI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [rti_fecha_creacion]
GO
ALTER TABLE [dbo].[Servicio_Tipo] DROP CONSTRAINT [DF_STI_FECHA_CREACION]
ALTER TABLE [dbo].[Servicio_Tipo] ADD CONSTRAINT [DF_STI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [sti_fecha_creacion]
GO
ALTER TABLE [dbo].[Suscripcion] DROP CONSTRAINT [DF_SUS_FECHA_CREACION]
ALTER TABLE [dbo].[Suscripcion] ADD CONSTRAINT [DF_SUS_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [sus_fecha_creacion]
GO
ALTER TABLE [dbo].[Suscripcion_Bloqueo_Log] DROP CONSTRAINT [DF_SBL_FECHA_CREACION]
ALTER TABLE [dbo].[Suscripcion_Bloqueo_Log] ADD CONSTRAINT [DF_SBL_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [sbl_fecha_creacion]
GO
ALTER TABLE [dbo].[Suscripcion_Consumo] DROP CONSTRAINT [DF_SCO_FECHA_CREACION]
ALTER TABLE [dbo].[Suscripcion_Consumo] ADD CONSTRAINT [DF_SCO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [sco_fecha_creacion]
GO
ALTER TABLE [dbo].[Suscripcion_Key_Historial] DROP CONSTRAINT [DF_SKH_FECHA_CREACION]
ALTER TABLE [dbo].[Suscripcion_Key_Historial] ADD CONSTRAINT [DF_SKH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [skh_fecha_creacion]
GO
ALTER TABLE [dbo].[Suscripcion_Pago] DROP CONSTRAINT [DF_SPA_FECHA_CREACION]
ALTER TABLE [dbo].[Suscripcion_Pago] ADD CONSTRAINT [DF_SPA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [spa_fecha_creacion]
GO
ALTER TABLE [dbo].[Suscripcion_Periodo] DROP CONSTRAINT [DF_SPE_FECHA_CREACION]
ALTER TABLE [dbo].[Suscripcion_Periodo] ADD CONSTRAINT [DF_SPE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [spe_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea] DROP CONSTRAINT [DF_TAR_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea] ADD CONSTRAINT [DF_TAR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [tar_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Categoria] DROP CONSTRAINT [DF_TCA_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Categoria] ADD CONSTRAINT [DF_TCA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [tca_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Checklist] DROP CONSTRAINT [DF_TCK_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Checklist] ADD CONSTRAINT [DF_TCK_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [tck_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Comentario] DROP CONSTRAINT [DF_TCO_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Comentario] ADD CONSTRAINT [DF_TCO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [tco_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Ejecucion] DROP CONSTRAINT [DF_TEJ_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Ejecucion] ADD CONSTRAINT [DF_TEJ_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [tej_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Historial] DROP CONSTRAINT [DF_THI_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Historial] ADD CONSTRAINT [DF_THI_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [thi_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Ocurrencia] DROP CONSTRAINT [DF_TOC_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Ocurrencia] ADD CONSTRAINT [DF_TOC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [toc_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Ocurrencia_Asignacion] DROP CONSTRAINT [DF_TOA_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Ocurrencia_Asignacion] ADD CONSTRAINT [DF_TOA_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [toa_fecha_creacion]
GO
ALTER TABLE [dbo].[Tarea_Programacion] DROP CONSTRAINT [DF_TPR_FECHA_CREACION]
ALTER TABLE [dbo].[Tarea_Programacion] ADD CONSTRAINT [DF_TPR_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [tpr_fecha_creacion]
GO
ALTER TABLE [dbo].[Unidad_Medida] DROP CONSTRAINT [DF_UME_FECHA_CREACION]
ALTER TABLE [dbo].[Unidad_Medida] ADD CONSTRAINT [DF_UME_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ume_fecha_creacion]
GO
ALTER TABLE [dbo].[Usuario_Accesibilidad] DROP CONSTRAINT [DF_UAC_FECHA_CREACION]
ALTER TABLE [dbo].[Usuario_Accesibilidad] ADD CONSTRAINT [DF_UAC_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [uac_fecha_creacion]
GO
ALTER TABLE [dbo].[Usuario_App_Dispositivo] DROP CONSTRAINT [DF__Usuario_A__uad_f__6B4FD30B]
ALTER TABLE [dbo].[Usuario_App_Dispositivo] ADD CONSTRAINT [DF__Usuario_A__uad_f__6B4FD30B] DEFAULT ([dbo].[FNC_AHORA]()) FOR [uad_fecha]
GO
ALTER TABLE [dbo].[Usuario_Especialidad] DROP CONSTRAINT [DF_UES_FECHA_CREACION]
ALTER TABLE [dbo].[Usuario_Especialidad] ADD CONSTRAINT [DF_UES_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ues_fecha_creacion]
GO
ALTER TABLE [dbo].[Usuario_Favorito] DROP CONSTRAINT [DF_UFV_FECHA_CREACION]
ALTER TABLE [dbo].[Usuario_Favorito] ADD CONSTRAINT [DF_UFV_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ufv_fecha_creacion]
GO
ALTER TABLE [dbo].[Usuario_Password_Historial] DROP CONSTRAINT [DF_UPH_FECHA_CREACION]
ALTER TABLE [dbo].[Usuario_Password_Historial] ADD CONSTRAINT [DF_UPH_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [uph_fecha_creacion]
GO
ALTER TABLE [dbo].[Usuario_Recuperacion] DROP CONSTRAINT [DF_URE_FECHA_CREACION]
ALTER TABLE [dbo].[Usuario_Recuperacion] ADD CONSTRAINT [DF_URE_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [ure_fecha_creacion]
GO
ALTER TABLE [dbo].[Valor_Uf] DROP CONSTRAINT [DF_VUF_FECHA_CREACION]
ALTER TABLE [dbo].[Valor_Uf] ADD CONSTRAINT [DF_VUF_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [vuf_fecha_creacion]
GO
ALTER TABLE [dbo].[Variable_Medicion] DROP CONSTRAINT [DF_VME_FECHA_CREACION]
ALTER TABLE [dbo].[Variable_Medicion] ADD CONSTRAINT [DF_VME_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [vme_fecha_creacion]
GO
ALTER TABLE [dbo].[Zona_Horaria] DROP CONSTRAINT [DF_ZHO_FECHA_CREACION]
ALTER TABLE [dbo].[Zona_Horaria] ADD CONSTRAINT [DF_ZHO_FECHA_CREACION] DEFAULT ([dbo].[FNC_AHORA]()) FOR [zho_fecha_creacion]
GO

PRINT '--- Hora de Santiago aplicada'
GO
