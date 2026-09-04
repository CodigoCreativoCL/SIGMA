using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// El prefijo de tres letras que lleva el código de cada módulo.
    ///
    /// DE DÓNDE SALE
    ///
    ///   De la tabla `Modulo_Codigo`, que es la MISMA que usa
    ///   `FNC_CODIGO_AUTOMATICO` en la base. Si la pantalla los escribiera a
    ///   mano habría dos fuentes para el mismo dato, y bastaría cambiar una
    ///   para que la etiqueta dijera "ARE-" mientras lo guardado empieza con
    ///   otra cosa.
    ///
    /// EL CACHÉ DURA UNA PETICIÓN
    ///
    ///   Una ficha pregunta el prefijo dos o tres veces —al pintar el campo,
    ///   al guardar— y sería un viaje a la base cada vez. Vive en
    ///   `HttpContext.Items`, que se vacía al terminar la petición: dentro de
    ///   una misma página todas las respuestas son iguales, y un cambio de
    ///   prefijo se ve en el clic siguiente.
    ///
    ///   No se usa `Session` a propósito. Ahí duraría hasta que la persona
    ///   cerrara sesión, y un prefijo corregido seguiría mostrándose mal
    ///   durante horas.
    ///
    /// SI NO HAY, NO SE INVENTA
    ///
    ///   Un módulo sin fila —o deshabilitado— devuelve cadena vacía. La ficha
    ///   que recibe vacío no muestra prefijo y deja escribir el código
    ///   completo, que es como funcionaba antes.
    /// </summary>
    public static class CodigoModulo
    {
        private const string CLAVE = "sg_prefijos_modulo";

        /// <summary>
        /// El prefijo de una tabla, sin el guion. Por ejemplo "ARE".
        /// </summary>
        public static string Prefijo(string tabla)
        {
            if (string.IsNullOrEmpty(tabla)) return "";

            Dictionary<string, string> mapa = Mapa();

            return mapa.ContainsKey(tabla) ? mapa[tabla] : "";
        }

        /// <summary>
        /// El prefijo listo para mostrar delante del campo: "ARE-".
        /// Vacío si el módulo no tiene, para que la ficha no dibuje un guión
        /// suelto.
        /// </summary>
        public static string Etiqueta(string tabla)
        {
            string p = Prefijo(tabla);

            return string.IsNullOrEmpty(p) ? "" : p + "-";
        }

        /// <summary>
        /// Arma el código final a partir de lo que escribió la persona.
        ///
        /// VACÍO SIGNIFICA "PONLO TÚ"
        ///   Devuelve "AUTO", que es la señal que el SP ya entiende para
        ///   generar &lt;PREFIJO&gt;-&lt;id&gt;. Así, quien no quiera inventar un
        ///   código sigue teniendo uno, y quien sí quiera lo escribe.
        ///
        /// NO SE DUPLICA EL PREFIJO
        ///   Si alguien escribe "ARE-CALDERAS" en un campo que ya muestra
        ///   "ARE-" delante, el resultado tiene que ser ARE-CALDERAS y no
        ///   ARE-ARE-CALDERAS. Se comprueba antes de concatenar.
        /// </summary>
        public static string Componer(string tabla, string escrito)
        {
            escrito = (escrito ?? "").Trim();

            if (escrito.Length == 0) return "AUTO";

            string p = Prefijo(tabla);

            if (string.IsNullOrEmpty(p)) return escrito.ToUpper();

            string limpio = escrito.ToUpper();
            string conGuion = p + "-";

            if (limpio.StartsWith(conGuion, StringComparison.Ordinal)) return limpio;

            /* Un guión inicial suelto —"-CALDERAS"— saldría como ARE--CALDERAS. */
            return conGuion + limpio.TrimStart('-');
        }

        /// <summary>
        /// Lo contrario: de "ARE-CALDERAS" devuelve "CALDERAS", para poder
        /// mostrarlo dentro del campo cuando se edita un registro que ya
        /// existe.
        /// </summary>
        public static string Sufijo(string tabla, string codigo)
        {
            codigo = (codigo ?? "").Trim();

            string p = Prefijo(tabla);

            if (string.IsNullOrEmpty(p)) return codigo;

            string conGuion = p + "-";

            return codigo.StartsWith(conGuion, StringComparison.OrdinalIgnoreCase)
                 ? codigo.Substring(conGuion.Length)
                 : codigo;
        }

        /// <summary>
        /// Todos los prefijos, leídos una vez por petición.
        /// </summary>
        private static Dictionary<string, string> Mapa()
        {
            HttpContext ctx = HttpContext.Current;

            if (ctx != null && ctx.Items[CLAVE] != null)
                return (Dictionary<string, string>)ctx.Items[CLAVE];

            Dictionary<string, string> mapa =
                new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_MODULO_CODIGO");

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                        mapa[dr["TABLA"].ToString()] = dr["PREFIJO"].ToString();
                }

                cmd.Connection.Close();
            }
            catch (Exception)
            {
                /* Sin prefijos la ficha deja escribir el código completo. Es
                   peor dejar la pantalla caída que dejarla sin la ayuda. */
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            if (ctx != null) ctx.Items[CLAVE] = mapa;

            return mapa;
        }
    }
}
