using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class TipoPerfilController
    {
        public List<TipoPerfil> ListoTipoPerfil()
        {
            List<TipoPerfil> tipoPerfiles = new List<TipoPerfil>();
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_TIPO_PERFIL";

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        TipoPerfil tipoPerfil = new TipoPerfil();

                        tipoPerfil.tpp_id = int.Parse(dr["TPP_ID"].ToString());
                        tipoPerfil.tpp_nombre = dr["TPP_NOMBRE"].ToString();


                        tipoPerfiles.Add(tipoPerfil);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return tipoPerfiles;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();

                return null;
            }
        }

    }
}