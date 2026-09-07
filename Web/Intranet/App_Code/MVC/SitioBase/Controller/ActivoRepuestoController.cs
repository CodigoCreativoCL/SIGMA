using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un repuesto compatible con un activo (para la Ficha 360).</summary>
    [Serializable]
    public class ActivoRepuesto
    {
        public int rep_id { get; set; }
        public string rep_codigo { get; set; }
        public string rep_nombre { get; set; }
        public string rep_fabricante { get; set; }
        public string rep_modelo { get; set; }
    }

    /// <summary>
    /// Repuestos que le sirven a un activo, segun su compatibilidad
    /// (Repuesto_Compatibilidad por tipo o modelo del activo). Solo lectura,
    /// para mostrarlos en la Ficha e historial.
    /// </summary>
    public class ActivoRepuestoController
    {
        public List<ActivoRepuesto> GetRepuestos(int activo, int cliente)
        {
            List<ActivoRepuesto> lista = new List<ActivoRepuesto>();
            if (activo <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_REPUESTO";
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoRepuesto r = new ActivoRepuesto();
                            r.rep_id = int.Parse(dr["REP_ID"].ToString());
                            r.rep_codigo = dr["REP_CODIGO"].ToString();
                            r.rep_nombre = dr["REP_NOMBRE"].ToString();
                            r.rep_fabricante = dr["REP_FABRICANTE"].ToString();
                            r.rep_modelo = dr["REP_MODELO"].ToString();
                            lista.Add(r);
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
