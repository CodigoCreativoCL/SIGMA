USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EQUIPO SIGMA
-- FECHA CREACION:  28-08-2026
-- DESCRIPTION:     SANEAMIENTO: ELIMINA EL LOG Y LOS SP LEGADOS DE SGF.
-- =============================================
-- Este es el bloque 00 que 00_MAESTRO.sql anuncia y que hasta ahora no
-- existia. Va PRIMERO, antes del 04.
--
-- QUE ELIMINA Y POR QUE
--
--   1. LOS 12 TRIGGERS TRG_LOG_*
--      Escriben en una tabla [Log] que no existe en esta base. Mientras
--      esten activos, cualquier INSERT, UPDATE o DELETE sobre Cliente,
--      Usuario, Perfiles, Paises, Cliente_Instalacion, Cliente_Usuario,
--      Menu_Perfil, Modulos_Sistema, Marcacion, Usuario_Paises,
--      Privacidad_Modulos_Sistema o Cliente_App_Instalacion FALLA.
--      Ese es el bloqueador que impide todo el Sprint 1.
--
--   2. LOS 3 SP SEL_LOG_*
--      Consultan [Log], [Log_Estado], [Log_Tabla] y [Log_Tipo_Api_Web].
--      Ninguna existe. La auditoria de SIGMA se resuelve en el dominio
--      D10 Bitacora (bloque 23), no aqui.
--
--   3. LOS 4 SP DE ARCHIVO LEGADO
--      Apuntan a [Archivo] y [Archivo_Binario] de SGF, que no existen.
--      Ademas COLISIONAN: el bloque 18 crea un [dbo].[Archivo] nuevo con
--      otro esquema. Si estos SP siguen vivos cuando corra el 18, dejan
--      de fallar por "objeto inexistente" y pasan a fallar por columnas.
--      Por eso el saneamiento va ANTES del 18, no despues.
--
--   4. LOS 17 SP DE CHECKLIST LEGADO
--      Apuntan a [Checklist], [Checklist_Detalle],
--      [Checklist_Detalle_Combobox], [Checklist_Tipo],
--      [Checklist_Tipo_Objeto], [Checklist_Tipo_Dato] y
--      [Cliente_Instalacion_Zona_Checklist*]. Ninguna existe. El
--      checklist de SIGMA es el dominio D7 (bloque 15), con 22 tablas y
--      un modelo distinto: plantilla, version, seccion, item, ocurrencia
--      y ejecucion. No hay nada que migrar.
--
-- LO QUE NO TOCA
--   DEL_CLIENTE queda en pie: es un SP vigente del nucleo. Tiene una
--   dependencia a [Checklist] en su bloque de limpieza que hay que
--   resolver aparte; ver el informe de saneamiento.
--   SEL_LOGIN y API_SEL_USUARIO_LOGIN no son del log: son de login.
--
-- RESPALDO
--   Las 36 definiciones estan en _RESPALDO_OBJETOS_LEGADOS.sql, en esta
--   misma carpeta, generadas desde la base antes del drop.
--
-- ES IDEMPOTENTE
--   Se puede correr dos veces. La segunda no hace nada y no falla.
-- =============================================

SET NOCOUNT ON

DECLARE @objeto  SYSNAME
DECLARE @tipo    NVARCHAR(20)
DECLARE @sql     NVARCHAR(500)
DECLARE @hechos  INT = 0
DECLARE @omitidos INT = 0

DECLARE @BAJA TABLE (nombre SYSNAME, tipo NVARCHAR(20))

-- 1. Triggers de log  (12)
INSERT INTO @BAJA VALUES
 (N'TRG_LOG_Cliente',                    N'TRIGGER'),
 (N'TRG_LOG_Cliente_App_Instalacion',    N'TRIGGER'),
 (N'TRG_LOG_Cliente_Instalacion',        N'TRIGGER'),
 (N'TRG_LOG_Cliente_Usuario',            N'TRIGGER'),
 (N'TRG_LOG_Marcacion',                  N'TRIGGER'),
 (N'TRG_LOG_Menu_Perfil',                N'TRIGGER'),
 (N'TRG_LOG_Modulos_Sistema',            N'TRIGGER'),
 (N'TRG_LOG_Paises',                     N'TRIGGER'),
 (N'TRG_LOG_Perfiles',                   N'TRIGGER'),
 (N'TRG_LOG_Privacidad_Modulos_Sistema', N'TRIGGER'),
 (N'TRG_LOG_Usuario',                    N'TRIGGER'),
 (N'TRG_LOG_Usuario_Paises',             N'TRIGGER')

-- 2. SP de consulta del log  (3)
INSERT INTO @BAJA VALUES
 (N'SEL_LOG_APP_WEB', N'PROCEDURE'),
 (N'SEL_LOG_SISTEMA', N'PROCEDURE'),
 (N'SEL_LOG_TABLA',   N'PROCEDURE')

-- 3. SP de archivo legado  (4)
INSERT INTO @BAJA VALUES
 (N'DEL_ARCHIVO',          N'PROCEDURE'),
 (N'INS_ARCHIVO',          N'PROCEDURE'),
 (N'SEL_ARCHIVO',          N'PROCEDURE'),
 (N'SEL_ARCHIVOS_BINARIO', N'PROCEDURE')

-- 4. SP de checklist legado  (17)
INSERT INTO @BAJA VALUES
 (N'DEL_CHECKLIST',                N'PROCEDURE'),
 (N'DEL_CHECKLIST_DETALLE',        N'PROCEDURE'),
 (N'DEL_CHECKLIST_DETALLE_OBJETO', N'PROCEDURE'),
 (N'INS_CHECKLIST',                N'PROCEDURE'),
 (N'INS_CHECKLIST_DETALLE',        N'PROCEDURE'),
 (N'INS_CHECKLIST_DETALLE_OBJETO', N'PROCEDURE'),
 (N'SEL_CHECKLIST',                N'PROCEDURE'),
 (N'SEL_CHECKLIST_DETALLE',        N'PROCEDURE'),
 (N'SEL_CHECKLIST_DETALLE_OBJETO', N'PROCEDURE'),
 (N'SEL_CHECKLIST_ESTADOS',        N'PROCEDURE'),
 (N'SEL_CHECKLIST_TIPO',           N'PROCEDURE'),
 (N'SEL_CHECKLIST_TIPO_OBJETO',    N'PROCEDURE'),
 (N'UPD_CHECKLIST',                N'PROCEDURE'),
 (N'UPD_CHECKLIST_DETALLE',        N'PROCEDURE'),
 (N'UPD_CHECKLIST_DETALLE_OBJETO', N'PROCEDURE'),
 (N'UPD_CHECKLIST_ESTADO',         N'PROCEDURE'),
 (N'UPD_CHECKLIST_ORDEN',          N'PROCEDURE')

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT nombre, tipo FROM @BAJA
OPEN cur
FETCH NEXT FROM cur INTO @objeto, @tipo

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @tipo = N'TRIGGER'
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.triggers WHERE name = @objeto)
        BEGIN
            SET @sql = N'DROP TRIGGER [dbo].' + QUOTENAME(@objeto)
            EXEC sp_executesql @sql
            PRINT '  baja  TRIGGER   ' + @objeto
            SET @hechos = @hechos + 1
        END
        ELSE
        BEGIN
            PRINT '  ya no existe    ' + @objeto
            SET @omitidos = @omitidos + 1
        END
    END
    ELSE
    BEGIN
        IF OBJECT_ID(N'[dbo].' + QUOTENAME(@objeto), N'P') IS NOT NULL
        BEGIN
            SET @sql = N'DROP PROCEDURE [dbo].' + QUOTENAME(@objeto)
            EXEC sp_executesql @sql
            PRINT '  baja  PROCEDURE ' + @objeto
            SET @hechos = @hechos + 1
        END
        ELSE
        BEGIN
            PRINT '  ya no existe    ' + @objeto
            SET @omitidos = @omitidos + 1
        END
    END

    FETCH NEXT FROM cur INTO @objeto, @tipo
END

CLOSE cur
DEALLOCATE cur

PRINT ''
PRINT '  eliminados en esta corrida: ' + CAST(@hechos AS VARCHAR(10))
PRINT '  ya inexistentes:            ' + CAST(@omitidos AS VARCHAR(10))
GO

-- ── Comprobacion ────────────────────────────────────────────────────────
-- Debe devolver CERO filas. Si devuelve algo, ese objeto sigue vivo.
SELECT o.type_desc AS tipo, o.name AS sigue_vivo
FROM sys.objects o
WHERE o.name LIKE 'TRG_LOG[_]%'
   OR o.name LIKE 'SEL_LOG[_]%'
   OR o.name LIKE '%CHECKLIST%'
   OR o.name IN ('DEL_ARCHIVO','INS_ARCHIVO','SEL_ARCHIVO','SEL_ARCHIVOS_BINARIO')
ORDER BY o.type_desc, o.name
GO
