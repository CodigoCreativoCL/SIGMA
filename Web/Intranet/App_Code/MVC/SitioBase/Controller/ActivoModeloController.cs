using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Modelos de activo del cliente (HU-031). El SEL trae los del cliente MAS
    /// los globales; INS/UPD/DEL solo tocan los del cliente (el SP rechaza los
    /// globales). La seguridad de datos la hace el filtro por cliente y el SP.
    /// </summary>
    public class ActivoModeloController
    {
        public List<ActivoModelo> GetModelos(ActivoModelo filtro = null)
        {
            List<ActivoModelo> lista = new List<ActivoModelo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ACTIVO_MODELO";

                    // @CLIENTE es obligatorio en el SEL: siempre el de la sesión.
                    int cliente = (filtro != null && filtro.filtro_cliente > 0) ? filtro.filtro_cliente : Session.ClienteId();
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    if (filtro != null)
                    {
                        if (filtro.amo_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.amo_id);
                        if (filtro.filtro_activo_tipo > 0) cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoModelo i = new ActivoModelo();
                            i.amo_id = int.Parse(dr["AMO_ID"].ToString());
                            if (dr["AMO_CLIENTE"] != DBNull.Value) i.amo_cliente = int.Parse(dr["AMO_CLIENTE"].ToString());
                            i.amo_activo_tipo = int.Parse(dr["AMO_ACTIVO_TIPO"].ToString());
                            i.amo_fabricante = dr["AMO_FABRICANTE"].ToString();
                            i.amo_nombre = dr["AMO_NOMBRE"].ToString();
                            i.amo_descripcion = dr["AMO_DESCRIPCION"].ToString();
                            i.amo_habilitado = bool.Parse(dr["AMO_HABILITADO"].ToString());
                            i.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            i.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            i.etiqueta = dr["ETIQUETA"].ToString();
                            if (dr["AMO_FECHA_CREACION"] != DBNull.Value) i.amo_fecha_creacion = DateTime.Parse(dr["AMO_FECHA_CREACION"].ToString());
                            if (dr["AMO_FECHA_ACTUALIZACION"] != DBNull.Value) i.amo_fecha_actualizacion = DateTime.Parse(dr["AMO_FECHA_ACTUALIZACION"].ToString());
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

        public ActivoModelo GetModelo(int id)
        {
            List<ActivoModelo> l = GetModelos(new ActivoModelo { amo_id = id });
            return (l != null && l.Count > 0) ? l[0] : new ActivoModelo();
        }

        public Respuesta InsertModelo(ActivoModelo e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_ACTIVO_MODELO");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", e.amo_cliente ?? Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", e.amo_activo_tipo);
                    cmd.Parameters.AddWithValue("@FABRICANTE", (object)e.amo_fabricante ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.amo_nombre);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.amo_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Modelo creado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            return r;
        }

        public Respuesta UpdateModelo(ActivoModelo e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_ACTIVO_MODELO");
                    cmd.Parameters.AddWithValue("@ID", e.amo_id);
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", e.amo_activo_tipo);
                    cmd.Parameters.AddWithValue("@FABRICANTE", (object)e.amo_fabricante ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.amo_nombre);
                    cmd.Parameters.AddWithValue("@DESCRIPCION", (object)e.amo_descripcion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.amo_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.amo_id; r.detalle = "Modelo actualizado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            return r;
        }

        public Respuesta DeleteModelo(ActivoModelo e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ACTIVO_MODELO");
                    cmd.Parameters.AddWithValue("@ID", e.amo_id);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.amo_id; r.detalle = "Modelo dado de baja con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            return r;
        }
    }
}
