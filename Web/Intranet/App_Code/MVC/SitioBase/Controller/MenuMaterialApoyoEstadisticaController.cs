using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    public class MenuMaterialApoyoEstadisticaController
    {

        public List<MenuMaterialApoyoEstadistica> GetEstadisticas(MenuMaterialApoyoEstadistica item)
        {
            List<MenuMaterialApoyoEstadistica> estadisticas = new List<MenuMaterialApoyoEstadistica>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_MENU_MATERIAL_APOYO_ESTADISTICAS";
                if (item.filtro != "") cmd.Parameters.AddWithValue("@FILTRO", item.filtro);
                if (item.mae_menu_apoyo > 0) cmd.Parameters.AddWithValue("@MENU", item.mae_menu_apoyo);
                if (item.mae_usuario > 0) cmd.Parameters.AddWithValue("@USUARIO", item.mae_usuario);
                if (item.mae_tipo > 0) cmd.Parameters.AddWithValue("@TIPO", item.mae_tipo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        item = new MenuMaterialApoyoEstadistica();

                        item.mae_id = int.Parse(dr["mae_id"].ToString());
                        item.mae_menu_apoyo = int.Parse(dr["mae_menu_apoyo"].ToString());
                        item.mae_tipo = int.Parse(dr["mae_tipo"].ToString());
                        item.mae_fecha = DateTime.Parse(dr["mae_fecha"].ToString());
                        item.NombreUsuario = dr["NOMBRE_USUARIO"].ToString();
                        item.tipo = dr["tipo"].ToString();
                        estadisticas.Add(item);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return estadisticas;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return estadisticas;
            }
        }


        public Respuesta InsertEstadistica(MenuMaterialApoyoEstadistica estadistica)
        {
            SqlCommand cmdExecute = new SqlCommand();

            Respuesta respuesta = new Respuesta();

            try
            {
                int idArchivo = 0;
                cmdExecute = Conexion.GetCommand("INS_MENU_MATERIAL_APOYO_ESTADISTICAS");
                cmdExecute.Parameters.AddWithValue("@ID", idArchivo).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@MENU_APOYO", estadistica.mae_menu_apoyo);
                cmdExecute.Parameters.AddWithValue("@TIPO", estadistica.mae_tipo);
                if (estadistica.mae_usuario > 0)
                    cmdExecute.Parameters.AddWithValue("@USUARIO", estadistica.mae_usuario);
                else
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());


                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();
                idArchivo = (int)cmdExecute.Parameters["@ID"].Value;

                respuesta.codigo = idArchivo;
                respuesta.detalle = "Estadistica creada con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                cmdExecute.Connection.Close();
                cmdExecute.Dispose();

                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

    }
}