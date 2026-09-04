using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>Componentes de los activos del cliente (HU-036).</summary>
    public class ActivoComponenteController
    {
        public List<ActivoComponente> GetComponentes(ActivoComponente filtro = null)
        {
            List<ActivoComponente> lista = new List<ActivoComponente>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_COMPONENTE";

                    if (filtro != null)
                    {
                        if (filtro.aco_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.aco_id);
                        if (filtro.aco_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.aco_cliente);
                        if (filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoComponente i = new ActivoComponente();
                            i.aco_id = int.Parse(dr["ACO_ID"].ToString());
                            i.aco_cliente = int.Parse(dr["ACO_CLIENTE"].ToString());
                            i.aco_activo = int.Parse(dr["ACO_ACTIVO"].ToString());
                            if (dr["ACO_COMPONENTE_PADRE"] != DBNull.Value) i.aco_componente_padre = int.Parse(dr["ACO_COMPONENTE_PADRE"].ToString());
                            i.aco_componente_tipo = int.Parse(dr["ACO_COMPONENTE_TIPO"].ToString());
                            if (dr["ACO_COMPONENTE_POSICION"] != DBNull.Value) i.aco_componente_posicion = int.Parse(dr["ACO_COMPONENTE_POSICION"].ToString());
                            i.aco_criticidad_nivel = int.Parse(dr["ACO_CRITICIDAD_NIVEL"].ToString());
                            i.aco_activo_componente_estado = int.Parse(dr["ACO_ACTIVO_COMPONENTE_ESTADO"].ToString());
                            i.aco_codigo = dr["ACO_CODIGO"].ToString();
                            i.aco_nombre = dr["ACO_NOMBRE"].ToString();
                            if (dr["ACO_FECHA_INSTALACION"] != DBNull.Value) i.aco_fecha_instalacion = DateTime.Parse(dr["ACO_FECHA_INSTALACION"].ToString());
                            i.aco_descripcion = dr["ACO_DESCRIPCION"].ToString();
                            i.aco_habilitado = bool.Parse(dr["ACO_HABILITADO"].ToString());
                            if (dr["ACO_FECHA_CREACION"] != DBNull.Value) i.aco_fecha_creacion = DateTime.Parse(dr["ACO_FECHA_CREACION"].ToString());
                            if (dr["ACO_FECHA_ACTUALIZACION"] != DBNull.Value) i.aco_fecha_actualizacion = DateTime.Parse(dr["ACO_FECHA_ACTUALIZACION"].ToString());
                            i.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            i.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            i.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            i.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            i.criticidad_nombre = dr["CRITICIDAD_NOMBRE"].ToString();
                            i.posicion_nombre = dr["POSICION_NOMBRE"].ToString();
                            i.padre_nombre = dr["PADRE_NOMBRE"].ToString();
                            i.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            i.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
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

        public ActivoComponente GetComponente(int id)
        {
            List<ActivoComponente> l = GetComponentes(new ActivoComponente { aco_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ActivoComponente();
        }

        public Respuesta InsertComponente(ActivoComponente e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_ACTIVO_COMPONENTE");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", e.aco_cliente);
                    cmd.Parameters.AddWithValue("@ACTIVO", e.aco_activo);
                    cmd.Parameters.AddWithValue("@COMPONENTE_PADRE", (object)e.aco_componente_padre ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@COMPONENTE_TIPO", e.aco_componente_tipo);
                    cmd.Parameters.AddWithValue("@COMPONENTE_POSICION", (object)e.aco_componente_posicion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@CRITICIDAD_NIVEL", e.aco_criticidad_nivel);
                    cmd.Parameters.AddWithValue("@ACTIVO_COMPONENTE_ESTADO", e.aco_activo_componente_estado);
                    cmd.Parameters.AddWithValue("@CODIGO", e.aco_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.aco_nombre);
                    cmd.Parameters.AddWithValue("@FECHA_INSTALACION", (object)e.aco_fecha_instalacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.aco_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Componente creado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }

        public Respuesta UpdateComponente(ActivoComponente e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_ACTIVO_COMPONENTE");
                    cmd.Parameters.AddWithValue("@ID", e.aco_id);
                    cmd.Parameters.AddWithValue("@COMPONENTE_PADRE", (object)e.aco_componente_padre ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@COMPONENTE_TIPO", e.aco_componente_tipo);
                    cmd.Parameters.AddWithValue("@COMPONENTE_POSICION", (object)e.aco_componente_posicion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@CRITICIDAD_NIVEL", e.aco_criticidad_nivel);
                    cmd.Parameters.AddWithValue("@ACTIVO_COMPONENTE_ESTADO", e.aco_activo_componente_estado);
                    cmd.Parameters.AddWithValue("@CODIGO", e.aco_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.aco_nombre);
                    cmd.Parameters.AddWithValue("@FECHA_INSTALACION", (object)e.aco_fecha_instalacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.aco_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.aco_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.aco_id; r.detalle = "Componente actualizado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }

        public Respuesta DeleteComponente(ActivoComponente e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ACTIVO_COMPONENTE");
                    cmd.Parameters.AddWithValue("@ID", e.aco_id);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.aco_id; r.detalle = "Componente dado de baja con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                /* SIN SESION NO SE FINGE EXITO.
            
                   `new Respuesta()` nace con `error = false` y `detalle` en nulo.
                   Sin este bloque, cuando no hay sesion el metodo devolvia ese
                   objeto tal cual y la pantalla lo leia como "guardado con
                   exito": alerta vacia y ni una fila escrita. */
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }
    }


    /// <summary>Tipos de componente para el combo (SEL_COMPONENTE_TIPO).</summary>
    public class ComponenteTipoController
    {
        public List<ComponenteTipo> GetTipos(ComponenteTipo filtro = null)
        {
            List<ComponenteTipo> lista = new List<ComponenteTipo>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_COMPONENTE_TIPO";
                    if (filtro != null)
                    {
                        if (filtro.cto_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.cto_id);
                        if (filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        while (dr.Read())
                        {
                            ComponenteTipo i = new ComponenteTipo();
                            i.cto_id = int.Parse(dr["CTO_ID"].ToString());
                            if (dr["CTO_CLIENTE"] != DBNull.Value) i.cto_cliente = int.Parse(dr["CTO_CLIENTE"].ToString());
                            i.cto_codigo = dr["CTO_CODIGO"].ToString();
                            i.cto_nombre = dr["CTO_NOMBRE"].ToString();
                            i.cto_habilitado = bool.Parse(dr["CTO_HABILITADO"].ToString());
                            lista.Add(i);
                        }
                    cmd.Connection.Close(); cmd.Dispose();
                }
                catch (Exception) { if (cmd.Connection != null) cmd.Connection.Close(); cmd.Dispose(); lista = null; }
            }
            return lista;
        }
    }


    /// <summary>Estados de componente para el combo (SEL_ACTIVO_COMPONENTE_ESTADO).</summary>
    public class ActivoComponenteEstadoController
    {
        public List<ActivoComponenteEstado> GetEstados(ActivoComponenteEstado filtro = null)
        {
            List<ActivoComponenteEstado> lista = new List<ActivoComponenteEstado>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_COMPONENTE_ESTADO";
                    if (filtro != null && filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        while (dr.Read())
                        {
                            ActivoComponenteEstado i = new ActivoComponenteEstado();
                            i.ace_id = int.Parse(dr["ACE_ID"].ToString());
                            i.ace_codigo = dr["ACE_CODIGO"].ToString();
                            i.ace_nombre = dr["ACE_NOMBRE"].ToString();
                            i.ace_habilitado = bool.Parse(dr["ACE_HABILITADO"].ToString());
                            lista.Add(i);
                        }
                    cmd.Connection.Close(); cmd.Dispose();
                }
                catch (Exception) { if (cmd.Connection != null) cmd.Connection.Close(); cmd.Dispose(); lista = null; }
            }
            return lista;
        }
    }


    /// <summary>Posiciones de componente para el combo (SEL_COMPONENTE_POSICION).</summary>
    public class ComponentePosicionController
    {
        public List<ComponentePosicion> GetPosiciones(ComponentePosicion filtro = null)
        {
            List<ComponentePosicion> lista = new List<ComponentePosicion>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_COMPONENTE_POSICION";
                    if (filtro != null)
                    {
                        if (filtro.cpn_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.cpn_id);
                        if (filtro.filtro_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        while (dr.Read())
                        {
                            ComponentePosicion i = new ComponentePosicion();
                            i.cpn_id = int.Parse(dr["CPN_ID"].ToString());
                            if (dr["CPN_CLIENTE"] != DBNull.Value) i.cpn_cliente = int.Parse(dr["CPN_CLIENTE"].ToString());
                            i.cpn_codigo = dr["CPN_CODIGO"].ToString();
                            i.cpn_nombre = dr["CPN_NOMBRE"].ToString();
                            i.cpn_habilitado = bool.Parse(dr["CPN_HABILITADO"].ToString());
                            lista.Add(i);
                        }
                    cmd.Connection.Close(); cmd.Dispose();
                }
                catch (Exception) { if (cmd.Connection != null) cmd.Connection.Close(); cmd.Dispose(); lista = null; }
            }
            return lista;
        }
    }
}
