using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;

namespace SitioBase.Controller
{
    /// <summary>
    /// Permisos de trabajo (HU-063, bloque 94).
    ///
    /// TODO SE ACOTA POR CLIENTE, SIEMPRE
    ///   @CLIENTE sale de la sesion y no es opcional en ninguno de los SP.
    ///   GetPermiso(id) llama al mismo SEL_ con el cliente de la sesion: un
    ///   SP aparte "por id" seria el sitio donde algun dia se olvida el
    ///   filtro.
    ///
    /// EL ADJUNTO PASA POR ArchivoController
    ///   Subir el documento firmado no se hace aca: lo hace ArchivoController,
    ///   que ya sabe hablar con Almacenamiento y crear la fila de Archivo.
    ///   Este controlador solo guarda el id resultante en ptr_archivo.
    /// </summary>
    public class PermisoTrabajoController
    {
        /// <summary>La categoria con la que se guarda el documento firmado.</summary>
        public const int CATEGORIA_PERMISO_TRABAJO = 13;

        public List<PermisoTrabajo> GetPermisos(PermisoTrabajo filtro = null)
        {
            List<PermisoTrabajo> lista = new List<PermisoTrabajo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PERMISO_TRABAJO";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.ptr_id > 0)
                            cmd.Parameters.AddWithValue("@ID", filtro.ptr_id);

                        if (filtro.filtro_orden_trabajo > 0)
                            cmd.Parameters.AddWithValue("@ORDEN_TRABAJO", filtro.filtro_orden_trabajo);

                        if (filtro.filtro_tipo > 0)
                            cmd.Parameters.AddWithValue("@TIPO", filtro.filtro_tipo);

                        if (filtro.filtro_estado > 0)
                            cmd.Parameters.AddWithValue("@ESTADO", filtro.filtro_estado);

                        if (!string.IsNullOrEmpty(filtro.filtro_situacion))
                            cmd.Parameters.AddWithValue("@SITUACION", filtro.filtro_situacion);

                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);

                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PermisoTrabajo item = new PermisoTrabajo();

                            item.ptr_id = int.Parse(dr["ptr_id"].ToString());
                            item.ptr_cliente = int.Parse(dr["ptr_cliente"].ToString());

                            if (dr["ptr_orden_trabajo"] != DBNull.Value)
                                item.ptr_orden_trabajo = int.Parse(dr["ptr_orden_trabajo"].ToString());

                            item.ptr_permiso_trabajo_tipo = int.Parse(dr["ptr_permiso_trabajo_tipo"].ToString());
                            item.ptr_permiso_trabajo_estado = int.Parse(dr["ptr_permiso_trabajo_estado"].ToString());
                            item.ptr_numero = dr["ptr_numero"].ToString();

                            if (dr["ptr_usuario_solicitante"] != DBNull.Value)
                                item.ptr_usuario_solicitante = int.Parse(dr["ptr_usuario_solicitante"].ToString());

                            if (dr["ptr_fecha_solicitud_utc"] != DBNull.Value)
                                item.ptr_fecha_solicitud_utc = DateTime.Parse(dr["ptr_fecha_solicitud_utc"].ToString());

                            if (dr["ptr_fecha_vigencia_inicio_utc"] != DBNull.Value)
                                item.ptr_fecha_vigencia_inicio_utc = DateTime.Parse(dr["ptr_fecha_vigencia_inicio_utc"].ToString());

                            if (dr["ptr_fecha_vigencia_fin_utc"] != DBNull.Value)
                                item.ptr_fecha_vigencia_fin_utc = DateTime.Parse(dr["ptr_fecha_vigencia_fin_utc"].ToString());

                            item.ptr_observacion = dr["ptr_observacion"].ToString();

                            if (dr["ptr_archivo"] != DBNull.Value)
                                item.ptr_archivo = int.Parse(dr["ptr_archivo"].ToString());

                            item.ptr_habilitado = bool.Parse(dr["ptr_habilitado"].ToString());
                            item.ptr_usuario_creacion = int.Parse(dr["ptr_usuario_creacion"].ToString());

                            if (dr["ptr_fecha_creacion"] != DBNull.Value)
                                item.ptr_fecha_creacion = DateTime.Parse(dr["ptr_fecha_creacion"].ToString());

                            if (dr["ptr_usuario_actualizacion"] != DBNull.Value)
                                item.ptr_usuario_actualizacion = int.Parse(dr["ptr_usuario_actualizacion"].ToString());

                            if (dr["ptr_fecha_actualizacion"] != DBNull.Value)
                                item.ptr_fecha_actualizacion = DateTime.Parse(dr["ptr_fecha_actualizacion"].ToString());

                            if (dr["DIAS_RESTANTES"] != DBNull.Value)
                                item.dias_restantes = int.Parse(dr["DIAS_RESTANTES"].ToString());

                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.tipo_codigo = dr["TIPO_CODIGO"].ToString();
                            item.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            item.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                            item.solicitante_nombre = dr["SOLICITANTE_NOMBRE"].ToString();
                            item.solicitante_id = int.Parse(dr["SOLICITANTE_ID"].ToString());
                            item.solicitante_foto = int.Parse(dr["SOLICITANTE_FOTO"].ToString());
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            item.orden_correlativo = dr["ORDEN_CORRELATIVO"].ToString();
                            item.orden_titulo = dr["ORDEN_TITULO"].ToString();
                            item.archivo_nombre = dr["ARCHIVO_NOMBRE"].ToString();
                            item.archivo_byte = long.Parse(dr["ARCHIVO_BYTE"].ToString());
                            item.archivo_extension = dr["ARCHIVO_EXTENSION"].ToString();
                            item.situacion = dr["SITUACION"].ToString();

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
        public PermisoTrabajo GetPermiso(int id)
        {
            List<PermisoTrabajo> lista = GetPermisos(new PermisoTrabajo { ptr_id = id });

            if (lista == null || lista.Count == 0) return new PermisoTrabajo();

            return lista[0];
        }

        public Respuesta InsertPermiso(PermisoTrabajo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_PERMISO_TRABAJO");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@TIPO", entidad.ptr_permiso_trabajo_tipo);
                    cmdExecute.Parameters.AddWithValue("@ESTADO", Id(entidad.ptr_permiso_trabajo_estado));
                    cmdExecute.Parameters.AddWithValue("@NUMERO", Texto(entidad.ptr_numero));
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO", Id(entidad.ptr_orden_trabajo));
                    cmdExecute.Parameters.AddWithValue("@SOLICITANTE", Id(entidad.ptr_usuario_solicitante));
                    cmdExecute.Parameters.AddWithValue("@VIGENCIA_INICIO", Fecha(entidad.ptr_fecha_vigencia_inicio_utc));
                    cmdExecute.Parameters.AddWithValue("@VIGENCIA_FIN", Fecha(entidad.ptr_fecha_vigencia_fin_utc));
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", Texto(entidad.ptr_observacion));
                    cmdExecute.Parameters.AddWithValue("@ARCHIVO", Id(entidad.ptr_archivo));
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Permiso de trabajo registrado con éxito.";
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

        public Respuesta UpdatePermiso(PermisoTrabajo entidad, bool quitaOrden = false)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PERMISO_TRABAJO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.ptr_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@TIPO", entidad.ptr_permiso_trabajo_tipo);
                    cmdExecute.Parameters.AddWithValue("@ESTADO", Id(entidad.ptr_permiso_trabajo_estado));
                    cmdExecute.Parameters.AddWithValue("@NUMERO", Texto(entidad.ptr_numero));
                    cmdExecute.Parameters.AddWithValue("@ORDEN_TRABAJO", Id(entidad.ptr_orden_trabajo));
                    cmdExecute.Parameters.AddWithValue("@SOLICITANTE", Id(entidad.ptr_usuario_solicitante));
                    cmdExecute.Parameters.AddWithValue("@VIGENCIA_INICIO", Fecha(entidad.ptr_fecha_vigencia_inicio_utc));
                    cmdExecute.Parameters.AddWithValue("@VIGENCIA_FIN", Fecha(entidad.ptr_fecha_vigencia_fin_utc));

                    /* Cadena vacia y no NULL: en el UPD_ la observacion va con
                       ISNULL(@X, columna), asi que un NULL significa "no me
                       toques esto" y borrarla seria imposible. */
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION",
                        entidad.ptr_observacion == null ? (object)"" : entidad.ptr_observacion.Trim());

                    cmdExecute.Parameters.AddWithValue("@ARCHIVO", Id(entidad.ptr_archivo));
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", entidad.ptr_habilitado);
                    cmdExecute.Parameters.AddWithValue("@QUITA_ORDEN", quitaOrden);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.ptr_id;
                    respuesta.detalle = "Permiso de trabajo actualizado con éxito.";
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

        /// <summary>
        /// Lo que esta vigente y lo que esta por vencer (HU-064, bloque 97).
        ///
        /// El orden lo pone el SP: lo vencido primero y despues lo que menos
        /// dias le queda. Es el orden en que hay que atenderlos, no el del
        /// calendario.
        /// </summary>
        public List<PermisoVigente> GetVigentes(int diasAviso = 7, int tipo = 0,
                                                bool incluirVencidos = true,
                                                bool soloPorVencer = false,
                                                string filtro = null)
        {
            List<PermisoVigente> lista = new List<PermisoVigente>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PERMISO_TRABAJO_VIGENTE";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@DIAS_AVISO", diasAviso);
                    cmd.Parameters.AddWithValue("@INCLUIR_VENCIDOS", incluirVencidos);
                    cmd.Parameters.AddWithValue("@SOLO_POR_VENCER", soloPorVencer);

                    if (tipo > 0) cmd.Parameters.AddWithValue("@TIPO", tipo);
                    if (!string.IsNullOrEmpty(filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PermisoVigente item = new PermisoVigente();

                            item.ptr_id = int.Parse(dr["ptr_id"].ToString());
                            item.ptr_permiso_trabajo_tipo = int.Parse(dr["ptr_permiso_trabajo_tipo"].ToString());
                            item.ptr_numero = dr["ptr_numero"].ToString();

                            if (dr["ptr_fecha_vigencia_inicio_utc"] != DBNull.Value)
                                item.ptr_fecha_vigencia_inicio_utc = DateTime.Parse(dr["ptr_fecha_vigencia_inicio_utc"].ToString());

                            if (dr["ptr_fecha_vigencia_fin_utc"] != DBNull.Value)
                                item.ptr_fecha_vigencia_fin_utc = DateTime.Parse(dr["ptr_fecha_vigencia_fin_utc"].ToString());

                            if (dr["ptr_archivo"] != DBNull.Value)
                                item.ptr_archivo = int.Parse(dr["ptr_archivo"].ToString());

                            if (dr["DIAS_RESTANTES"] != DBNull.Value)
                                item.dias_restantes = int.Parse(dr["DIAS_RESTANTES"].ToString());

                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            item.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                            item.solicitante_nombre = dr["SOLICITANTE_NOMBRE"].ToString();
                            item.solicitante_id = int.Parse(dr["SOLICITANTE_ID"].ToString());
                            item.solicitante_foto = int.Parse(dr["SOLICITANTE_FOTO"].ToString());
                            item.archivo_nombre_vig = dr["ARCHIVO_NOMBRE"].ToString();
                            item.archivo_extension_vig = dr["ARCHIVO_EXTENSION"].ToString();
                            item.archivo_mime = dr["ARCHIVO_MIME"].ToString();
                            item.archivo_byte_vig = long.Parse(dr["ARCHIVO_BYTE"].ToString());
                            item.orden_correlativo = dr["ORDEN_CORRELATIVO"].ToString();
                            item.orden_titulo = dr["ORDEN_TITULO"].ToString();
                            item.instalacion_nombre = dr["INSTALACION_NOMBRE"].ToString();
                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.situacion = dr["SITUACION"].ToString();

                            item.tiene_documento = (dr["TIENE_DOCUMENTO"].ToString() == "1"
                                                 || dr["TIENE_DOCUMENTO"].ToString() == "True");

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
        /// Baja a Excel lo que la pantalla esta mostrando.
        ///
        /// Se arma desde la MISMA lista que se pinto, no con otra consulta:
        /// un segundo viaje con los mismos filtros puede devolver algo
        /// distinto —alguien registro un permiso entre medio— y entonces el
        /// archivo no coincidiria con la pantalla desde la que se pidio.
        /// </summary>
        public void ExportarVigentes(List<PermisoVigente> lista)
        {
            DataTable t = new DataTable();

            t.Columns.Add("SITUACION");
            t.Columns.Add("DIAS", typeof(int));
            t.Columns.Add("TIPO");
            t.Columns.Add("FOLIO");
            t.Columns.Add("ESTADO");
            t.Columns.Add("SOLICITANTE");
            t.Columns.Add("ORDEN");
            t.Columns.Add("VIGENTE_DESDE");
            t.Columns.Add("VIGENTE_HASTA");
            t.Columns.Add("DOCUMENTO");

            if (lista != null)
            {
                foreach (PermisoVigente p in lista)
                {
                    DataRow f = t.NewRow();

                    f["SITUACION"] = p.situacion;
                    f["DIAS"] = (object)p.dias_restantes ?? DBNull.Value;
                    f["TIPO"] = p.tipo_nombre;
                    f["FOLIO"] = p.ptr_numero;
                    f["ESTADO"] = p.estado_nombre;
                    f["SOLICITANTE"] = p.solicitante_nombre;
                    f["ORDEN"] = p.orden_correlativo;

                    f["VIGENTE_DESDE"] = p.ptr_fecha_vigencia_inicio_utc == null
                        ? "" : p.ptr_fecha_vigencia_inicio_utc.Value.ToString("dd-MM-yyyy");

                    f["VIGENTE_HASTA"] = p.ptr_fecha_vigencia_fin_utc == null
                        ? "" : p.ptr_fecha_vigencia_fin_utc.Value.ToString("dd-MM-yyyy");

                    /* "Sí"/"No" y no true/false: el archivo lo abre una
                       persona, no un programa. */
                    f["DOCUMENTO"] = p.tiene_documento ? "Sí" : "No";

                    t.Rows.Add(f);
                }
            }

            byte[] binario = Tools.Excel.exportExcelXLSX_Bytes(t, true);

            string archivo = "PERMISOS VIGENTES " + DateTime.Now.ToString("dd-MM-yyyy");

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.AddHeader("content-disposition",
                                                   "attachment; filename=" + archivo + ".xlsx");
            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }

        /// <summary>Los tipos, para el combo.</summary>
        public List<PermisoTrabajoTipo> GetTipos()
        {
            List<PermisoTrabajoTipo> lista = new List<PermisoTrabajoTipo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PERMISO_TRABAJO_TIPO";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PermisoTrabajoTipo item = new PermisoTrabajoTipo();
                            item.ptt_id = int.Parse(dr["PTT_ID"].ToString());
                            item.ptt_codigo = dr["PTT_CODIGO"].ToString();
                            item.ptt_nombre = dr["PTT_NOMBRE"].ToString();
                            item.ptt_orden = int.Parse(dr["PTT_ORDEN"].ToString());
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

        /// <summary>Los estados, para el combo.</summary>
        public List<PermisoTrabajoEstado> GetEstados()
        {
            List<PermisoTrabajoEstado> lista = new List<PermisoTrabajoEstado>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PERMISO_TRABAJO_ESTADO";

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PermisoTrabajoEstado item = new PermisoTrabajoEstado();
                            item.pte_id = int.Parse(dr["PTE_ID"].ToString());
                            item.pte_codigo = dr["PTE_CODIGO"].ToString();
                            item.pte_nombre = dr["PTE_NOMBRE"].ToString();
                            item.pte_orden = int.Parse(dr["PTE_ORDEN"].ToString());
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

        private object Id(int? valor)
        {
            return (valor == null || valor.Value <= 0) ? (object)DBNull.Value : valor.Value;
        }

        private object Fecha(DateTime? valor)
        {
            return valor == null ? (object)DBNull.Value : valor.Value;
        }

        private object Texto(string valor)
        {
            if (string.IsNullOrEmpty(valor) || valor.Trim().Length == 0) return DBNull.Value;
            return valor.Trim();
        }
    }
}
