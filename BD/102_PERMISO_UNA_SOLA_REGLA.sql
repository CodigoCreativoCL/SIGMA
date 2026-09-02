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
    DECLARE @HOY             DATE = CAST(GETDATE() AS DATE)
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

    DECLARE @HOY DATE = CAST(GETDATE() AS DATE)

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


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'la funcion mira el perfil de plataforma' AS OBJETO,
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('FNC_USUARIO_TIENE_PERMISO')
            AND definition LIKE '%per_tipo = 1%') AS HAY, 1 AS ESPERADO
UNION ALL
SELECT  'el SP filtra el espejo por tipo',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_USUARIO_PERMISOS')
            AND definition LIKE '%per.per_tipo = 1%'), 1
UNION ALL
SELECT  'el SP aplica la autorizacion de planta',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('SEL_USUARIO_PERMISOS')
            AND definition LIKE '%Cliente_Instalacion_Usuario%'), 1
GO
