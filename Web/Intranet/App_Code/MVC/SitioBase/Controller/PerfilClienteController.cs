using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Los perfiles que define cada empresa (bloque 341).
    ///
    /// EL CLIENTE SALE DE LA SESIÓN, NUNCA DEL PARÁMETRO
    ///   Si viniera de afuera, cambiarlo en el POST dejaría editar los perfiles
    ///   de otra empresa. Los SP igual validan que el perfil sea del cliente,
    ///   pero la primera barrera está acá.
    /// </summary>
    public class PerfilClienteController
    {
        public List<PerfilCliente> GetPerfilesCliente(PerfilCliente filtro)
        {
            List<PerfilCliente> lista = new List<PerfilCliente>();
            if (!Token.TokenSeguridad() || Session.ClienteId() <= 0) return lista;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_PERFIL_CLIENTE");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                if (filtro != null)
                {
                    if (filtro.per_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.per_id);
                    if (!string.IsNullOrWhiteSpace(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro.Trim());
                    if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado.Value);
                    if (filtro.filtro_plantillas) cmd.Parameters.AddWithValue("@PLANTILLAS", true);
                }

                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                    {
                        PerfilCliente p = new PerfilCliente();
                        p.per_id = Convert.ToInt32(dr["PER_ID"]);
                        p.per_nombre = dr["PER_NOMBRE"].ToString();
                        p.per_descripcion = dr["PER_DESCRIPCION"].ToString();
                        p.per_ambito = dr["PER_AMBITO"] == DBNull.Value ? 3 : Convert.ToInt32(dr["PER_AMBITO"]);
                        p.per_solo_ejecucion = Convert.ToBoolean(dr["PER_SOLO_EJECUCION"]);
                        p.per_habilitado = Convert.ToBoolean(dr["PER_HABILITADO"]);
                        p.es_sistema = Convert.ToBoolean(dr["ES_SISTEMA"]);
                        p.usuarios = Convert.ToInt32(dr["USUARIOS"]);
                        p.permisos = Convert.ToInt32(dr["PERMISOS"]);
                        if (dr["PER_FECHA_ACT"] != DBNull.Value) p.per_fecha_act = Convert.ToDateTime(dr["PER_FECHA_ACT"]);
                        lista.Add(p);
                    }
                }
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
            return lista;
        }

        public PerfilCliente GetPerfilCliente(int id)
        {
            List<PerfilCliente> l = GetPerfilesCliente(new PerfilCliente { per_id = id });
            if (l.Count == 0) l = GetPerfilesCliente(new PerfilCliente { per_id = id, filtro_plantillas = true });
            return l.Count > 0 ? l[0] : null;
        }

        /// <summary>Lo que la empresa puede dar; con perfil, marca lo que ese perfil ya tiene.</summary>
        public List<PerfilClientePermiso> GetPermisos(int perfil)
        {
            List<PerfilClientePermiso> lista = new List<PerfilClientePermiso>();
            if (!Token.TokenSeguridad() || Session.ClienteId() <= 0) return lista;

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("SEL_PERFIL_CLIENTE_PERMISO");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                if (perfil > 0) cmd.Parameters.AddWithValue("@PERFIL", perfil);

                using (SqlDataReader dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                    {
                        lista.Add(new PerfilClientePermiso
                        {
                            prm_id = Convert.ToInt32(dr["PRM_ID"]),
                            prm_codigo = dr["PRM_CODIGO"].ToString(),
                            prm_nombre = dr["PRM_NOMBRE"].ToString(),
                            prm_descripcion = dr["PRM_DESCRIPCION"].ToString(),
                            prm_modulo = dr["PRM_MODULO"].ToString(),
                            asignado = Convert.ToBoolean(dr["ASIGNADO"])
                        });
                    }
                }
                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                throw;
            }
            return lista;
        }

        /// <summary>
        /// Guarda el perfil y, si viene la lista, sus permisos. Son dos SP: si el
        /// segundo falla el perfil ya quedó creado y se devuelve su id, para que
        /// la pantalla siga sobre él y no cree un duplicado al reintentar.
        /// </summary>
        public Respuesta Guardar(PerfilCliente entidad, IEnumerable<int> permisos)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad() || Session.ClienteId() <= 0)
            {
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
                return respuesta;
            }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPS_PERFIL_CLIENTE");
                cmd.Parameters.AddWithValue("@ID", entidad.per_id).Direction = ParameterDirection.InputOutput;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@NOMBRE", entidad.per_nombre ?? "");
                cmd.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.per_descripcion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@AMBITO", entidad.per_ambito);
                cmd.Parameters.AddWithValue("@SOLO_EJECUCION", entidad.per_solo_ejecucion);
                cmd.Parameters.AddWithValue("@HABILITADO", entidad.per_habilitado);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                int id = Convert.ToInt32(cmd.Parameters["@ID"].Value);
                respuesta.codigo = id;

                if (permisos != null)
                {
                    cmd = Conexion.GetCommand("UPS_PERFIL_CLIENTE_PERMISO");
                    cmd.Parameters.AddWithValue("@PERFIL", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@PERMISOS", string.Join(",", permisos));
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                }

                respuesta.detalle = entidad.per_id > 0 ? "Perfil actualizado con éxito." : "Perfil creado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                if (respuesta.codigo <= 0) respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }
            return respuesta;
        }

        /// <summary>Activar o desactivar sin tocar lo demás (botón del listado).</summary>
        public Respuesta CambiarEstado(int id, bool habilitado)
        {
            PerfilCliente p = GetPerfilCliente(id);
            if (p == null || p.es_sistema)
                return new Respuesta { codigo = -1, error = true, detalle = "Ese perfil no es de su empresa." };
            p.per_habilitado = habilitado;
            Respuesta r = Guardar(p, null);
            if (!r.error) r.detalle = habilitado ? "Perfil activado." : "Perfil desactivado.";
            return r;
        }
    }
}
