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
    /// CONTROLLER de la entidad TAREA_CATEGORIA.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 3):
    ///  1. Namespace SitioBase.Controller. Una clase por entidad.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()).
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        SEL_TAREA_CATEGORIA  INS_TAREA_CATEGORIA  UPD_TAREA_CATEGORIA  DEL_TAREA_CATEGORIA
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta.
    ///  6. try/catch en todos los metodos, cerrando la conexion en AMBOS caminos.
    ///  7. Los parametros de filtro se agregan SOLO si vienen informados.
    ///
    /// ARCHIVO GENERADO por 03-Generador.
    /// </summary>
    public class TareaCategoriaController
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<TareaCategoria> GetTareaCategorias(TareaCategoria tareacategoria = null)
        {
            List<TareaCategoria> tareacategorias = new List<TareaCategoria>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA_CATEGORIA";

                    // Cada filtro se agrega SOLO si viene informado. Lo que no se
                    // agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if (tareacategoria != null)
                    {
                        if (tareacategoria.tca_id > 0)
                            cmd.Parameters.AddWithValue("@ID", tareacategoria.tca_id);

                        if (!string.IsNullOrEmpty(tareacategoria.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", tareacategoria.filtro);

                        if (tareacategoria.filtro_habilitado.HasValue)
                            cmd.Parameters.AddWithValue("@HABILITADO", tareacategoria.filtro_habilitado.Value);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            TareaCategoria item = new TareaCategoria();

                            item.tca_id = int.Parse(dr["TCA_ID"].ToString());
                            item.tca_codigo = dr["TCA_CODIGO"].ToString();
                            item.tca_nombre = dr["TCA_NOMBRE"].ToString();
                            item.tca_color = dr["TCA_COLOR"].ToString();
                            item.tca_orden = int.Parse(dr["TCA_ORDEN"].ToString());
                            item.tca_habilitado = bool.Parse(dr["TCA_HABILITADO"].ToString());

                            tareacategorias.Add(item);
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
                    tareacategorias = null;
                }
            }

            return tareacategorias;
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP SEL_TAREA_CATEGORIA pasandole @ID.
        /// </summary>
        public TareaCategoria GetTareaCategoria(TareaCategoria tareacategoria)
        {
            TareaCategoria item = new TareaCategoria();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA_CATEGORIA";
                    cmd.Parameters.AddWithValue("@ID", tareacategoria.tca_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item.tca_id = int.Parse(dr["TCA_ID"].ToString());
                            item.tca_codigo = dr["TCA_CODIGO"].ToString();
                            item.tca_nombre = dr["TCA_NOMBRE"].ToString();
                            item.tca_color = dr["TCA_COLOR"].ToString();
                            item.tca_orden = int.Parse(dr["TCA_ORDEN"].ToString());
                            item.tca_habilitado = bool.Parse(dr["TCA_HABILITADO"].ToString());
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
        /// ALTA. El SP INS_TAREA_CATEGORIA devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
        public Respuesta InsertTareaCategoria(TareaCategoria tareacategoria)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_TAREA_CATEGORIA");

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

                    cmdExecute.Parameters.AddWithValue("@CODIGO", tareacategoria.tca_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", tareacategoria.tca_nombre);
                    cmdExecute.Parameters.AddWithValue("@COLOR", (object)tareacategoria.tca_color ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", tareacategoria.tca_orden);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", tareacategoria.tca_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "TareaCategoria creada con exito.";
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
        public Respuesta UpdateTareaCategoria(TareaCategoria tareacategoria)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_TAREA_CATEGORIA");

                    cmdExecute.Parameters.AddWithValue("@ID", tareacategoria.tca_id);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", tareacategoria.tca_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", tareacategoria.tca_nombre);
                    cmdExecute.Parameters.AddWithValue("@COLOR", (object)tareacategoria.tca_color ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", tareacategoria.tca_orden);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", tareacategoria.tca_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tareacategoria.tca_id;
                    respuesta.detalle = "TareaCategoria actualizada con exito.";
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
        /// BAJA. TAREA_CATEGORIA es una tabla MAESTRO: el patron pide baja LOGICA
        /// (UPD_TAREA_CATEGORIA con @HABILITADO = 0), no DELETE fisico.
        /// DEL_TAREA_CATEGORIA existe solo para casos excepcionales.
        /// </summary>
        public Respuesta DeleteTareaCategoria(TareaCategoria tareacategoria)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_TAREA_CATEGORIA");
                    cmdExecute.Parameters.AddWithValue("@ID", tareacategoria.tca_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = tareacategoria.tca_id;
                    respuesta.detalle = "TareaCategoria eliminada con exito.";
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
        /// Reutiliza UPD_TAREA_CATEGORIA en vez de crear un SP nuevo.
        /// </summary>
        public Respuesta DeshabilitarTareaCategoria(TareaCategoria tareacategoria)
        {
            tareacategoria.tca_habilitado = false;
            Respuesta respuesta = UpdateTareaCategoria(tareacategoria);

            if (!respuesta.error)
                respuesta.detalle = "TareaCategoria deshabilitada con exito.";

            return respuesta;
        }

        #endregion
    }
}
