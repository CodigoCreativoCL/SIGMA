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
    /// Arbol de centros de costo del cliente (HU-013).
    /// </summary>
    public class CentroCostoController
    {
        public List<CentroCosto> GetCentrosCosto(CentroCosto filtro = null)
        {
            List<CentroCosto> lista = new List<CentroCosto>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CENTRO_COSTO";

                    if (filtro != null)
                    {
                        if (filtro.cco_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.cco_id);
                        if (filtro.cco_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.cco_cliente);
                        if (filtro.cco_centro_costo_padre != null && filtro.cco_centro_costo_padre > 0)
                            cmd.Parameters.AddWithValue("@CENTRO_COSTO_PADRE", filtro.cco_centro_costo_padre);
                        if (filtro.filtro_solo_raiz) cmd.Parameters.AddWithValue("@SOLO_RAIZ", true);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            CentroCosto item = new CentroCosto();

                            item.cco_id = int.Parse(dr["CCO_ID"].ToString());
                            item.cco_cliente = int.Parse(dr["CCO_CLIENTE"].ToString());
                            if (dr["CCO_CENTRO_COSTO_PADRE"] != DBNull.Value)
                                item.cco_centro_costo_padre = int.Parse(dr["CCO_CENTRO_COSTO_PADRE"].ToString());
                            item.cco_codigo = dr["CCO_CODIGO"].ToString();
                            item.cco_nombre = dr["CCO_NOMBRE"].ToString();
                            item.cco_habilitado = bool.Parse(dr["CCO_HABILITADO"].ToString());
                            item.padre_nombre = dr["PADRE_NOMBRE"].ToString();
                            item.nivel = int.Parse(dr["NIVEL"].ToString());
                            item.ruta = dr["RUTA"].ToString();

                            if (dr["CCO_FECHA_CREACION"] != DBNull.Value)
                                item.cco_fecha_creacion = DateTime.Parse(dr["CCO_FECHA_CREACION"].ToString());
                            if (dr["CCO_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.cco_fecha_actualizacion = DateTime.Parse(dr["CCO_FECHA_ACTUALIZACION"].ToString());

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

        public CentroCosto GetCentroCosto(CentroCosto entidad)
        {
            List<CentroCosto> lista = GetCentrosCosto(new CentroCosto { cco_id = entidad.cco_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new CentroCosto();
        }

        public Respuesta InsertCentroCosto(CentroCosto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CENTRO_COSTO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.cco_cliente);
                    cmdExecute.Parameters.AddWithValue("@CENTRO_COSTO_PADRE", (object)entidad.cco_centro_costo_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.cco_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.cco_nombre);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Centro de costo creado con éxito.";
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

        public Respuesta UpdateCentroCosto(CentroCosto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_CENTRO_COSTO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.cco_id);
                    cmdExecute.Parameters.AddWithValue("@CENTRO_COSTO_PADRE", (object)entidad.cco_centro_costo_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.cco_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.cco_nombre);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.cco_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PADRE", entidad.quita_padre);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.cco_id;
                    respuesta.detalle = "Centro de costo actualizado con éxito.";
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

        public Respuesta DeleteCentroCosto(CentroCosto entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_CENTRO_COSTO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.cco_id);
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.cco_id;
                    respuesta.detalle = "Centro de costo eliminado con éxito.";
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
    }
}
