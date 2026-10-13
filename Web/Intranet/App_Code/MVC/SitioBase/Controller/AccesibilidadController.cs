using System;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Las opciones de accesibilidad de la PERSONA que entró (HU-162).
    ///
    /// No describen lo que le falta al usuario; describen lo que hace la
    /// aplicación por él: texto más grande, más contraste, iconos grandes, voz
    /// y sonido. Hay una fila por usuario (índice único UX_UAC_USUARIO): cada
    /// quien configura la suya, y el intranet la respeta en todas las pantallas.
    /// </summary>
    [Serializable]
    public class UsuarioAccesibilidad
    {
        public int uac_id;
        public int uac_usuario;
        public bool entrada_voz;
        public bool lectura_voz;
        public bool confirmacion_hablada;
        public decimal velocidad_voz;
        public bool texto_grande;
        public bool alto_contraste;
        public bool iconos_grandes;
        public int? idioma;
        public decimal volumen;
        public bool silenciar_alertas;
        public bool habilitado;

        public UsuarioAccesibilidad()
        {
            // Por defecto: nada activo, voz y volumen al 100%, habilitado.
            velocidad_voz = 1.00m;
            volumen = 1.00m;
            habilitado = true;
        }
    }

    public class AccesibilidadController
    {
        /// <summary>
        /// Las opciones de quien está en sesión. Si todavía no configuró
        /// ninguna, devuelve los valores por defecto (uac_id = 0): la pantalla
        /// las ofrece igual y, al guardar, se crean.
        /// </summary>
        public UsuarioAccesibilidad GetMisOpciones()
        {
            UsuarioAccesibilidad o = new UsuarioAccesibilidad();
            o.uac_usuario = Convert.ToInt32(Session.UsuarioId());

            if (!Token.TokenSeguridad()) return o;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_USUARIO_ACCESIBILIDAD";
                cmd.Parameters.AddWithValue("@USUARIO", o.uac_usuario);
                cmd.Parameters.AddWithValue("@HABILITADO", 1);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        o.uac_id = Convert.ToInt32(dr["uac_id"]);
                        o.entrada_voz = Convert.ToBoolean(dr["uac_entrada_voz"]);
                        o.lectura_voz = Convert.ToBoolean(dr["uac_lectura_voz"]);
                        o.confirmacion_hablada = Convert.ToBoolean(dr["uac_confirmacion_hablada"]);
                        o.velocidad_voz = Convert.ToDecimal(dr["uac_velocidad_voz"]);
                        o.texto_grande = Convert.ToBoolean(dr["uac_texto_grande"]);
                        o.alto_contraste = Convert.ToBoolean(dr["uac_alto_contraste"]);
                        o.iconos_grandes = Convert.ToBoolean(dr["uac_iconos_grandes"]);
                        if (dr["uac_idioma"] != DBNull.Value) o.idioma = Convert.ToInt32(dr["uac_idioma"]);
                        o.volumen = Convert.ToDecimal(dr["uac_volumen"]);
                        o.silenciar_alertas = Convert.ToBoolean(dr["uac_silenciar_alertas"]);
                        o.habilitado = Convert.ToBoolean(dr["uac_habilitado"]);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return o;
        }

        /// <summary>
        /// Guarda las opciones de la persona. Si todavía no tenía fila (uac_id =
        /// 0) la crea; si ya la tenía, la corrige. Deja las preferencias
        /// visuales en la sesión para que el master las aplique de inmediato en
        /// todas las pantallas.
        /// </summary>
        public Respuesta GuardarMisOpciones(UsuarioAccesibilidad o)
        {
            Respuesta r = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                r.error = true; r.codigo = -1;
                r.detalle = "La sesión no es válida o expiró. Vuelve a entrar y repite la operación.";
                return r;
            }

            /* LA POTESTAD SE COMPRUEBA EN EL SERVIDOR (T-5340), no escondiendo el
               botón: quien manda el postback a mano no se la salta. Y se escribe
               SOLO lo propio: el uac_id sale de GetMisOpciones() —la fila de la
               persona en sesión—, nunca de un id del cliente, así nadie corrige
               las opciones de otro. */
            if (!Token.Puede("CONFIGURAR ACCESIBILIDAD"))
            {
                r.error = true; r.codigo = -1;
                r.detalle = "Tu perfil no tiene permiso para configurar la accesibilidad.";
                return r;
            }

            int usuario = Convert.ToInt32(Session.UsuarioId());
            SqlCommand cmd = null;

            try
            {
                if (o.uac_id <= 0)
                {
                    cmd = Conexion.GetCommand("INS_USUARIO_ACCESIBILIDAD");
                    cmd.Parameters.AddWithValue("@USUARIO", usuario);
                    cmd.Parameters.AddWithValue("@USUARIO_CREACION", usuario);
                    cmd.Parameters.Add("@ID", SqlDbType.Int).Direction = ParameterDirection.Output;
                }
                else
                {
                    cmd = Conexion.GetCommand("UPD_USUARIO_ACCESIBILIDAD");
                    cmd.Parameters.AddWithValue("@ID", o.uac_id);
                    cmd.Parameters.AddWithValue("@USUARIO_ACTUALIZACION", usuario);
                }

                cmd.Parameters.AddWithValue("@ENTRADA_VOZ", o.entrada_voz);
                cmd.Parameters.AddWithValue("@LECTURA_VOZ", o.lectura_voz);
                cmd.Parameters.AddWithValue("@CONFIRMACION_HABLADA", o.confirmacion_hablada);
                cmd.Parameters.AddWithValue("@VELOCIDAD_VOZ", o.velocidad_voz);
                cmd.Parameters.AddWithValue("@TEXTO_GRANDE", o.texto_grande);
                cmd.Parameters.AddWithValue("@ALTO_CONTRASTE", o.alto_contraste);
                cmd.Parameters.AddWithValue("@ICONOS_GRANDES", o.iconos_grandes);
                cmd.Parameters.AddWithValue("@IDIOMA", (object)o.idioma ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@VOLUMEN", o.volumen);
                cmd.Parameters.AddWithValue("@SILENCIAR_ALERTAS", o.silenciar_alertas);

                cmd.ExecuteNonQuery();

                if (o.uac_id <= 0 && cmd.Parameters["@ID"].Value != DBNull.Value)
                    o.uac_id = Convert.ToInt32(cmd.Parameters["@ID"].Value);

                cmd.Connection.Close();
                cmd.Dispose();

                AplicarEnSesion(o);

                r.error = false; r.codigo = o.uac_id;
                r.detalle = "Tus opciones de accesibilidad quedaron guardadas.";
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                if (cmd != null) cmd.Dispose();
                r.error = true; r.codigo = -1; r.detalle = ex.Message;
            }

            return r;
        }

        /// <summary>
        /// Carga las preferencias visuales de la persona en la sesión, una vez,
        /// para que el master las aplique en cada pantalla sin pegarle a la base
        /// en cada request. Lo llama el master la primera vez que las necesita.
        /// </summary>
        public void CargarEnSesion()
        {
            AplicarEnSesion(GetMisOpciones());
        }

        /// <summary>Deja en la sesión las tres preferencias que cambian el render global.</summary>
        private static void AplicarEnSesion(UsuarioAccesibilidad o)
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null) return;
            System.Web.SessionState.HttpSessionState s = HttpContext.Current.Session;
            s["acc_texto_grande"] = o.texto_grande;
            s["acc_alto_contraste"] = o.alto_contraste;
            s["acc_iconos_grandes"] = o.iconos_grandes;
            s["acc_cargado"] = true;
        }

        /// <summary>
        /// Las clases que el master pone en &lt;body&gt; según las preferencias
        /// de la persona. Las carga de la sesión; si no están, las trae una vez.
        /// Nunca lanza: una preferencia que no se puede leer no debe tumbar la
        /// página, sólo no aplicarse.
        /// </summary>
        public static string ClasesBody()
        {
            try
            {
                if (HttpContext.Current == null || HttpContext.Current.Session == null) return "";
                System.Web.SessionState.HttpSessionState s = HttpContext.Current.Session;

                if (s["acc_cargado"] == null)
                    new AccesibilidadController().CargarEnSesion();

                string c = "";
                if (s["acc_texto_grande"] as bool? == true) c += " sg-acc-texto-grande";
                if (s["acc_alto_contraste"] as bool? == true) c += " sg-acc-alto-contraste";
                if (s["acc_iconos_grandes"] as bool? == true) c += " sg-acc-iconos-grandes";
                return c.Trim();
            }
            catch (Exception)
            {
                return "";
            }
        }
    }
}
