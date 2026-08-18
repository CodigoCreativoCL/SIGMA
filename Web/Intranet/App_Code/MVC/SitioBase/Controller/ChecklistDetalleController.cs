using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class ChecklistDetalleController
    {
        //Lista
        public List<ChecklistDetalle> GetCheckListDetalles(ChecklistDetalle checklistDetalle)
        {
            List<ChecklistDetalle> checkListDetalles = new List<ChecklistDetalle>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_DETALLE";
                if (checklistDetalle.chd_id > 0) cmd.Parameters.AddWithValue("@ID", checklistDetalle.chd_id);
                if (checklistDetalle.chd_id_checklist > 0) cmd.Parameters.AddWithValue("@ID_CHECKLIST", checklistDetalle.chd_id_checklist);
                if (checklistDetalle.filtro != null) cmd.Parameters.AddWithValue("@FILTRO", checklistDetalle.filtro);
                //cmd.Parameters.AddWithValue("@USUARIO", SitioBase.Session.UsuarioId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        checklistDetalle = new ChecklistDetalle();

                        checklistDetalle.chd_id = int.Parse(dr["CHD_ID"].ToString());
                        checklistDetalle.chd_id_checklist = int.Parse(dr["CHD_ID_CHECKLIST"].ToString());
                        checklistDetalle.nombreCheckList = dr["CHK_NOMBRE"].ToString();
                        checklistDetalle.chd_pregunta = dr["CHD_PREGUNTA"].ToString();
                        checklistDetalle.chd_objeto = int.Parse(dr["CHD_OBJETO"].ToString());
                        checklistDetalle.nombreObjeto = dr["CHO_NOMBRE"].ToString();
                        checklistDetalle.nombreTipoDato = dr["CHT_NOMBRE"].ToString();
                        checklistDetalle.chd_habilitado = bool.Parse(dr["CHD_HABILITADO"].ToString());

                        if (!string.IsNullOrEmpty(dr["CHD_VALOR_PREDETERMINADO"].ToString())) checklistDetalle.chd_valor_predeterminado = bool.Parse(dr["CHD_VALOR_PREDETERMINADO"].ToString());
                        if (!string.IsNullOrEmpty(dr["CHD_VALOR"].ToString())) checklistDetalle.chd_valor = dr["CHD_VALOR"].ToString();
                        if (dr["CHD_ORDEN"].ToString() != "") checklistDetalle.chd_orden = int.Parse(dr["CHD_ORDEN"].ToString());
                        if (!string.IsNullOrEmpty(dr["CHD_NOTIFICACION"].ToString())) checklistDetalle.chd_notificacion = bool.Parse(dr["CHD_NOTIFICACION"].ToString());


                        checkListDetalles.Add(checklistDetalle);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checkListDetalles;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checkListDetalles;
            }
        }

        //Devuelve
        public ChecklistDetalle GetCheckListDetalle(ChecklistDetalle checklistDetalle)
        {

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_DETALLE";
                cmd.Parameters.AddWithValue("@ID", checklistDetalle.chd_id);


                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        checklistDetalle = new ChecklistDetalle();

                        checklistDetalle.chd_id = int.Parse(dr["CHD_ID"].ToString());
                        checklistDetalle.chd_id_checklist = int.Parse(dr["CHD_ID_CHECKLIST"].ToString());
                        checklistDetalle.nombreCheckList = dr["CHK_NOMBRE"].ToString();
                        checklistDetalle.chd_pregunta = dr["CHD_PREGUNTA"].ToString();
                        checklistDetalle.chd_objeto = int.Parse(dr["CHD_OBJETO"].ToString());
                        checklistDetalle.nombreObjeto = dr["CHO_NOMBRE"].ToString();
                        checklistDetalle.nombreTipoDato = dr["CHT_NOMBRE"].ToString();
                        checklistDetalle.chd_habilitado = bool.Parse(dr["CHD_HABILITADO"].ToString());
                        if (!string.IsNullOrEmpty(dr["CHD_VALOR_PREDETERMINADO"].ToString())) checklistDetalle.chd_valor_predeterminado = bool.Parse(dr["CHD_VALOR_PREDETERMINADO"].ToString());
                        if (!string.IsNullOrEmpty(dr["CHD_VALOR"].ToString())) checklistDetalle.chd_valor = dr["CHD_VALOR"].ToString();
                        if (!string.IsNullOrEmpty(dr["CHD_NOTIFICACION"].ToString())) checklistDetalle.chd_notificacion = bool.Parse(dr["CHD_NOTIFICACION"].ToString());

                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checklistDetalle;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checklistDetalle;
            }
        }

        //Inserta
        public Respuesta InsertCheckListDetalle(ChecklistDetalle checklistDetalle)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("INS_CHECKLIST_DETALLE");

                cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@ID_CHECKLIST", checklistDetalle.chd_id_checklist);
                cmdExecute.Parameters.AddWithValue("@PREGUNTA", checklistDetalle.chd_pregunta);
                cmdExecute.Parameters.AddWithValue("@OBJETO", checklistDetalle.chd_objeto);
                cmdExecute.Parameters.AddWithValue("@VALOR_PRED", checklistDetalle.chd_valor_predeterminado);
                cmdExecute.Parameters.AddWithValue("@VALOR", checklistDetalle.chd_valor);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", checklistDetalle.chd_habilitado);
                cmdExecute.Parameters.AddWithValue("@NOTIFICACION", checklistDetalle.chd_notificacion);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();
                id = (int)cmdExecute.Parameters["@ID"].Value;

                respuesta.codigo = id;
                respuesta.detalle = "Ítem creado con éxito.";
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
        public Respuesta UpdateCheckListDetalle(ChecklistDetalle checklistDetalle)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("UPD_CHECKLIST_DETALLE");

                cmdExecute.Parameters.AddWithValue("@ID", checklistDetalle.chd_id);
                cmdExecute.Parameters.AddWithValue("@ID_CHECKLIST", checklistDetalle.chd_id_checklist);
                cmdExecute.Parameters.AddWithValue("@PREGUNTA", checklistDetalle.chd_pregunta);
                cmdExecute.Parameters.AddWithValue("@OBJETO", checklistDetalle.chd_objeto);
                cmdExecute.Parameters.AddWithValue("@VALOR_PRED", checklistDetalle.chd_valor_predeterminado);
                cmdExecute.Parameters.AddWithValue("@VALOR", checklistDetalle.chd_valor);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", checklistDetalle.chd_habilitado);
                cmdExecute.Parameters.AddWithValue("@NOTIFICACION", checklistDetalle.chd_notificacion);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = id;
                respuesta.detalle = "Ítem actualizado con éxito.";
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
        public Respuesta DeleteCheckListDetalle(ChecklistDetalle checklistDetalle)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                SqlCommand cmdExecute = Conexion.GetCommand("DEL_CHECKLIST_DETALLE");

                cmdExecute.Parameters.AddWithValue("@ID", checklistDetalle.chd_id);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "Ítem(s) eliminado(s) con éxito.";
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
        public Respuesta UpdateCheckListOrden(ChecklistDetalle checklistDetalle)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("UPD_CHECKLIST_ORDEN");

                cmdExecute.Parameters.AddWithValue("@ID", checklistDetalle.chd_id);
                cmdExecute.Parameters.AddWithValue("@ORDEN", checklistDetalle.chd_orden);
                cmdExecute.Parameters.AddWithValue("@ID_CHECK_LIST", checklistDetalle.chd_id_checklist);


                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = id;
                respuesta.detalle = "Orden actualizado con éxito.";
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

