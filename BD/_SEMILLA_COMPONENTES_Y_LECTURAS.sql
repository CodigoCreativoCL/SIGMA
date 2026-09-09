USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     DATOS DE PRUEBA PARA COMPONENTES, MEDIDORES Y LECTURAS.
-- =============================================
-- ESTO NO ES UNA MIGRACION
--
--   Va con guion bajo y sin numero a proposito: no cambia la estructura de
--   nada, mete filas de ejemplo. `Activo_Componente`, `Activo_Medidor` y
--   `Activo_Medidor_Lectura` estaban en CERO, asi que las pantallas 8.1 a
--   8.4 y 9.2 no se podian ni mirar: una lista vacia se ve igual estando
--   bien que estando rota.
--
--   Los datos reales se cargan desde la web. Esto es para poder verificar.
--
--   Es idempotente: se puede correr dos veces sin duplicar nada.
--
-- UN HALLAZGO DE PASO
--
--   `INS_ACTIVO_MEDIDOR` **no recibe @ACTIVO_COMPONENTE**, aunque la columna
--   `ame_activo_componente` existe y la usa la ficha del componente. O sea
--   que hoy, ni desde la web ni desde ningun SP, se puede colgar un medidor
--   de un componente: solo de un activo. Aca se hace con un UPDATE directo
--   porque son datos de prueba, pero el SP le falta el parametro y eso es
--   trabajo de base, no de la app. Queda anotado en el checklist.
-- =============================================
SET NOCOUNT ON
GO

DECLARE @CLIENTE INT = 1
DECLARE @USUARIO INT = (SELECT TOP 1 usu_id FROM [dbo].[Usuario] WHERE usu_login = 'rodrigo.quezada@hamburgo.cl')
DECLARE @ACTIVO  INT = (SELECT TOP 1 act_id FROM [dbo].[Activo] WHERE act_codigo = 'ACT-33' AND act_cliente = @CLIENTE)

IF (@ACTIVO IS NULL OR @USUARIO IS NULL)
BEGIN
    RAISERROR('1.- FALTA EL ACTIVO ACT-33 O EL USUARIO DE PRUEBA.', 16, 1)
    RETURN
END

-- ---------------------------------------------------------------------------
-- Tres componentes de la modeladora, con criticidad y estado distintos
-- ---------------------------------------------------------------------------
--
-- Distintos a proposito: con tres «Operativo / Media» la pantalla se ve bien
-- aunque el color y el orden esten mal, y no se probaria nada.
DECLARE @MOTOR INT, @REDUCTOR INT, @RODAMIENTO INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-01' AND aco_cliente = @CLIENTE)
    EXEC [dbo].[INS_ACTIVO_COMPONENTE]
         @ID = @MOTOR OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACTIVO,
         @COMPONENTE_PADRE = NULL, @COMPONENTE_TIPO = 1,
         @COMPONENTE_POSICION = 3, @CRITICIDAD_NIVEL = 4,
         @ACTIVO_COMPONENTE_ESTADO = 1,
         @CODIGO = N'CMP-33-01', @NOMBRE = N'Motor principal',
         @FECHA_INSTALACION = '2023-03-15',
         @DESCRIPCION = N'Motor trifásico 15 kW del accionamiento principal',
         @USUARIO = @USUARIO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-02' AND aco_cliente = @CLIENTE)
    EXEC [dbo].[INS_ACTIVO_COMPONENTE]
         @ID = @REDUCTOR OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACTIVO,
         @COMPONENTE_PADRE = NULL, @COMPONENTE_TIPO = 2,
         @COMPONENTE_POSICION = 1, @CRITICIDAD_NIVEL = 3,
         @ACTIVO_COMPONENTE_ESTADO = 3,
         @CODIGO = N'CMP-33-02', @NOMBRE = N'Reductor de salida',
         @FECHA_INSTALACION = '2023-03-15',
         @DESCRIPCION = N'Reductor de engranajes, relación 1:40',
         @USUARIO = @USUARIO

SET @MOTOR    = (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-01' AND aco_cliente = @CLIENTE)
SET @REDUCTOR = (SELECT aco_id FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-02' AND aco_cliente = @CLIENTE)

-- El rodamiento cuelga del motor: sin un componente hijo no se prueba que la
-- ficha sepa mostrar el padre.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Componente] WHERE aco_codigo = 'CMP-33-03' AND aco_cliente = @CLIENTE)
    EXEC [dbo].[INS_ACTIVO_COMPONENTE]
         @ID = @RODAMIENTO OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACTIVO,
         @COMPONENTE_PADRE = @MOTOR, @COMPONENTE_TIPO = 3,
         @COMPONENTE_POSICION = 3, @CRITICIDAD_NIVEL = 2,
         @ACTIVO_COMPONENTE_ESTADO = 2,
         @CODIGO = N'CMP-33-03', @NOMBRE = N'Rodamiento lado motor',
         @FECHA_INSTALACION = '2025-11-02',
         @DESCRIPCION = N'Rodamiento 6208-2RS, lado acople',
         @USUARIO = @USUARIO

-- ---------------------------------------------------------------------------
-- Un medidor de horas colgado del motor, con su historia
-- ---------------------------------------------------------------------------
DECLARE @MEDIDOR INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor] WHERE ame_codigo = 'MED-33-H' AND ame_cliente = @CLIENTE)
    EXEC [dbo].[INS_ACTIVO_MEDIDOR]
         @ID = @MEDIDOR OUTPUT, @CLIENTE = @CLIENTE, @ACTIVO = @ACTIVO,
         @UNIDAD_MEDIDA = 13,   -- Hora
         @CODIGO = N'MED-33-H', @NOMBRE = N'Horómetro del motor',
         @VALOR_ACTUAL = 0, @VALOR_REINICIO = NULL, @PERMITE_REINICIO = 0,
         @USUARIO = @USUARIO

SET @MEDIDOR = (SELECT ame_id FROM [dbo].[Activo_Medidor] WHERE ame_codigo = 'MED-33-H' AND ame_cliente = @CLIENTE)

-- El UPDATE directo, por lo dicho arriba: el SP de alta no tiene el
-- parametro con que colgarlo del componente.
UPDATE [dbo].[Activo_Medidor]
   SET ame_activo_componente = @MOTOR
 WHERE ame_id = @MEDIDOR AND ISNULL(ame_activo_componente, 0) <> @MOTOR

-- ---------------------------------------------------------------------------
-- Doce lecturas mensuales, para que el grafico de 9.2 tenga que dibujar algo
-- ---------------------------------------------------------------------------
--
-- El horometro es ACUMULADO: sube siempre. El grafico de tendencia dibuja el
-- INCREMENTO entre lecturas, no el acumulado -una recta que sube no dice
-- nada-, y por eso el salto de cada mes es distinto: hay meses de parada y
-- hay uno con un salto grande, que es el caso que 9.1 llama «salto no
-- razonable» y el que la pantalla tiene que saber destacar.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_activo_medidor = @MEDIDOR)
BEGIN
    ;WITH pasos AS (
        SELECT * FROM (VALUES
            ( 1,  620.0), ( 2,  580.0), ( 3,  640.0), ( 4,  410.0),
            ( 5,  600.0), ( 6,  655.0), ( 7,   90.0), ( 8,  610.0),
            ( 9,  630.0), (10, 1480.0), (11,  600.0), (12,  585.0)
        ) v(n, salto)
    )
    INSERT INTO [dbo].[Activo_Medidor_Lectura]
        (aml_uuid, aml_cliente, aml_activo_medidor, aml_fecha_lectura_utc,
         aml_valor_acumulado, aml_es_reinicio, aml_dato_origen,
         aml_medicion_calidad, aml_entrada_modo,
         aml_observacion, aml_usuario_creacion, aml_fecha_creacion)
    SELECT  NEWID(), @CLIENTE, @MEDIDOR,
            DATEADD(MONTH, p.n - 12, CAST('2026-09-01' AS DATETIME)),
            (SELECT SUM(q.salto) FROM pasos q WHERE q.n <= p.n),
            0,
            3,  -- Ingreso manual
            1,  -- Valida
            1,  -- Teclado
            CASE WHEN p.n = 7  THEN N'Mes de parada por mantención mayor'
                 WHEN p.n = 10 THEN N'Turno extra por pedido especial'
                 ELSE NULL END,
            @USUARIO, GETUTCDATE()
    FROM    pasos p

    -- El medidor tiene que quedar diciendo lo mismo que su ultima lectura.
    UPDATE  [dbo].[Activo_Medidor]
       SET  ame_valor_actual = (SELECT MAX(aml_valor_acumulado) FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_activo_medidor = @MEDIDOR),
            ame_fecha_valor_actual_utc = (SELECT MAX(aml_fecha_lectura_utc) FROM [dbo].[Activo_Medidor_Lectura] WHERE aml_activo_medidor = @MEDIDOR)
     WHERE  ame_id = @MEDIDOR
END

-- ---------------------------------------------------------------------------
-- Una anotacion de bitacora sobre el reductor, para la linea de tiempo (8.3)
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Bitacora] WHERE bit_activo_componente = @REDUCTOR)
    INSERT INTO [dbo].[Bitacora]
        (bit_uuid, bit_cliente, bit_cliente_instalacion, bit_bitacora_tipo, bit_activo, bit_activo_componente,
         bit_titulo, bit_texto, bit_fecha_evento_utc, bit_requiere_atencion,
         bit_usuario_creacion, bit_fecha_creacion)
    SELECT  NEWID(), @CLIENTE,
            (SELECT act_cliente_instalacion FROM [dbo].[Activo] WHERE act_id = @ACTIVO),
            (SELECT TOP 1 bti_id FROM [dbo].[Bitacora_Tipo] ORDER BY bti_id),
            @ACTIVO, @REDUCTOR,
            N'Ruido en el reductor',
            N'Se escucha un golpeteo a régimen. Se deja en observación hasta la próxima parada.',
            DATEADD(DAY, -12, GETUTCDATE()), 1, @USUARIO, GETUTCDATE()

GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT  'COMPONENTE ' + aco.aco_codigo + ' · ' + aco.aco_nombre +
        ' · ' + ace.ace_nombre + ' · ' + crn.crn_nombre +
        ISNULL(' · hijo de ' + pad.aco_codigo, '') AS RESULTADO
FROM    [dbo].[Activo_Componente] aco
JOIN    [dbo].[Activo_Componente_Estado] ace ON ace.ace_id = aco.aco_activo_componente_estado
JOIN    [dbo].[Criticidad_Nivel] crn ON crn.crn_id = aco.aco_criticidad_nivel
LEFT JOIN [dbo].[Activo_Componente] pad ON pad.aco_id = aco.aco_componente_padre
WHERE   aco.aco_codigo LIKE 'CMP-33-%'

UNION ALL
SELECT  'LECTURAS = ' + CAST(COUNT(*) AS VARCHAR) +
        ' · acumulado final ' + CAST(CAST(MAX(aml_valor_acumulado) AS DECIMAL(18,1)) AS VARCHAR)
FROM    [dbo].[Activo_Medidor_Lectura] aml
JOIN    [dbo].[Activo_Medidor] ame ON ame.ame_id = aml.aml_activo_medidor
WHERE   ame.ame_codigo = 'MED-33-H'
GO
