using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Los tipos de repuesto que definió el cliente.
    ///
    /// EL CLIENTE SALE DE LA SESIÓN, NUNCA DEL PARÁMETRO
    ///   Si viniera de afuera, cambiarlo en el POST mostraría —o peor,
    ///   modificaría— las categorías de otra empresa. Los SP igual filtran por
    ///   él, pero la primera barrera está acá.
    /// </summary>
    public class RepuestoTipoController
    {
        public List<RepuestoTipo> GetRepuestoTipos(RepuestoTipo filtro)
        {
            List<RepuestoTipo> lista = new List<RepuestoTipo>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_REPUESTO_TIPO");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                if (filtro != null && filtro.rti_id > 0)
                    cmd.Parameters.AddWithValue("@ID", filtro.rti_id);

                if (filtro != null && filtro.filtro_habilitado != null)
                    cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado.Value);

                if (filtro != null && !string.IsNullOrEmpty(filtro.filtro))
                    cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        RepuestoTipo t = new RepuestoTipo();

                        t.rti_id = int.Parse(dr["RTI_ID"].ToString());
                        t.rti_cliente = int.Parse(dr["RTI_CLIENTE"].ToString());
                        t.rti_codigo = dr["RTI_CODIGO"].ToString();
                        t.rti_nombre = dr["RTI_NOMBRE"].ToString();
                        t.rti_descripcion = dr["RTI_DESCRIPCION"].ToString();
                        t.rti_orden = int.Parse(dr["RTI_ORDEN"].ToString());
                        t.rti_habilitado = Convert.ToBoolean(dr["RTI_HABILITADO"]);
                        t.repuestos = int.Parse(dr["REPUESTOS"].ToString());

                        if (dr["RTI_FECHA_CREACION"] != DBNull.Value)
                            t.rti_fecha_creacion = DateTime.Parse(dr["RTI_FECHA_CREACION"].ToString());

                        lista.Add(t);
                    }
                }

                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            return lista;
        }

        public RepuestoTipo GetRepuestoTipo(int id)
        {
            List<RepuestoTipo> l = GetRepuestoTipos(new RepuestoTipo { rti_id = id });

            return l.Count > 0 ? l[0] : new RepuestoTipo();
        }

        public Respuesta InsertRepuestoTipo(RepuestoTipo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("INS_REPUESTO_TIPO");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@CODIGO", entidad.rti_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", entidad.rti_nombre);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.rti_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ORDEN", entidad.rti_orden);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Tipo de repuesto creado con éxito.";
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

        public Respuesta UpdateRepuestoTipo(RepuestoTipo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPD_REPUESTO_TIPO");
                    cmd.Parameters.AddWithValue("@ID", entidad.rti_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@CODIGO", (object)entidad.rti_codigo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", (object)entidad.rti_nombre ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)entidad.rti_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ORDEN", entidad.rti_orden);
                    cmd.Parameters.AddWithValue("@HABILITADO", entidad.rti_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = entidad.rti_id;
                    respuesta.detalle = "Tipo de repuesto actualizado con éxito.";
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

        public Respuesta DeleteRepuestoTipo(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("DEL_REPUESTO_TIPO");
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = "Tipo de repuesto eliminado.";
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
