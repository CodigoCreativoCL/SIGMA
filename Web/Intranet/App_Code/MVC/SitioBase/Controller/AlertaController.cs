using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;

namespace SitioBase.Controller
{
    /// <summary>
    /// Las notificaciones: lo que el sistema encontró y hay que mirar.
    ///
    /// EL RESUMEN SE PIDE UNA VEZ POR PÁGINA, Y SE GUARDA
    ///   La cabecera se dibuja en TODAS las pantallas, y el menú lateral
    ///   también. Sin caché, cada carga del sitio serían dos consultas más
    ///   para pintar un número que cambia cada varios minutos.
    ///
    ///   Se guarda en HttpContext.Items —que vive lo que dura UNA petición— y
    ///   no en Session: en Session el contador se quedaría pegado y la persona
    ///   vería un punto rojo que ya no corresponde, o peor, no vería uno nuevo.
    /// </summary>
    public class AlertaController
    {
        private const string CLAVE_RESUMEN = "SIGMA_ALERTA_RESUMEN";

        /// <summary>
        /// Los números de la campana y de cada menú, en una sola llamada: la
        /// cabecera necesita los dos y pedirlos por separado duplicaría el
        /// costo en cada página del sitio.
        /// </summary>
        public AlertaResumen GetResumen()
        {
            HttpContext ctx = HttpContext.Current;

            if (ctx != null && ctx.Items[CLAVE_RESUMEN] != null)
                return (AlertaResumen)ctx.Items[CLAVE_RESUMEN];

            AlertaResumen resumen = new AlertaResumen();

            if (!Token.TokenSeguridad()) return resumen;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA_RESUMEN";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        resumen.Abiertas = dr["ABIERTAS"] != DBNull.Value
                                           ? int.Parse(dr["ABIERTAS"].ToString()) : 0;
                        resumen.NoLeidas = dr["NO_LEIDAS"] != DBNull.Value
                                           ? int.Parse(dr["NO_LEIDAS"].ToString()) : 0;
                    }

                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            string link = dr["MENU_LINK"].ToString();
                            int abiertas = int.Parse(dr["ABIERTAS"].ToString());

                            if (!resumen.PorMenu.ContainsKey(link))
                                resumen.PorMenu.Add(link, abiertas);
                        }
                    }
                }
            }
            catch (Exception)
            {
                /* La cabecera se dibuja en todas las pantallas: si el resumen
                   falla, el sitio tiene que seguir funcionando sin el número.
                   Tumbar cada página por un contador sería desproporcionado. */
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            if (ctx != null) ctx.Items[CLAVE_RESUMEN] = resumen;

            return resumen;
        }

        /// <summary>La bandeja.</summary>
        public List<Alerta> GetAlertas(bool soloAbiertas = true, int tope = 50)
        {
            List<Alerta> lista = new List<Alerta>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ALERTA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.Parameters.AddWithValue("@SOLO_ABIERTAS", soloAbiertas);
                cmd.Parameters.AddWithValue("@TOPE", tope);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        Alerta a = new Alerta();

                        a.ale_id = int.Parse(dr["ale_id"].ToString());
                        a.ale_titulo = dr["ale_titulo"].ToString();
                        a.ale_descripcion = dr["ale_descripcion"].ToString();
                        a.ale_fecha_deteccion_utc = DateTime.Parse(dr["ale_fecha_deteccion_utc"].ToString());

                        a.alt_codigo = dr["alt_codigo"].ToString();
                        a.alt_nombre = dr["alt_nombre"].ToString();
                        a.alt_icono = dr["alt_icono"].ToString();
                        a.alt_menu_link = dr["alt_menu_link"].ToString();
                        a.FICHA_LINK = dr["FICHA_LINK"].ToString();

                        if (dr["FICHA_ID"] != DBNull.Value)
                            a.FICHA_ID = int.Parse(dr["FICHA_ID"].ToString());

                        a.aet_codigo = dr["aet_codigo"].ToString();
                        a.aet_nombre = dr["aet_nombre"].ToString();

                        a.sev_codigo = dr["sev_codigo"].ToString();
                        a.sev_nombre = dr["sev_nombre"].ToString();

                        a.LEIDA = (dr["LEIDA"].ToString() == "1" ||
                                   dr["LEIDA"].ToString().ToUpper() == "TRUE");
                        a.MINUTOS = int.Parse(dr["MINUTOS"].ToString());

                        if (dr["ale_repuesto"] != DBNull.Value)
                            a.ale_repuesto = int.Parse(dr["ale_repuesto"].ToString());

                        if (dr["ale_bodega"] != DBNull.Value)
                            a.ale_bodega = int.Parse(dr["ale_bodega"].ToString());

                        if (dr["ale_repuesto_lote"] != DBNull.Value)
                            a.ale_repuesto_lote = int.Parse(dr["ale_repuesto_lote"].ToString());

                        lista.Add(a);
                    }
                }
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>
        /// Marca como leída. Sin id, marca todo lo que esa persona puede ver.
        /// </summary>
        public int Leer(int alerta = 0)
        {
            if (!Token.TokenSeguridad()) return 0;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "UPD_ALERTA_LEER";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                if (alerta > 0) cmd.Parameters.AddWithValue("@ALERTA", alerta);

                int marcadas = 0;

                /* Este Conexion no tiene GetScalar: se lee la primera fila del
                   lector, que es lo mismo con el helper que si existe. */
                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read() && dr[0] != DBNull.Value)
                        marcadas = int.Parse(dr[0].ToString());
                }

                /* El resumen en caché quedó viejo en cuanto se marcó algo. */
                if (HttpContext.Current != null)
                    HttpContext.Current.Items.Remove(CLAVE_RESUMEN);

                return marcadas;
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                return 0;
            }
        }

        /// <summary>
        /// Pregunta si hay algo nuevo, y de paso lo detecta si toca.
        ///
        /// UNA LLAMADA, DOS COSAS
        ///   GEN_ALERTA_DETECTAR decide si corresponde correr el detector —el
        ///   freno vive en la base, para que dos usuarios simultáneos no lo
        ///   ejecuten los dos— y devuelve el resumen SIEMPRE, corriera o no.
        ///   El navegador pregunta para refrescar sus números; hacerle dar dos
        ///   viajes sería el doble de tráfico para lo mismo.
        ///
        /// SE PUEDE LLAMAR CADA MINUTO SIN MIEDO
        ///   El detector es idempotente —abre lo que empezó a pasar y cierra
        ///   lo que dejó de pasar— y el freno lo detiene casi siempre: la
        ///   llamada normal solo cuenta filas.
        ///
        /// <param name="forzar">
        ///   Se salta el freno. Lo usa el botón "Revisar ahora": si alguien lo
        ///   aprieta es porque quiere saber en este momento.
        /// </param>
        /// </summary>
        public AlertaResumen Detectar(bool forzar = false)
        {
            AlertaResumen resumen = new AlertaResumen();

            if (!Token.TokenSeguridad()) return resumen;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "GEN_ALERTA_DETECTAR";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                if (forzar) cmd.Parameters.AddWithValue("@FORZAR", true);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        resumen.Abiertas = dr["ABIERTAS"] != DBNull.Value
                                           ? int.Parse(dr["ABIERTAS"].ToString()) : 0;
                        resumen.NoLeidas = dr["NO_LEIDAS"] != DBNull.Value
                                           ? int.Parse(dr["NO_LEIDAS"].ToString()) : 0;
                    }

                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            string link = dr["MENU_LINK"].ToString();
                            int abiertas = int.Parse(dr["ABIERTAS"].ToString());

                            if (!resumen.PorMenu.ContainsKey(link))
                                resumen.PorMenu.Add(link, abiertas);
                        }
                    }
                }

                /* Lo que hubiera en caché es de ANTES de detectar. */
                if (HttpContext.Current != null)
                    HttpContext.Current.Items[CLAVE_RESUMEN] = resumen;
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return resumen;
        }
    }
}
