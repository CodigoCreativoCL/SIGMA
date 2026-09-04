using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Permisos puntuales de una persona dentro de un cliente (HU-007).
    ///
    /// Son excepciones al perfil: conceden o deniegan un permiso concreto,
    /// opcionalmente acotadas a una planta o a un area y con vigencia.
    /// Quien decide si aplican es FNC_USUARIO_TIENE_PERMISO, no este
    /// controller: aqui solo se administran.
    /// </summary>
    public class ClienteUsuarioPermisoController
    {
        public List<ClienteUsuarioPermiso> GetPermisos(ClienteUsuarioPermiso filtro = null)
        {
            List<ClienteUsuarioPermiso> lista = new List<ClienteUsuarioPermiso>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_USUARIO_PERMISO";

                    if (filtro != null)
                    {
                        if (filtro.cpm_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.cpm_id);
                        if (filtro.cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.cliente);
                        if (filtro.cpm_cliente_usuario > 0) cmd.Parameters.AddWithValue("@CLIENTE_USUARIO", filtro.cpm_cliente_usuario);
                        if (filtro.usuario_destino > 0) cmd.Parameters.AddWithValue("@USUARIO", filtro.usuario_destino);
                        if (filtro.cpm_cliente_instalacion != null && filtro.cpm_cliente_instalacion > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", filtro.cpm_cliente_instalacion);
                        if (filtro.filtro_solo_vigentes) cmd.Parameters.AddWithValue("@SOLO_VIGENTES", true);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ClienteUsuarioPermiso item = new ClienteUsuarioPermiso();

                            item.cpm_id = int.Parse(dr["CPM_ID"].ToString());
                            item.cpm_cliente_usuario = int.Parse(dr["CPM_CLIENTE_USUARIO"].ToString());
                            item.cpm_permiso = int.Parse(dr["CPM_PERMISO"].ToString());
                            if (dr["CPM_CLIENTE_INSTALACION"] != DBNull.Value)
                                item.cpm_cliente_instalacion = int.Parse(dr["CPM_CLIENTE_INSTALACION"].ToString());
                            if (dr["CPM_INSTALACION_AREA"] != DBNull.Value)
                                item.cpm_instalacion_area = int.Parse(dr["CPM_INSTALACION_AREA"].ToString());
                            item.cpm_otorgado = bool.Parse(dr["CPM_OTORGADO"].ToString());
                            item.cpm_motivo = dr["CPM_MOTIVO"].ToString();
                            item.cpm_habilitado = bool.Parse(dr["CPM_HABILITADO"].ToString());
                            item.usu_id = int.Parse(dr["USU_ID"].ToString());
                            item.usu_nombre = dr["USU_NOMBRE"].ToString();
                            item.usu_correo = dr["USU_CORREO"].ToString();
                            item.prm_codigo = dr["PRM_CODIGO"].ToString();
                            item.prm_nombre = dr["PRM_NOMBRE"].ToString();
                            item.prm_modulo = dr["PRM_MODULO"].ToString();
                            item.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            item.iar_nombre = dr["IAR_NOMBRE"].ToString();
                            item.otorgado_por = dr["OTORGADO_POR"].ToString();
                            item.estado = dr["ESTADO"].ToString();
                            item.ambito = dr["AMBITO"].ToString();

                            if (dr["CPM_FECHA_INICIO"] != DBNull.Value)
                                item.cpm_fecha_inicio = DateTime.Parse(dr["CPM_FECHA_INICIO"].ToString());
                            if (dr["CPM_FECHA_FIN"] != DBNull.Value)
                                item.cpm_fecha_fin = DateTime.Parse(dr["CPM_FECHA_FIN"].ToString());
                            if (dr["CPM_FECHA_CREACION"] != DBNull.Value)
                                item.cpm_fecha_creacion = DateTime.Parse(dr["CPM_FECHA_CREACION"].ToString());

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

        public ClienteUsuarioPermiso GetPermiso(ClienteUsuarioPermiso entidad)
        {
            List<ClienteUsuarioPermiso> lista = GetPermisos(new ClienteUsuarioPermiso { cpm_id = entidad.cpm_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new ClienteUsuarioPermiso();
        }

        public Respuesta InsertPermiso(ClienteUsuarioPermiso entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CLIENTE_USUARIO_PERMISO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_USUARIO", entidad.cpm_cliente_usuario);
                    cmdExecute.Parameters.AddWithValue("@PERMISO", entidad.cpm_permiso);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", (object)entidad.cpm_cliente_instalacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA", (object)entidad.cpm_instalacion_area ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@OTORGADO", entidad.cpm_otorgado);
                    cmdExecute.Parameters.AddWithValue("@FECHA_INICIO", (object)entidad.cpm_fecha_inicio ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_FIN", (object)entidad.cpm_fecha_fin ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MOTIVO", (object)entidad.cpm_motivo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.cliente);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Permiso asignado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdatePermiso(ClienteUsuarioPermiso entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_CLIENTE_USUARIO_PERMISO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.cpm_id);
                    cmdExecute.Parameters.AddWithValue("@OTORGADO", entidad.cpm_otorgado);
                    cmdExecute.Parameters.AddWithValue("@FECHA_INICIO", (object)entidad.cpm_fecha_inicio ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_FIN", (object)entidad.cpm_fecha_fin ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@MOTIVO", (object)entidad.cpm_motivo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.cpm_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.cpm_id;
                    respuesta.detalle = "Permiso actualizado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>
        /// Revocar (HU-007 escenario 2).
        ///
        /// Es una baja LOGICA, no un borrado: el escenario pide que la
        /// revocacion quede registrada, y una fila borrada no registra nada.
        /// Al quedar deshabilitada, la persona vuelve a lo que dice su
        /// perfil, que es exactamente lo pedido.
        /// </summary>
        public Respuesta RevocarPermiso(ClienteUsuarioPermiso entidad)
        {
            entidad.cpm_habilitado = false;
            Respuesta respuesta = UpdatePermiso(entidad);

            if (!respuesta.error)
                respuesta.detalle = "Permiso revocado con éxito.";

            return respuesta;
        }

        /// <summary>
        /// Los permisos del catalogo que pueden concederse a una persona.
        /// Solo los marcados prm_asignable_usuario: hay permisos que solo
        /// tienen sentido por perfil y ofrecerlos aqui seria un error.
        /// </summary>
        public List<Permiso> GetPermisosAsignables()
        {
            List<Permiso> lista = new List<Permiso>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PERMISO";
                    cmd.Parameters.AddWithValue("@ASIGNABLE_USUARIO", true);
                    cmd.Parameters.AddWithValue("@HABILITADO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Permiso item = new Permiso();

                            item.prm_id = int.Parse(dr["PRM_ID"].ToString());
                            item.prm_codigo = dr["PRM_CODIGO"].ToString();
                            item.prm_nombre = dr["PRM_NOMBRE"].ToString();
                            item.prm_modulo = dr["PRM_MODULO"].ToString();

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
    }
}
