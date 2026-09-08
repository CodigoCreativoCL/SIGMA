USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  08-09-2026
-- DESCRIPTION:     LOS PERFILES QUE EL 194 DEJO SIN ALERTAS SIN QUERERLO.
-- =============================================
-- QUE PASO
--
--   BD/194 movio las alertas de VER ACTIVOS y VER EXISTENCIAS a los dos
--   permisos nuevos, y los asigno a los cinco perfiles de los que se hablo:
--   Bodeguero, Jefe, Planificador, Supervisor y Tecnico.
--
--   Pero habia CUATRO perfiles mas que recibian alertas por tener VER ACTIVOS
--   o VER EXISTENCIAS, y al cambiar el liston se quedaron sin ninguna sin que
--   nadie lo pidiera. Se detecto comprobando FNC_USUARIO_TIENE_PERMISO usuario
--   por usuario despues de aplicar el 194: el Administrador del Cliente salia
--   con mantenimiento=0 e inventario=0.
--
--   Quitarle a alguien lo que tenia es un cambio; hacerlo sin decidirlo es un
--   descuido. Este script devuelve a cada uno lo que ya recibia, ni mas.
--
-- QUIEN VUELVE Y POR QUE
--
--   Administrador del Cliente (10) -> LAS DOS. Tenia VER ACTIVOS, VER
--     EXISTENCIAS y VER REPUESTOS: recibia todo, y es quien administra la
--     empresa dentro de la plataforma.
--
--   Soporte (2) -> INVENTARIO. Tenia VER EXISTENCIAS y VER REPUESTOS, no
--     VER ACTIVOS: recibia las de stock y lote, no las de mantenimiento. Se
--     respeta ese alcance.
--
--   Prevencionista de Riesgos (16) -> MANTENIMIENTO. No tenia ninguno de los
--     dos, asi que por el liston viejo no recibia nada; pero SI tiene VER
--     PERMISOS TRABAJO, y PERMISO VENCIDO es exactamente su alerta. Es el
--     unico caso en que se AGREGA algo en vez de devolverlo, y se agrega
--     porque un permiso de trabajo vencido sin que lo sepa el prevencionista
--     es el aviso llegando a todos menos a quien le toca actuar.
--
--   Gerente Comercial (3) -> NINGUNA. No tenia VER ACTIVOS ni VER
--     EXISTENCIAS, asi que no recibia alertas de planta y sigue igual. No es
--     un olvido: es un perfil comercial.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @MANT INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS MANTENIMIENTO')
DECLARE @INV  INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'VER ALERTAS INVENTARIO')

IF (@MANT IS NULL OR @INV IS NULL)
BEGIN
    RAISERROR('1.- FALTAN LOS PERMISOS DE AMBITO. APLIQUE BD/194 PRIMERO.', 16, 1)
    RETURN
END

DECLARE @DESTINO TABLE (perfil INT, permiso INT)

INSERT INTO @DESTINO (perfil, permiso) VALUES
    (10, @MANT),   -- Administrador del Cliente: recibia todo
    (10, @INV),
    (2,  @INV),    -- Soporte: solo inventario, como antes
    (16, @MANT)    -- Prevencionista: PERMISO VENCIDO es su alerta

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT d.perfil, d.permiso, 1, GETDATE()
FROM @DESTINO d
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                   WHERE ppe_perfil = d.perfil AND ppe_permiso = d.permiso)
GO

-- ---------------------------------------------------------------------------
-- Verificacion: los nueve perfiles, y que recibe cada uno
-- ---------------------------------------------------------------------------
SELECT pf.per_nombre COLLATE DATABASE_DEFAULT + ' | mantenimiento=' +
       CAST(MAX(CASE WHEN p.prm_codigo = 'VER ALERTAS MANTENIMIENTO' THEN 1 ELSE 0 END) AS VARCHAR) +
       ' inventario=' +
       CAST(MAX(CASE WHEN p.prm_codigo = 'VER ALERTAS INVENTARIO' THEN 1 ELSE 0 END) AS VARCHAR)
       AS RESULTADO
FROM [dbo].[Perfiles] pf
LEFT JOIN [dbo].[Perfil_Permiso] pp ON pp.ppe_perfil = pf.per_id
LEFT JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
WHERE pf.per_habilitado = 1
GROUP BY pf.per_id, pf.per_nombre
ORDER BY 1
GO
