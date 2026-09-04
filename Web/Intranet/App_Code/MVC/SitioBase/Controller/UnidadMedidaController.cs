using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Unidades de medida (HU-040). Catálogo GLOBAL: no lleva @CLIENTE —un
    /// kilogramo pesa lo mismo en toda planta—. Su administración es de
    /// plataforma (Root); los combos de medidores/repuestos/variables lo leen
    /// para elegir, sin necesitar el permiso de la pantalla.
    /// </summary>
    public class UnidadMedidaController
    {
        /// <summary>
        /// Para los combos: solo las habilitadas. Mantiene la firma que ya
        /// usan las fichas de medidor y de repuesto.
        /// </summary>
        public List<UnidadMedida> GetUnidades(int id = 0)
        {
            UnidadMedida filtro = new UnidadMedida { filtro_habilitado = true };
            if (id > 0) filtro.ume_id = id;
            return GetUnidades(filtro);
        }

        /// <summary>Para el mantenedor: con filtros (id, magnitud, texto, habilitado).</summary>
        public List<UnidadMedida> GetUnidades(UnidadMedida filtro)
        {
            List<UnidadMedida> lista = new List<UnidadMedida>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_UNIDAD_MEDIDA";

                    if (filtro != null)
                    {
                        if (filtro.ume_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ume_id);
                        if (filtro.filtro_magnitud > 0) cmd.Parameters.AddWithValue("@MAGNITUD", filtro.filtro_magnitud);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            UnidadMedida item = new UnidadMedida();

                            item.ume_id = int.Parse(dr["UME_ID"].ToString());
                            item.ume_magnitud = int.Parse(dr["UME_MAGNITUD"].ToString());
                            if (dr["UME_UNIDAD_BASE"] != DBNull.Value)
                                item.ume_unidad_base = int.Parse(dr["UME_UNIDAD_BASE"].ToString());
                            item.ume_codigo = dr["UME_CODIGO"].ToString();
                            item.ume_nombre = dr["UME_NOMBRE"].ToString();
                            item.ume_simbolo = dr["UME_SIMBOLO"].ToString();
                            item.ume_factor = decimal.Parse(dr["UME_FACTOR"].ToString());
                            item.ume_offset = decimal.Parse(dr["UME_OFFSET"].ToString());
                            item.ume_habilitado = bool.Parse(dr["UME_HABILITADO"].ToString());
                            item.magnitud_nombre = dr["MAGNITUD_NOMBRE"].ToString();
                            item.unidad_base_nombre = dr["UNIDAD_BASE_NOMBRE"].ToString();
                            item.etiqueta = dr["ETIQUETA"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            if (dr["UME_FECHA_CREACION"] != DBNull.Value)
                                item.ume_fecha_creacion = DateTime.Parse(dr["UME_FECHA_CREACION"].ToString());
                            if (dr["UME_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.ume_fecha_actualizacion = DateTime.Parse(dr["UME_FECHA_ACTUALIZACION"].ToString());

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

        public UnidadMedida GetUnidad(int id)
        {
            List<UnidadMedida> lista = GetUnidades(new UnidadMedida { ume_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new UnidadMedida();
        }

        public Respuesta InsertUnidad(UnidadMedida entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_UNIDAD_MEDIDA");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@MAGNITUD", entidad.ume_magnitud);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_BASE", (object)entidad.ume_unidad_base ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.ume_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.ume_nombre);
                    cmdExecute.Parameters.AddWithValue("@SIMBOLO", entidad.ume_simbolo);
                    cmdExecute.Parameters.AddWithValue("@FACTOR", entidad.ume_factor);
                    cmdExecute.Parameters.AddWithValue("@OFFSET", entidad.ume_offset);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Unidad de medida creada con éxito.";
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

        public Respuesta UpdateUnidad(UnidadMedida entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_UNIDAD_MEDIDA");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ume_id);
                    cmdExecute.Parameters.AddWithValue("@MAGNITUD", entidad.ume_magnitud);
                    cmdExecute.Parameters.AddWithValue("@UNIDAD_BASE", (object)entidad.ume_unidad_base ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.ume_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.ume_nombre);
                    cmdExecute.Parameters.AddWithValue("@SIMBOLO", entidad.ume_simbolo);
                    cmdExecute.Parameters.AddWithValue("@FACTOR", entidad.ume_factor);
                    cmdExecute.Parameters.AddWithValue("@OFFSET", entidad.ume_offset);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.ume_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_BASE", entidad.quita_base);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ume_id;
                    respuesta.detalle = "Unidad de medida actualizada con éxito.";
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

        public Respuesta DeleteUnidad(UnidadMedida entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_UNIDAD_MEDIDA");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ume_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ume_id;
                    respuesta.detalle = "Unidad de medida dada de baja con éxito.";
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


    /// <summary>Magnitudes para el combo de la ficha de unidad (SEL_MAGNITUD).</summary>
    public class MagnitudController
    {
        public List<Magnitud> GetMagnitudes()
        {
            List<Magnitud> lista = new List<Magnitud>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_MAGNITUD";
                    cmd.Parameters.AddWithValue("@HABILITADO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Magnitud item = new Magnitud();
                            item.mag_id = int.Parse(dr["MAG_ID"].ToString());
                            item.mag_codigo = dr["MAG_CODIGO"].ToString();
                            item.mag_nombre = dr["MAG_NOMBRE"].ToString();
                            item.mag_habilitado = bool.Parse(dr["MAG_HABILITADO"].ToString());
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
    }
}
