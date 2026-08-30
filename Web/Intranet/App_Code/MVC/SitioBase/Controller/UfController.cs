using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Globalization;
using System.Net;
using System.Web;
using System.Web.Script.Serialization;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// El valor de la UF (ANEXO F §4).
    ///
    /// POR QUE ESTO VIVE EN EL SERVIDOR Y NO EN EL NAVEGADOR
    ///   El monto que se le cobra a un cliente sale de multiplicar las UF
    ///   del plan por el valor de la UF del dia. Si ese valor llegara desde
    ///   el navegador, quien paga podria alterarlo antes de enviarlo. Aqui
    ///   la consulta a la fuente la hace el servidor y el valor se escribe
    ///   en Valor_Uf con su origen y su hora, de modo que despues se puede
    ///   auditar con que numero se cobro.
    ///
    /// POR QUE NO ES UN JOB DE SQL
    ///   El anexo pide un job del servidor. Este hosting no da acceso a
    ///   msdb, asi que no hay SQL Agent disponible. El alimentador corre
    ///   aqui, una vez al dia, disparado por la primera visita del dia.
    ///   Escribe por el mismo SP que usaria un job, de modo que el dia que
    ///   haya Agent basta con programarlo y quitar esta llamada.
    /// </summary>
    public class UfController
    {
        /// <summary>
        /// Marca en memoria del ultimo dia en que ya se alimento, para no
        /// salir a Internet en cada peticion. Vive en Application y no en
        /// Session: el valor de la UF es del sistema, no de cada persona.
        /// </summary>
        private const string CLAVE_ULTIMO_DIA = "_sigma_uf_ultimo_dia";

        /// <summary>
        /// Se llama en cada visita pero solo trabaja una vez al dia.
        /// Nunca lanza: si algo falla, la pagina tiene que abrirse igual.
        /// El detalle queda en Sis_Excepcion.
        /// </summary>
        public static void AsegurarValorDeHoy()
        {
            try
            {
                HttpContext ctx = HttpContext.Current;
                if (ctx == null || ctx.Application == null) return;

                string hoy = DateTime.Today.ToString("yyyy-MM-dd");

                if (ctx.Application[CLAVE_ULTIMO_DIA] != null &&
                    ctx.Application[CLAVE_ULTIMO_DIA].ToString() == hoy)
                    return;

                // Se marca ANTES de intentar. Si la fuente esta caida y
                // tarda, no queremos que cada visita del dia vuelva a
                // esperar el timeout completo.
                ctx.Application[CLAVE_ULTIMO_DIA] = hoy;

                UfController controller = new UfController();
                controller.Alimentar();
            }
            catch (Exception ex)
            {
                // Que la alimentacion de la UF falle no puede impedir que
                // alguien entre al sistema.
            }
        }

        /// <summary>
        /// Trae la serie desde la fuente y la escribe. Si no se puede,
        /// arrastra el ultimo valor conocido para que hoy tenga uno.
        /// </summary>
        public Respuesta Alimentar()
        {
            Respuesta respuesta = new Respuesta();
            respuesta.error = false;

            List<KeyValuePair<DateTime, decimal>> serie = null;

            try
            {
                serie = LeerFuente();
            }
            catch (Exception ex)
            {
                RegistrarExcepcion("UfController.LeerFuente", ex.Message);
                serie = null;
            }

            if (serie != null && serie.Count > 0)
            {
                int escritos = 0;

                foreach (KeyValuePair<DateTime, decimal> dia in serie)
                {
                    if (Guardar(dia.Key, dia.Value, "API EXTERNA", ObtenerUrl())) escritos++;
                }

                respuesta.codigo = escritos;
                respuesta.detalle = escritos + " día(s) de UF actualizados.";
                return respuesta;
            }

            // La fuente no respondio: se arrastra para no dejar el dia sin valor.
            if (Arrastrar())
            {
                respuesta.codigo = 0;
                respuesta.detalle = "La fuente de UF no respondió. Se arrastró el último valor conocido.";
            }
            else
            {
                respuesta.error = true;
                respuesta.detalle = "La fuente de UF no respondió y no hay ningún valor anterior que arrastrar.";
            }

            return respuesta;
        }

        private string ObtenerUrl()
        {
            // La URL es un parametro del sistema, no una constante: cambiar
            // de proveedor no deberia obligar a recompilar.
            /* global:: porque dentro del namespace SitioBase.Controller el
               nombre "SitioBase" resuelve a la CLASE SitioBase.SitioBase y
               no al namespace, y el compilador termina buscando un miembro
               que no existe. */
            string url = global::SitioBase.SitioBase.Parametros("UF_API_URL");

            if (string.IsNullOrEmpty(url))
                url = ConfigurationManager.AppSettings["UF_API_URL"];

            return url;
        }

        /// <summary>
        /// Lee la serie del mes desde la fuente configurada.
        ///
        /// En Chile la UF se publica con anticipacion -el valor de cada dia
        /// entre el 10 de un mes y el 9 del siguiente se conoce al comienzo
        /// de esa ventana- asi que la fuente devuelve el periodo completo y
        /// se guarda entero. Eso permite cotizar una renovacion antes de
        /// que llegue el dia.
        /// </summary>
        private List<KeyValuePair<DateTime, decimal>> LeerFuente()
        {
            string url = ObtenerUrl();
            if (string.IsNullOrEmpty(url)) return null;

            string json;

            // TLS 1.2: sin esto, el handshake con la fuente falla en .NET 4.x
            // con un error de conexion cerrada que no dice nada util.
            ServicePointManager.SecurityProtocol =
                SecurityProtocolType.Tls12 | SecurityProtocolType.Tls11 | SecurityProtocolType.Tls;

            using (WebClient wc = new WebClient())
            {
                wc.Encoding = System.Text.Encoding.UTF8;
                json = wc.DownloadString(url);
            }

            if (string.IsNullOrEmpty(json)) return null;

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = 4 * 1024 * 1024;

            Dictionary<string, object> raiz = js.Deserialize<Dictionary<string, object>>(json);

            if (raiz == null || !raiz.ContainsKey("serie")) return null;

            List<KeyValuePair<DateTime, decimal>> serie = new List<KeyValuePair<DateTime, decimal>>();

            object[] filas = raiz["serie"] as object[];
            if (filas == null) return null;

            foreach (object fila in filas)
            {
                Dictionary<string, object> item = fila as Dictionary<string, object>;
                if (item == null || !item.ContainsKey("fecha") || !item.ContainsKey("valor")) continue;

                DateTime fecha;
                decimal valor;

                // El punto decimal viene en formato invariante: parsear con
                // la cultura local es-CL leeria 40871.14 como 4087114.
                if (!DateTime.TryParse(item["fecha"].ToString(), CultureInfo.InvariantCulture,
                                       DateTimeStyles.RoundtripKind, out fecha))
                    continue;

                if (!decimal.TryParse(Convert.ToString(item["valor"], CultureInfo.InvariantCulture),
                                      NumberStyles.Float, CultureInfo.InvariantCulture, out valor))
                    continue;

                if (valor > 0) serie.Add(new KeyValuePair<DateTime, decimal>(fecha.Date, valor));
            }

            return serie;
        }

        /// <summary>Escribe un dia. Devuelve true si realmente escribio.</summary>
        private bool Guardar(DateTime fecha, decimal valor, string origen, string respuestaCruda)
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_VALOR_UF");
                cmd.Parameters.AddWithValue("@FECHA", fecha);
                cmd.Parameters.AddWithValue("@VALOR", valor);
                cmd.Parameters.AddWithValue("@ORIGEN_CODIGO", origen);
                cmd.Parameters.AddWithValue("@RESPUESTA", (object)respuestaCruda ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", 1);
                cmd.Parameters.AddWithValue("@ESCRITO", false).Direction = System.Data.ParameterDirection.Output;
                cmd.ExecuteNonQuery();

                bool escrito = Convert.ToBoolean(cmd.Parameters["@ESCRITO"].Value);
                cmd.Connection.Close();

                return escrito;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                RegistrarExcepcion("UfController.Guardar " + fecha.ToString("yyyy-MM-dd"), ex.Message);
                return false;
            }
        }

        private bool Arrastrar()
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_VALOR_UF_ARRASTRE");
                cmd.Parameters.AddWithValue("@FECHA", DateTime.Today);
                cmd.Parameters.AddWithValue("@USUARIO", 1);
                cmd.Parameters.AddWithValue("@ESCRITO", false).Direction = System.Data.ParameterDirection.Output;
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                return true;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                RegistrarExcepcion("UfController.Arrastrar", ex.Message);
                return false;
            }
        }

        /// <summary>Ultimos valores, para la pantalla de control.</summary>
        public List<ValorUf> GetValores(DateTime? desde = null, DateTime? hasta = null, bool soloArrastre = false, int tope = 60)
        {
            List<ValorUf> lista = new List<ValorUf>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_VALOR_UF";
                    if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde);
                    if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta);
                    if (soloArrastre) cmd.Parameters.AddWithValue("@SOLO_ARRASTRE", true);
                    cmd.Parameters.AddWithValue("@TOPE", tope);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ValorUf item = new ValorUf();

                            item.vuf_id = int.Parse(dr["VUF_ID"].ToString());
                            item.vuf_fecha = DateTime.Parse(dr["VUF_FECHA"].ToString());
                            item.vuf_valor = decimal.Parse(dr["VUF_VALOR"].ToString());
                            item.ufo_nombre = dr["UFO_NOMBRE"].ToString();
                            item.ufo_codigo = dr["UFO_CODIGO"].ToString();
                            item.vuf_respuesta_cruda = dr["VUF_RESPUESTA_CRUDA"].ToString();
                            item.es_arrastre = dr["ES_ARRASTRE"].ToString() == "1";

                            if (dr["VUF_FECHA_OBTENCION_UTC"] != DBNull.Value)
                                item.vuf_fecha_obtencion_utc = DateTime.Parse(dr["VUF_FECHA_OBTENCION_UTC"].ToString());

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        private void RegistrarExcepcion(string variables, string mensaje)
        {
            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("INS_EXCEPCION");
                cmd.Parameters.AddWithValue("@CODIGO", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@VARIABLES", variables);
                cmd.Parameters.AddWithValue("@MSG", mensaje);
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
            }
            catch
            {
                // INS_EXCEPCION termina en RAISERROR por diseño: esa
                // excepción es esperada y se descarta.
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }
        }
    }
}
