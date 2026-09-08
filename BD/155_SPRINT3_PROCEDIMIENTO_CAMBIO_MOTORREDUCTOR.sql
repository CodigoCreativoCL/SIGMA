USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          EMILIO FUENTES
-- FECHA CREACION:  06-09-2026
-- DESCRIPTION:     SPRINT 3 (HU-061) - PROCEDIMIENTO REAL: CAMBIO DE MOTORREDUCTOR
--                  DE LA REVOLVEDORA (TIPO AMASADORA).
-- =============================================
-- Registra la "receta" reutilizable para reemplazar el motorreductor de una
-- revolvedora/amasadora (caso real: Revolvedora 1 - ACT-35, motorreductor
-- SEW W30 DT71D4/TH). El encabezado se crea con INS_PROCEDIMIENTO (mismas
-- reglas que la pantalla) y los PASOS se insertan en Procedimiento_Paso.
-- Aplica al TIPO Amasadora, asi sirve para todas las revolvedoras.
-- Requiere permiso de BLOQUEO DE ENERGIA (LOTO).
-- ES IDEMPOTENTE: no duplica el procedimiento ni sus pasos.
-- =============================================

SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1, @USUARIO INT = 9, @TIPO INT, @PERMISO INT, @NEW INT
DECLARE @PAIS INT, @NOW DATETIME

SELECT @TIPO   = ati_id FROM [dbo].[Activo_Tipo] WHERE ati_cliente = @CLIENTE AND ati_nombre = N'Amasadora' AND ati_habilitado = 1
SELECT @PERMISO = ptt_id FROM [dbo].[Permiso_Trabajo_Tipo] WHERE ptt_codigo = 'BLOQUEO ENERGIA'
SELECT @PAIS   = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET    @NOW    = [dbo].[FNC_PAIS_HORA](@PAIS)

-- 1) Encabezado (buscar-o-crear por codigo + version).
SELECT @NEW = prc_id FROM [dbo].[Procedimiento]
WHERE  prc_cliente = @CLIENTE AND prc_codigo = N'CAMBIO-MOTORREDUCTOR' AND prc_version = 1

IF @NEW IS NULL
BEGIN
    EXEC [dbo].[INS_PROCEDIMIENTO] @ID=@NEW OUTPUT, @CLIENTE=@CLIENTE,
         @CODIGO=N'CAMBIO-MOTORREDUCTOR',
         @NOMBRE=N'Cambio de motorreductor (revolvedora / amasadora)',
         @VERSION=1, @ACTIVO_TIPO=@TIPO,
         @DESCRIPCION=N'Receta para reemplazar el motorreductor de una revolvedora (amasadora). Caso de referencia: Revolvedora 1, motorreductor SEW W30 DT71D4/TH. Trabajo con bloqueo y tarjeteo de energia (LOTO); verificar la placa del repuesto antes de montar y el sentido de giro antes de entregar.',
         @DURACION=170, @REQUIERE_PERMISO=1, @PERMISO_TIPO=@PERMISO, @USUARIO=@USUARIO
    PRINT '--- Procedimiento CAMBIO-MOTORREDUCTOR creado. Id = ' + LTRIM(STR(@NEW))
END
ELSE
    PRINT '--- Procedimiento CAMBIO-MOTORREDUCTOR ya existia. Id = ' + LTRIM(STR(@NEW))

-- 2) Pasos (solo si el procedimiento todavia no tiene pasos).
IF @NEW IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[Procedimiento_Paso] WHERE ppa_procedimiento = @NEW)
BEGIN
    INSERT INTO [dbo].[Procedimiento_Paso]
        (ppa_procedimiento, ppa_orden, ppa_nombre, ppa_instruccion,
         ppa_es_punto_control, ppa_requiere_evidencia, ppa_requiere_medicion,
         ppa_duracion_estimada_minuto, ppa_usuario_creacion, ppa_fecha_creacion, ppa_habilitado)
    VALUES
    (@NEW, 1, N'Preparacion, aislamiento y bloqueo (LOTO)',
        N'Detener el equipo desde el tablero. Aislar todas las fuentes de energia (electrica y, si aplica, neumatica). Aplicar bloqueo y tarjeteo (LOTO) en el seccionador del motor. Verificar ausencia de tension con multimetro/detector. Esperar la detencion total del tazon.',
        1, 1, 0, 20, @USUARIO, @NOW, 1),
    (@NEW, 2, N'Retiro de guardas y protecciones',
        N'Retirar las guardas de la transmision y cualquier proteccion que impida el acceso al motorreductor. Guardar la tornilleria en bolsa rotulada.',
        0, 0, 0, 10, @USUARIO, @NOW, 1),
    (@NEW, 3, N'Desconexion electrica del motor',
        N'En la caja de bornes del motor SEW, fotografiar y rotular la conexion (U1/V1/W1 + tierra). Desconectar los conductores y el prensaestopa. Cubrir los cables con capuchones aislantes.',
        0, 1, 0, 15, @USUARIO, @NOW, 1),
    (@NEW, 4, N'Liberar la transmision',
        N'Aflojar y liberar el elemento de transmision (acople, pinon-cadena o correa) entre el motorreductor y la revolvedora. Aliviar la tension antes de soltar.',
        0, 0, 0, 15, @USUARIO, @NOW, 1),
    (@NEW, 5, N'Desmontaje del motorreductor',
        N'Sostener el motorreductor (usar eslinga o apoyo si el peso lo requiere). Soltar los pernos de fijacion de la brida/patas. Retirar el motorreductor y depositarlo en zona segura.',
        0, 1, 0, 20, @USUARIO, @NOW, 1),
    (@NEW, 6, N'Verificacion del repuesto (placa SEW)',
        N'Confirmar que el repuesto coincide con la placa: SEW W30 DT71D4/TH (potencia, relacion de reduccion, rpm de salida, tension/frecuencia, forma constructiva y sentido). Verificar estado de retenes y nivel/tipo de aceite del reductor.',
        1, 0, 0, 15, @USUARIO, @NOW, 1),
    (@NEW, 7, N'Montaje y alineacion',
        N'Montar el motorreductor nuevo en su brida/patas. Colocar y apretar los pernos al torque indicado. Verificar la alineacion del eje/acople (holgura y concentricidad).',
        0, 1, 0, 25, @USUARIO, @NOW, 1),
    (@NEW, 8, N'Reconexion de la transmision',
        N'Instalar el acople/cadena/correa. Ajustar la tension y verificar el engrane/alineacion. Lubricar la cadena si corresponde.',
        0, 0, 0, 15, @USUARIO, @NOW, 1),
    (@NEW, 9, N'Reconexion electrica y sentido de giro',
        N'Reconectar los conductores segun el rotulo (U1/V1/W1 + tierra). Bajo control, hacer un arranque breve de prueba y verificar el SENTIDO DE GIRO correcto. Si es inverso, permutar dos fases con la energia nuevamente aislada.',
        1, 1, 0, 15, @USUARIO, @NOW, 1),
    (@NEW, 10, N'Reposicion, prueba en vacio y cierre',
        N'Reponer todas las guardas y protecciones. Retirar el bloqueo/tarjeteo (LOTO). Prueba en vacio verificando ruido, vibracion, temperatura y ausencia de fugas de aceite. Registrar el cambio (numero de serie retirado/instalado) y dejar el area limpia.',
        1, 1, 0, 20, @USUARIO, @NOW, 1)

    PRINT '--- 10 pasos insertados para el procedimiento ' + LTRIM(STR(@NEW))
END
ELSE
    PRINT '--- El procedimiento ya tenia pasos. No se insertaron.'
GO


/* ========================================================================
   COMPROBACION
   ======================================================================== */
SELECT p.prc_id, p.prc_codigo, p.prc_version, p.prc_nombre, p.prc_requiere_permiso,
       (SELECT COUNT(*) FROM [dbo].[Procedimiento_Paso] s WHERE s.ppa_procedimiento = p.prc_id AND s.ppa_habilitado = 1) AS PASOS
FROM   [dbo].[Procedimiento] p
WHERE  p.prc_cliente = 1 AND p.prc_codigo = N'CAMBIO-MOTORREDUCTOR'
ORDER  BY p.prc_version
GO

PRINT '155_SPRINT3_PROCEDIMIENTO_CAMBIO_MOTORREDUCTOR aplicado.'
GO
