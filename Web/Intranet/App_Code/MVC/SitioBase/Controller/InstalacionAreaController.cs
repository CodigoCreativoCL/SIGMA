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
    /// Areas y subareas de una planta (HU-012).
    /// </summary>
    public class InstalacionAreaController
    {
        public List<InstalacionArea> GetInstalacionAreas(InstalacionArea filtro = null)
        {
            List<InstalacionArea> lista = new List<InstalacionArea>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_INSTALACION_AREA";

                    if (filtro != null)
                    {
                        if (filtro.iar_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.iar_id);
                        if (filtro.iar_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.iar_cliente);
                        if (filtro.iar_cliente_instalacion > 0) cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", filtro.iar_cliente_instalacion);
                        if (filtro.iar_area_padre != null && filtro.iar_area_padre > 0) cmd.Parameters.AddWithValue("@AREA_PADRE", filtro.iar_area_padre);
                        if (filtro.filtro_solo_raiz) cmd.Parameters.AddWithValue("@SOLO_RAIZ", true);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InstalacionArea item = new InstalacionArea();

                            item.iar_id = int.Parse(dr["IAR_ID"].ToString());
                            item.iar_cliente = int.Parse(dr["IAR_CLIENTE"].ToString());
                            item.iar_cliente_instalacion = int.Parse(dr["IAR_CLIENTE_INSTALACION"].ToString());
                            if (dr["IAR_AREA_PADRE"] != DBNull.Value) item.iar_area_padre = int.Parse(dr["IAR_AREA_PADRE"].ToString());
                            if (dr["IAR_INSTALACION_AREA_TIPO"] != DBNull.Value) item.iar_instalacion_area_tipo = int.Parse(dr["IAR_INSTALACION_AREA_TIPO"].ToString());
                            item.iar_codigo = dr["IAR_CODIGO"].ToString();
                            item.iar_nombre = dr["IAR_NOMBRE"].ToString();
                            item.iar_descripcion = dr["IAR_DESCRIPCION"].ToString();
                            item.iar_habilitado = bool.Parse(dr["IAR_HABILITADO"].ToString());
                            item.cin_nombre = dr["CIN_NOMBRE"].ToString();
                            item.padre_nombre = dr["PADRE_NOMBRE"].ToString();
                            item.iat_nombre = dr["IAT_NOMBRE"].ToString();
                            item.nivel = int.Parse(dr["NIVEL"].ToString());
                            item.ruta = dr["RUTA"].ToString();

                            if (dr["IAR_FECHA_CREACION"] != DBNull.Value)
                                item.iar_fecha_creacion = DateTime.Parse(dr["IAR_FECHA_CREACION"].ToString());
                            if (dr["IAR_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.iar_fecha_actualizacion = DateTime.Parse(dr["IAR_FECHA_ACTUALIZACION"].ToString());

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

        public InstalacionArea GetInstalacionArea(InstalacionArea entidad)
        {
            List<InstalacionArea> lista = GetInstalacionAreas(new InstalacionArea { iar_id = entidad.iar_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new InstalacionArea();
        }

        public Respuesta InsertInstalacionArea(InstalacionArea entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_INSTALACION_AREA");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.iar_cliente);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", entidad.iar_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@AREA_PADRE", (object)entidad.iar_area_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA_TIPO", (object)entidad.iar_instalacion_area_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.iar_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.iar_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.iar_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Área creada con éxito.";
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

            return respuesta;
        }

        public Respuesta UpdateInstalacionArea(InstalacionArea entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_INSTALACION_AREA");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.iar_id);
                    cmdExecute.Parameters.AddWithValue("@AREA_PADRE", (object)entidad.iar_area_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA_TIPO", (object)entidad.iar_instalacion_area_tipo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.iar_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.iar_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.iar_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.iar_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PADRE", entidad.quita_padre);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.iar_id;
                    respuesta.detalle = "Área actualizada con éxito.";
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

            return respuesta;
        }

        public Respuesta DeleteInstalacionArea(InstalacionArea entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_INSTALACION_AREA");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.iar_id);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.iar_id;
                    respuesta.detalle = "Área eliminada con éxito.";
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

            return respuesta;
        }
    }
}
