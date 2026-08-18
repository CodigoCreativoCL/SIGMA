using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;
using SitioBase;

namespace SitioBase.Controller
{
    public class ChecklistTipoObjetoController
    {
        //Lista
        public List<ChecklistTipoObjeto> GetCheckListTipoObjetos(ChecklistTipoObjeto checklistTipoObjeto)
        {
            List<ChecklistTipoObjeto> checklistTipoObjetos = new List<ChecklistTipoObjeto>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_TIPO_OBJETO";
                if (checklistTipoObjeto.cho_id > 0) cmd.Parameters.AddWithValue("@ID", checklistTipoObjeto.cho_id);
                //cmd.Parameters.AddWithValue("@USUARIO", SitioBase.Session.UsuarioId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        checklistTipoObjeto = new ChecklistTipoObjeto();

                        checklistTipoObjeto.cho_id = int.Parse(dr["CHO_ID"].ToString());
                        checklistTipoObjeto.cho_nombre = dr["CHO_NOMBRE"].ToString();
                        checklistTipoObjeto.cho_tipo_dato = int.Parse(dr["CHO_TIPO_DATO"].ToString());

                        checklistTipoObjetos.Add(checklistTipoObjeto);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checklistTipoObjetos;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checklistTipoObjetos;
            }
        }

    }
}
