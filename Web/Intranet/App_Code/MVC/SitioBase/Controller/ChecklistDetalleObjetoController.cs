using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase.Model;
using SitioBase;

namespace SitioBase.Controller
{
    public class ChecklistDetalleObjetoController
    {
        //Lista
        public List<ChecklistDetalleObjeto> GetCheckListDetalleObjetos(ChecklistDetalleObjeto checklistDetalleObjeto)
        {
            List<ChecklistDetalleObjeto> checkListDetalleObjetos = new List<ChecklistDetalleObjeto>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_DETALLE_OBJETO";
                if (checklistDetalleObjeto.cdc_id > 0) cmd.Parameters.AddWithValue("@ID", checklistDetalleObjeto.cdc_id);
                if (checklistDetalleObjeto.cdc_id_checklist_detalle > 0) cmd.Parameters.AddWithValue("@ID_CHECKLIST_DETALLE", checklistDetalleObjeto.cdc_id_checklist_detalle);
                if (checklistDetalleObjeto.filtro != null) cmd.Parameters.AddWithValue("@FILTRO", checklistDetalleObjeto.filtro);
                //cmd.Parameters.AddWithValue("@USUARIO", Exproges.Session.UsuarioId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        checklistDetalleObjeto = new ChecklistDetalleObjeto();

                        checklistDetalleObjeto.cdc_id = int.Parse(dr["CDC_ID"].ToString());
                        checklistDetalleObjeto.cdc_id_checklist_detalle = int.Parse(dr["CDC_ID_CHECKLIST_DETALLE"].ToString());
                        checklistDetalleObjeto.cdc_orden = int.Parse(dr["CDC_ORDEN"].ToString());
                        checklistDetalleObjeto.cdc_nombre = dr["CDC_NOMBRE"].ToString();
                        checklistDetalleObjeto.cdc_usuario_creacion = int.Parse(dr["CDC_USUARIO_CREACION"].ToString());
                        checklistDetalleObjeto.cdc_fecha_creacion = DateTime.Parse(dr["CDC_FECHA_CREACION"].ToString());
                        checklistDetalleObjeto.cdc_usuario_act = int.Parse(dr["CDC_USUARIO_ACT"].ToString());
                        checklistDetalleObjeto.cdc_fecha_act = DateTime.Parse(dr["CDC_FECHA_ACT"].ToString());

                        checkListDetalleObjetos.Add(checklistDetalleObjeto);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checkListDetalleObjetos;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checkListDetalleObjetos;
            }
        }

        //Devuelve
        public ChecklistDetalleObjeto GetCheckListDetalleObjeto(ChecklistDetalleObjeto checklistDetalleObjeto)
        {

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_DETALLE_OBJETO";
                cmd.Parameters.AddWithValue("@ID", checklistDetalleObjeto.cdc_id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read())
                    {
                        checklistDetalleObjeto = new ChecklistDetalleObjeto();

                        checklistDetalleObjeto.cdc_id = int.Parse(dr["CDC_ID"].ToString());
                        checklistDetalleObjeto.cdc_id_checklist_detalle = int.Parse(dr["CDC_ID_CHECKLIST_DETALLE"].ToString());
                        checklistDetalleObjeto.cdc_orden = int.Parse(dr["CDC_ORDEN"].ToString());
                        checklistDetalleObjeto.cdc_nombre = dr["CDC_NOMBRE"].ToString();
                        checklistDetalleObjeto.cdc_usuario_creacion = int.Parse(dr["CDC_USUARIO_CREACION"].ToString());
                        checklistDetalleObjeto.cdc_fecha_creacion = DateTime.Parse(dr["CDC_FECHA_CREACION"].ToString());
                        checklistDetalleObjeto.cdc_usuario_act = int.Parse(dr["CDC_USUARIO_ACT"].ToString());
                        checklistDetalleObjeto.cdc_fecha_act = DateTime.Parse(dr["CDC_FECHA_ACT"].ToString());
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return checklistDetalleObjeto;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return checklistDetalleObjeto;
            }
        }

        //Inserta
        public Respuesta InsertCheckListDetalleObjeto(ChecklistDetalleObjeto checklistDetalleObjeto)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("INS_CHECKLIST_DETALLE_OBJETO");

                cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@ID_CHECKLIST_DETALLE", checklistDetalleObjeto.cdc_id_checklist_detalle);
                cmdExecute.Parameters.AddWithValue("@ORDEN", checklistDetalleObjeto.cdc_orden);
                cmdExecute.Parameters.AddWithValue("@NOMBRE", checklistDetalleObjeto.cdc_nombre);
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
        public Respuesta UpdateCheckListDetalleObjeto(ChecklistDetalleObjeto checklistDetalleObjeto)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("UPD_CHECKLIST_DETALLE_OBJETO");

                cmdExecute.Parameters.AddWithValue("@ID", checklistDetalleObjeto.cdc_id);
                cmdExecute.Parameters.AddWithValue("@ID_CHECKLIST_DETALLE", checklistDetalleObjeto.cdc_id_checklist_detalle);
                cmdExecute.Parameters.AddWithValue("@ORDEN", checklistDetalleObjeto.cdc_orden);
                cmdExecute.Parameters.AddWithValue("@NOMBRE", checklistDetalleObjeto.cdc_nombre);
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
        public Respuesta DeleteCheckListDetalleObjeto(ChecklistDetalleObjeto checklistDetalleObjeto)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                SqlCommand cmdExecute = Conexion.GetCommand("DEL_CHECKLIST_DETALLE_OBJETO");

                cmdExecute.Parameters.AddWithValue("@ID", checklistDetalleObjeto.cdc_id);
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
    }
}

