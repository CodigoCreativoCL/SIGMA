using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// CONTROLLER de Checklist_Item_Dependencia (HU-092): dependencias entre
    /// ítems. Toda operación pasa por Token.TokenSeguridad y por SP; el cliente va
    /// desde la sesión. SP: SEL/INS/UPD/DEL_CHECKLIST_ITEM_DEPENDENCIA. Los ítems
    /// del combo salen de SEL_CHECKLIST_ITEM_LISTA (compartido con HU-091).
    /// </summary>
    public class ChecklistItemDependenciaController
    {
        #region LECTURA

        public List<ChecklistItemDependencia> GetDependencias(ChecklistItemDependencia filtro = null)
        {
            List<ChecklistItemDependencia> lista = new List<ChecklistItemDependencia>();
            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM_DEPENDENCIA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                if (filtro != null)
                {
                    if (filtro.filtro_plantilla.HasValue && filtro.filtro_plantilla.Value > 0)
                        cmd.Parameters.AddWithValue("@PLANTILLA", filtro.filtro_plantilla.Value);
                    if (filtro.filtro_version.HasValue && filtro.filtro_version.Value > 0)
                        cmd.Parameters.AddWithValue("@VERSION", filtro.filtro_version.Value);
                    if (!string.IsNullOrEmpty(filtro.filtro))
                        cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                }

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    while (dr.Read()) lista.Add(Map(dr));

                cmd.Connection.Close(); cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                lista = null;
            }
            return lista;
        }

        public ChecklistItemDependencia GetDependencia(int id)
        {
            ChecklistItemDependencia item = null;
            if (!Token.TokenSeguridad()) return null;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM_DEPENDENCIA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ID", id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    if (dr.Read()) item = Map(dr);

                cmd.Connection.Close(); cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return item;
        }

        private static ChecklistItemDependencia Map(SqlDataReader dr)
        {
            ChecklistItemDependencia d = new ChecklistItemDependencia();
            d.cid_id = int.Parse(dr["CID_ID"].ToString());
            d.item_id = int.Parse(dr["ITEM_ID"].ToString());
            d.item_texto = dr["ITEM_TEXTO"].ToString();
            d.condicion_id = int.Parse(dr["CONDICION_ID"].ToString());
            d.condicion_texto = dr["CONDICION_TEXTO"].ToString();
            d.operador_id = int.Parse(dr["OPERADOR_ID"].ToString());
            d.operador_nombre = dr["OPERADOR_NOMBRE"].ToString();
            d.valor = dr["VALOR"].ToString();
            if (dr["OPCION_ID"] != DBNull.Value) d.opcion_id = int.Parse(dr["OPCION_ID"].ToString());
            d.opcion_texto = dr["OPCION_TEXTO"].ToString();
            d.accion_id = int.Parse(dr["ACCION_ID"].ToString());
            d.accion_codigo = dr["ACCION_CODIGO"].ToString();
            d.accion_nombre = dr["ACCION_NOMBRE"].ToString();
            d.plantilla_id = int.Parse(dr["PLANTILLA_ID"].ToString());
            d.plantilla_nombre = dr["PLANTILLA_NOMBRE"].ToString();
            d.habilitado = bool.Parse(dr["HABILITADO"].ToString());
            return d;
        }

        #endregion

        #region ESCRITURA

        public Respuesta InsertDependencia(ChecklistItemDependencia e)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "Sesión no válida."; r.codigo = -1; return r; }

            SqlCommand cmd = null;
            try
            {
                int id = 0;
                cmd = Conexion.GetCommand("INS_CHECKLIST_ITEM_DEPENDENCIA");
                cmd.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ITEM", e.item_id);
                cmd.Parameters.AddWithValue("@CONDICION", e.condicion_id);
                Cuerpo(cmd, e);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = (int)cmd.Parameters["@ID"].Value;
                r.detalle = "Dependencia creada con éxito.";
                r.error = false;
            }
            catch (Exception ex) { Cerrar(cmd); r.codigo = -1; r.detalle = ex.Message; r.error = true; }
            return r;
        }

        public Respuesta UpdateDependencia(ChecklistItemDependencia e)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "Sesión no válida."; r.codigo = -1; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPD_CHECKLIST_ITEM_DEPENDENCIA");
                cmd.Parameters.AddWithValue("@ID", e.cid_id);
                cmd.Parameters.AddWithValue("@CONDICION", e.condicion_id);
                Cuerpo(cmd, e);
                cmd.Parameters.AddWithValue("@HABILITADO", e.habilitado);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = e.cid_id;
                r.detalle = "Dependencia actualizada con éxito.";
                r.error = false;
            }
            catch (Exception ex) { Cerrar(cmd); r.codigo = -1; r.detalle = ex.Message; r.error = true; }
            return r;
        }

        public Respuesta DeleteDependencia(ChecklistItemDependencia e)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "Sesión no válida."; r.codigo = -1; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("DEL_CHECKLIST_ITEM_DEPENDENCIA");
                cmd.Parameters.AddWithValue("@ID", e.cid_id);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = e.cid_id;
                r.detalle = "Dependencia dada de baja con éxito.";
                r.error = false;
            }
            catch (Exception ex) { Cerrar(cmd); r.codigo = -1; r.detalle = ex.Message; r.error = true; }
            return r;
        }

        private static void Cuerpo(SqlCommand cmd, ChecklistItemDependencia e)
        {
            cmd.Parameters.AddWithValue("@OPERADOR", e.operador_id);
            cmd.Parameters.AddWithValue("@VALOR", (object)e.valor ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@OPCION", (object)e.opcion_id ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ACCION", e.accion_id);
        }

        private static void Cerrar(SqlCommand cmd)
        {
            if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
        }

        #endregion
    }
}
