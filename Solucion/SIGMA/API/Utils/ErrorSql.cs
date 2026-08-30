using System;
using System.Data.SqlClient;
using System.Net;
using System.Text.RegularExpressions;

namespace API.Utils
{
    /// <summary>
    /// Traduce un error de un stored procedure a un código HTTP con mensaje
    /// legible.
    ///
    /// POR QUE EXISTE
    ///   Todas las reglas de negocio de SIGMA viven en los SPs y se
    ///   comunican con RAISERROR (patrón del grupo). Sin esto, cada regla
    ///   incumplida llegaba al cliente como un 500 con el stack de
    ///   SqlException: la app no puede distinguir "el RUT ya existe" de "la
    ///   base se cayó", y las dos cosas exigen reacciones opuestas —una se
    ///   le muestra al usuario, la otra se reintenta o se escala—.
    ///
    /// COMO DISTINGUE
    ///   Los SPs del proyecto emiten mensajes con un formato fijo:
    ///
    ///       RAISERROR('3.- EL PLAN NO TIENE PRECIO VIGENTE.', 16, 1)
    ///
    ///   Severidad 16 = error de negocio previsto por quien escribió el SP.
    ///   Severidad mayor = problema de infraestructura. Esa es la primera
    ///   división, y es la que importa.
    ///
    ///   Dentro de los de negocio, el código sale del TEXTO. No es
    ///   elegante, pero la alternativa —un catálogo de códigos por SP— hay
    ///   que mantenerla sincronizada con 150 procedimientos, y el día que se
    ///   desincronice mentirá con más seguridad que esto.
    ///
    /// LO QUE NUNCA SE FILTRA
    ///   Un error que NO es de negocio se responde 500 con un texto
    ///   genérico. El detalle real no viaja al cliente: nombres de tablas,
    ///   de columnas y de servidores son justo lo que sirve para atacar la
    ///   base. Queda en el log del servidor, que es donde hace falta.
    /// </summary>
    public static class ErrorSql
    {
        /// <summary>Severidad con la que los SPs del proyecto avisan reglas de negocio.</summary>
        private const int SEVERIDAD_NEGOCIO = 16;

        private static readonly Regex PREFIJO_NUMERADO = new Regex(@"^\s*\d+\s*\.\-\s*", RegexOptions.Compiled);

        /// <summary>
        /// El código HTTP que corresponde a la excepción.
        /// </summary>
        public static HttpStatusCode Codigo(Exception ex)
        {
            SqlException sql = Buscar(ex);

            // No es de SQL, o es un fallo de infraestructura: 500.
            if (sql == null || sql.Class != SEVERIDAD_NEGOCIO)
                return HttpStatusCode.InternalServerError;

            string texto = (sql.Message ?? "").ToUpperInvariant();

            /* El orden importa: "YA EXISTE" contiene "EXISTE", así que el
               conflicto se evalúa antes que el no-encontrado. */

            if (texto.Contains("YA EXISTE") || texto.Contains("YA TIENE") ||
                texto.Contains("YA ESTÁ") || texto.Contains("YA ESTA") ||
                texto.Contains("DUPLICAD"))
                return HttpStatusCode.Conflict;              // 409

            if (texto.Contains("BLOQUEAD"))
                return (HttpStatusCode)423;                  // 423 Locked

            if (texto.Contains("NO TIENE PERMISO") || texto.Contains("NO AUTORIZ") ||
                texto.Contains("NO ESTÁ HABILITAD") || texto.Contains("NO ESTA HABILITAD") ||
                texto.Contains("NO PERTENECE"))
                return HttpStatusCode.Forbidden;             // 403

            if (texto.Contains("NO EXISTE") || texto.Contains("NO SE ENCONTR"))
                return HttpStatusCode.NotFound;              // 404

            /* Cualquier otra regla de negocio es una petición mal formada
               desde el punto de vista del dominio: falta un dato, un monto
               es negativo, una fecha es pasada. 400. */
            return HttpStatusCode.BadRequest;
        }

        /// <summary>
        /// El mensaje que se le puede mostrar a una persona.
        ///
        /// Le quita el "3.- " del principio: ese número ordena los
        /// controles dentro del SP y no significa nada fuera de él. Lo que
        /// sí queda es la frase, que está escrita para leerse.
        /// </summary>
        public static string Mensaje(Exception ex)
        {
            SqlException sql = Buscar(ex);

            if (sql == null || sql.Class != SEVERIDAD_NEGOCIO)
                return "Ocurrió un error al procesar la solicitud. " +
                       "Si vuelve a pasar, avise al administrador.";

            string mensaje = PREFIJO_NUMERADO.Replace(sql.Message ?? "", "").Trim();

            return string.IsNullOrEmpty(mensaje)
                ? "La operación no se pudo completar."
                : mensaje;
        }

        /// <summary>
        /// True si la excepción es una regla de negocio y no una falla.
        /// Sirve para decidir si el detalle se registra como incidente.
        /// </summary>
        public static bool EsDeNegocio(Exception ex)
        {
            SqlException sql = Buscar(ex);
            return sql != null && sql.Class == SEVERIDAD_NEGOCIO;
        }

        /// <summary>
        /// Encuentra la SqlException aunque venga envuelta.
        ///
        /// Los controllers del proyecto capturan y relanzan con
        /// `new Exception(ex.Message)`, lo que pierde el tipo. Por eso se
        /// recorre la cadena de InnerException en vez de hacer un cast
        /// directo: sin esto, toda regla de negocio que pase por un
        /// controller heredado se vería como un 500.
        /// </summary>
        private static SqlException Buscar(Exception ex)
        {
            Exception actual = ex;

            while (actual != null)
            {
                SqlException sql = actual as SqlException;
                if (sql != null) return sql;

                actual = actual.InnerException;
            }

            return null;
        }
    }
}
