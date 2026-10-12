using System;
using System.Data.SqlClient;
using SitioBase;

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
    }
}
