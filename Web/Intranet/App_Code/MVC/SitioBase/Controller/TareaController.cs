using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>
    /// CONTROLLER de la entidad TAREA.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 3):
    ///  1. Namespace SitioBase.Controller. Una clase por entidad.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()).
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        SEL_TAREA  INS_TAREA  UPD_TAREA  DEL_TAREA
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta.
    ///  6. try/catch en todos los metodos, cerrando la conexion en AMBOS caminos.
    ///  7. Los parametros de filtro se agregan SOLO si vienen informados.
    ///
    /// ARCHIVO GENERADO por 03-Generador.
    /// </summary>
    public class TareaController
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<Tarea> GetTareas(Tarea tarea = null)
        {
            List<Tarea> tareas = new List<Tarea>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA";

                    // Cada filtro se agrega SOLO si viene informado. Lo que no se
                    // agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if (tarea != null)
                    {
                        if (tarea.tar_id > 0)
                            cmd.Parameters.AddWithValue("@ID", tarea.tar_id);

                        if (!string.IsNullOrEmpty(tarea.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", tarea.filtro);

                        if (tarea.filtro_habilitado.HasValue)
                            cmd.Parameters.AddWithValue("@HABILITADO", tarea.filtro_habilitado.Value);

                        if (tarea.filtro_tarea_prioridad.HasValue && tarea.filtro_tarea_prioridad.Value > 0)
                            cmd.Parameters.AddWithValue("@TAREA_PRIORIDAD", tarea.filtro_tarea_prioridad.Value);

                        if (tarea.filtro_tarea_categoria.HasValue && tarea.filtro_tarea_categoria.Value > 0)
                            cmd.Parameters.AddWithValue("@TAREA_CATEGORIA", tarea.filtro_tarea_categoria.Value);

                        if (tarea.filtro_cliente_instalacion.HasValue && tarea.filtro_cliente_instalacion.Value > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE_INSTALACION", tarea.filtro_cliente_instalacion.Value);

                        if (tarea.filtro_instalacion_area.HasValue && tarea.filtro_instalacion_area.Value > 0)
                            cmd.Parameters.AddWithValue("@INSTALACION_AREA", tarea.filtro_instalacion_area.Value);

                        if (tarea.filtro_activo.HasValue && tarea.filtro_activo.Value > 0)
                            cmd.Parameters.AddWithValue("@ACTIVO", tarea.filtro_activo.Value);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Tarea item = new Tarea();

                            item.tar_id = int.Parse(dr["TAR_ID"].ToString());
                            item.tar_codigo = dr["TAR_CODIGO"].ToString();
                            item.tar_titulo = dr["TAR_TITULO"].ToString();
                            item.tar_descripcion = dr["TAR_DESCRIPCION"].ToString();
                            item.tar_tarea_prioridad = int.Parse(dr["TAR_TAREA_PRIORIDAD"].ToString());
                            // FK opcionales: en la BD son NULL cuando la ficha se
                            // guarda sin categoria / instalacion / area / activo.
                            // Se leen con guarda DBNull (patron del proyecto): sin
                            // esto int.Parse("") revienta y GetTareas devuelve null,
                            // dejando la grilla vacia aunque existan tareas.
                            if (dr["TAR_TAREA_CATEGORIA"] != DBNull.Value)
                                item.tar_tarea_categoria = int.Parse(dr["TAR_TAREA_CATEGORIA"].ToString());
                            if (dr["TAR_CLIENTE_INSTALACION"] != DBNull.Value)
                                item.tar_cliente_instalacion = int.Parse(dr["TAR_CLIENTE_INSTALACION"].ToString());
                            if (dr["TAR_INSTALACION_AREA"] != DBNull.Value)
                                item.tar_instalacion_area = int.Parse(dr["TAR_INSTALACION_AREA"].ToString());
                            if (dr["TAR_ACTIVO"] != DBNull.Value)
                                item.tar_activo = int.Parse(dr["TAR_ACTIVO"].ToString());
                            if (dr["TAR_DURACION_ESTIMADA_MINUTO"] != DBNull.Value)
                                item.tar_duracion_estimada_minuto = int.Parse(dr["TAR_DURACION_ESTIMADA_MINUTO"].ToString());
                            item.tar_requiere_evidencia = bool.Parse(dr["TAR_REQUIERE_EVIDENCIA"].ToString());
                            item.tar_habilitado = bool.Parse(dr["TAR_HABILITADO"].ToString());

                            // Campos del JOIN: se muestran en el grid.
                            // OJO: los alias del SP SEL_TAREA no siguen el prefijo
                            // de tabla (son PRIORIDAD_/CATEGORIA_/PLANTA_/AREA_/
                            // ACTIVO_NOMBRE). Leer por el nombre del prefijo hacia
                            // dr[...] lanza excepcion y GetTareas devuelve null,
                            // dejando la grilla vacia. Se lee por el alias real.
                            item.tpa_nombre = dr["PRIORIDAD_NOMBRE"].ToString();
                            item.tca_nombre = dr["CATEGORIA_NOMBRE"].ToString();
                            item.cin_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.iar_nombre = dr["AREA_NOMBRE"].ToString();
                            item.act_nombre = dr["ACTIVO_NOMBRE"].ToString();

                            tareas.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    // En los Get devolvemos null para que la vista distinga
                    // "error" de "lista vacia".
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    tareas = null;
                }
            }

            return tareas;
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP SEL_TAREA pasandole @ID.
        /// </summary>
        public Tarea GetTarea(Tarea tarea)
        {
            Tarea item = new Tarea();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA";
                    cmd.Parameters.AddWithValue("@ID", tarea.tar_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item.tar_id = int.Parse(dr["TAR_ID"].ToString());
                            item.tar_codigo = dr["TAR_CODIGO"].ToString();
                            item.tar_titulo = dr["TAR_TITULO"].ToString();
                            item.tar_descripcion = dr["TAR_DESCRIPCION"].ToString();
                            item.tar_tarea_prioridad = int.Parse(dr["TAR_TAREA_PRIORIDAD"].ToString());
                            // FK opcionales: en la BD son NULL cuando la ficha se
                            // guarda sin categoria / instalacion / area / activo.
                            // Se leen con guarda DBNull (patron del proyecto): sin
                            // esto int.Parse("") revienta y GetTareas devuelve null,
                            // dejando la grilla vacia aunque existan tareas.
                            if (dr["TAR_TAREA_CATEGORIA"] != DBNull.Value)
                                item.tar_tarea_categoria = int.Parse(dr["TAR_TAREA_CATEGORIA"].ToString());
                            if (dr["TAR_CLIENTE_INSTALACION"] != DBNull.Value)
                                item.tar_cliente_instalacion = int.Parse(dr["TAR_CLIENTE_INSTALACION"].ToString());
                            if (dr["TAR_INSTALACION_AREA"] != DBNull.Value)
                                item.tar_instalacion_area = int.Parse(dr["TAR_INSTALACION_AREA"].ToString());
                            if (dr["TAR_ACTIVO"] != DBNull.Value)
                                item.tar_activo = int.Parse(dr["TAR_ACTIVO"].ToString());
                            if (dr["TAR_DURACION_ESTIMADA_MINUTO"] != DBNull.Value)
                                item.tar_duracion_estimada_minuto = int.Parse(dr["TAR_DURACION_ESTIMADA_MINUTO"].ToString());
                            item.tar_requiere_evidencia = bool.Parse(dr["TAR_REQUIERE_EVIDENCIA"].ToString());
                            item.tar_habilitado = bool.Parse(dr["TAR_HABILITADO"].ToString());

                            // Campos del JOIN: se muestran en el grid.
                            // OJO: los alias del SP SEL_TAREA no siguen el prefijo
                            // de tabla (son PRIORIDAD_/CATEGORIA_/PLANTA_/AREA_/
                            // ACTIVO_NOMBRE). Leer por el nombre del prefijo hacia
                            // dr[...] lanza excepcion y GetTareas devuelve null,
                            // dejando la grilla vacia. Se lee por el alias real.
                            item.tpa_nombre = dr["PRIORIDAD_NOMBRE"].ToString();
                            item.tca_nombre = dr["CATEGORIA_NOMBRE"].ToString();
                            item.cin_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.iar_nombre = dr["AREA_NOMBRE"].ToString();
                            item.act_nombre = dr["ACTIVO_NOMBRE"].ToString();
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    item = null;
                }
            }

            return item;
        }

        #endregion

        #region ESCRITURA

        /// <summary>
        /// ALTA. El SP INS_TAREA devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
        public Respuesta InsertTarea(Tarea tarea)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_TAREA");

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

                    // @CLIENTE es OBLIGATORIO en INS_TAREA y NUNCA lo manda la pantalla:
                    // el multicliente se resuelve con el cliente activo de la sesion.
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    cmdExecute.Parameters.AddWithValue("@CODIGO", (object)tarea.tar_codigo ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@TITULO", tarea.tar_titulo);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)tarea.tar_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@TAREA_PRIORIDAD", tarea.tar_tarea_prioridad);
                    cmdExecute.Parameters.AddWithValue("@TAREA_CATEGORIA", tarea.tar_tarea_categoria > 0 ? (object)tarea.tar_tarea_categoria : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", tarea.tar_cliente_instalacion > 0 ? (object)tarea.tar_cliente_instalacion : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA", tarea.tar_instalacion_area > 0 ? (object)tarea.tar_instalacion_area : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO", tarea.tar_activo > 0 ? (object)tarea.tar_activo : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", tarea.tar_duracion_estimada_minuto > 0 ? (object)tarea.tar_duracion_estimada_minuto : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", tarea.tar_requiere_evidencia);
                    // INS_TAREA NO recibe @HABILITADO: el alta siempre entra habilitada.

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Tarea creada con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    // ex.Message trae el texto del RAISERROR del SP.
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// MODIFICACION. Mismo patron que el alta pero con @ID de entrada.
        /// </summary>
        public Respuesta UpdateTarea(Tarea tarea)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_TAREA");

                    cmdExecute.Parameters.AddWithValue("@ID", tarea.tar_id);
                    // UPD_TAREA NO recibe @CODIGO: el codigo es inmutable tras el alta.
                    cmdExecute.Parameters.AddWithValue("@TITULO", tarea.tar_titulo);
                    cmdExecute.Parameters.AddWithValue("@TAREA_PRIORIDAD", tarea.tar_tarea_prioridad);
                    cmdExecute.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", tarea.tar_requiere_evidencia);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", tarea.tar_habilitado);

                    // Campos OPCIONALES. UPD_TAREA conserva con ISNULL(@X, actual):
                    // enviar NULL NO vacia el dato guardado. Para vaciarlo hay que
                    // activar su flag @QUITA_X. Como la ficha refleja el estado
                    // completo deseado, un control vacio significa "quitar".
                    bool quitaCategoria = !(tarea.tar_tarea_categoria > 0);
                    bool quitaInstalacion = !(tarea.tar_cliente_instalacion > 0);
                    bool quitaArea = !(tarea.tar_instalacion_area > 0);
                    bool quitaActivo = !(tarea.tar_activo > 0);
                    bool quitaDuracion = !(tarea.tar_duracion_estimada_minuto > 0);
                    bool quitaDescripcion = string.IsNullOrEmpty(tarea.tar_descripcion);

                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", quitaDescripcion ? DBNull.Value : (object)tarea.tar_descripcion);
                    cmdExecute.Parameters.AddWithValue("@TAREA_CATEGORIA", quitaCategoria ? DBNull.Value : (object)tarea.tar_tarea_categoria);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE_INSTALACION", quitaInstalacion ? DBNull.Value : (object)tarea.tar_cliente_instalacion);
                    cmdExecute.Parameters.AddWithValue("@INSTALACION_AREA", quitaArea ? DBNull.Value : (object)tarea.tar_instalacion_area);
                    cmdExecute.Parameters.AddWithValue("@ACTIVO", quitaActivo ? DBNull.Value : (object)tarea.tar_activo);
                    cmdExecute.Parameters.AddWithValue("@DURACION_ESTIMADA_MINUTO", quitaDuracion ? DBNull.Value : (object)tarea.tar_duracion_estimada_minuto);

                    cmdExecute.Parameters.AddWithValue("@QUITA_CATEGORIA", quitaCategoria);
                    cmdExecute.Parameters.AddWithValue("@QUITA_INSTALACION", quitaInstalacion);
                    cmdExecute.Parameters.AddWithValue("@QUITA_AREA", quitaArea);
                    cmdExecute.Parameters.AddWithValue("@QUITA_ACTIVO", quitaActivo);
                    cmdExecute.Parameters.AddWithValue("@QUITA_DURACION", quitaDuracion);
                    cmdExecute.Parameters.AddWithValue("@QUITA_DESCRIPCION", quitaDescripcion);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tarea.tar_id;
                    respuesta.detalle = "Tarea actualizada con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// BAJA. TAREA es una tabla MAESTRO: el patron pide baja LOGICA
        /// (UPD_TAREA con @HABILITADO = 0), no DELETE fisico.
        /// DEL_TAREA existe solo para casos excepcionales.
        /// </summary>
        public Respuesta DeleteTarea(Tarea tarea)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_TAREA");
                    cmdExecute.Parameters.AddWithValue("@ID", tarea.tar_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tarea.tar_id;
                    respuesta.detalle = "Tarea eliminada con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// BAJA LOGICA: la que realmente usa el boton "Deshabilitar" del grid.
        /// Reutiliza UPD_TAREA en vez de crear un SP nuevo.
        ///
        /// NO se enruta por UpdateTarea: el grid solo aporta el tar_id, asi que
        /// la prioridad llegaria en 0 (rompe la validacion del SP) y los @QUITA_*
        /// vaciarian planta/area/equipo/categoria. UPD_TAREA conserva con ISNULL
        /// todo lo que no se manda, de modo que basta tocar @HABILITADO.
        /// </summary>
        public Respuesta DeshabilitarTarea(Tarea tarea)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_TAREA");
                    cmdExecute.Parameters.AddWithValue("@ID", tarea.tar_id);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", false);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tarea.tar_id;
                    respuesta.detalle = "Tarea deshabilitada con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        #endregion
    }
}
