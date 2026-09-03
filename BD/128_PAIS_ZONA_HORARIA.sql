/* ============================================================================
   SIGMA - Bloque 128
   LA HORA DEL PAIS DEJA DE DEPENDER DE DONDE ESTE EL SERVIDOR
   ----------------------------------------------------------------------------

   EL SINTOMA

     En la ficha de un grupo se agregaba a alguien como lider "desde hoy" y el
     resumen seguia diciendo "Sin lider vigente", mientras la fila de abajo
     mostraba el chip LIDER. La pantalla se contradecia sola.

   LA CAUSA

     El servidor de base de datos corre en UTC-07:00 y el cliente trabaja en
     Chile. Pasadas las 21:00 en Chile, para el servidor todavia es el dia
     anterior. La persona elige "hoy" en el calendario -que muestra la fecha
     de SU pantalla- y el servidor la compara contra un "hoy" que va tres
     horas atras: la fecha elegida queda en el futuro y el tramo se marca
     PENDIENTE.

     Esto no era un problema del modulo de grupos. Toca todo lo que compara
     fechas: permisos vencidos, proyecciones de programacion, estados de
     activo. Un dia de corrimiento, todas las noches.

   POR QUE NO ALCANZABA LO QUE HABIA

     `FNC_PAIS_HORA` ya existia para esto, pero suma o resta un numero entero
     de horas guardado en PAISES. Dos problemas:

       1. Ese numero es un desfase respecto del servidor, no respecto de UTC.
          Estaba configurado para cuando el servidor vivia en Chile: por eso
          Chile quedo en 0. Al mudarse el servidor, todos los desfases
          quedaron mal, y no hay forma de saberlo mirando el dato.

       2. Un entero fijo no sabe de horario de verano. Chile cambia de hora
          dos veces al año; un 0 -o un 3- acierta la mitad del año.

   LA CORRECCION

     Se agrega a PAISES la zona horaria real del pais y `FNC_PAIS_HORA` la
     usa con AT TIME ZONE, que resuelve el desfase contra UTC y aplica el
     horario de verano solo. Deja de importar donde este alojado el servidor.

     El cambio es ADITIVO: si un pais no tiene zona configurada, la funcion
     se comporta exactamente como antes. Ningun pais cambia de
     comportamiento salvo los que se configuran aca abajo, y esos se
     verifican contra sys.time_zone_info antes de escribirse.
   ============================================================================ */

SET NOCOUNT ON
GO

/* ------------------------------------------------------------------ columna */
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.PAISES')
                 AND name = 'pai_zona_horaria')
BEGIN
    ALTER TABLE [dbo].[PAISES] ADD [pai_zona_horaria] VARCHAR(100) NULL
END
GO

/* ---------------------------------------------------------------------- dato

   Solo se escribe la zona si el motor la reconoce. Un nombre mal escrito
   haria fallar AT TIME ZONE en tiempo de ejecucion, dentro de una funcion
   que llama medio sistema: preferible que ese pais siga con el
   comportamiento viejo a que reviente una consulta.                          */
;WITH ZONAS AS
(
    SELECT 1 AS PAIS, 'Pacific SA Standard Time' AS ZONA   -- Chile
    UNION ALL SELECT 3, 'SA Pacific Standard Time'          -- Peru
    UNION ALL SELECT 4, 'Argentina Standard Time'           -- Argentina
    UNION ALL SELECT 5, 'SA Pacific Standard Time'          -- Ecuador
    UNION ALL SELECT 6, 'SA Western Standard Time'          -- Panama
)
UPDATE  p
SET     p.pai_zona_horaria = z.ZONA
FROM    [dbo].[PAISES] p
JOIN    ZONAS z ON z.PAIS = p.pai_id
WHERE   EXISTS (SELECT 1 FROM sys.time_zone_info t WHERE t.name = z.ZONA)
  AND   ISNULL(p.pai_zona_horaria, '') <> z.ZONA
GO

/* -------------------------------------------------------------------- funcion */
CREATE OR ALTER FUNCTION [dbo].[FNC_PAIS_HORA]
(
    @PAIS INT
)
RETURNS DATETIME
AS
BEGIN

    IF @PAIS IS NULL OR @PAIS = 0
        RETURN GETDATE()

    DECLARE @ZONA       VARCHAR(100)
           ,@SUMA_RESTA VARCHAR(1)
           ,@HORA       INT
           ,@FECHA      DATETIME

    SELECT  @ZONA       = pai_zona_horaria
           ,@SUMA_RESTA = pai_suma_resta
           ,@HORA       = pai_hora
    FROM    [dbo].[PAISES]
    WHERE   pai_id = @PAIS

    /* Camino nuevo: la zona resuelve el desfase contra UTC y el horario de
       verano. SYSDATETIMEOFFSET() trae el offset real del servidor, asi que
       da igual donde este alojado. */
    IF @ZONA IS NOT NULL AND @ZONA <> ''
        RETURN CAST(SYSDATETIMEOFFSET() AT TIME ZONE @ZONA AS DATETIME)

    /* Camino viejo, intacto, para cualquier pais todavia sin zona. */
    IF @SUMA_RESTA IS NULL OR @HORA IS NULL OR @HORA = 0
        RETURN GETDATE()

    IF @SUMA_RESTA = '+'
        SET @FECHA = DATEADD(HOUR,  @HORA, GETDATE())
    ELSE
        SET @FECHA = DATEADD(HOUR, -@HORA, GETDATE())

    RETURN @FECHA

END
GO
