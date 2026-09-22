using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Versiones de un plan de mantenimiento (HU-084). La publicación es un
    /// proceso en el SP (UPD_PLAN_VERSION_PUBLICAR, que delega en el del bloque
    /// 14): las reglas viven en la base, así web y API dan el mismo resultado.
    /// Siempre acotado al cliente en sesión.
    /// </summary>
    public class PlanVersionController
    {
        /// <summary>Versiones de un plan (la más nueva primero). Solo del cliente en sesión.</summary>
        public List<PlanVersion> GetVersiones(int plan, int cliente)
        {
            List<PlanVersion> lista = new List<PlanVersion>();
            if (plan <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_PLAN_VERSION";
                    cmd.Parameters.AddWithValue("@PLAN", plan);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente > 0 ? cliente : Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanVersion v = new PlanVersion();
                            v.pmv_id = int.Parse(dr["PMV_ID"].ToString());
                            v.pmv_plan_mantenimiento = int.Parse(dr["PMV_PLAN_MANTENIMIENTO"].ToString());
                            v.pmv_numero = int.Parse(dr["PMV_NUMERO"].ToString());
                            v.pmv_estado = int.Parse(dr["PMV_PLAN_VERSION_ESTADO"].ToString());
                            v.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                            v.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            if (dr["PMV_FECHA_PUBLICACION"] != DBNull.Value) v.pmv_fecha_publicacion = DateTime.Parse(dr["PMV_FECHA_PUBLICACION"].ToString());
                            if (dr["PMV_FECHA_RETIRO"] != DBNull.Value) v.pmv_fecha_retiro = DateTime.Parse(dr["PMV_FECHA_RETIRO"].ToString());
                            v.pmv_observacion = dr["PMV_OBSERVACION"].ToString();
                            if (dr["PMV_FECHA_CREACION"] != DBNull.Value) v.pmv_fecha_creacion = DateTime.Parse(dr["PMV_FECHA_CREACION"].ToString());
                            v.plan_cliente = int.Parse(dr["PLAN_CLIENTE"].ToString());
                            v.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            v.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            v.hitos = int.Parse(dr["HITOS"].ToString());
                            v.activos = int.Parse(dr["ACTIVOS"].ToString());
                            v.ocurrencias = int.Parse(dr["OCURRENCIAS"].ToString());
                            v.usuario_publicacion_nombre = dr["USUARIO_PUBLICACION_NOMBRE"].ToString();
                            v.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
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
        /// Publica la versión en borrador del plan. Las reglas (existe, es borrador,
        /// tiene hitos y equipos, y la carrera) están en el SP. Se pasa el id de la
        /// versión (pmv_id), no el del plan.
        /// </summary>
        public Respuesta Publicar(int versionId, string observacion)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_PLAN_VERSION_PUBLICAR");
                    cmd.Parameters.AddWithValue("@ID", versionId);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrEmpty(observacion) ? (object)DBNull.Value : observacion);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = versionId; r.detalle = "Versión publicada con éxito."; r.error = false;
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
