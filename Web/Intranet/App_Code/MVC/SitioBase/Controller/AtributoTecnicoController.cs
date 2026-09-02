using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Atributos técnicos de los tipos de activo del cliente (HU-032). El SEL
    /// trae los del cliente MAS los globales; INS/UPD/DEL solo tocan los del
    /// cliente (el SP rechaza los globales). El código es automático (ATR-id).
    /// </summary>
    public class AtributoTecnicoController
    {
        public List<AtributoTecnico> GetAtributos(AtributoTecnico filtro = null)
        {
            List<AtributoTecnico> lista = new List<AtributoTecnico>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ATRIBUTO_TECNICO";

                    int cliente = (filtro != null && filtro.filtro_cliente > 0) ? filtro.filtro_cliente : Session.ClienteId();
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    if (filtro != null)
                    {
                        if (filtro.ate_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ate_id);
                        if (filtro.filtro_activo_tipo > 0) cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            AtributoTecnico i = new AtributoTecnico();
                            i.ate_id = int.Parse(dr["ATE_ID"].ToString());
                            if (dr["ATE_CLIENTE"] != DBNull.Value) i.ate_cliente = int.Parse(dr["ATE_CLIENTE"].ToString());
                            if (dr["ATE_ACTIVO_TIPO"] != DBNull.Value) i.ate_activo_tipo = int.Parse(dr["ATE_ACTIVO_TIPO"].ToString());
                            i.ate_tipo_dato = int.Parse(dr["ATE_TIPO_DATO"].ToString());
                            if (dr["ATE_UNIDAD_MEDIDA"] != DBNull.Value) i.ate_unidad_medida = int.Parse(dr["ATE_UNIDAD_MEDIDA"].ToString());
                            i.ate_codigo = dr["ATE_CODIGO"].ToString();
                            i.ate_nombre = dr["ATE_NOMBRE"].ToString();
                            if (dr["ATE_ORDEN"] != DBNull.Value) i.ate_orden = int.Parse(dr["ATE_ORDEN"].ToString());
                            i.ate_habilitado = bool.Parse(dr["ATE_HABILITADO"].ToString());
                            i.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            i.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            i.tipo_dato_nombre = dr["TIPO_DATO_NOMBRE"].ToString();
                            i.unidad_nombre = dr["UNIDAD_NOMBRE"].ToString();
                            if (dr["ATE_FECHA_CREACION"] != DBNull.Value) i.ate_fecha_creacion = DateTime.Parse(dr["ATE_FECHA_CREACION"].ToString());
                            if (dr["ATE_FECHA_ACTUALIZACION"] != DBNull.Value) i.ate_fecha_actualizacion = DateTime.Parse(dr["ATE_FECHA_ACTUALIZACION"].ToString());
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

        public AtributoTecnico GetAtributo(int id)
        {
            List<AtributoTecnico> l = GetAtributos(new AtributoTecnico { ate_id = id });
            return (l != null && l.Count > 0) ? l[0] : new AtributoTecnico();
        }

        public Respuesta InsertAtributo(AtributoTecnico e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int id = 0;
                    cmd = Conexion.GetCommand("INS_ATRIBUTO_TECNICO");
                    cmd.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", e.ate_cliente ?? Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", (object)e.ate_activo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@TIPO_DATO", e.ate_tipo_dato);
                    cmd.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)e.ate_unidad_medida ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@CODIGO", e.ate_codigo);          // 'AUTO' -> ATR-<id> en el SP
                    cmd.Parameters.AddWithValue("@NOMBRE", e.ate_nombre);
                    cmd.Parameters.AddWithValue("@ORDEN", (object)e.ate_orden ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                    r.codigo = id; r.detalle = "Atributo creado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            return r;
        }

        public Respuesta UpdateAtributo(AtributoTecnico e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("UPD_ATRIBUTO_TECNICO");
                    cmd.Parameters.AddWithValue("@ID", e.ate_id);
                    cmd.Parameters.AddWithValue("@ACTIVO_TIPO", (object)e.ate_activo_tipo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@TIPO_DATO", e.ate_tipo_dato);
                    cmd.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)e.ate_unidad_medida ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@NOMBRE", e.ate_nombre);
                    cmd.Parameters.AddWithValue("@ORDEN", (object)e.ate_orden ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HABILITADO", e.ate_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.ate_id; r.detalle = "Atributo actualizado con éxito."; r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            return r;
        }

        public Respuesta DeleteAtributo(AtributoTecnico e)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ATRIBUTO_TECNICO");
                    cmd.Parameters.AddWithValue("@ID", e.ate_id);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = e.ate_id; r.detalle = "Atributo dado de baja con éxito."; r.error = false;
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


    /// <summary>Tipos de dato para el combo de la ficha (SEL_TIPO_DATO).</summary>
    public class TipoDatoController
    {
        public List<TipoDato> GetTiposDato(TipoDato filtro = null)
        {
            List<TipoDato> lista = new List<TipoDato>();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_TIPO_DATO";
                    if (filtro != null && filtro.filtro_habilitado != null)
                        cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                        while (dr.Read())
                        {
                            TipoDato i = new TipoDato();
                            i.tda_id = int.Parse(dr["TDA_ID"].ToString());
                            i.tda_codigo = dr["TDA_CODIGO"].ToString();
                            i.tda_nombre = dr["TDA_NOMBRE"].ToString();
                            i.tda_habilitado = bool.Parse(dr["TDA_HABILITADO"].ToString());
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
