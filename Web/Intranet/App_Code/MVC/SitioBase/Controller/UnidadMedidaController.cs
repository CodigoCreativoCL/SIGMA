using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Unidades de medida, EN LECTURA.
    ///
    /// Su mantenedor es HU-040 (Sprint 2) y todavia no se construye. Esto
    /// es lo minimo para que la ficha de repuesto tenga que ofrecer: sin
    /// unidad no se puede crear un repuesto, porque rep_unidad_medida es
    /// NOT NULL.
    ///
    /// No lleva @CLIENTE: las unidades son del sistema, no de una empresa.
    /// Un kilogramo pesa lo mismo en Hamburgo que en cualquier otra planta.
    /// </summary>
    public class UnidadMedidaController
    {
        public List<UnidadMedida> GetUnidades(int id = 0)
        {
            List<UnidadMedida> lista = new List<UnidadMedida>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_UNIDAD_MEDIDA";

                    if (id > 0) cmd.Parameters.AddWithValue("@ID", id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            UnidadMedida item = new UnidadMedida();

                            item.ume_id = int.Parse(dr["UME_ID"].ToString());
                            item.ume_codigo = dr["UME_CODIGO"].ToString();
                            item.ume_nombre = dr["UME_NOMBRE"].ToString();
                            item.ume_simbolo = dr["UME_SIMBOLO"].ToString();
                            item.ume_habilitado = bool.Parse(dr["UME_HABILITADO"].ToString());
                            item.magnitud_nombre = dr["MAGNITUD_NOMBRE"].ToString();
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
