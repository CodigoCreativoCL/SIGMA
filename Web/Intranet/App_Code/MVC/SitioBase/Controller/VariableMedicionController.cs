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

        /// <summary>
        /// Id de la variable de medicion con ese nombre (comun o de la empresa);
        /// si no existe la crea como propia, decimal y con esa unidad (bloque 345).
        /// 0 si falla.
        /// </summary>
        public int ResolverPorNombre(string nombre, int unidad)
        {
            if (!Token.TokenSeguridad() || string.IsNullOrWhiteSpace(nombre)) return 0;
            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPS_VARIABLE_MEDICION_NOMBRE");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@NOMBRE", nombre.Trim());
                cmd.Parameters.AddWithValue("@UNIDAD", unidad > 0 ? (object)unidad : DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
                return cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value;
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                return 0;
            }
        }

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
