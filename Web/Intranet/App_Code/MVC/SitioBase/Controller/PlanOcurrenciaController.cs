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
            string archivo = "CALENDARIO " + (string.IsNullOrEmpty(sufijo) ? "" : sufijo + " ") + global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy");

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

        /// <summary>
        /// HU-076: genera las ocurrencias que faltan del plan (o de todos) en el
        /// horizonte. El SP es idempotente; el detalle resume que se genero.
        /// </summary>
        public Respuesta GenerarOcurrencias(int? plan, int horizonteDias)
        {
            return Generar("GEN_PLAN_OCURRENCIAS", "@PLAN", plan, horizonteDias,
                dr => dr["PLAN_CODIGO"] + " · " + dr["HITO_CODIGO"] + ": " + dr["GENERADAS"] + " en " + dr["EQUIPOS"] + " equipo(s)");
        }

        internal static Respuesta Generar(string sp, string parametroEntidad, int? entidad, int horizonteDias, Func<SqlDataReader, string> linea)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand(sp);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue(parametroEntidad, (object)entidad ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HORIZONTE_DIA", horizonteDias);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.Parameters.AddWithValue("@GENERADAS", 0).Direction = ParameterDirection.Output;

                    StringBuilder sb = new StringBuilder();
                    using (SqlDataReader dr = cmd.ExecuteReader())
                        while (dr.Read()) sb.Append("<br/>· ").Append(linea(dr));
                    cmd.Connection.Close();

                    int n = cmd.Parameters["@GENERADAS"].Value == DBNull.Value ? 0 : (int)cmd.Parameters["@GENERADAS"].Value;
                    respuesta.codigo = n;
                    respuesta.detalle = n == 0
                        ? "No había ocurrencias nuevas que generar en los próximos " + horizonteDias + " días."
                        : n + " ocurrencia(s) generada(s) para los próximos " + horizonteDias + " días." + sb;
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

        /* ==================================================================
           REPROGRAMAR (HU-086)

           Lo de arriba es el calendario: leer, exportar y generar. Lo de aca
           abajo es mover una cita de fecha, que es un proceso del SP
           (PLAN_OCURRENCIA_REPROGRAMAR): la ocurrencia no cambia de dia, pasa
           a REPROGRAMADA y nace otra en la fecha nueva, ligada por el origen.

           Las dos cosas viven en el mismo controlador porque son la misma
           tabla: separarlas obligaba a que dos clases supieran leer la misma
           fila, y esas dos lecturas se separan a la primera columna nueva.
           ================================================================== */

        /// <summary>Ficha de una ocurrencia (para cargar la pantalla y ver el resultado).</summary>
        public PlanOcurrencia GetOcurrencia(int id, int cliente)
        {
            PlanOcurrencia o = null;
            if (id <= 0) return null;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_PLAN_OCURRENCIA_REPROGRAMAR";
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente > 0 ? cliente : Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            o = new PlanOcurrencia();
                            o.pmo_id = int.Parse(dr["PMO_ID"].ToString());
                            o.pmo_cliente = int.Parse(dr["PMO_CLIENTE"].ToString());
                            o.pmo_estado = int.Parse(dr["PMO_ESTADO"].ToString());
                            o.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                            if (dr["PMO_FECHA_PROGRAMADA"] != DBNull.Value) o.pmo_fecha_programada = DateTime.Parse(dr["PMO_FECHA_PROGRAMADA"].ToString());
                            if (dr["PMO_FECHA_ORIGINAL"] != DBNull.Value) o.pmo_fecha_original = DateTime.Parse(dr["PMO_FECHA_ORIGINAL"].ToString());
                            if (dr["PMO_OCURRENCIA_ORIGEN"] != DBNull.Value) o.pmo_ocurrencia_origen = int.Parse(dr["PMO_OCURRENCIA_ORIGEN"].ToString());
                            o.pmo_observacion = dr["PMO_OBSERVACION"].ToString();
                            if (dr["PMO_ORDEN_TRABAJO"] != DBNull.Value) o.pmo_orden_trabajo = int.Parse(dr["PMO_ORDEN_TRABAJO"].ToString());
                            o.pmo_activo = int.Parse(dr["PMO_ACTIVO"].ToString());
                            o.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                            o.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            o.hito_codigo = dr["HITO_CODIGO"].ToString();
                            o.hito_nombre = dr["HITO_NOMBRE"].ToString();
                            o.plan_codigo = dr["PLAN_CODIGO"].ToString();
                            o.plan_nombre = dr["PLAN_NOMBRE"].ToString();
                            if (dr["PMO_FECHA_ACTUALIZACION"] != DBNull.Value) o.pmo_fecha_actualizacion = DateTime.Parse(dr["PMO_FECHA_ACTUALIZACION"].ToString());
                            o.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();
                            if (dr["PMO_FECHA_NUEVA"] != DBNull.Value) o.pmo_fecha_nueva = DateTime.Parse(dr["PMO_FECHA_NUEVA"].ToString());
                            if (dr["PMO_OCURRENCIA_NUEVA"] != DBNull.Value) o.pmo_ocurrencia_nueva = int.Parse(dr["PMO_OCURRENCIA_NUEVA"].ToString());
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    o = null;
                }
            }
            return o;
        }

        /// <summary>
        /// Reprograma la ocurrencia a una nueva fecha, con motivo obligatorio.
        /// Las reglas (estado, colisión, carrera) están en el SP. Devuelve en
        /// r.codigo el id de la ocurrencia nueva.
        /// </summary>
        public Respuesta Reprogramar(int id, DateTime nuevaFecha, string motivo)
        {
            Respuesta r = new Respuesta();
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("PLAN_OCURRENCIA_REPROGRAMAR");
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@NUEVA_FECHA", nuevaFecha);
                    cmd.Parameters.AddWithValue("@MOTIVO", string.IsNullOrEmpty(motivo) ? (object)DBNull.Value : motivo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    SqlParameter pn = cmd.Parameters.Add("@NUEVO_ID", SqlDbType.Int);
                    pn.Direction = ParameterDirection.Output;
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    r.codigo = pn.Value != DBNull.Value ? (int)pn.Value : 0;
                    r.detalle = "Ocurrencia reprogramada con éxito.";
                    r.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    r.codigo = -1; r.detalle = ex.Message; r.error = true;
                }
            }
            else
            {
                r.codigo = -1;
                r.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                r.error = true;
            }
            return r;
        }
    }
}
