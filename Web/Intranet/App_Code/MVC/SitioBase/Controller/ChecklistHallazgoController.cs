using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Model
{
    /// <summary>Un hallazgo que dejo una pauta ejecutada en terreno (HU-096). Solo lectura desde la web.</summary>
    public class ChecklistHallazgo
    {
        public int cha_id { get; set; }
        public Guid cha_uuid { get; set; }
        public string cha_titulo { get; set; }
        public string cha_descripcion { get; set; }
        public DateTime? cha_fecha_creacion { get; set; }
        public bool cha_generado_ia { get; set; }
        public decimal? cha_confianza_ia { get; set; }
        public string cha_motivo_descarte { get; set; }
        public DateTime? cha_fecha_confirmacion { get; set; }
        public int? severidad_id { get; set; }
        public string severidad_codigo { get; set; }
        public string severidad_nombre { get; set; }
        public string criticidad_nombre { get; set; }
        public int? estado_id { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        public int? activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string planta_nombre { get; set; }
        public string componente_nombre { get; set; }
        public int ejecucion_id { get; set; }
        public DateTime? ejecucion_fecha { get; set; }
        public string plantilla_codigo { get; set; }
        public string plantilla_nombre { get; set; }
        public string ejecutor_nombre { get; set; }
        public string item_texto { get; set; }
        public string respuesta_texto { get; set; }
        public decimal? respuesta_numero { get; set; }
        public string respuesta_unidad { get; set; }
        public bool respuesta_fuera_rango { get; set; }
        public string respuesta_comentario { get; set; }
        public int? orden_trabajo_id { get; set; }
        public int? orden_trabajo_correlativo { get; set; }
        public string orden_trabajo_estado { get; set; }
        public string confirmador_nombre { get; set; }
        public int total { get; set; }

        public int? filtro_instalacion { get; set; }
        public int? filtro_activo { get; set; }
        public int? filtro_severidad { get; set; }
        public int? filtro_estado { get; set; }
        public DateTime? filtro_desde { get; set; }
        public DateTime? filtro_hasta { get; set; }
        public string filtro { get; set; }
    }
}

namespace SitioBase.Controller
{
    public class ChecklistHallazgoController
    {
        public List<ChecklistHallazgo> GetHallazgos(ChecklistHallazgo filtro)
        {
            List<ChecklistHallazgo> lista = new List<ChecklistHallazgo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CHECKLIST_HALLAZGO";
                    Filtrar(cmd, filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ChecklistHallazgo h = new ChecklistHallazgo();
                            h.cha_id = int.Parse(dr["CHA_ID"].ToString());
                            h.cha_uuid = (Guid)dr["CHA_UUID"];
                            h.cha_titulo = dr["CHA_TITULO"].ToString();
                            h.cha_descripcion = dr["CHA_DESCRIPCION"].ToString();
                            if (dr["CHA_FECHA_CREACION"] != DBNull.Value) h.cha_fecha_creacion = (DateTime)dr["CHA_FECHA_CREACION"];
                            h.cha_generado_ia = dr["CHA_GENERADO_IA"] != DBNull.Value && (bool)dr["CHA_GENERADO_IA"];
                            if (dr["CHA_CONFIANZA_IA"] != DBNull.Value) h.cha_confianza_ia = decimal.Parse(dr["CHA_CONFIANZA_IA"].ToString());
                            h.cha_motivo_descarte = dr["CHA_MOTIVO_DESCARTE"].ToString();
                            if (dr["CHA_FECHA_CONFIRMACION"] != DBNull.Value) h.cha_fecha_confirmacion = (DateTime)dr["CHA_FECHA_CONFIRMACION"];
                            if (dr["SEVERIDAD_ID"] != DBNull.Value) h.severidad_id = int.Parse(dr["SEVERIDAD_ID"].ToString());
                            h.severidad_codigo = dr["SEVERIDAD_CODIGO"].ToString();
                            h.severidad_nombre = dr["SEVERIDAD_NOMBRE"].ToString();
                            h.criticidad_nombre = dr["CRITICIDAD_NOMBRE"].ToString();
                            if (dr["ESTADO_ID"] != DBNull.Value) h.estado_id = int.Parse(dr["ESTADO_ID"].ToString());
                            h.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                            h.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            if (dr["ACTIVO_ID"] != DBNull.Value) h.activo_id = int.Parse(dr["ACTIVO_ID"].ToString());
                            h.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            h.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            h.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            h.componente_nombre = dr["COMPONENTE_NOMBRE"].ToString();
                            h.ejecucion_id = int.Parse(dr["EJECUCION_ID"].ToString());
                            if (dr["EJECUCION_FECHA"] != DBNull.Value) h.ejecucion_fecha = (DateTime)dr["EJECUCION_FECHA"];
                            h.plantilla_codigo = dr["PLANTILLA_CODIGO"].ToString();
                            h.plantilla_nombre = dr["PLANTILLA_NOMBRE"].ToString();
                            h.ejecutor_nombre = dr["EJECUTOR_NOMBRE"].ToString();
                            h.item_texto = dr["ITEM_TEXTO"].ToString();
                            h.respuesta_texto = dr["RESPUESTA_TEXTO"].ToString();
                            if (dr["RESPUESTA_NUMERO"] != DBNull.Value) h.respuesta_numero = decimal.Parse(dr["RESPUESTA_NUMERO"].ToString());
                            h.respuesta_unidad = dr["RESPUESTA_UNIDAD"].ToString();
                            h.respuesta_fuera_rango = dr["RESPUESTA_FUERA_RANGO"] != DBNull.Value && (bool)dr["RESPUESTA_FUERA_RANGO"];
                            h.respuesta_comentario = dr["RESPUESTA_COMENTARIO"].ToString();
                            if (dr["ORDEN_TRABAJO_ID"] != DBNull.Value) h.orden_trabajo_id = int.Parse(dr["ORDEN_TRABAJO_ID"].ToString());
                            if (dr["ORDEN_TRABAJO_CORRELATIVO"] != DBNull.Value) h.orden_trabajo_correlativo = int.Parse(dr["ORDEN_TRABAJO_CORRELATIVO"].ToString());
                            h.orden_trabajo_estado = dr["ORDEN_TRABAJO_ESTADO"].ToString();
                            h.confirmador_nombre = dr["CONFIRMADOR_NOMBRE"].ToString();
                            h.total = int.Parse(dr["TOTAL"].ToString());
                            lista.Add(h);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public void Exportar(ChecklistHallazgo filtro)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "RPT_CHECKLIST_HALLAZGO_EXCEL";
            Filtrar(cmd, filtro);

            DataTable datos = Conexion.GetDataTable(cmd);
            byte[] binario = Tools.Excel.exportExcelXLSX_Bytes(datos, true);
            string archivo = "HALLAZGOS " + DateTime.Now.ToString("dd-MM-yyyy");

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
            HttpContext.Current.Response.ContentEncoding = Encoding.Default;
            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + archivo + ".xlsx");
            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }

        /// <summary>Convierte el hallazgo en una orden (origen HALLAZGO CHECKLIST). Idempotente: devuelve la que ya tenia.</summary>
        public Respuesta GenerarOrden(int hallazgo)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) { respuesta.error = true; respuesta.codigo = -1; respuesta.detalle = "La sesion no es valida o expiro."; return respuesta; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("INS_ORDEN_TRABAJO_HALLAZGO");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@HALLAZGO", hallazgo);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                int correlativo = 0; bool yaExistia = false;
                using (SqlDataReader dr = cmd.ExecuteReader())
                    if (dr.Read()) { correlativo = int.Parse(dr["OTR_CORRELATIVO"].ToString()); yaExistia = (bool)dr["YA_EXISTIA"]; }
                cmd.Connection.Close();

                respuesta.codigo = cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value;
                respuesta.detalle = "OT-" + correlativo + (yaExistia ? " (ya existía)" : " generada");
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1; respuesta.detalle = ex.Message; respuesta.error = true;
            }
            return respuesta;
        }

        /// <summary>Descarta con motivo (el SP exige al menos 10 caracteres) y deja quien y cuando.</summary>
        public Respuesta Descartar(int hallazgo, string motivo)
        {
            Respuesta respuesta = new Respuesta();
            if (!Token.TokenSeguridad()) { respuesta.error = true; respuesta.codigo = -1; respuesta.detalle = "La sesion no es valida o expiro."; return respuesta; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPD_CHECKLIST_HALLAZGO_DESCARTAR");
                cmd.Parameters.AddWithValue("@ID", hallazgo);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@MOTIVO", motivo ?? "");
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();
                respuesta.codigo = hallazgo; respuesta.detalle = "Hallazgo descartado."; respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1; respuesta.detalle = ex.Message; respuesta.error = true;
            }
            return respuesta;
        }

        /// <summary>El cliente va SIEMPRE desde la sesion: lo de otra empresa no se ve aunque se conozca el id.</summary>
        private static void Filtrar(SqlCommand cmd, ChecklistHallazgo f)
        {
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            if (f == null) return;
            if (f.cha_id > 0) cmd.Parameters.AddWithValue("@ID", f.cha_id);
            if (f.filtro_instalacion != null && f.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", f.filtro_instalacion);
            if (f.filtro_activo != null && f.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", f.filtro_activo);
            if (f.filtro_severidad != null && f.filtro_severidad > 0) cmd.Parameters.AddWithValue("@SEVERIDAD", f.filtro_severidad);
            if (f.filtro_estado != null && f.filtro_estado > 0) cmd.Parameters.AddWithValue("@ESTADO", f.filtro_estado);
            if (f.filtro_desde != null) cmd.Parameters.AddWithValue("@DESDE", f.filtro_desde.Value.Date);
            if (f.filtro_hasta != null) cmd.Parameters.AddWithValue("@HASTA", f.filtro_hasta.Value.Date);
            if (!string.IsNullOrEmpty(f.filtro)) cmd.Parameters.AddWithValue("@FILTRO", f.filtro);
        }
    }
}
