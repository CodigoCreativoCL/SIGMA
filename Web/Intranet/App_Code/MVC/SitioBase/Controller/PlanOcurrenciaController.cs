using System;
using System.Data;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Ocurrencias de un plan de mantenimiento (HU-086). Reprogramar es un
    /// proceso en el SP (PLAN_OCURRENCIA_REPROGRAMAR): las reglas viven en la
    /// base, así web y API dan el mismo resultado. Siempre acotado al cliente
    /// en sesión.
    /// </summary>
    public class PlanOcurrenciaController
    {
        /// <summary>Ficha de una ocurrencia (para cargar la pantalla y ver el resultado).</summary>
        public PlanOcurrencia GetOcurrencia(int id, int cliente)
        {
            PlanOcurrencia o = null;
            if (id <= 0) return null;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_PLAN_OCURRENCIA_REPROGRAMAR";
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente > 0 ? cliente : Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            o = new PlanOcurrencia();
                            o.pmo_id = int.Parse(dr["PMO_ID"].ToString());
                            o.pmo_cliente = int.Parse(dr["PMO_CLIENTE"].ToString());
                            o.pmo_estado = int.Parse(dr["PMO_ESTADO"].ToString());
                            o.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            if (dr["PMO_FECHA_PROGRAMADA"] != DBNull.Value) o.pmo_fecha_programada = DateTime.Parse(dr["PMO_FECHA_PROGRAMADA"].ToString());
                            if (dr["PMO_FECHA_ORIGINAL"] != DBNull.Value) o.pmo_fecha_original = DateTime.Parse(dr["PMO_FECHA_ORIGINAL"].ToString());
                            if (dr["PMO_OCURRENCIA_ORIGEN"] != DBNull.Value) o.pmo_ocurrencia_origen = int.Parse(dr["PMO_OCURRENCIA_ORIGEN"].ToString());
                            o.pmo_observacion = dr["PMO_OBSERVACION"].ToString();
                            if (dr["PMO_ORDEN_TRABAJO"] != DBNull.Value) o.pmo_orden_trabajo = int.Parse(dr["PMO_ORDEN_TRABAJO"].ToString());
                            o.pmo_activo = int.Parse(dr["PMO_ACTIVO"].ToString());
                            o.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            o.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            o.hito_codigo = dr["HITO_CODIGO"].ToString();
                            o.hito_nombre = dr["HITO_NOMBRE"].ToString();
                            o.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            o.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            if (dr["PMO_FECHA_ACTUALIZACION"] != DBNull.Value) o.pmo_fecha_actualizacion = DateTime.Parse(dr["PMO_FECHA_ACTUALIZACION"].ToString());
                            o.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            if (dr["PMO_FECHA_NUEVA"] != DBNull.Value) o.pmo_fecha_nueva = DateTime.Parse(dr["PMO_FECHA_NUEVA"].ToString());
                            if (dr["PMO_OCURRENCIA_NUEVA"] != DBNull.Value) o.pmo_ocurrencia_nueva = int.Parse(dr["PMO_OCURRENCIA_NUEVA"].ToString());
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    o = null;
                }
            }
            return o;
        }

        /// <summary>
        /// Reprograma la ocurrencia a una nueva fecha, con motivo obligatorio.
        /// Las reglas (estado, colisión, carrera) están en el SP. Devuelve en
        /// r.codigo el id de la ocurrencia nueva.
        /// </summary>
        public Respuesta Reprogramar(int id, DateTime nuevaFecha, string motivo)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("PLAN_OCURRENCIA_REPROGRAMAR");
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@NUEVA_FECHA", nuevaFecha);
                    cmd.Parameters.AddWithValue("@MOTIVO", string.IsNullOrEmpty(motivo) ? (object)DBNull.Value : motivo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    SqlParameter pn = cmd.Parameters.Add("@NUEVO_ID", SqlDbType.Int);
                    pn.Direction = ParameterDirection.Output;
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = pn.Value != DBNull.Value ? (int)pn.Value : 0;
                    r.detalle = "Ocurrencia reprogramada con éxito.";
                    r.error = false;
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
