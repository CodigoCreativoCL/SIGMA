using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Modelos de activo, para los combos (bloque 93).
    ///
    /// Solo lee. El mantenedor de modelos es del modulo de activos y no de
    /// HU-051; estas consultas existen porque la compatibilidad necesita
    /// ofrecerlos y las tablas nunca se habian leido desde la aplicacion.
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
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.amo_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.amo_id);
                        if (filtro.filtro_activo_tipo > 0)
                            cmd.Parameters.AddWithValue("@ACTIVO_TIPO", filtro.filtro_activo_tipo);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoModelo item = new ActivoModelo();

                            item.amo_id = int.Parse(dr["AMO_ID"].ToString());

                            if (dr["AMO_CLIENTE"] != DBNull.Value)
                                item.amo_cliente = int.Parse(dr["AMO_CLIENTE"].ToString());

                            item.amo_activo_tipo = int.Parse(dr["AMO_ACTIVO_TIPO"].ToString());
                            item.amo_fabricante = dr["AMO_FABRICANTE"].ToString();
                            item.amo_nombre = dr["AMO_NOMBRE"].ToString();
                            item.amo_descripcion = dr["AMO_DESCRIPCION"].ToString();
                            item.amo_habilitado = bool.Parse(dr["AMO_HABILITADO"].ToString());
                            item.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.etiqueta = dr["ETIQUETA"].ToString();

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
    }


    /// <summary>
    /// Componentes de activo, para los combos (bloque 93).
    ///
    /// Hoy la tabla esta vacia: poblarla es del modulo de activos. El combo
    /// lo dice con todas sus letras en vez de quedarse en blanco.
    /// </summary>
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
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.aco_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.aco_id);
                        if (filtro.filtro_activo > 0)
                            cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoComponente item = new ActivoComponente();

                            item.aco_id = int.Parse(dr["ACO_ID"].ToString());
                            item.aco_cliente = int.Parse(dr["ACO_CLIENTE"].ToString());
                            item.aco_activo = int.Parse(dr["ACO_ACTIVO"].ToString());
                            item.aco_codigo = dr["ACO_CODIGO"].ToString();
                            item.aco_nombre = dr["ACO_NOMBRE"].ToString();
                            item.aco_descripcion = dr["ACO_DESCRIPCION"].ToString();
                            item.aco_habilitado = bool.Parse(dr["ACO_HABILITADO"].ToString());
                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.etiqueta = dr["ETIQUETA"].ToString();

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
    }
}
