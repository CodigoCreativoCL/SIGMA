using SitioBase;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Catalogo de fabricantes y sus modelos (bloque 333), para los combos de
    /// la ficha del repuesto en la web y en el mapa 3D.
    ///
    /// No escribe: el alta de un fabricante o modelo nuevo la hace el trigger
    /// TRG_REPUESTO_FABRICANTE al guardar el repuesto, sea cual sea la puerta
    /// (web, mapa, carga masiva, API). Aqui solo se lee lo que hay.
    /// </summary>
    public class FabricanteController
    {
        public class Fabricante
        {
            public string nombre { get; set; }
            public int repuestos { get; set; }
            public List<string> modelos { get; set; }
        }

        public List<Fabricante> Catalogo()
        {
            List<Fabricante> lista = new List<Fabricante>();
            if (!Token.TokenSeguridad()) return lista;
            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_FABRICANTE_CATALOGO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                Dictionary<int, Fabricante> porId = new Dictionary<int, Fabricante>();
                foreach (DataRow r in Conexion.GetDataTable(cmd).Rows)
                {
                    int id = Convert.ToInt32(r["FAB_ID"]);
                    Fabricante f;
                    if (!porId.TryGetValue(id, out f))
                    {
                        f = new Fabricante { nombre = Convert.ToString(r["FABRICANTE"]), modelos = new List<string>() };
                        porId[id] = f;
                        lista.Add(f);
                    }
                    if (r["MODELO"] != DBNull.Value) f.modelos.Add(Convert.ToString(r["MODELO"]));
                    f.repuestos += Convert.ToInt32(r["REPUESTOS"]);
                }
            }
            catch (Exception)
            {
                // sin el bloque 333 los combos quedan vacios y se escribe libre, como antes
                if (cmd.Connection != null) cmd.Connection.Close();
            }
            return lista;
        }
    }
}
