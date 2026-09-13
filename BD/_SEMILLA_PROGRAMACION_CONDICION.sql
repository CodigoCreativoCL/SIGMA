USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  12-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA PROGRAMACION POR CONDICION (T-3261, HU-074).
-- =============================================
-- ESTO NO ES UNA MIGRACION. Estaba bloqueada porque Activo_Variable no tenia
-- filas (HU-041). Ya las tiene -las descubrio el telefono y ahora tienen
-- mantenedor (BD/224)-, asi que se puede armar la programacion por
-- condicion de HU-074: «temperatura del horno L1 mayor a 80 °C durante 30
-- minutos, severidad alta» y una segunda condicion sobre la vibracion de la
-- revolvedora para la politica TODAS (criterio 3). Idempotente por nombre.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @TEMP INT = (SELECT TOP 1 v.ava_id FROM [dbo].[Activo_Variable] v JOIN [dbo].[Activo] a ON a.act_id = v.ava_activo
                     WHERE v.ava_cliente = @CLIENTE AND a.act_codigo = 'ACT-34' AND v.ava_variable_medicion = 8 AND v.ava_activo_componente IS NULL)
DECLARE @VIB  INT = (SELECT TOP 1 v.ava_id FROM [dbo].[Activo_Variable] v JOIN [dbo].[Activo] a ON a.act_id = v.ava_activo
                     WHERE v.ava_cliente = @CLIENTE AND a.act_codigo = 'ACT-35' AND v.ava_variable_medicion = 9 AND v.ava_activo_componente IS NULL)
DECLARE @PROG INT, @ID INT

IF (@USUARIO IS NULL OR @TEMP IS NULL)
BEGIN
    RAISERROR('1.- FALTAN LAS VARIABLES DE ACT-34 (TEMPERATURA): CORRA BD/224 Y REVISE Activo_Variable.', 16, 1)
    RETURN
END

-- 1) Sobretemperatura del horno: una condicion, politica UNO (criterios 1 y 2)
SET @PROG = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = N'Sobretemperatura horno L1 (semilla)')
IF @PROG IS NULL
BEGIN
    EXEC [dbo].[INS_PROGRAMACION]
         @ID = @PROG OUTPUT, @CLIENTE = @CLIENTE, @TIPO = 6,   -- CONDICION
         @NOMBRE = N'Sobretemperatura horno L1 (semilla)', @FECHA_INICIO = '2026-01-01', @FECHA_FIN = NULL,
         @ZONA_HORARIA = 1, @TOLERANCIA_ANTES = 0, @TOLERANCIA_DESPUES = 1440,
         @PERMITE_ANTICIPADA = 0, @PERMITE_ATRASADA = 1, @CUMPLIMIENTO_POLITICA = 1,
         @GENERA_AUTOMATICAMENTE = 1, @INSTALACION = NULL, @AREA = NULL, @ACTIVO = NULL, @GRUPO = NULL,
         @USUARIO = @USUARIO

    EXEC [dbo].[INS_PROGRAMACION_CONDICION]
         @ID = @ID OUTPUT, @PROGRAMACION = @PROG, @CLIENTE = @CLIENTE,
         @ACTIVO_VARIABLE = @TEMP, @OPERADOR = 3,             -- MAYOR
         @UMBRAL = 80, @UMBRAL_HASTA = NULL, @DURACION_MINIMA = 30, @SEVERIDAD = 4,
         @USUARIO = @USUARIO
END

-- 2) Dos condiciones con politica TODOS (criterio 3)
IF @VIB IS NOT NULL
BEGIN
    SET @PROG = (SELECT TOP 1 pro_id FROM [dbo].[Programacion] WHERE pro_cliente = @CLIENTE AND pro_nombre = N'Temperatura y vibración (semilla)')
    IF @PROG IS NULL
    BEGIN
        EXEC [dbo].[INS_PROGRAMACION]
             @ID = @PROG OUTPUT, @CLIENTE = @CLIENTE, @TIPO = 6,
             @NOMBRE = N'Temperatura y vibración (semilla)', @FECHA_INICIO = '2026-01-01', @FECHA_FIN = NULL,
             @ZONA_HORARIA = 1, @TOLERANCIA_ANTES = 0, @TOLERANCIA_DESPUES = 1440,
             @PERMITE_ANTICIPADA = 0, @PERMITE_ATRASADA = 1, @CUMPLIMIENTO_POLITICA = 2,   -- TODOS
             @GENERA_AUTOMATICAMENTE = 1, @INSTALACION = NULL, @AREA = NULL, @ACTIVO = NULL, @GRUPO = NULL,
             @USUARIO = @USUARIO

        EXEC [dbo].[INS_PROGRAMACION_CONDICION] @ID = @ID OUTPUT, @PROGRAMACION = @PROG, @CLIENTE = @CLIENTE,
             @ACTIVO_VARIABLE = @TEMP, @OPERADOR = 3, @UMBRAL = 80, @DURACION_MINIMA = NULL, @SEVERIDAD = 3, @USUARIO = @USUARIO
        EXEC [dbo].[INS_PROGRAMACION_CONDICION] @ID = @ID OUTPUT, @PROGRAMACION = @PROG, @CLIENTE = @CLIENTE,
             @ACTIVO_VARIABLE = @VIB, @OPERADOR = 4, @UMBRAL = 7.1, @DURACION_MINIMA = NULL, @SEVERIDAD = 3, @USUARIO = @USUARIO
    END
END
GO

SELECT p.pro_nombre COLLATE DATABASE_DEFAULT + ' · ' + CAST(COUNT(c.pco_id) AS VARCHAR) + ' condición(es) · política ' + cp.cpo_codigo COLLATE DATABASE_DEFAULT AS RESULTADO
FROM   [dbo].[Programacion] p
LEFT JOIN [dbo].[Programacion_Condicion] c ON c.pco_programacion = p.pro_id AND c.pco_habilitado = 1
LEFT JOIN [dbo].[Cumplimiento_Politica] cp ON cp.cpo_id = p.pro_cumplimiento_politica
WHERE  p.pro_cliente = 1 AND p.pro_programacion_tipo = 6
GROUP BY p.pro_nombre, cp.cpo_codigo
GO
