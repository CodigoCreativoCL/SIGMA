using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Caching;

namespace SitioBase.Controller
{
    /// <summary>
    /// El modulo Soporte (mesa de ayuda, centro de ayuda y campanas) habla con
    /// la base por aca.
    ///
    /// POR QUE FILAS Y NO MODELOS
    ///   Las pantallas de soporte se dibujan en el navegador (sigma-soporte.js)
    ///   y lo unico que hace el servidor es pasarles lo que devuelve el SP. Un
    ///   modelo por cada resultado serian treinta clases que solo copian
    ///   columnas a propiedades y de vuelta a JSON. Aca cada fila sale como
    ///   diccionario con el nombre de la columna, y la autorizacion queda
    ///   donde corresponde: en el SP, que recibe al usuario y decide.
    ///
    /// LAS FECHAS VIAJAN EN ISO
    ///   JavaScriptSerializer las escribe como "/Date(…)/", que el navegador no
    ///   entiende. Se mandan como "2026-10-06T09:30:00" (hora de Chile, igual
    ///   que en la base) y el JS hace new Date(…).
    /// </summary>
    public static class SoporteDatos
    {
        public static int Usuario()
        {
            int id;
            return int.TryParse(Session.UsuarioId(), out id) ? id : 0;
        }

        /// <summary>Todos los resultados del SP, cada uno como lista de filas.</summary>
        public static List<List<Dictionary<string, object>>> Conjuntos(string sp, params object[] parametros)
        {
            List<List<Dictionary<string, object>>> todos = new List<List<Dictionary<string, object>>>();
            SqlCommand cmd = new SqlCommand(sp);
            cmd.CommandTimeout = 60;

            for (int i = 0; i + 1 < parametros.Length; i += 2)
                cmd.Parameters.AddWithValue((string)parametros[i], parametros[i + 1] ?? DBNull.Value);

            try
            {
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    do
                    {
                        List<Dictionary<string, object>> filas = new List<Dictionary<string, object>>();
                        while (dr.Read())
                        {
                            Dictionary<string, object> f = new Dictionary<string, object>(dr.FieldCount);
                            for (int c = 0; c < dr.FieldCount; c++)
                            {
                                object v = dr.GetValue(c);
                                if (v == DBNull.Value) v = null;
                                else if (v is DateTime) v = ((DateTime)v).ToString("yyyy-MM-ddTHH:mm:ss");
                                else if (v is decimal) v = Convert.ToDouble(v);
                                f[dr.GetName(c)] = v;
                            }
                            filas.Add(f);
                        }
                        todos.Add(filas);
                    } while (dr.NextResult());
                }
            }
            finally
            {
                if (cmd.Connection != null) cmd.Connection.Dispose();
            }

            return todos;
        }

        public static List<Dictionary<string, object>> Filas(string sp, params object[] parametros)
        {
            List<List<Dictionary<string, object>>> c = Conjuntos(sp, parametros);
            return c.Count > 0 ? c[0] : new List<Dictionary<string, object>>();
        }

        /// <summary>La primera fila del primer resultado (el que trae el id en los INS/UPS).</summary>
        public static Dictionary<string, object> Fila(string sp, params object[] parametros)
        {
            List<List<Dictionary<string, object>>> c = Conjuntos(sp, parametros);
            for (int i = c.Count - 1; i >= 0; i--)
                if (c[i].Count > 0) return c[i][0];
            return new Dictionary<string, object>();
        }

        public static List<Dictionary<string, object>> Del(List<List<Dictionary<string, object>>> c, int i)
        {
            return c.Count > i ? c[i] : new List<Dictionary<string, object>>();
        }

        /// <summary>
        /// Sube un adjunto (base64 desde el navegador) y devuelve su id. Las
        /// imagenes se alivianan antes de llegar al blob.
        /// </summary>
        public static int SubirArchivo(int cliente, string carpeta, string nombre, string mime, string base64, int maxMb)
        {
            if (cliente <= 0) throw new Exception("Elige un cliente antes de subir archivos.");
            byte[] bytes = Convert.FromBase64String(base64 ?? "");
            if (bytes.Length == 0) throw new Exception("El archivo llegó vacío.");
            if (bytes.Length > maxMb * 1024L * 1024L) throw new Exception("El archivo pesa más de " + maxMb + " MB.");

            mime = string.IsNullOrEmpty(mime) ? "application/octet-stream" : mime;
            Archivo arc = new Archivo();
            arc.arc_cliente = cliente;
            arc.arc_archivo_categoria = mime.StartsWith("image/", StringComparison.OrdinalIgnoreCase) ? 10 : 9;
            arc.arc_nombre_original = System.IO.Path.GetFileName(string.IsNullOrEmpty(nombre) ? "archivo" : nombre);
            arc.arc_mime = mime;
            arc.contenido = bytes;
            ArchivoController.Alivianar(arc);

            Respuesta r = new ArchivoController().InsertArchivo(arc, carpeta);
            if (r.error || r.codigo <= 0) throw new Exception(r.detalle ?? "No se pudo subir el archivo.");
            return r.codigo;
        }
    }

    /// <summary>
    /// En que pantalla esta la persona, dicho como lo entiende la ayuda:
    /// Modulo > Submodulo > Pantalla. Sale de Ayuda_Pantalla (que a su vez
    /// sale de Menus) y se guarda diez minutos: el master lo pide en cada
    /// pagina y la tabla cambia solo cuando alguien registra un menu.
    /// </summary>
    public static class SoporteContexto
    {
        private const string CLAVE = "SIGMA_SOPORTE_PANTALLAS";

        public static string[] DePagina(string link)
        {
            if (string.IsNullOrEmpty(link)) return null;
            Dictionary<string, string[]> mapa = Mapa();
            string[] r;
            return mapa != null && mapa.TryGetValue(link.ToLowerInvariant(), out r) ? r : null;
        }

        private static Dictionary<string, string[]> Mapa()
        {
            Dictionary<string, string[]> mapa = HttpRuntime.Cache[CLAVE] as Dictionary<string, string[]>;
            if (mapa != null) return mapa;

            mapa = new Dictionary<string, string[]>();
            try
            {
                foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_AYUDA_PANTALLAS"))
                {
                    string link = Convert.ToString(f["apa_link"]).ToLowerInvariant();
                    if (link.Length == 0 || mapa.ContainsKey(link)) continue;
                    mapa[link] = new string[] { Convert.ToString(f["apa_modulo"]), Convert.ToString(f["apa_submodulo"]), Convert.ToString(f["apa_pantalla"]) };
                }
            }
            catch (Exception)
            {
                /* Sin contexto la ayuda igual funciona (con lo que diga la
                   pagina); lo que no puede pasar es que el master se caiga. */
                return mapa;
            }

            HttpRuntime.Cache.Insert(CLAVE, mapa, null, DateTime.UtcNow.AddMinutes(10), Cache.NoSlidingExpiration);
            return mapa;
        }
    }
}
