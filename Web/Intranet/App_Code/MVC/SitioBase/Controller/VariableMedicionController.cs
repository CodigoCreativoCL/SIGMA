using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Variables de medición para poblar combos (HU-062). Trae las del cliente
    /// MÁS las globales del sistema con SEL_VARIABLE_MEDICION.
    /// </summary>
    public class VariableMedicionController
    {
        public List<VariableMedicion> GetVariables(int cliente, bool soloHabilitadas = true)
        {
            List<VariableMedicion> lista = new List<VariableMedicion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_VARIABLE_MEDICION";
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente > 0 ? cliente : Session.ClienteId());
                    if (soloHabilitadas) cmd.Parameters.AddWithValue("@HABILITADO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            VariableMedicion v = new VariableMedicion();
                            v.vme_id = int.Parse(dr["VME_ID"].ToString());
                            v.vme_codigo = dr["VME_CODIGO"].ToString();
                            v.vme_nombre = dr["VME_NOMBRE"].ToString();
                            v.etiqueta = dr["ETIQUETA"].ToString();
                            v.es_global = int.Parse(dr["ES_GLOBAL"].ToString()) == 1;
                            lista.Add(v);
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
