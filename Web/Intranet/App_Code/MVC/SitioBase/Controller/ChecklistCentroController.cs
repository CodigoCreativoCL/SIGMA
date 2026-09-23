using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>
    /// Una ronda con fecha: la programacion la genero y alguien tiene que
    /// hacerla. Trae su ejecucion cuando ya paso.
    /// </summary>
    [Serializable]
    public class ChecklistOcurrencia
    {
        public int coc_id { get; set; }
        public int? programacion_id { get; set; }
        public int version_id { get; set; }
        public int version_numero { get; set; }
        public DateTime? prevista { get; set; }
        public DateTime? limite { get; set; }
        public int estado_id { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }

        public int? activo_id { get; set; }
        public string activo_codigo { get; set; }
        public string activo_nombre { get; set; }
        public string area { get; set; }
        public string recurrencia { get; set; }
        public string programacion { get; set; }
        public int? responsable_id { get; set; }
        public string responsable { get; set; }

        public int? ejecucion_id { get; set; }
        public string ejecutor { get; set; }
        public DateTime? inicio { get; set; }
        public DateTime? fin { get; set; }
        public int? minutos { get; set; }
        public int item_total { get; set; }
        public int item_respondido { get; set; }
        public int item_no_conforme { get; set; }
        public string observacion { get; set; }
        public string dispositivo { get; set; }
        public int hallazgos { get; set; }

        public bool ejecutada { get { return ejecucion_id != null && fin != null; } }

        /// <summary>Que tanto de la ronda quedo respondido, de 0 a 100.</summary>
        public int avance
        {
            get { return item_total <= 0 ? 0 : (int)Math.Round(item_respondido * 100.0 / item_total); }
        }

        /// <summary>
        /// De donde vino la ejecucion. La app graba el modelo del telefono;
        /// cuando no hay dispositivo no se inventa un origen.
        /// </summary>
        public string origen
        {
            get
            {
                if (ejecucion_id == null) return "";
                return string.IsNullOrEmpty(dispositivo) ? "No informado" : "App móvil · " + dispositivo;
            }
        }

        public string donde
        {
            get
            {
                if (!string.IsNullOrEmpty(activo_codigo)) return activo_codigo + " · " + activo_nombre;
                return string.IsNullOrEmpty(area) ? "Sin objetivo" : area;
            }
        }
    }

    /// <summary>Un item de la pauta con lo que el tecnico respondio, si respondio.</summary>
    [Serializable]
    public class ChecklistRespuesta
    {
        public int item_id { get; set; }
        public int orden { get; set; }
        public string texto { get; set; }
        public string ayuda { get; set; }
        public bool obligatorio { get; set; }
        public bool requiere_evidencia { get; set; }
        public string seccion { get; set; }
        public int seccion_orden { get; set; }
        public string tipo_codigo { get; set; }
        public string tipo_nombre { get; set; }
        public string unidad { get; set; }

        public int? respuesta_id { get; set; }
        public bool fuera_rango { get; set; }
        public bool no_aplica { get; set; }
        public string comentario { get; set; }
        public DateTime? fecha { get; set; }
        public string valor { get; set; }
        public int evidencias { get; set; }

        public bool respondido { get { return respuesta_id != null; } }
    }

    /// <summary>Una foto que el tecnico adjunto a una respuesta.</summary>
    [Serializable]
    public class ChecklistArchivo
    {
        public int arc_id { get; set; }
        public string nombre { get; set; }
        public string mime { get; set; }
        public DateTime? fecha { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
        public string usuario { get; set; }
        public int? respuesta_id { get; set; }
        public string item { get; set; }
        public string seccion { get; set; }
        public bool es_imagen { get; set; }
        public bool es_video { get; set; }
        public bool es_audio { get; set; }

        public string etiqueta { get { return !string.IsNullOrEmpty(titulo) ? titulo : nombre; } }
        public bool es_documento { get { return !es_imagen && !es_video && !es_audio; } }
    }

    /// <summary>
    /// El terreno de una pauta de inspeccion: lo que la programacion genero,
    /// lo que el tecnico respondio y lo que fotografio.
    ///
    /// POR QUE NO SIRVE EL SP DE LA APP
    ///   API_SEL_CHECKLIST filtra por usuario y por las plantas donde esa
    ///   persona esta asignada: correcto para descargar al telefono, inutil
    ///   para revisar una pauta desde el escritorio, porque quien la revisa no
    ///   es quien la ejecuta. Estos leen por PAUTA (bloque 266).
    /// </summary>
    public class ChecklistCentroController
    {
        public List<ChecklistOcurrencia> GetOcurrencias(int plantilla, DateTime? desde = null,
                                                        DateTime? hasta = null, int? estado = null)
        {
            List<ChecklistOcurrencia> lista = new List<ChecklistOcurrencia>();

            if (plantilla <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_OCURRENCIA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@PLANTILLA", plantilla);
                if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde.Value);
                if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta.Value);
                if (estado != null) cmd.Parameters.AddWithValue("@ESTADO", estado.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ChecklistOcurrencia o = new ChecklistOcurrencia();

                        o.coc_id = int.Parse(dr["coc_id"].ToString());
                        if (dr["coc_checklist_programacion"] != DBNull.Value) o.programacion_id = int.Parse(dr["coc_checklist_programacion"].ToString());
                        o.version_id = int.Parse(dr["coc_checklist_plantilla_version"].ToString());
                        o.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
                        if (dr["coc_fecha_programada_utc"] != DBNull.Value) o.prevista = (DateTime)dr["coc_fecha_programada_utc"];
                        if (dr["coc_fecha_limite_utc"] != DBNull.Value) o.limite = (DateTime)dr["coc_fecha_limite_utc"];
                        o.estado_id = int.Parse(dr["coc_checklist_ocurrencia_estado"].ToString());
                        o.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                        o.estado_nombre = dr["ESTADO_NOMBRE"].ToString();

                        if (dr["coc_activo"] != DBNull.Value) o.activo_id = int.Parse(dr["coc_activo"].ToString());
                        o.activo_codigo = dr["ACTIVO_CODIGO"].ToString();
                        o.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                        o.area = dr["AREA_NOMBRE"].ToString();
                        o.recurrencia = dr["PROGRAMACION_NOMBRE"].ToString();
                        o.programacion = dr["PROGRAMACION_TITULO"].ToString();
                        if (dr["RESPONSABLE_ID"] != DBNull.Value) o.responsable_id = int.Parse(dr["RESPONSABLE_ID"].ToString());
                        o.responsable = dr["RESPONSABLE_NOMBRE"].ToString();

                        if (dr["EJECUCION_ID"] != DBNull.Value) o.ejecucion_id = int.Parse(dr["EJECUCION_ID"].ToString());
                        o.ejecutor = dr["EJECUTOR_NOMBRE"].ToString();
                        if (dr["EJECUCION_INICIO"] != DBNull.Value) o.inicio = (DateTime)dr["EJECUCION_INICIO"];
                        if (dr["EJECUCION_FIN"] != DBNull.Value) o.fin = (DateTime)dr["EJECUCION_FIN"];
                        if (dr["EJECUCION_MINUTOS"] != DBNull.Value) o.minutos = int.Parse(dr["EJECUCION_MINUTOS"].ToString());
                        o.item_total = int.Parse(dr["ITEM_TOTAL"].ToString());
                        o.item_respondido = int.Parse(dr["ITEM_RESPONDIDO"].ToString());
                        o.item_no_conforme = int.Parse(dr["ITEM_NO_CONFORME"].ToString());
                        o.observacion = dr["EJECUCION_OBSERVACION"].ToString();
                        o.dispositivo = dr["EJECUCION_DISPOSITIVO"].ToString();
                        o.hallazgos = int.Parse(dr["HALLAZGOS"].ToString());

                        lista.Add(o);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        /// <summary>
        /// Todos los items de la version con su respuesta, o sin ella. Un item
        /// sin responder tambien dice algo -quedo pendiente-: omitirlo haria
        /// ver completa una ronda que no lo esta.
        /// </summary>
        public List<ChecklistRespuesta> GetRespuestas(int ejecucion)
        {
            List<ChecklistRespuesta> lista = new List<ChecklistRespuesta>();

            if (ejecucion <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_EJECUCION_RESPUESTA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@EJECUCION", ejecucion);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ChecklistRespuesta r = new ChecklistRespuesta();

                        r.item_id = int.Parse(dr["cpi_id"].ToString());
                        r.orden = int.Parse(dr["cpi_orden"].ToString());
                        r.texto = dr["cpi_texto"].ToString();
                        r.ayuda = dr["ITEM_AYUDA"].ToString();
                        r.obligatorio = (bool)dr["cpi_obligatorio"];
                        r.requiere_evidencia = (bool)dr["cpi_requiere_evidencia"];
                        r.seccion = dr["SECCION_NOMBRE"].ToString();
                        r.seccion_orden = int.Parse(dr["SECCION_ORDEN"].ToString());
                        r.tipo_codigo = dr["TIPO_CODIGO"].ToString();
                        r.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                        r.unidad = dr["UNIDAD"].ToString();

                        if (dr["RESPUESTA_ID"] != DBNull.Value) r.respuesta_id = int.Parse(dr["RESPUESTA_ID"].ToString());
                        if (dr["cer_fuera_rango"] != DBNull.Value) r.fuera_rango = (bool)dr["cer_fuera_rango"];
                        if (dr["cer_no_aplica"] != DBNull.Value) r.no_aplica = (bool)dr["cer_no_aplica"];
                        r.comentario = dr["COMENTARIO"].ToString();
                        if (dr["cer_fecha_respuesta_utc"] != DBNull.Value) r.fecha = (DateTime)dr["cer_fecha_respuesta_utc"];
                        r.valor = dr["VALOR"].ToString();
                        r.evidencias = int.Parse(dr["EVIDENCIAS"].ToString());

                        lista.Add(r);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }

        public List<ChecklistArchivo> GetEvidencias(int ejecucion)
        {
            List<ChecklistArchivo> lista = new List<ChecklistArchivo>();

            if (ejecucion <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_CHECKLIST_EJECUCION_ARCHIVO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@EJECUCION", ejecucion);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ChecklistArchivo a = new ChecklistArchivo();

                        a.arc_id = int.Parse(dr["arc_id"].ToString());
                        a.nombre = dr["arc_nombre_original"].ToString();
                        a.mime = dr["arc_mime"].ToString();
                        if (dr["arc_fecha_creacion"] != DBNull.Value) a.fecha = (DateTime)dr["arc_fecha_creacion"];
                        a.titulo = dr["AVI_TITULO"].ToString();
                        a.descripcion = dr["AVI_DESCRIPCION"].ToString();
                        a.usuario = dr["USUARIO_NOMBRE"].ToString();
                        if (dr["RESPUESTA_ID"] != DBNull.Value) a.respuesta_id = int.Parse(dr["RESPUESTA_ID"].ToString());
                        a.item = dr["ITEM_TEXTO"].ToString();
                        a.seccion = dr["SECCION_NOMBRE"].ToString();
                        a.es_imagen = int.Parse(dr["ES_IMAGEN"].ToString()) == 1;
                        a.es_video = int.Parse(dr["ES_VIDEO"].ToString()) == 1;
                        a.es_audio = int.Parse(dr["ES_AUDIO"].ToString()) == 1;

                        lista.Add(a);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }

            return lista;
        }
    }
}
