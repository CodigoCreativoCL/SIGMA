using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Proveedores y contratistas (HU-060, bloque 91).
    ///
    /// TODO SE ACOTA POR CLIENTE, SIEMPRE
    ///   @CLIENTE sale de la sesion, nunca de la pantalla. Es lo que impide
    ///   que un id puesto a mano en la URL muestre el proveedor de otra
    ///   empresa —el mismo agujero que tenia Pago.aspx y se corrigio en el
    ///   bloque 52—.
    ///
    ///   Por eso GetProveedor(id) no confia en el id: llama al mismo SEL_
    ///   con el cliente de la sesion, y si el proveedor es de otra empresa
    ///   no vuelve nada. Un SP aparte "por id" seria el sitio donde algun
    ///   dia se olvida el filtro.
    /// </summary>
    public class ProveedorController
    {
        public List<Proveedor> GetProveedores(Proveedor filtro = null)
        {
            List<Proveedor> lista = new List<Proveedor>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROVEEDOR";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.prv_id > 0)
                            cmd.Parameters.AddWithValue("@ID", filtro.prv_id);

                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);

                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);

                        if (filtro.filtro_es_contratista != null)
                            cmd.Parameters.AddWithValue("@ES_CONTRATISTA", filtro.filtro_es_contratista);

                        if (filtro.filtro_es_proveedor_repuesto != null)
                            cmd.Parameters.AddWithValue("@ES_PROV_REPUESTO", filtro.filtro_es_proveedor_repuesto);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Proveedor item = new Proveedor();

                            item.prv_id = int.Parse(dr["prv_id"].ToString());
                            item.prv_cliente = int.Parse(dr["prv_cliente"].ToString());
                            item.prv_rut = dr["prv_rut"].ToString();
                            item.prv_razon_social = dr["prv_razon_social"].ToString();
                            item.prv_nombre_fantasia = dr["prv_nombre_fantasia"].ToString();
                            item.prv_giro = dr["prv_giro"].ToString();
                            item.prv_contacto = dr["prv_contacto"].ToString();
                            item.prv_email = dr["prv_email"].ToString();
                            item.prv_telefono = dr["prv_telefono"].ToString();
                            item.prv_direccion = dr["prv_direccion"].ToString();
                            item.prv_observacion = dr["prv_observacion"].ToString();

                            item.prv_es_contratista = bool.Parse(dr["prv_es_contratista"].ToString());
                            item.prv_es_proveedor_repuesto = bool.Parse(dr["prv_es_proveedor_repuesto"].ToString());
                            item.prv_habilitado = bool.Parse(dr["prv_habilitado"].ToString());

                            item.prv_usuario_creacion = int.Parse(dr["prv_usuario_creacion"].ToString());

                            if (dr["prv_fecha_creacion"] != DBNull.Value)
                                item.prv_fecha_creacion = DateTime.Parse(dr["prv_fecha_creacion"].ToString());

                            if (dr["prv_usuario_actualizacion"] != DBNull.Value)
                                item.prv_usuario_actualizacion = int.Parse(dr["prv_usuario_actualizacion"].ToString());

                            if (dr["prv_fecha_actualizacion"] != DBNull.Value)
                                item.prv_fecha_actualizacion = DateTime.Parse(dr["prv_fecha_actualizacion"].ToString());

                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

                            item.lotes = int.Parse(dr["LOTES"].ToString());
                            item.servicios = int.Parse(dr["SERVICIOS"].ToString());

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

        /// <summary>
        /// Uno solo. Devuelve un objeto vacio —no null— cuando no existe o no
        /// es de este cliente, para que la ficha se abra en blanco en vez de
        /// reventar con una referencia nula.
        /// </summary>
        public Proveedor GetProveedor(int id)
        {
            List<Proveedor> lista = GetProveedores(new Proveedor { prv_id = id });

            if (lista == null || lista.Count == 0) return new Proveedor();

            return lista[0];
        }

        /// <summary>
        /// Los servicios que prestó el proveedor, con los adjuntos de sus
        /// órdenes de trabajo.
        ///
        /// Vienen en dos resultados y se arman acá: los archivos son de la
        /// ORDEN, no de la línea de servicio, así que traerlos repetidos
        /// dentro de cada servicio sería traer el doble para mostrar lo mismo.
        /// Se agrupan por orden y se reparten.
        /// </summary>
        public List<ProveedorServicio> GetServicios(int idProveedor)
        {
            List<ProveedorServicio> lista = new List<ProveedorServicio>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_PROVEEDOR_SERVICIO");
                cmd.Parameters.AddWithValue("@PROVEEDOR", idProveedor);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                Dictionary<int, List<ProveedorAdjunto>> porOrden =
                    new Dictionary<int, List<ProveedorAdjunto>>();

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ProveedorServicio x = new ProveedorServicio();

                        x.ots_id = int.Parse(dr["ots_id"].ToString());
                        x.ots_orden_trabajo = int.Parse(dr["ots_orden_trabajo"].ToString());
                        x.OT_NUMERO = dr["OT_NUMERO"].ToString();
                        x.OT_TITULO = dr["OT_TITULO"].ToString();
                        x.OT_ESTADO = dr["OT_ESTADO"].ToString();
                        x.TIPO_NOMBRE = dr["TIPO_NOMBRE"].ToString();
                        x.ots_descripcion = dr["ots_descripcion"].ToString();

                        if (dr["ots_cantidad"] != DBNull.Value)
                            x.ots_cantidad = decimal.Parse(dr["ots_cantidad"].ToString());

                        if (dr["ots_monto_unitario"] != DBNull.Value)
                            x.ots_monto_unitario = decimal.Parse(dr["ots_monto_unitario"].ToString());

                        if (dr["ots_monto"] != DBNull.Value)
                            x.ots_monto = decimal.Parse(dr["ots_monto"].ToString());

                        x.MONEDA_NOMBRE = dr["MONEDA_NOMBRE"].ToString();
                        x.ots_documento_referencia = dr["ots_documento_referencia"].ToString();

                        if (dr["ots_fecha_servicio_utc"] != DBNull.Value)
                            x.ots_fecha_servicio_utc = DateTime.Parse(dr["ots_fecha_servicio_utc"].ToString());

                        if (dr["ots_fecha_documento"] != DBNull.Value)
                            x.ots_fecha_documento = DateTime.Parse(dr["ots_fecha_documento"].ToString());

                        x.ADJUNTOS = int.Parse(dr["ADJUNTOS"].ToString());
                        x.ADJUNTOS_RETENIDOS = int.Parse(dr["ADJUNTOS_RETENIDOS"].ToString());

                        lista.Add(x);
                    }

                    // ---- segundo resultado: los archivos ----
                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            ProveedorAdjunto a = new ProveedorAdjunto();

                            a.arc_id = int.Parse(dr["arc_id"].ToString());
                            a.avi_orden_trabajo = int.Parse(dr["avi_orden_trabajo"].ToString());
                            a.arc_nombre_original = dr["arc_nombre_original"].ToString();
                            a.arc_extension = dr["arc_extension"].ToString();
                            a.arc_mime = dr["arc_mime"].ToString();

                            if (dr["arc_byte"] != DBNull.Value)
                                a.arc_byte = long.Parse(dr["arc_byte"].ToString());

                            if (dr["arc_fecha_creacion"] != DBNull.Value)
                                a.arc_fecha_creacion = DateTime.Parse(dr["arc_fecha_creacion"].ToString());

                            a.CATEGORIA = dr["CATEGORIA"].ToString();
                            a.ANTIVIRUS = dr["ANTIVIRUS"].ToString();
                            a.avi_titulo = dr["avi_titulo"].ToString();

                            if (!porOrden.ContainsKey(a.avi_orden_trabajo))
                                porOrden[a.avi_orden_trabajo] = new List<ProveedorAdjunto>();

                            porOrden[a.avi_orden_trabajo].Add(a);
                        }
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                /* Cada servicio recibe los archivos de SU orden. Dos servicios
                   de la misma OT comparten la lista, que es justamente lo que
                   pasa en la realidad. */
                foreach (ProveedorServicio x in lista)
                    if (porOrden.ContainsKey(x.ots_orden_trabajo))
                        x.Adjuntos = porOrden[x.ots_orden_trabajo];
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            return lista;
        }

        public Respuesta InsertProveedor(Proveedor entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PROVEEDOR");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@RUT", (object)entidad.prv_rut ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@RAZON_SOCIAL", (object)entidad.prv_razon_social ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE_FANTASIA", Texto(entidad.prv_nombre_fantasia));
                    cmdExecute.Parameters.AddWithValue("@GIRO", Texto(entidad.prv_giro));
                    cmdExecute.Parameters.AddWithValue("@CONTACTO", Texto(entidad.prv_contacto));
                    cmdExecute.Parameters.AddWithValue("@EMAIL", Texto(entidad.prv_email));
                    cmdExecute.Parameters.AddWithValue("@TELEFONO", Texto(entidad.prv_telefono));
                    cmdExecute.Parameters.AddWithValue("@DIRECCION", Texto(entidad.prv_direccion));
                    cmdExecute.Parameters.AddWithValue("@ES_CONTRATISTA", entidad.prv_es_contratista);
                    cmdExecute.Parameters.AddWithValue("@ES_PROV_REPUESTO", entidad.prv_es_proveedor_repuesto);
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", Texto(entidad.prv_observacion));
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Proveedor creado con éxito.";
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

        public Respuesta UpdateProveedor(Proveedor entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PROVEEDOR");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.prv_id);
                    cmdExecute.Parameters.AddWithValue("@RUT", (object)entidad.prv_rut ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@RAZON_SOCIAL", (object)entidad.prv_razon_social ?? DBNull.Value);

                    /* Texto() manda cadena vacia y no NULL cuando el campo se
                       dejo en blanco: en el UPD_ los campos van con
                       ISNULL(@X, columna), asi que un NULL significa "no me
                       toques esto". Si se mandara NULL al borrar el telefono,
                       el telefono viejo se quedaria puesto y la pantalla
                       diria que se guardo. */
                    cmdExecute.Parameters.AddWithValue("@NOMBRE_FANTASIA", TextoVacio(entidad.prv_nombre_fantasia));
                    cmdExecute.Parameters.AddWithValue("@GIRO", TextoVacio(entidad.prv_giro));
                    cmdExecute.Parameters.AddWithValue("@CONTACTO", TextoVacio(entidad.prv_contacto));
                    cmdExecute.Parameters.AddWithValue("@EMAIL", TextoVacio(entidad.prv_email));
                    cmdExecute.Parameters.AddWithValue("@TELEFONO", TextoVacio(entidad.prv_telefono));
                    cmdExecute.Parameters.AddWithValue("@DIRECCION", TextoVacio(entidad.prv_direccion));
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", TextoVacio(entidad.prv_observacion));

                    cmdExecute.Parameters.AddWithValue("@ES_CONTRATISTA", entidad.prv_es_contratista);
                    cmdExecute.Parameters.AddWithValue("@ES_PROV_REPUESTO", entidad.prv_es_proveedor_repuesto);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.prv_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.prv_id;
                    respuesta.detalle = "Proveedor actualizado con éxito.";
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
        /// Baja logica. El SP rechaza con un mensaje que dice cuantos
        /// registros dependen del proveedor, en vez de dejar lotes apuntando
        /// a una empresa que ya no esta.
        /// </summary>
        public Respuesta DeleteProveedor(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PROVEEDOR");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = "Proveedor eliminado con éxito.";
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

        /// <summary>Vacio significa "no informado" en el alta.</summary>
        private object Texto(string valor)
        {
            if (string.IsNullOrEmpty(valor) || valor.Trim().Length == 0) return DBNull.Value;
            return valor.Trim();
        }

        /// <summary>
        /// Vacio significa "borralo" en la edicion, y por eso viaja como
        /// cadena vacia y no como NULL. Ver el comentario de UpdateProveedor.
        /// </summary>
        private object TextoVacio(string valor)
        {
            return valor == null ? (object)"" : valor.Trim();
        }
    }
}
