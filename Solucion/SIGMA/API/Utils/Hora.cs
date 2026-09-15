using System;

namespace API.Utils
{
    /// <summary>
    /// El reloj de la plataforma: la hora de Santiago de Chile.
    ///
    /// DateTime.Now es la hora de la maquina donde corre el sitio, y esa
    /// maquina puede estar en cualquier parte (el SQL Server del hosting,
    /// por ejemplo, va en UTC-7). Toda fecha de negocio que la API calcula
    /// por su cuenta -"hoy" para una vigencia, la hora por defecto de una
    /// falla, el anio del calendario- sale de aqui, que es el mismo reloj
    /// que usa la base con FNC_AHORA() (BD/230). FNC_PAIS_HORA sigue
    /// resolviendo la hora del pais de cada cliente cuando el SP la conoce.
    /// </summary>
    public static class Hora
    {
        private static readonly TimeZoneInfo Santiago = Zona();

        private static TimeZoneInfo Zona()
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById("Pacific SA Standard Time"); }
            catch (Exception) { return TimeZoneInfo.Local; }
        }

        /// <summary>Fecha y hora actual en Santiago.</summary>
        public static DateTime Ahora
        {
            get { return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Santiago); }
        }

        /// <summary>La fecha de hoy en Santiago, sin hora.</summary>
        public static DateTime Hoy
        {
            get { return Ahora.Date; }
        }
    }
}
