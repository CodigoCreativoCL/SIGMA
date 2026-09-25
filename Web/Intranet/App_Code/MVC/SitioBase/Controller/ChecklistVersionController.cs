using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Versiones de una pauta de checklist (HU-093). La publicación es un proceso
    /// en el SP (PUBLICAR_CHECKLIST_VERSION): reglas en la base, así web y API dan
    /// el mismo resultado. Siempre acotado al cliente en sesión.
    /// </summary>
    public class ChecklistVersionController
    {
        public List<ChecklistVersion> GetVersiones(int plantilla, int cliente)
        {
            List<ChecklistVersion> lista = new List<ChecklistVersion>();
            if (plantilla <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_VERSION";
                    cmd.Parameters.AddWithValue("@PLANTILLA", plantilla);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente > 0 ? cliente : Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ChecklistVersion v = new ChecklistVersion();
                            v.cpv_id = int.Parse(dr["CPV_ID"].ToString());
                            v.cpv_checklist_plantilla = int.Parse(dr["CPV_CHECKLIST_PLANTILLA"].ToString());
                            v.cpv_numero = int.Parse(dr["CPV_NUMERO"].ToString());
                            v.cpv_estado = int.Parse(dr["CPV_ESTADO"].ToString());
                            v.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            if (dr["CPV_FECHA_PUBLICACION"] != DBNull.Value) v.cpv_fecha_publicacion = DateTime.Parse(dr["CPV_FECHA_PUBLICACION"].ToString());
                            if (dr["CPV_FECHA_RETIRO"] != DBNull.Value) v.cpv_fecha_retiro = DateTime.Parse(dr["CPV_FECHA_RETIRO"].ToString());
                            v.cpv_observacion = dr["CPV_OBSERVACION"].ToString();
                            v.plantilla_codigo = dr["PLANTILLA_CODIGO"].ToString();
                            v.plantilla_nombre = dr["PLANTILLA_NOMBRE"].ToString();
                            v.items = int.Parse(dr["ITEMS"].ToString());
                            v.secciones = int.Parse(dr["SECCIONES"].ToString());
                            v.usuario_publicacion_nombre = dr["USUARIO_PUBLICACION_NOMBRE"].ToString();
                            lista.Add(v);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }
            return lista;
        }

        /// <summary>
        /// Pautas que tienen una versión PUBLICADA (una por pauta, la última
        /// publicada). Sirve para el combo de "pauta" al programarla (HU-094):
        /// solo se puede programar una pauta ya publicada.
        /// </summary>
        public List<ChecklistVersion> GetPublicadas(int cliente)
        {
            List<ChecklistVersion> lista = new List<ChecklistVersion>();
            System.Collections.Generic.HashSet<int> vistos = new System.Collections.Generic.HashSet<int>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_VERSION";
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente > 0 ? cliente : Session.ClienteId());
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            if (int.Parse(dr["CPV_ESTADO"].ToString()) != 2) continue;   // solo PUBLICADO
                            int plantilla = int.Parse(dr["CPV_CHECKLIST_PLANTILLA"].ToString());
                            if (vistos.Contains(plantilla)) continue;                     // una por pauta (SEL viene ordenado por numero desc)
                            vistos.Add(plantilla);
                            ChecklistVersion v = new ChecklistVersion();
                            v.cpv_id = int.Parse(dr["CPV_ID"].ToString());
                            v.cpv_checklist_plantilla = plantilla;
                            v.cpv_numero = int.Parse(dr["CPV_NUMERO"].ToString());
                            v.plantilla_codigo = dr["PLANTILLA_CODIGO"].ToString();
                            v.plantilla_nombre = dr["PLANTILLA_NOMBRE"].ToString();
                            lista.Add(v);
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
            }
            return lista;
        }

        /// <summary>Publica el borrador de la pauta. Las reglas (CA1/CA2) están en el SP.</summary>
        public Respuesta Publicar(int plantilla, string observacion)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int version = 0;
                    cmd = Conexion.GetCommand("PUBLICAR_CHECKLIST_VERSION");
                    cmd.Parameters.AddWithValue("@PLANTILLA", plantilla);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@OBSERVACION", (object)(observacion ?? "") ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.Parameters.AddWithValue("@VERSION", version).Direction = System.Data.ParameterDirection.Output;
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    version = cmd.Parameters["@VERSION"].Value != DBNull.Value ? (int)cmd.Parameters["@VERSION"].Value : 0;
                    r.codigo = version; r.detalle = "Versión publicada con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }
    }
}
