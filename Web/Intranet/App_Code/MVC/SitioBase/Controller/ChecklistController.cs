using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;
using SitioBase;

namespace SitioBase.Controller
{
    public class ChecklistController
    {
        //Lista
        public List<Checklist> GetChecklists(Checklist checkList)
        {
            List<Checklist> checkLists = new List<Checklist>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST";
                cmd.Parameters.AddWithValue("@CLIENTE", checkList.chk_cliente);

                if (checkList.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", checkList.filtro_habilitado);
                if (checkList.filtro != null) cmd.Parameters.AddWithValue("@FILTRO", checkList.filtro);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        checkList = new Checklist();

                        checkList.chk_id = int.Parse(dr["CHK_ID"].ToString());
                        checkList.chk_nombre = dr["CHK_NOMBRE"].ToString();
                        checkList.chk_cliente = int.Parse(dr["CHK_CLIENTE"].ToString());
                        checkList.chk_descripcion = dr["CHK_DESCRIPCION"].ToString();
                        checkList.chk_habilitado = bool.Parse(dr["CHK_HABILITADO"].ToString());

                        checkLists.Add(checkList);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checkLists;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checkLists;
            }
        }

        //Devuelve
        public Checklist GetChecklist(Checklist checkList)
        {

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST";
                cmd.Parameters.AddWithValue("@ID", checkList.chk_id);
                cmd.Parameters.AddWithValue("@CLIENTE", checkList.chk_cliente);


                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        checkList = new Checklist();

                        checkList.chk_id = int.Parse(dr["CHK_ID"].ToString());
                        checkList.chk_nombre = dr["CHK_NOMBRE"].ToString();
                        checkList.chk_cliente = int.Parse(dr["CHK_CLIENTE"].ToString());
                        checkList.chk_descripcion = dr["CHK_DESCRIPCION"].ToString();
                        checkList.chk_habilitado = bool.Parse(dr["CHK_HABILITADO"].ToString());
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checkList;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checkList;
            }
        }

        //Inserta
        public Respuesta InsertChecklist(Checklist checkList)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int Id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("INS_CHECKLIST");

                cmdExecute.Parameters.AddWithValue("@ID", Id).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@NOMBRE", checkList.chk_nombre);
                cmdExecute.Parameters.AddWithValue("@CLIENTE", checkList.chk_cliente);
                cmdExecute.Parameters.AddWithValue("@DESCRIPCION", checkList.chk_descripcion);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", checkList.chk_habilitado);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();
                Id = (int)cmdExecute.Parameters["@ID"].Value;

                respuesta.codigo = Id;
                respuesta.detalle = "CheckList creado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        //Actualiza
        public Respuesta UpdateChecklist(Checklist checkList)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("UPD_CHECKLIST");

                cmdExecute.Parameters.AddWithValue("@ID", checkList.chk_id);
                cmdExecute.Parameters.AddWithValue("@NOMBRE", checkList.chk_nombre);
                cmdExecute.Parameters.AddWithValue("@CLIENTE", checkList.chk_cliente);
                cmdExecute.Parameters.AddWithValue("@DESCRIPCION", checkList.chk_descripcion);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", checkList.chk_habilitado);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());


                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = id;
                respuesta.detalle = "CheckList actualizado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        //Elimina
        public Respuesta DeleteChecklist(Checklist checkList)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                SqlCommand cmdExecute = Conexion.GetCommand("DEL_CHECKLIST");

                cmdExecute.Parameters.AddWithValue("@ID", checkList.chk_id);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "CheckList(s) eliminado(s) con �xito.";
                respuesta.error = false;

            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

    }
}

