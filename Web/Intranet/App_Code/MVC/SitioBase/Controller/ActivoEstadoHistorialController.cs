using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Cambio de estado de un activo y su historial (HU-038). El proceso vive
    /// en el SP ACTIVO_CAMBIAR_ESTADO —con sus reglas— para que la web y la
    /// API den el mismo resultado. El cliente sale de la sesión.
    /// </summary>
    public class ActivoEstadoHistorialController
    {
        public List<ActivoEstadoHistorial> GetHistorial(int activo, int cliente)
        {
            List<ActivoEstadoHistorial> lista = new List<ActivoEstadoHistorial>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_ESTADO_HISTORIAL";
                    if (activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    if (cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoEstadoHistorial i = new ActivoEstadoHistorial();
                            i.aeh_id = int.Parse(dr["AEH_ID"].ToString());
                            i.aeh_cliente = int.Parse(dr["AEH_CLIENTE"].ToString());
                            i.aeh_activo = int.Parse(dr["AEH_ACTIVO"].ToString());
                            i.aeh_activo_estado = int.Parse(dr["AEH_ACTIVO_ESTADO"].ToString());
                            if (dr["AEH_FECHA_INICIO_UTC"] != DBNull.Value) i.aeh_fecha_inicio_utc = DateTime.Parse(dr["AEH_FECHA_INICIO_UTC"].ToString());
                            if (dr["AEH_FECHA_FIN_UTC"] != DBNull.Value) i.aeh_fecha_fin_utc = DateTime.Parse(dr["AEH_FECHA_FIN_UTC"].ToString());
                            i.aeh_motivo = dr["AEH_MOTIVO"].ToString();
                            i.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            i.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            i.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            i.vigente = int.Parse(dr["VIGENTE"].ToString()) == 1;
                            i.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            lista.Add(i);
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

        /// <summary>Dispara el proceso de cambio de estado. Las reglas las hace el SP.</summary>
        public Respuesta CambiarEstado(ActivoEstadoHistorial e, int cliente, string motivo)
        {
            Respuesta r = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("ACTIVO_CAMBIAR_ESTADO");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@ACTIVO", e.aeh_activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);
                    cmd.Parameters.AddWithValue("@NUEVO_ESTADO", e.nuevo_estado);
                    cmd.Parameters.AddWithValue("@MOTIVO", string.IsNullOrEmpty(motivo) ? (object)DBNull.Value : motivo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    r.codigo = (int)cmd.Parameters["@ID"].Value;
                    r.detalle = "Estado cambiado con éxito.";
                    r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1;
                    r.detalle = ex.Message;
                    r.error = true;
                }
            }

            return r;
        }
    }
}
