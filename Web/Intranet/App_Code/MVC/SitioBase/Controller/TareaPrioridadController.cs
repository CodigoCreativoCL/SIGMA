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
    /// CONTROLLER de la entidad TAREA_PRIORIDAD.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 3):
    ///  1. Namespace SitioBase.Controller. Una clase por entidad.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()).
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        SEL_TAREA_PRIORIDAD  INS_TAREA_PRIORIDAD  UPD_TAREA_PRIORIDAD  DEL_TAREA_PRIORIDAD
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta.
    ///  6. try/catch en todos los metodos, cerrando la conexion en AMBOS caminos.
    ///  7. Los parametros de filtro se agregan SOLO si vienen informados.
    ///
    /// ARCHIVO GENERADO por 03-Generador.
    /// </summary>
    public class TareaPrioridadController
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<TareaPrioridad> GetTareaPrioridads(TareaPrioridad tareaprioridad = null)
        {
            List<TareaPrioridad> tareaprioridads = new List<TareaPrioridad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA_PRIORIDAD";

                    // Cada filtro se agrega SOLO si viene informado. Lo que no se
                    // agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if (tareaprioridad != null)
                    {
                        if (tareaprioridad.tpa_id > 0)
                            cmd.Parameters.AddWithValue("@ID", tareaprioridad.tpa_id);

                        if (!string.IsNullOrEmpty(tareaprioridad.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", tareaprioridad.filtro);

                        if (tareaprioridad.filtro_habilitado.HasValue)
                            cmd.Parameters.AddWithValue("@HABILITADO", tareaprioridad.filtro_habilitado.Value);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            TareaPrioridad item = new TareaPrioridad();

                            item.tpa_id = int.Parse(dr["TPA_ID"].ToString());
                            item.tpa_codigo = dr["TPA_CODIGO"].ToString();
                            item.tpa_nombre = dr["TPA_NOMBRE"].ToString();
                            item.tpa_orden = int.Parse(dr["TPA_ORDEN"].ToString());
                            item.tpa_habilitado = bool.Parse(dr["TPA_HABILITADO"].ToString());

                            tareaprioridads.Add(item);
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
                    tareaprioridads = null;
                }
            }

            return tareaprioridads;
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP SEL_TAREA_PRIORIDAD pasandole @ID.
        /// </summary>
        public TareaPrioridad GetTareaPrioridad(TareaPrioridad tareaprioridad)
        {
            TareaPrioridad item = new TareaPrioridad();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA_PRIORIDAD";
                    cmd.Parameters.AddWithValue("@ID", tareaprioridad.tpa_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item.tpa_id = int.Parse(dr["TPA_ID"].ToString());
                            item.tpa_codigo = dr["TPA_CODIGO"].ToString();
                            item.tpa_nombre = dr["TPA_NOMBRE"].ToString();
                            item.tpa_orden = int.Parse(dr["TPA_ORDEN"].ToString());
                            item.tpa_habilitado = bool.Parse(dr["TPA_HABILITADO"].ToString());
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
        /// ALTA. El SP INS_TAREA_PRIORIDAD devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
        public Respuesta InsertTareaPrioridad(TareaPrioridad tareaprioridad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_TAREA_PRIORIDAD");

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

                    cmdExecute.Parameters.AddWithValue("@CODIGO", tareaprioridad.tpa_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", tareaprioridad.tpa_nombre);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", tareaprioridad.tpa_orden);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", tareaprioridad.tpa_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "TareaPrioridad creada con exito.";
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
        public Respuesta UpdateTareaPrioridad(TareaPrioridad tareaprioridad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_TAREA_PRIORIDAD");

                    cmdExecute.Parameters.AddWithValue("@ID", tareaprioridad.tpa_id);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", tareaprioridad.tpa_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", tareaprioridad.tpa_nombre);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", tareaprioridad.tpa_orden);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", tareaprioridad.tpa_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tareaprioridad.tpa_id;
                    respuesta.detalle = "TareaPrioridad actualizada con exito.";
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
        /// BAJA. TAREA_PRIORIDAD es una tabla MAESTRO: el patron pide baja LOGICA
        /// (UPD_TAREA_PRIORIDAD con @HABILITADO = 0), no DELETE fisico.
        /// DEL_TAREA_PRIORIDAD existe solo para casos excepcionales.
        /// </summary>
        public Respuesta DeleteTareaPrioridad(TareaPrioridad tareaprioridad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_TAREA_PRIORIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", tareaprioridad.tpa_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tareaprioridad.tpa_id;
                    respuesta.detalle = "TareaPrioridad eliminada con exito.";
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
        /// Reutiliza UPD_TAREA_PRIORIDAD en vez de crear un SP nuevo.
        /// </summary>
        public Respuesta DeshabilitarTareaPrioridad(TareaPrioridad tareaprioridad)
        {
            tareaprioridad.tpa_habilitado = false;
            Respuesta respuesta = UpdateTareaPrioridad(tareaprioridad);

            if (!respuesta.error)
                respuesta.detalle = "TareaPrioridad deshabilitada con exito.";

            return respuesta;
        }

        #endregion
    }
}
