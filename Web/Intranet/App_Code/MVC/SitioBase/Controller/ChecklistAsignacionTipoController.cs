using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Catálogo de tipos de asignación de checklist para poblar combos (HU-090),
    /// vía SEL_CHECKLIST_ASIGNACION_TIPO.
    /// </summary>
    public class ChecklistAsignacionTipoController
    {
        public List<ChecklistAsignacionTipo> GetTipos(bool soloHabilitados = true)
        {
            List<ChecklistAsignacionTipo> lista = new List<ChecklistAsignacionTipo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_ASIGNACION_TIPO";
                    if (soloHabilitados) cmd.Parameters.AddWithValue("@HABILITADO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ChecklistAsignacionTipo c = new ChecklistAsignacionTipo();
                            c.cat_id = int.Parse(dr["CAT_ID"].ToString());
                            c.cat_codigo = dr["CAT_CODIGO"].ToString();
                            c.cat_nombre = dr["CAT_NOMBRE"].ToString();
                            c.cat_habilitado = bool.Parse(dr["CAT_HABILITADO"].ToString());
                            lista.Add(c);
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
