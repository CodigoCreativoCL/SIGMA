using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Maestro de activos del cliente (HU-035).
    ///
    /// El usuario que audita SIEMPRE sale de la sesión (Session.UsuarioId),
    /// nunca del Model: aceptarlo por parámetro dejaría auditar a nombre de
    /// cualquiera. El cliente lo pone la pantalla desde Session.ClienteId,
    /// que es la empresa activa en el selector.
    /// </summary>
    public class ActivoController
    {
        public List<Activo> GetActivos(Activo filtro = null)
        {
            List<Activo> lista = new List<Activo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO";

                    if (filtro != null)
                    {
                        if (filtro.act_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.act_id);
                        if (filtro.act_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.act_cliente);
                        if (filtro.filtro_cliente_instalacion > 0) cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", filtro.filtro_cliente_instalacion);
                        if (filtro.filtro_instalacion_area > 0) cmd.Parameters.AddWithValue("@INSTALACION_AREA", filtro.filtro_instalacion_area);
                        if (filtro.filtro_activo_tipo > 0) cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_activo_estado > 0) cmd.Parameters.AddWithValue("@ACTIVO_ESTADO", filtro.filtro_activo_estado);
                        if (filtro.act_activo_padre != null && filtro.act_activo_padre > 0)
                            cmd.Parameters.AddWithValue("@ACTIVO_PADRE", filtro.act_activo_padre);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Activo item = new Activo();

                            item.act_id = int.Parse(dr["ACT_ID"].ToString());
                            item.act_cliente = int.Parse(dr["ACT_CLIENTE"].ToString());
                            item.act_cliente_instalacion = int.Parse(dr["ACT_CLIENTE_INSTALACION"].ToString());
                            if (dr["ACT_INSTALACION_AREA"] != DBNull.Value)
                                item.act_instalacion_area = int.Parse(dr["ACT_INSTALACION_AREA"].ToString());
                            item.act_activo_tipo = int.Parse(dr["ACT_ACTIVO_TIPO"].ToString());
                            if (dr["ACT_ACTIVO_MODELO"] != DBNull.Value)
                                item.act_activo_modelo = int.Parse(dr["ACT_ACTIVO_MODELO"].ToString());
                            item.act_activo_estado = int.Parse(dr["ACT_ACTIVO_ESTADO"].ToString());
                            if (dr["ACT_ACTIVO_PADRE"] != DBNull.Value)
                                item.act_activo_padre = int.Parse(dr["ACT_ACTIVO_PADRE"].ToString());
                            if (dr["ACT_CENTRO_COSTO"] != DBNull.Value)
                                item.act_centro_costo = int.Parse(dr["ACT_CENTRO_COSTO"].ToString());
                            item.act_criticidad_nivel = int.Parse(dr["ACT_CRITICIDAD_NIVEL"].ToString());
                            item.act_codigo = dr["ACT_CODIGO"].ToString();
                            item.act_nombre = dr["ACT_NOMBRE"].ToString();
                            item.act_numero_serie = dr["ACT_NUMERO_SERIE"].ToString();
                            item.act_fabricante = dr["ACT_FABRICANTE"].ToString();
                            if (dr["ACT_ANIO_FABRICACION"] != DBNull.Value)
                                item.act_anio_fabricacion = int.Parse(dr["ACT_ANIO_FABRICACION"].ToString());
                            if (dr["ACT_FECHA_PUESTA_MARCHA"] != DBNull.Value)
                                item.act_fecha_puesta_marcha = DateTime.Parse(dr["ACT_FECHA_PUESTA_MARCHA"].ToString());
                            if (dr["ACT_FECHA_BAJA"] != DBNull.Value)
                                item.act_fecha_baja = DateTime.Parse(dr["ACT_FECHA_BAJA"].ToString());
                            item.act_descripcion = dr["ACT_DESCRIPCION"].ToString();
                            if (dr["ACT_REGISTRO_ORIGEN"] != DBNull.Value)
                                item.act_registro_origen = int.Parse(dr["ACT_REGISTRO_ORIGEN"].ToString());
                            item.act_habilitado = bool.Parse(dr["ACT_HABILITADO"].ToString());

                            if (dr["ACT_FECHA_CREACION"] != DBNull.Value)
                                item.act_fecha_creacion = DateTime.Parse(dr["ACT_FECHA_CREACION"].ToString());
                            if (dr["ACT_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.act_fecha_actualizacion = DateTime.Parse(dr["ACT_FECHA_ACTUALIZACION"].ToString());

                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.area_nombre = dr["AREA_NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            item.criticidad_nombre = dr["CRITICIDAD_NOMBRE"].ToString();
                            item.centro_costo_nombre = dr["CENTRO_COSTO_NOMBRE"].ToString();
                            item.padre_codigo = dr["PADRE_CODIGO"].ToString();
                            item.padre_nombre = dr["PADRE_NOMBRE"].ToString();
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

        public Activo GetActivo(int id)
        {
            List<Activo> lista = GetActivos(new Activo { act_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new Activo();
        }

        public Respuesta InsertActivo(Activo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_ACTIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.act_cliente);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", entidad.act_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA", (object)entidad.act_instalacion_area ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO", entidad.act_activo_tipo);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_MODELO", (object)entidad.act_activo_modelo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_ESTADO", entidad.act_activo_estado);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_PADRE", (object)entidad.act_activo_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CENTRO_COSTO", (object)entidad.act_centro_costo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CRITICIDAD_NIVEL", entidad.act_criticidad_nivel);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.act_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.act_nombre);
                    cmdExecute.Parameters.AddWithValue("@NUMERO_SERIE", (object)entidad.act_numero_serie ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FABRICANTE", (object)entidad.act_fabricante ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ANIO_FABRICACION", (object)entidad.act_anio_fabricacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_PUESTA_MARCHA", (object)entidad.act_fecha_puesta_marcha ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.act_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Activo creado con éxito.";
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

        public Respuesta UpdateActivo(Activo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ACTIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.act_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", entidad.act_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA", (object)entidad.act_instalacion_area ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO", entidad.act_activo_tipo);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_MODELO", (object)entidad.act_activo_modelo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_ESTADO", entidad.act_activo_estado);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_PADRE", (object)entidad.act_activo_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CENTRO_COSTO", (object)entidad.act_centro_costo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CRITICIDAD_NIVEL", entidad.act_criticidad_nivel);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.act_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.act_nombre);
                    cmdExecute.Parameters.AddWithValue("@NUMERO_SERIE", (object)entidad.act_numero_serie ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FABRICANTE", (object)entidad.act_fabricante ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ANIO_FABRICACION", (object)entidad.act_anio_fabricacion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@FECHA_PUESTA_MARCHA", (object)entidad.act_fecha_puesta_marcha ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.act_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.act_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.act_id;
                    respuesta.detalle = "Activo actualizado con éxito.";
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

        public Respuesta DeleteActivo(Activo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_ACTIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.act_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.act_id;
                    respuesta.detalle = "Activo dado de baja con éxito.";
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


    /// <summary>Tipos de activo para poblar el combo de la ficha (SEL_ACTIVO_TIPO).</summary>
    public class ActivoTipoController
    {
        public List<ActivoTipo> GetActivoTipos(ActivoTipo filtro = null)
        {
            List<ActivoTipo> lista = new List<ActivoTipo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_TIPO";

                    if (filtro != null)
                    {
                        if (filtro.ati_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ati_id);
                        if (filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.ati_activo_tipo_padre != null && filtro.ati_activo_tipo_padre > 0)
                            cmd.Parameters.AddWithValue("@ACTIVO_TIPO_PADRE", filtro.ati_activo_tipo_padre);
                        if (filtro.filtro_solo_raiz) cmd.Parameters.AddWithValue("@SOLO_RAIZ", true);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoTipo item = new ActivoTipo();
                            item.ati_id = int.Parse(dr["ATI_ID"].ToString());
                            if (dr["ATI_CLIENTE"] != DBNull.Value)
                                item.ati_cliente = int.Parse(dr["ATI_CLIENTE"].ToString());
                            if (dr["ATI_ACTIVO_TIPO_PADRE"] != DBNull.Value)
                                item.ati_activo_tipo_padre = int.Parse(dr["ATI_ACTIVO_TIPO_PADRE"].ToString());
                            item.ati_codigo = dr["ATI_CODIGO"].ToString();
                            item.ati_nombre = dr["ATI_NOMBRE"].ToString();
                            item.ati_descripcion = dr["ATI_DESCRIPCION"].ToString();
                            if (dr["ATI_ORDEN"] != DBNull.Value)
                                item.ati_orden = int.Parse(dr["ATI_ORDEN"].ToString());
                            item.ati_habilitado = bool.Parse(dr["ATI_HABILITADO"].ToString());
                            item.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            item.padre_nombre = dr["PADRE_NOMBRE"].ToString();
                            item.nivel = int.Parse(dr["NIVEL"].ToString());
                            item.ruta = dr["RUTA"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            if (dr["ATI_FECHA_CREACION"] != DBNull.Value)
                                item.ati_fecha_creacion = DateTime.Parse(dr["ATI_FECHA_CREACION"].ToString());
                            if (dr["ATI_FECHA_ACTUALIZACION"] != DBNull.Value)
                                item.ati_fecha_actualizacion = DateTime.Parse(dr["ATI_FECHA_ACTUALIZACION"].ToString());
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

        public ActivoTipo GetActivoTipo(int id)
        {
            List<ActivoTipo> lista = GetActivoTipos(new ActivoTipo { ati_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new ActivoTipo();
        }

        public Respuesta InsertActivoTipo(ActivoTipo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_ACTIVO_TIPO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.ati_cliente ?? 0);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO_PADRE", (object)entidad.ati_activo_tipo_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.ati_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.ati_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.ati_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", (object)entidad.ati_orden ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Tipo de activo creado con éxito.";
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

        public Respuesta UpdateActivoTipo(ActivoTipo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_ACTIVO_TIPO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ati_id);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO_TIPO_PADRE", (object)entidad.ati_activo_tipo_padre ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", entidad.ati_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", entidad.ati_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.ati_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", (object)entidad.ati_orden ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.ati_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_PADRE", entidad.quita_padre);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ati_id;
                    respuesta.detalle = "Tipo de activo actualizado con éxito.";
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

        public Respuesta DeleteActivoTipo(ActivoTipo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_ACTIVO_TIPO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ati_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ati_id;
                    respuesta.detalle = "Tipo de activo dado de baja con éxito.";
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


    /// <summary>Estados de activo para el combo de la ficha (SEL_ACTIVO_ESTADO).</summary>
    public class ActivoEstadoController
    {
        public List<ActivoEstado> GetActivoEstados(ActivoEstado filtro = null)
        {
            List<ActivoEstado> lista = new List<ActivoEstado>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_ESTADO";

                    if (filtro != null)
                    {
                        if (filtro.aes_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.aes_id);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoEstado item = new ActivoEstado();
                            item.aes_id = int.Parse(dr["AES_ID"].ToString());
                            item.aes_codigo = dr["AES_CODIGO"].ToString();
                            item.aes_nombre = dr["AES_NOMBRE"].ToString();
                            item.aes_icono = dr["AES_ICONO"].ToString();
                            item.aes_habilitado = bool.Parse(dr["AES_HABILITADO"].ToString());
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


    /// <summary>Niveles de criticidad para el combo de la ficha (SEL_CRITICIDAD_NIVEL).</summary>
    public class CriticidadNivelController
    {
        public List<CriticidadNivel> GetCriticidadNiveles(CriticidadNivel filtro = null)
        {
            List<CriticidadNivel> lista = new List<CriticidadNivel>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CRITICIDAD_NIVEL";

                    if (filtro != null)
                    {
                        if (filtro.crn_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.crn_id);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            CriticidadNivel item = new CriticidadNivel();
                            item.crn_id = int.Parse(dr["CRN_ID"].ToString());
                            item.crn_codigo = dr["CRN_CODIGO"].ToString();
                            item.crn_nombre = dr["CRN_NOMBRE"].ToString();
                            item.crn_icono = dr["CRN_ICONO"].ToString();
                            item.crn_habilitado = bool.Parse(dr["CRN_HABILITADO"].ToString());
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
