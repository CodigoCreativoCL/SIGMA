/* ============================================================================
   SIGMA — Bloque 106
   PROYECCION DE FECHAS                HU-070 · HU-071 · HU-072 · HU-075 · (HU-076)
   ----------------------------------------------------------------------------

   QUE HACE

     Responde "¿que fechas produciria esta programacion entre tal y tal dia?"
     sin crear ni una ocurrencia.

   POR QUE ES LO MAS IMPORTANTE DEL SPRINT

     Los 21 criterios de aceptacion de las siete historias de programacion
     estan redactados como "entonces se genera la ocurrencia". Pero una
     ocurrencia no se puede insertar todavia: `Plan_Mantenimiento_Ocurrencia.
     pmo_plan_mantenimiento_hito` es NOT NULL contra `Plan_Mantenimiento_Hito`,
     que es HU-081 del Sprint 4 y hoy tiene cero filas.

     Esta funcion separa las dos mitades del problema:

       - CUANDO toca  -> es esto, y se puede probar hoy contra los criterios.
       - QUE se crea  -> es HU-076, y necesita el plan del Sprint 4.

     El calculo dificil -el ultimo dia de febrero, el ultimo viernes del mes,
     el desplazamiento por feriado- queda escrito y verificable ahora. El
     generador de HU-076 la va a llamar tal cual, sin reescribir nada.

   DOS COSAS QUE NO PROYECTA, Y NO ES UNA OMISION

     MEDIDOR y CONDICION no devuelven filas: no dependen del calendario sino
     de una lectura que todavia no ocurrio. "Cada 500 horas" no tiene fecha
     hasta que el horometro llegue. Se resuelven al registrar la medicion,
     no al proyectar.

   EL CAP DE SEGURIDAD

     La proyeccion se corta a 5000 filas. Una programacion diaria a diez anos
     son 3650 fechas; una cada 5 minutos son millones y colgarian la pantalla.
     El tope es explicito y la funcion marca si lo alcanzo, en vez de devolver
     una lista truncada que parece completa.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. FNC_PROGRAMACION_FECHAS
   ======================================================================== */
IF OBJECT_ID('dbo.FNC_PROGRAMACION_FECHAS') IS NOT NULL
    DROP FUNCTION [dbo].[FNC_PROGRAMACION_FECHAS]
GO

CREATE FUNCTION [dbo].[FNC_PROGRAMACION_FECHAS]
(
    @PROGRAMACION   INT,
    @DESDE          DATE,
    @HASTA          DATE
)
RETURNS @R TABLE
(
    FECHA           DATETIME    NOT NULL,
    FECHA_ORIGINAL  DATETIME    NULL,
    DESPLAZADA      BIT         NOT NULL,
    MOTIVO          NVARCHAR(400) NULL,

    /* LAS EXCLUIDAS TAMBIEN SALEN

       Antes se calculaban —la parada de planta marca DESCARTADA— y despues
       se tiraban con un WHERE. El resultado era una lista de fechas donde
       simplemente faltaban dias, sin nada que explicara por que: quien la
       miraba tenia que ir a la pestaña de exclusiones y cruzar a mano.

       Ahora se devuelven marcadas. Quien consulta decide si las muestra; lo
       que no puede es no enterarse de que existen. */
    DESCARTADA      BIT         NOT NULL DEFAULT 0
)
AS
BEGIN
    DECLARE @TIPO NVARCHAR(100), @INICIO DATE, @FIN DATE, @HABILITADO BIT
    DECLARE @D1 DATE, @D2 DATE, @DIAS INT

    SELECT  @TIPO       = t.pti_codigo,
            @INICIO     = p.pro_fecha_inicio,
            @FIN        = p.pro_fecha_fin,
            @HABILITADO = p.pro_habilitado
      FROM  [dbo].[Programacion] p
      JOIN  [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
     WHERE  p.pro_id = @PROGRAMACION

    IF (@TIPO IS NULL OR @HABILITADO = 0) RETURN

    /* La ventana pedida se recorta contra la vigencia: proyectar fuera de
       ella daria fechas que la programacion nunca va a producir. */
    SET @D1 = CASE WHEN @DESDE > @INICIO THEN @DESDE ELSE @INICIO END
    SET @D2 = CASE WHEN @FIN IS NOT NULL AND @HASTA > @FIN THEN @FIN ELSE @HASTA END

    IF (@D1 IS NULL OR @D2 IS NULL OR @D2 < @D1) RETURN

    SET @DIAS = DATEDIFF(DAY, @D1, @D2) + 1
    IF (@DIAS > 20000) SET @DIAS = 20000

    /* Tabla de dias sin recursion: la CTE recursiva topa en 100 niveles por
       defecto y OPTION(MAXRECURSION) dentro de una funcion es fragil. */
    DECLARE @CAL TABLE (D DATE PRIMARY KEY, DOW TINYINT)

    ;WITH N0 AS (SELECT 1 c UNION ALL SELECT 1),
          N1 AS (SELECT 1 c FROM N0 a CROSS JOIN N0 b),
          N2 AS (SELECT 1 c FROM N1 a CROSS JOIN N1 b),
          N3 AS (SELECT 1 c FROM N2 a CROSS JOIN N2 b),
          N4 AS (SELECT 1 c FROM N3 a CROSS JOIN N3 b),
          NUM AS (SELECT TOP (@DIAS) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
                    FROM N4)
    INSERT INTO @CAL (D, DOW)
    SELECT  DATEADD(DAY, n, @D1),
            /* 1 = lunes ... 7 = domingo, sin depender de @@DATEFIRST, que
               cambia con el idioma de la sesion y daria dias distintos
               segun quien ejecute. */
            ((DATEPART(WEEKDAY, DATEADD(DAY, n, @D1)) + @@DATEFIRST - 2) % 7) + 1
      FROM  NUM

    /* --------------------------------------------------------------------
       Las fechas crudas, antes de exclusiones
       -------------------------------------------------------------------- */
    DECLARE @CRUDO TABLE (FECHA DATETIME NOT NULL)

    /* ---- FECHA UNICA -------------------------------------------- HU-070 */
    IF (@TIPO = 'FECHA UNICA')
    BEGIN
        INSERT INTO @CRUDO (FECHA)
        SELECT CAST(f.pfe_fecha AS DATETIME)
               + CAST(ISNULL(f.pfe_hora, '00:00:00') AS DATETIME)
          FROM [dbo].[Programacion_Fecha] f
         WHERE f.pfe_programacion = @PROGRAMACION
           AND f.pfe_incluida = 1
           AND f.pfe_fecha BETWEEN @D1 AND @D2
    END

    /* ---- CALENDARIO --------------------------------------------- HU-071 */
    IF (@TIPO = 'CALENDARIO')
    BEGIN
        DECLARE @FREC NVARCHAR(100), @INTERVALO INT, @ORDINAL INT
        DECLARE @DIA_MES INT, @MES INT, @HORA TIME, @PCA INT
        DECLARE @LUNES_BASE DATE

        SELECT TOP 1
               @PCA = c.pca_id, @FREC = f.fre_codigo, @INTERVALO = c.pca_intervalo,
               @ORDINAL = c.pca_semana_ordinal, @DIA_MES = c.pca_dia_mes,
               @MES = c.pca_mes, @HORA = c.pca_hora_local
          FROM [dbo].[Programacion_Calendario] c
          JOIN [dbo].[Frecuencia_Tipo] f ON f.fre_id = c.pca_frecuencia_tipo
         WHERE c.pca_programacion = @PROGRAMACION AND c.pca_habilitado = 1

        IF (@PCA IS NOT NULL)
        BEGIN
            /* El lunes de la semana de inicio: contar semanas con
               DATEDIFF(WEEK,...) tambien depende de @@DATEFIRST. */
            SET @LUNES_BASE = DATEADD(DAY,
                    -(((DATEPART(WEEKDAY, @INICIO) + @@DATEFIRST - 2) % 7)), @INICIO)

            INSERT INTO @CRUDO (FECHA)
            SELECT CAST(c.D AS DATETIME) + CAST(@HORA AS DATETIME)
              FROM @CAL c
             WHERE c.D >= @INICIO
               AND (
                    /* -------- DIARIA -------- */
                    (@FREC = 'DIARIA'
                     AND DATEDIFF(DAY, @INICIO, c.D) % @INTERVALO = 0)

                    /* -------- SEMANAL: HU-071 #1 -------- */
                 OR (@FREC = 'SEMANAL'
                     AND (DATEDIFF(DAY, @LUNES_BASE, c.D) / 7) % @INTERVALO = 0
                     AND EXISTS (SELECT 1 FROM [dbo].[Programacion_Calendario_Dia] d
                                  WHERE d.pcd_programacion_calendario = @PCA
                                    AND d.pcd_dia_semana = c.DOW))

                    /* -------- MENSUAL: HU-071 #2 y #3 -------- */
                 OR (@FREC = 'MENSUAL'
                     AND DATEDIFF(MONTH, @INICIO, c.D) % @INTERVALO = 0
                     AND (
                          /* por dia del mes: -1 = el ultimo. Un 31 en
                             febrero se pega al ultimo dia real en vez de
                             no producir nada. */
                          (@DIA_MES IS NOT NULL
                           AND DAY(c.D) = CASE WHEN @DIA_MES = -1 THEN DAY(EOMONTH(c.D))
                                               WHEN @DIA_MES > DAY(EOMONTH(c.D)) THEN DAY(EOMONTH(c.D))
                                               ELSE @DIA_MES END)
                          /* por ordinal de semana: -1 = el ultimo */
                       OR (@DIA_MES IS NULL AND @ORDINAL IS NOT NULL
                           AND EXISTS (SELECT 1 FROM [dbo].[Programacion_Calendario_Dia] d
                                        WHERE d.pcd_programacion_calendario = @PCA
                                          AND d.pcd_dia_semana = c.DOW)
                           AND ((@ORDINAL = -1 AND DAY(c.D) + 7 > DAY(EOMONTH(c.D)))
                             OR (@ORDINAL <> -1 AND ((DAY(c.D) - 1) / 7) + 1 = @ORDINAL)))
                         ))

                    /* -------- ANUAL -------- */
                 OR (@FREC = 'ANUAL'
                     AND MONTH(c.D) = @MES
                     AND DATEDIFF(YEAR, @INICIO, c.D) % @INTERVALO = 0
                     AND (
                          (@DIA_MES IS NOT NULL
                           AND DAY(c.D) = CASE WHEN @DIA_MES = -1 THEN DAY(EOMONTH(c.D))
                                               WHEN @DIA_MES > DAY(EOMONTH(c.D)) THEN DAY(EOMONTH(c.D))
                                               ELSE @DIA_MES END)
                       OR (@DIA_MES IS NULL AND @ORDINAL IS NOT NULL
                           AND EXISTS (SELECT 1 FROM [dbo].[Programacion_Calendario_Dia] d
                                        WHERE d.pcd_programacion_calendario = @PCA
                                          AND d.pcd_dia_semana = c.DOW)
                           AND ((@ORDINAL = -1 AND DAY(c.D) + 7 > DAY(EOMONTH(c.D)))
                             OR (@ORDINAL <> -1 AND ((DAY(c.D) - 1) / 7) + 1 = @ORDINAL)))
                         ))
                   )
        END
    END

    /* ---- INTERVALO DE TIEMPO ------------------------------------ HU-072 */
    IF (@TIPO = 'INTERVALO TIEMPO')
    BEGIN
        DECLARE @UNIDAD NVARCHAR(100), @CANTIDAD INT, @ANCLA DATETIME
        DECLARE @PASOS INT

        SELECT TOP 1 @UNIDAD = u.uti_codigo, @CANTIDAD = i.pin_cantidad,
                     @ANCLA = i.pin_fecha_ancla_utc
          FROM [dbo].[Programacion_Intervalo] i
          JOIN [dbo].[Unidad_Tiempo] u ON u.uti_id = i.pin_unidad_tiempo
         WHERE i.pin_programacion = @PROGRAMACION AND i.pin_habilitado = 1

        IF (@UNIDAD IS NOT NULL AND @CANTIDAD > 0)
        BEGIN
            /* Cuantos saltos caben hasta el final de la ventana. DATEADD por
               unidad resuelve solo el mes corto: DATEADD(MONTH,1,'31-01')
               da 28-02, que es exactamente lo que se espera. */
            SET @PASOS =
                CASE @UNIDAD
                    WHEN 'MINUTO' THEN DATEDIFF(MINUTE, @ANCLA, DATEADD(DAY, 1, @D2)) / @CANTIDAD
                    WHEN 'HORA'   THEN DATEDIFF(HOUR,   @ANCLA, DATEADD(DAY, 1, @D2)) / @CANTIDAD
                    WHEN 'DIA'    THEN DATEDIFF(DAY,    @ANCLA, @D2) / @CANTIDAD
                    WHEN 'SEMANA' THEN DATEDIFF(WEEK,   @ANCLA, @D2) / @CANTIDAD + 1
                    WHEN 'MES'    THEN DATEDIFF(MONTH,  @ANCLA, @D2) / @CANTIDAD + 1
                    WHEN 'ANIO'   THEN DATEDIFF(YEAR,   @ANCLA, @D2) / @CANTIDAD + 1
                    ELSE 0 END

            IF (@PASOS < 0) SET @PASOS = 0
            IF (@PASOS > 5000) SET @PASOS = 5000

            ;WITH M0 AS (SELECT 1 c UNION ALL SELECT 1),
                  M1 AS (SELECT 1 c FROM M0 a CROSS JOIN M0 b),
                  M2 AS (SELECT 1 c FROM M1 a CROSS JOIN M1 b),
                  M3 AS (SELECT 1 c FROM M2 a CROSS JOIN M2 b),
                  M4 AS (SELECT 1 c FROM M3 a CROSS JOIN M3 b),
                  PASO AS (SELECT TOP (@PASOS + 1)
                                  ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
                             FROM M4)
            INSERT INTO @CRUDO (FECHA)
            SELECT F FROM (
                SELECT CASE @UNIDAD
                            WHEN 'MINUTO' THEN DATEADD(MINUTE, n * @CANTIDAD, @ANCLA)
                            WHEN 'HORA'   THEN DATEADD(HOUR,   n * @CANTIDAD, @ANCLA)
                            WHEN 'DIA'    THEN DATEADD(DAY,    n * @CANTIDAD, @ANCLA)
                            WHEN 'SEMANA' THEN DATEADD(WEEK,   n * @CANTIDAD, @ANCLA)
                            WHEN 'MES'    THEN DATEADD(MONTH,  n * @CANTIDAD, @ANCLA)
                            WHEN 'ANIO'   THEN DATEADD(YEAR,   n * @CANTIDAD, @ANCLA)
                       END AS F
                  FROM PASO) x
             WHERE CAST(F AS DATE) BETWEEN @D1 AND @D2
        END
    END

    /* ---- MEDIDOR y CONDICION ------------------------- HU-073 · HU-074
       No proyectan: dependen de una lectura que todavia no ocurrio. */

    /* --------------------------------------------------------------------
       Exclusiones                                            HU-075 #2 y #3
       -------------------------------------------------------------------- */
    DECLARE @W TABLE (
        ID              INT IDENTITY(1,1) PRIMARY KEY,
        FECHA           DATETIME NOT NULL,
        FECHA_ORIGINAL  DATETIME NULL,
        DESPLAZADA      BIT NOT NULL DEFAULT 0,
        MOTIVO          NVARCHAR(400) NULL,
        DESCARTADA      BIT NOT NULL DEFAULT 0
    )

    INSERT INTO @W (FECHA, DESPLAZADA, DESCARTADA)
    SELECT TOP 5000 FECHA, 0, 0 FROM @CRUDO ORDER BY FECHA

    /* #3 -parada de planta-: la fecha simplemente no existe. */
    /* Se guarda tambien el MOTIVO. Una fecha excluida sin decir por que
       obliga a ir a buscar cual de las exclusiones la tapo. */
    UPDATE w
       SET DESCARTADA = 1,
           MOTIVO = ISNULL(w.MOTIVO, x.pxc_motivo)
      FROM @W w
     CROSS APPLY (SELECT TOP 1 e.pxc_motivo
                    FROM [dbo].[Programacion_Exclusion] e
                   WHERE e.pxc_programacion = @PROGRAMACION
                     AND e.pxc_habilitado = 1
                     AND e.pxc_desplaza = 0
                     AND w.FECHA >= e.pxc_fecha_inicio_utc
                     AND w.FECHA <= e.pxc_fecha_fin_utc) x

    /* #2 -feriado-: se corre al siguiente dia habil y se guarda la original.
       Se itera porque el dia siguiente puede caer en otro feriado o en fin
       de semana. El tope de 15 vueltas evita el ciclo infinito si alguien
       excluye un mes entero con desplazamiento.

       OJO CON EL FIN DE SEMANA: solo se salta cuando la fecha YA venia
       desplazada. Una programacion diaria que cae sabado se queda el sabado
       -en industria se trabaja fin de semana-; lo que no puede pasar es que
       un feriado la empuje justo AL sabado y ahi se detenga, porque el
       criterio pide "el siguiente dia habil". */
    DECLARE @VUELTA INT = 0

    WHILE (@VUELTA < 15)
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM @W w
             WHERE w.DESCARTADA = 0
               AND (EXISTS (SELECT 1 FROM [dbo].[Programacion_Exclusion] e
                             WHERE e.pxc_programacion = @PROGRAMACION
                               AND e.pxc_habilitado = 1
                               AND e.pxc_desplaza = 1
                               AND w.FECHA >= e.pxc_fecha_inicio_utc
                               AND w.FECHA <= e.pxc_fecha_fin_utc)
                    OR (w.DESPLAZADA = 1
                        AND ((DATEPART(WEEKDAY, w.FECHA) + @@DATEFIRST - 2) % 7) + 1 IN (6, 7))))
            BREAK

        UPDATE w
           SET FECHA_ORIGINAL = ISNULL(w.FECHA_ORIGINAL, w.FECHA),
               FECHA          = DATEADD(DAY, 1, w.FECHA),
               DESPLAZADA     = 1,
               MOTIVO = ISNULL(w.MOTIVO,
                          ISNULL((SELECT TOP 1 e.pxc_motivo
                                    FROM [dbo].[Programacion_Exclusion] e
                                   WHERE e.pxc_programacion = @PROGRAMACION
                                     AND e.pxc_habilitado = 1
                                     AND e.pxc_desplaza = 1
                                     AND w.FECHA >= e.pxc_fecha_inicio_utc
                                     AND w.FECHA <= e.pxc_fecha_fin_utc),
                                 N'Fin de semana'))
          FROM @W w
         WHERE w.DESCARTADA = 0
           AND (EXISTS (SELECT 1 FROM [dbo].[Programacion_Exclusion] e
                         WHERE e.pxc_programacion = @PROGRAMACION
                           AND e.pxc_habilitado = 1
                           AND e.pxc_desplaza = 1
                           AND w.FECHA >= e.pxc_fecha_inicio_utc
                           AND w.FECHA <= e.pxc_fecha_fin_utc)
                OR (w.DESPLAZADA = 1
                    AND ((DATEPART(WEEKDAY, w.FECHA) + @@DATEFIRST - 2) % 7) + 1 IN (6, 7)))

        SET @VUELTA = @VUELTA + 1
    END

    /* Una fecha desplazada puede haber salido de la ventana de vigencia. */
    INSERT INTO @R (FECHA, FECHA_ORIGINAL, DESPLAZADA, MOTIVO, DESCARTADA)
    SELECT w.FECHA, w.FECHA_ORIGINAL, w.DESPLAZADA, w.MOTIVO, w.DESCARTADA
      FROM @W w
     WHERE (@FIN IS NULL OR CAST(w.FECHA AS DATE) <= @FIN)
     ORDER BY w.FECHA

    RETURN
END
GO

PRINT '--- FNC_PROGRAMACION_FECHAS creada.'
GO


/* ========================================================================
   2. SEL_PROGRAMACION_PROYECCION

      El C# nunca ejecuta SQL: la pantalla y la API llaman a este SP, que
      ademas verifica el cliente antes de proyectar.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_PROYECCION') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROGRAMACION_PROYECCION]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_PROYECCION]
    @PROGRAMACION   INT,
    @CLIENTE        INT,
    @DESDE          DATE = NULL,
    @HASTA          DATE = NULL,
    @TOP            INT = 12
AS
SET NOCOUNT ON

DECLARE @PAIS INT, @HOY DATE, @TIPO NVARCHAR(100), @HORIZONTE INT

IF NOT EXISTS (SELECT 1 FROM [dbo].[Programacion]
                WHERE pro_id = @PROGRAMACION AND pro_cliente = @CLIENTE)
BEGIN
    RAISERROR('1.- LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE.', 16, 1)
    RETURN -1
END

SELECT @PAIS = cli_pais FROM [dbo].[Cliente] WHERE cli_id = @CLIENTE
SET @HOY = CAST([dbo].[FNC_PAIS_HORA](@PAIS) AS DATE)

SELECT @TIPO = t.pti_codigo
  FROM [dbo].[Programacion] p
  JOIN [dbo].[Programacion_Tipo] t ON t.pti_id = p.pro_programacion_tipo
 WHERE p.pro_id = @PROGRAMACION

/* Sin ventana explicita se usa el horizonte de la propia programacion, que
   es el mismo que va a usar el generador de HU-076. Asi la vista previa
   muestra lo que realmente se va a crear. */
SELECT @HORIZONTE = ISNULL(pge_horizonte_dia, 90)
  FROM [dbo].[Programacion_Generacion] WHERE pge_programacion = @PROGRAMACION

SET @DESDE = ISNULL(@DESDE, @HOY)
SET @HASTA = ISNULL(@HASTA, DATEADD(DAY, ISNULL(@HORIZONTE, 90) * 4, @DESDE))

IF (@TOP IS NULL OR @TOP < 1) SET @TOP = 12
IF (@TOP > 500) SET @TOP = 500

    SELECT TOP (@TOP)
           f.FECHA,
           f.DESCARTADA,
           f.FECHA_ORIGINAL,
           f.DESPLAZADA,
           f.MOTIVO,
           CAST(CASE WHEN CAST(f.FECHA AS DATE) < @HOY THEN 1 ELSE 0 END AS BIT) AS ES_PASADA,
           @TIPO AS TIPO_CODIGO
      FROM [dbo].[FNC_PROGRAMACION_FECHAS](@PROGRAMACION, @DESDE, @HASTA) f
     ORDER BY f.FECHA
GO

PRINT '--- SEL_PROGRAMACION_PROYECCION creado.'
GO

PRINT '106_PROGRAMACION_PROYECCION aplicado.'
GO
