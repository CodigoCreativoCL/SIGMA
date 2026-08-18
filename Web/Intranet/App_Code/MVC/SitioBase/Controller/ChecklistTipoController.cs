using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase.Model;
using SitioBase;

namespace SitioBase.Controller
{
    public class ChecklistTipoController
    {
        //Lista
        public List<ChecklistTipo> GetChecklistTipos(ChecklistTipo checklistTipo)
        {
            List<ChecklistTipo> checklistTipos = new List<ChecklistTipo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_TIPO";
                    if (!string.IsNullOrEmpty(checklistTipo.filtro)) cmd.Parameters.AddWithValue("@FILTRO", checklistTipo.filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ChecklistTipo item = new ChecklistTipo();

                            item.ckt_id = int.Parse(dr["ckt_id"].ToString());
                            item.ckt_nombre = dr["ckt_nombre"].ToString();

                            checklistTipos.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    checklistTipos = null;
                }
            }

            return checklistTipos;
        }
    }
}
