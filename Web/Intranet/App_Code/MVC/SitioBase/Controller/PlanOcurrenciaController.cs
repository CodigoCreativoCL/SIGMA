using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Calendario de mantenimiento (HU-085). Solo lectura: el SP pagina y
    /// devuelve el total en cada fila; la exportacion baja lo mismo con los
    /// encabezados de la planilla, sin paginar.
    /// </summary>
    public class PlanOcurrenciaController
    {
        public List<PlanOcurrencia> GetCalendario(PlanOcurrencia filtro)
        {
            List<PlanOcurrencia> lista = new List<PlanOcurrencia>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PLAN_CALENDARIO";
                    Filtrar(cmd, filtro);
                    if (filtro != null && filtro.pagina != null) cmd.Parameters.AddWithValue("@PAGINA", filtro.pagina);
                    if (filtro != null && filtro.tamano != null) cmd.Parameters.AddWithValue("@TAMANO", filtro.tamano);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            PlanOcurrencia item = new PlanOcurrencia();

                            item.pmo_id = int.Parse(dr["PMO_ID"].ToString());
                            item.pmo_uuid = (Guid)dr["PMO_UUID"];
                            item.fecha_programada = (DateTime)dr["FECHA_PROGRAMADA"];
                            if (dr["FECHA_LIMITE"] != DBNull.Value) item.fecha_limite = (DateTime)dr["FECHA_LIMITE"];
                            if (dr["FECHA_DISPONIBLE"] != DBNull.Value) item.fecha_disponible = (DateTime)dr["FECHA_DISPONIBLE"];
                            if (dr["FECHA_ORIGINAL"] != DBNull.Value) item.fecha_original = (DateTime)dr["FECHA_ORIGINAL"];
                            item.mes = dr["MES"].ToString();

                            item.plan_id = int.Parse(dr["PLAN_ID"].ToString());
                            item.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            item.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            if (dr["VERSION_NUMERO"] != DBNull.Value) item.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());

                            item.hito_id = int.Parse(dr["HITO_ID"].ToString());
                            item.hito_codigo = dr["HITO_CODIGO"].ToString();
                            item.hito_nombre = dr["HITO_NOMBRE"].ToString();
                            item.es_overhaul = dr["ES_OVERHAUL"] != DBNull.Value && (bool)dr["ES_OVERHAUL"];
                            item.requiere_parada = dr["REQUIERE_PARADA"] != DBNull.Value && (bool)dr["REQUIERE_PARADA"];
                            if (dr["DURACION_ESTIMADA_MINUTO"] != DBNull.Value) item.duracion_estimada_minuto = int.Parse(dr["DURACION_ESTIMADA_MINUTO"].ToString());

                            item.activo_id = int.Parse(dr["ACTIVO_ID"].ToString());
                            item.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.planta_nombre = dr["PLANTA_NOMBRE"].ToString();
                            item.componente_nombre = dr["COMPONENTE_NOMBRE"].ToString();
                            if (dr["VALOR_MEDIDOR_OBJETIVO"] != DBNull.Value) item.valor_medidor_objetivo = decimal.Parse(dr["VALOR_MEDIDOR_OBJETIVO"].ToString());

                            item.estado_id = int.Parse(dr["ESTADO_ID"].ToString());
                            item.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                            item.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            item.situacion = dr["SITUACION"].ToString();
                            item.dias_restantes = int.Parse(dr["DIAS_RESTANTES"].ToString());
                            item.fue_reprogramada = dr["FUE_REPROGRAMADA"].ToString() == "1";

                            if (dr["ORDEN_TRABAJO_ID"] != DBNull.Value) item.orden_trabajo_id = int.Parse(dr["ORDEN_TRABAJO_ID"].ToString());
                            if (dr["ORDEN_TRABAJO_CORRELATIVO"] != DBNull.Value) item.orden_trabajo_correlativo = int.Parse(dr["ORDEN_TRABAJO_CORRELATIVO"].ToString());
                            item.orden_trabajo_titulo = dr["ORDEN_TRABAJO_TITULO"].ToString();
                            item.observacion = dr["OBSERVACION"].ToString();
                            item.total = int.Parse(dr["TOTAL"].ToString());

                            lista.Add(item);
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

        /// <summary>
        /// Baja a Excel lo que se esta viendo, con el MISMO filtro de la
        /// pantalla y sin paginar: quien filtro «octubre» espera octubre.
        /// </summary>
        public void ExportarCalendario(PlanOcurrencia filtro, string sufijo)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "RPT_PLAN_CALENDARIO_EXCEL";
            Filtrar(cmd, filtro);

            DataTable datos = Conexion.GetDataTable(cmd);
            byte[] binario = Tools.Excel.exportExcelXLSX_Bytes(datos, true);
            string archivo = "CALENDARIO " + (string.IsNullOrEmpty(sufijo) ? "" : sufijo + " ") + DateTime.Now.ToString("dd-MM-yyyy");

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/vnd.ms-excel";
            HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
            HttpContext.Current.Response.ContentEncoding = Encoding.Default;
            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + archivo + ".xlsx");
            HttpContext.Current.Response.BinaryWrite(binario);
            HttpContext.Current.Response.End();
        }

        /// <summary>
        /// Genera la orden de trabajo de una ocurrencia (HU-111). Las reglas
        /// viven en el SP: si la ocurrencia ya tiene orden devuelve esa
        /// (YA_EXISTIA), asi que la generacion masiva puede reintentar.
        /// </summary>
        public Respuesta GenerarOrden(int ocurrencia)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("INS_ORDEN_TRABAJO_OCURRENCIA");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@OCURRENCIA", ocurrencia);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    int correlativo = 0; bool yaExistia = false;
                    using (SqlDataReader dr = cmd.ExecuteReader())
                    {
                        if (dr.Read())
                        {
                            correlativo = int.Parse(dr["OTR_CORRELATIVO"].ToString());
                            yaExistia = (bool)dr["YA_EXISTIA"];
                        }
                    }
                    cmd.Connection.Close();

                    respuesta.codigo = cmd.Parameters["@ID"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "OT-" + correlativo + (yaExistia ? " (ya existía)" : " generada");
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }
            else
            {
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>Los mismos parametros para consultar y para exportar. El cliente va SIEMPRE desde la sesion.</summary>
        private static void Filtrar(SqlCommand cmd, PlanOcurrencia filtro)
        {
            cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
            if (filtro == null) return;

            if (filtro.filtro_plan != null && filtro.filtro_plan > 0) cmd.Parameters.AddWithValue("@PLAN", filtro.filtro_plan);
            if (filtro.filtro_activo != null && filtro.filtro_activo > 0) cmd.Parameters.AddWithValue("@ACTIVO", filtro.filtro_activo);
            if (filtro.filtro_instalacion != null && filtro.filtro_instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", filtro.filtro_instalacion);
            if (filtro.filtro_estado != null && filtro.filtro_estado > 0) cmd.Parameters.AddWithValue("@ESTADO", filtro.filtro_estado);
            if (filtro.filtro_desde != null) cmd.Parameters.AddWithValue("@DESDE", filtro.filtro_desde.Value.Date);
            if (filtro.filtro_hasta != null) cmd.Parameters.AddWithValue("@HASTA", filtro.filtro_hasta.Value.Date);
            if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
        }
    }
}
