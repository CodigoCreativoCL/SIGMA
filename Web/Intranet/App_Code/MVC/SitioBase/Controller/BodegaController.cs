using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Bodegas y sus ubicaciones (HU-052).
    ///
    /// TODO SE ACOTA POR CLIENTE, SIEMPRE
    ///   @CLIENTE no es opcional en ninguno de los SP de este modulo, y
    ///   sale de la sesion, nunca de la pantalla. Es lo que impide que un
    ///   id en la URL muestre la bodega de otra empresa —el mismo agujero
    ///   que tenia Pago.aspx y se corrigio en el bloque 52—.
    /// </summary>
    public class BodegaController
    {
        public List<Bodega> GetBodegas(Bodega filtro = null)
        {
            List<Bodega> lista = new List<Bodega>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_BODEGA";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.bod_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.bod_id);
                        if (filtro.filtro_instalacion > 0)
                            cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_instalacion);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Bodega item = new Bodega();

                            item.bod_id = int.Parse(dr["BOD_ID"].ToString());
                            item.bod_cliente = int.Parse(dr["BOD_CLIENTE"].ToString());
                            item.bod_cliente_instalacion = int.Parse(dr["BOD_CLIENTE_INSTALACION"].ToString());
                            item.bod_codigo = dr["BOD_CODIGO"].ToString();
                            item.bod_nombre = dr["BOD_NOMBRE"].ToString();
                            item.bod_descripcion = dr["BOD_DESCRIPCION"].ToString();
                            item.bod_habilitado = bool.Parse(dr["BOD_HABILITADO"].ToString());
                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.ubicaciones = int.Parse(dr["UBICACIONES"].ToString());
                            item.repuestos_con_saldo = int.Parse(dr["REPUESTOS_CON_SALDO"].ToString());

                            if (dr["BOD_FECHA_CREACION"] != DBNull.Value)
                                item.bod_fecha_creacion = DateTime.Parse(dr["BOD_FECHA_CREACION"].ToString());
                            if (dr["BOD_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.bod_fecha_actualizacion = DateTime.Parse(dr["BOD_FECHA_ACTUALIZACION"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();


                            lista.Add(item);
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

        public Bodega GetBodega(int id)
        {
            List<Bodega> lista = GetBodegas(new Bodega { bod_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new Bodega();
        }

        public Respuesta InsertBodega(Bodega entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_BODEGA");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@INSTALACION", entidad.bod_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.bod_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.bod_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.bod_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = (int)cmdExecute.Parameters["@ID"].Value;
                    respuesta.detalle = "Bodega creada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// El CODIGO no viaja: no se edita. Es con lo que se identifica la
        /// bodega en cualquier carga de datos.
        /// </summary>
        public Respuesta UpdateBodega(Bodega entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_BODEGA");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.bod_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@INSTALACION", entidad.bod_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.bod_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.bod_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.bod_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.bod_id;
                    respuesta.detalle = "Bodega actualizada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// Baja logica. El SP rechaza si la bodega tiene existencia:
        /// esconderla no vacia la estanteria.
        /// </summary>
        public Respuesta DeleteBodega(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_BODEGA");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    string mensaje = "Bodega dada de baja.";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmdExecute))
                    {
                        if (dr.Read() && dr["MENSAJE"] != DBNull.Value) mensaje = dr["MENSAJE"].ToString();
                    }

                    cmdExecute.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = mensaje;
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }


        /* ================================================================
           UBICACIONES  (HU-052 criterio 2)
           ================================================================ */

        public List<BodegaUbicacion> GetUbicaciones(BodegaUbicacion filtro = null)
        {
            List<BodegaUbicacion> lista = new List<BodegaUbicacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_BODEGA_UBICACION";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.bub_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.bub_id);
                        if (filtro.bub_bodega > 0) cmd.Parameters.AddWithValue("@BODEGA", filtro.bub_bodega);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            BodegaUbicacion item = new BodegaUbicacion();

                            item.bub_id = int.Parse(dr["BUB_ID"].ToString());
                            item.bub_bodega = int.Parse(dr["BUB_BODEGA"].ToString());
                            item.bub_codigo = dr["BUB_CODIGO"].ToString();
                            item.bub_nombre = dr["BUB_NOMBRE"].ToString();
                            item.bub_habilitado = bool.Parse(dr["BUB_HABILITADO"].ToString());
                            item.bodega_codigo = dr["BODEGA_CODIGO"].ToString();
                            item.bodega_nombre = dr["BODEGA_NOMBRE"].ToString();

                            if (dr["BUB_FECHA_CREACION"] != DBNull.Value)
                                item.bub_fecha_creacion = DateTime.Parse(dr["BUB_FECHA_CREACION"].ToString());
                            if (dr["BUB_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.bub_fecha_actualizacion = DateTime.Parse(dr["BUB_FECHA_ACTUALIZACION"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();


                            lista.Add(item);
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

        public Respuesta GuardarUbicacion(BodegaUbicacion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    if (entidad.bub_id > 0)
                    {
                        cmdExecute = Conexion.GetCommand("UPD_BODEGA_UBICACION");
                        cmdExecute.Parameters.AddWithValue("@ID", entidad.bub_id);
                        cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                        cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.bub_nombre);
                        cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.bub_habilitado);
                        cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                        cmdExecute.ExecuteNonQuery();

                        respuesta.codigo = entidad.bub_id;
                        respuesta.detalle = "Ubicación actualizada.";
                    }
                    else
                    {
                        int id = 0;

                        cmdExecute = Conexion.GetCommand("INS_BODEGA_UBICACION");
                        cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                        cmdExecute.Parameters.AddWithValue("@BODEGA", entidad.bub_bodega);
                        cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                        cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.bub_codigo);
                        cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.bub_nombre);
                        cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                        cmdExecute.ExecuteNonQuery();

                        respuesta.codigo = (int)cmdExecute.Parameters["@ID"].Value;
                        respuesta.detalle = "Ubicación creada.";
                    }

                    cmdExecute.Connection.Close();
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public Respuesta DeleteUbicacion(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_BODEGA_UBICACION");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = "Ubicación dada de baja.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }
    }
}
