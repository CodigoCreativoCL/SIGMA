using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>Versiones de un plan (HU-084): listar, abrir la siguiente y publicar.</summary>
    public class PlanVersionController
    {
        public List<PlanVersion> GetPlanVersiones(PlanVersion filtro = null)
        {
            List<PlanVersion> lista = new List<PlanVersion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_VERSION";

                    if (filtro != null)
                    {
                        if (filtro.pmv_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.pmv_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_plan != null && filtro.filtro_plan > 0) cmd.Parameters.AddWithValue("@PLAN", filtro.filtro_plan);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanVersion v = new PlanVersion();
                            v.pmv_id = int.Parse(dr["PMV_ID"].ToString());
                            v.pmv_plan_mantenimiento = int.Parse(dr["PMV_PLAN_MANTENIMIENTO"].ToString());
                            v.pmv_numero = int.Parse(dr["PMV_NUMERO"].ToString());
                            v.pmv_plan_version_estado = int.Parse(dr["PMV_PLAN_VERSION_ESTADO"].ToString());
                            v.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                            v.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            if (dr["PMV_FECHA_PUBLICACION"] != DBNull.Value) v.pmv_fecha_publicacion = (DateTime)dr["PMV_FECHA_PUBLICACION"];
                            v.usuario_publicacion_nombre = dr["USUARIO_PUBLICACION_NOMBRE"].ToString();
                            if (dr["PMV_FECHA_RETIRO"] != DBNull.Value) v.pmv_fecha_retiro = (DateTime)dr["PMV_FECHA_RETIRO"];
                            v.pmv_observacion = dr["PMV_OBSERVACION"].ToString();
                            if (dr["PMV_FECHA_CREACION"] != DBNull.Value) v.pmv_fecha_creacion = (DateTime)dr["PMV_FECHA_CREACION"];
                            v.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            v.pmv_habilitado = (bool)dr["PMV_HABILITADO"];
                            v.plan_cliente = int.Parse(dr["PLAN_CLIENTE"].ToString());
                            v.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            v.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            v.hitos = int.Parse(dr["HITOS"].ToString());
                            v.activos = int.Parse(dr["ACTIVOS"].ToString());
                            v.ocurrencias = int.Parse(dr["OCURRENCIAS"].ToString());
                            lista.Add(v);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public Respuesta AbrirVersionNueva(int plan, string observacion)
        {
            return Ejecutar("INS_PLAN_VERSION_NUEVA", "Versión nueva abierta en borrador, con los hitos y equipos de la vigente.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@PLAN", plan);
                cmd.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrEmpty(observacion) ? (object)DBNull.Value : observacion);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, true);
        }

        public Respuesta Publicar(int version, string observacion)
        {
            return Ejecutar("UPD_PLAN_VERSION_PUBLICAR", "Versión publicada. La anterior quedó retirada.", cmd =>
            {
                cmd.Parameters.AddWithValue("@ID", version);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@OBSERVACION", string.IsNullOrEmpty(observacion) ? (object)DBNull.Value : observacion);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
            }, false, version);
        }

        private static Respuesta Ejecutar(string sp, string exito, Action<SqlCommand> parametros, bool conSalida, int id = 0)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand(sp);
                    parametros(cmd);
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    respuesta.codigo = conSalida ? (int)cmd.Parameters["@ID"].Value : id;
                    respuesta.detalle = exito;
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }
    }
}
