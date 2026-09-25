USE [db_acd593_sigma]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- AUTHOR:          BRYAN CHAVEZ
-- FECHA CREACION:  09-09-2026
-- DESCRIPTION:     EL HISTORIAL DE LECTURAS DE UN MEDIDOR (VISTA 9.2).
-- =============================================
-- QUE FALTABA
--
--   Registrar una lectura ya se podia -API_INS_ACTIVO_MEDIDOR_LECTURA, HU-043-
--   pero no habia forma de LEER las anteriores. La consecuencia practica: el
--   tecnico anotaba el horometro sin poder ver si el valor que estaba
--   escribiendo tenia sentido contra los ultimos seis meses.
--
-- EL INCREMENTO SE CALCULA ACA, NO EN EL TELEFONO
--
--   El medidor guarda el ACUMULADO. Lo que dice algo es el INCREMENTO entre
--   dos lecturas: 7.500 h no significa nada, «580 h este mes contra 90 el
--   anterior» significa que la maquina estuvo parada. Si lo calculara la app,
--   la primera fila de cada pagina tendria un incremento equivocado -no
--   tiene con quien restarse- y ademas la web tendria que repetir la misma
--   resta. LAG() lo hace una vez y bien.
--
-- LOS REINICIOS
--
--   Un medidor que se reinicia -se cambio el instrumento, o dio la vuelta-
--   deja una lectura MENOR que la anterior. Restar a ciegas daria un
--   incremento negativo enorme y el grafico se iria al suelo. La fila marcada
--   `aml_es_reinicio` devuelve incremento NULL: no se sabe cuanto corrio, y
--   decir «no se sabe» es lo unico honesto.
--
-- EL UMBRAL SALE DE LA PROGRAMACION, NO DE UNA TABLA DE UMBRALES
--
--   No existe tabla de umbrales, y no hace falta inventarla: `Programacion_
--   Medidor` ya dice que la mantencion toca cada @CADA_CANTIDAD unidades
--   desde @VALOR_INICIAL, con @AVISO_ANTICIPACION de margen. Ese es el umbral
--   real del negocio -«a las 8.000 h toca cambio de aceite»- y ya lo mantiene
--   alguien. Una tabla nueva seria un segundo sitio donde decir lo mismo.
-- =============================================
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) API_SEL_ACTIVO_MEDIDOR_LECTURA — las lecturas, con su incremento
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ACTIVO_MEDIDOR_LECTURA]
@MEDIDOR        INT,
@CLIENTE        INT,
@FECHA_DESDE    DATE = NULL,
@FECHA_HASTA    DATE = NULL,
@PAGINA         INT = 1,
@TAMANO         INT = 50,
@TOTAL          INT = NULL OUTPUT
AS
SET NOCOUNT ON

-- Barrera multicliente: el medidor tiene que ser del cliente en sesion.
IF NOT EXISTS (SELECT 1 FROM [dbo].[Activo_Medidor]
                WHERE ame_id = @MEDIDOR AND ame_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- EL MEDIDOR NO PERTENECE A ESTE CLIENTE.', 16, 1)
    RETURN -1
END

IF @PAGINA < 1 SET @PAGINA = 1
IF @TAMANO < 1 SET @TAMANO = 50
IF @TAMANO > 500 SET @TAMANO = 500
DECLARE @OFFSET INT = (@PAGINA - 1) * @TAMANO

/* EL INCREMENTO SE CALCULA SOBRE LA SERIE COMPLETA, NO SOBRE EL RANGO

   Si se filtrara primero por fecha y despues se restara, la primera lectura
   del rango se restaria contra nada y saldria sin incremento. Mirando «desde
   junio» eso pinta un mes vacio que en realidad tuvo 600 horas. Por eso el
   LAG() va antes del filtro: cada lectura se resta contra la que de verdad
   le precede, este o no dentro del rango que se pidio. */
;WITH serie AS (
    SELECT  aml.aml_id,
            aml.aml_fecha_lectura_utc,
            aml.aml_valor_acumulado,
            aml.aml_es_reinicio,
            aml.aml_observacion,
            aml.aml_orden_trabajo,
            aml.aml_entrada_modo,
            aml.aml_dato_origen,
            aml.aml_medicion_calidad,
            aml.aml_usuario_creacion,
            LAG(aml.aml_valor_acumulado) OVER (ORDER BY aml.aml_fecha_lectura_utc, aml.aml_id) AS anterior
    FROM    [dbo].[Activo_Medidor_Lectura] aml
    WHERE   aml.aml_activo_medidor = @MEDIDOR
      AND   aml.aml_cliente        = @CLIENTE
)
SELECT  s.aml_id                        AS AML_ID,
        s.aml_fecha_lectura_utc         AS FECHA_LECTURA_UTC,
        s.aml_valor_acumulado           AS VALOR_ACUMULADO,
        -- NULL en el reinicio y en la primera: no hay resta que valga.
        CASE WHEN s.aml_es_reinicio = 1 THEN NULL
             WHEN s.anterior IS NULL    THEN NULL
             ELSE s.aml_valor_acumulado - s.anterior
        END                             AS INCREMENTO,
        s.aml_es_reinicio               AS ES_REINICIO,
        s.aml_observacion               AS OBSERVACION,
        s.aml_orden_trabajo             AS ORDEN_TRABAJO,
        otr.otr_correlativo             AS ORDEN_CORRELATIVO,
        emo.emo_nombre                  AS MODO_NOMBRE,
        dor.dor_nombre                  AS ORIGEN_NOMBRE,
        mca.mca_nombre                  AS CALIDAD_NOMBRE,
        LTRIM(RTRIM(ISNULL(u.usu_nombre, N'') + N' ' +
                    ISNULL(u.usu_apellido_paterno, N''))) AS USUARIO_NOMBRE
INTO    #pagina
FROM    serie s
LEFT JOIN [dbo].[Orden_Trabajo]   otr ON otr.otr_id = s.aml_orden_trabajo
LEFT JOIN [dbo].[Entrada_Modo]    emo ON emo.emo_id = s.aml_entrada_modo
LEFT JOIN [dbo].[Dato_Origen]     dor ON dor.dor_id = s.aml_dato_origen
LEFT JOIN [dbo].[Medicion_Calidad] mca ON mca.mca_id = s.aml_medicion_calidad
LEFT JOIN [dbo].[Usuario]         u   ON u.usu_id   = s.aml_usuario_creacion
WHERE   (@FECHA_DESDE IS NULL OR s.aml_fecha_lectura_utc >= @FECHA_DESDE)
  AND   (@FECHA_HASTA IS NULL OR s.aml_fecha_lectura_utc < DATEADD(DAY, 1, @FECHA_HASTA))

SET @TOTAL = (SELECT COUNT(*) FROM #pagina)

-- Ascendente por fecha: esto lo consume un grafico, y un grafico dibujado al
-- reves cuenta la historia de atras para adelante. Quien quiera la tabla
-- «lo ultimo primero» la da vuelta en la pantalla, que es una linea.
SELECT  *
FROM    #pagina
ORDER BY FECHA_LECTURA_UTC ASC, AML_ID ASC
OFFSET @OFFSET ROWS FETCH NEXT @TAMANO ROWS ONLY

DROP TABLE #pagina

RETURN(0)
GO

-- ---------------------------------------------------------------------------
-- 2) API_SEL_ACTIVO_MEDIDOR_UMBRAL — a cuanto toca la proxima mantencion
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[API_SEL_ACTIVO_MEDIDOR_UMBRAL]
@MEDIDOR    INT,
@CLIENTE    INT
AS
SET NOCOUNT ON

DECLARE @ACTUAL DECIMAL(18,2) = (SELECT ame_valor_actual FROM [dbo].[Activo_Medidor]
                                  WHERE ame_id = @MEDIDOR AND ame_cliente = @CLIENTE)

IF (@ACTUAL IS NULL) RETURN(0)   -- medidor de otro cliente, o inexistente

    /* EL PROXIMO MULTIPLO, NO EL PRIMERO

       Una programacion «cada 500 h desde 0» con el medidor en 7.500 tiene su
       proximo hito en 8.000, no en 500. Se calcula con division entera sobre
       lo ya recorrido; asi la respuesta sigue siendo correcta dentro de diez
       años sin que nadie toque una fila. */
    SELECT  pme.pme_id                  AS PME_ID,
            pro.pro_nombre              AS PROGRAMACION_NOMBRE,
            pme.pme_cada_cantidad       AS CADA_CANTIDAD,
            pme.pme_aviso_anticipacion  AS AVISO_ANTICIPACION,
            @ACTUAL                     AS VALOR_ACTUAL,
            umbral.PROXIMO              AS PROXIMO_UMBRAL,
            umbral.PROXIMO - ISNULL(pme.pme_aviso_anticipacion, 0) AS AVISO_DESDE,
            umbral.PROXIMO - @ACTUAL    AS FALTA
    FROM    [dbo].[Programacion_Medidor] pme
    INNER JOIN [dbo].[Programacion] pro ON pro.pro_id = pme.pme_programacion
    CROSS APPLY (
        SELECT CASE
                 WHEN ISNULL(pme.pme_cada_cantidad, 0) <= 0
                      THEN NULL   -- programacion mal configurada: no se inventa
                 ELSE pme.pme_valor_inicial +
                      (FLOOR((@ACTUAL - pme.pme_valor_inicial) / pme.pme_cada_cantidad) + 1)
                      * pme.pme_cada_cantidad
               END AS PROXIMO
    ) umbral
    WHERE   pme.pme_activo_medidor = @MEDIDOR
      AND   pme.pme_habilitado     = 1
      AND   pro.pro_cliente        = @CLIENTE
      AND   pro.pro_habilitado     = 1
    ORDER BY umbral.PROXIMO
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
DECLARE @M INT = (SELECT TOP 1 ame_id FROM [dbo].[Activo_Medidor] WHERE ame_codigo = 'MED-33-H')
DECLARE @T INT

IF (@M IS NOT NULL)
BEGIN
    EXEC [dbo].[API_SEL_ACTIVO_MEDIDOR_LECTURA]
         @MEDIDOR = @M, @CLIENTE = 1, @PAGINA = 1, @TAMANO = 5, @TOTAL = @T OUTPUT
    SELECT 'TOTAL DE LECTURAS = ' + CAST(ISNULL(@T, -1) AS VARCHAR) AS RESULTADO
END
ELSE
    SELECT 'SIN MEDIDOR DE PRUEBA (corre _SEMILLA_COMPONENTES_Y_LECTURAS.sql)' AS RESULTADO
GO
