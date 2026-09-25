using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Categorías de tarea del cliente (HU-100). Un solo SEL sirve al listado y
    /// a la ficha; las reglas (código único por cliente, dependientes) viven en
    /// los SP. Todo acotado al cliente en sesión.
    /// </summary>
    public class TareaCategoriaController
    {
        public List<TareaCategoria> GetTareaCategorias(TareaCategoria filtro = null)
        {
            List<TareaCategoria> lista = new List<TareaCategoria>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TAREA_CATEGORIA";
                    if (filtro != null)
                    {
                        if (filtro.tca_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.tca_id);
                        if (filtro.tca_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.tca_cliente);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            TareaCategoria item = new TareaCategoria();
                            item.tca_id = int.Parse(dr["TCA_ID"].ToString());
                            item.tca_cliente = int.Parse(dr["TCA_CLIENTE"].ToString());
                            item.tca_codigo = dr["TCA_CODIGO"].ToString();
                            item.tca_nombre = dr["TCA_NOMBRE"].ToString();
                            item.tca_color = dr["TCA_COLOR"].ToString();
                            if (dr["TCA_ORDEN"] != DBNull.Value) item.tca_orden = int.Parse(dr["TCA_ORDEN"].ToString());
                            item.tca_habilitado = bool.Parse(dr["TCA_HABILITADO"].ToString());
                            if (dr["TCA_FECHA_CREACION"] != DBNull.Value) item.tca_fecha_creacion = DateTime.Parse(dr["TCA_FECHA_CREACION"].ToString());
                            if (dr["TCA_FECHA_ACTUALIZACION"] != DBNull.Value) item.tca_fecha_actualizacion = DateTime.Parse(dr["TCA_FECHA_ACTUALIZACION"].ToString());
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

        public TareaCategoria GetTareaCategoria(int id)
        {
            List<TareaCategoria> lista = GetTareaCategorias(new TareaCategoria { tca_id = id });
            return (lista != null && lista.Count > 0) ? lista[0] : new TareaCategoria();
        }

        public Respuesta InsertTareaCategoria(TareaCategoria entidad)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("INS_TAREA_CATEGORIA");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", entidad.tca_cliente);
                    cmd.Parameters.AddWithValue("@CODIGO", entidad.tca_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", entidad.tca_nombre);
                    cmd.Parameters.AddWithValue("@COLOR", (object)entidad.tca_color ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ORDEN", (object)entidad.tca_orden ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = (int)cmd.Parameters["@ID"].Value;
                    r.detalle = "Categoría creada con éxito.";
                    r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else { r.codigo = -1; r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion."; r.error = true; }
            return r;
        }

        public Respuesta UpdateTareaCategoria(TareaCategoria entidad)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_TAREA_CATEGORIA");
                    cmd.Parameters.AddWithValue("@ID", entidad.tca_id);
                    cmd.Parameters.AddWithValue("@CODIGO", entidad.tca_codigo);
                    cmd.Parameters.AddWithValue("@NOMBRE", entidad.tca_nombre);
                    cmd.Parameters.AddWithValue("@COLOR", (object)entidad.tca_color ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ORDEN", (object)entidad.tca_orden ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", entidad.tca_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = entidad.tca_id;
                    r.detalle = "Categoría actualizada con éxito.";
                    r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else { r.codigo = -1; r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion."; r.error = true; }
            return r;
        }

        public Respuesta DeleteTareaCategoria(TareaCategoria entidad)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_TAREA_CATEGORIA");
                    cmd.Parameters.AddWithValue("@ID", entidad.tca_id);
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = entidad.tca_id;
                    r.detalle = "Categoría dada de baja con éxito.";
                    r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else { r.codigo = -1; r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion."; r.error = true; }
            return r;
        }
    }
}
