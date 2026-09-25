using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>
    /// Una ocurrencia de tarea: lo que la programacion genero para un dia, con
    /// su ejecucion si ya paso.
    ///
    /// El RESPONSABLE sale de la programacion -es quien tiene que hacerla- y el
    /// EJECUTOR de la ejecucion -quien la hizo-. No siempre son el mismo, y esa
    /// diferencia es justo lo que se mira al revisar una tarea.
    /// </summary>
    [Serializable]
    public class TareaOcurrencia
    {
        public int toc_id { get; set; }
        public int tarea { get; set; }
        public int? programacion_id { get; set; }
        public DateTime? prevista { get; set; }
        public DateTime? limite { get; set; }
        public int estado_id { get; set; }
        public string estado_codigo { get; set; }
        public string estado_nombre { get; set; }
        public string observacion { get; set; }
        public int? orden_trabajo { get; set; }

        public string programacion { get; set; }
        public int? responsable_id { get; set; }
        public string responsable { get; set; }
        public string grupo { get; set; }

        public int? ejecucion_id { get; set; }
        public string ejecutor { get; set; }
        public DateTime? inicio { get; set; }
        public DateTime? fin { get; set; }
        public int? minutos { get; set; }
        public string resultado { get; set; }
        public bool? conforme { get; set; }
        public string dispositivo { get; set; }

        public int comentarios { get; set; }
        public int evidencias { get; set; }

        /// <summary>Ya se ejecuto: hay una ejecucion con fecha de termino.</summary>
        public bool ejecutada { get { return ejecucion_id != null && fin != null; } }

        /// <summary>
        /// De donde vino la ejecucion. La app graba el modelo del telefono en
        /// tej_dispositivo; cuando no hay dispositivo no se inventa un origen:
        /// se dice que no quedo informado.
        /// </summary>
        public string origen
        {
            get
            {
                if (ejecucion_id == null) return "";
                return string.IsNullOrEmpty(dispositivo) ? "No informado" : "App móvil · " + dispositivo;
            }
        }
    }

    /// <summary>Una foto que el tecnico adjunto al ejecutar la tarea.</summary>
    [Serializable]
    public class TareaOcurrenciaArchivo
    {
        public int arc_id { get; set; }
        public string nombre { get; set; }
        public string mime { get; set; }
        public long bytes { get; set; }
        public DateTime? fecha { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
        public string usuario { get; set; }
        public bool es_imagen { get; set; }
        public bool es_video { get; set; }
        public bool es_audio { get; set; }
        public int ocurrencia { get; set; }
        public DateTime? ocurrencia_fecha { get; set; }

        public string etiqueta { get { return !string.IsNullOrEmpty(titulo) ? titulo : nombre; } }

        /// <summary>Lo que no es imagen, video ni audio: un PDF, una planilla.</summary>
        public bool es_documento { get { return !es_imagen && !es_video && !es_audio; } }
    }

    /// <summary>
    /// Las ocurrencias de una tarea, leidas desde el escritorio.
    ///
    /// POR QUE NO SIRVE EL SP DE LA APP
    ///   SEL_TAREA_EJECUCION filtra por usuario y por las plantas donde esa
    ///   persona esta asignada, que es lo correcto para descargar al telefono
    ///   y lo inutil para revisar una tarea: quien la revisa no es quien la
    ///   ejecuta. Estos SP leen por TAREA.
    /// </summary>
    public class TareaOcurrenciaController
    {
        public List<TareaOcurrencia> Get(int tarea, DateTime? desde = null, DateTime? hasta = null,
                                         int? estado = null, int? responsable = null)
        {
            List<TareaOcurrencia> lista = new List<TareaOcurrencia>();

            if (tarea <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_TAREA_OCURRENCIA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@TAREA", tarea);
                if (desde != null) cmd.Parameters.AddWithValue("@DESDE", desde.Value);
                if (hasta != null) cmd.Parameters.AddWithValue("@HASTA", hasta.Value);
                if (estado != null) cmd.Parameters.AddWithValue("@ESTADO", estado.Value);
                if (responsable != null) cmd.Parameters.AddWithValue("@RESPONSABLE", responsable.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        TareaOcurrencia o = new TareaOcurrencia();

                        o.toc_id = int.Parse(dr["toc_id"].ToString());
                        o.tarea = int.Parse(dr["toc_tarea"].ToString());
                        if (dr["toc_tarea_programacion"] != DBNull.Value) o.programacion_id = int.Parse(dr["toc_tarea_programacion"].ToString());
                        if (dr["toc_fecha_programada_utc"] != DBNull.Value) o.prevista = (DateTime)dr["toc_fecha_programada_utc"];
                        if (dr["toc_fecha_limite_utc"] != DBNull.Value) o.limite = (DateTime)dr["toc_fecha_limite_utc"];
                        o.estado_id = int.Parse(dr["toc_tarea_ocurrencia_estado"].ToString());
                        o.estado_codigo = dr["ESTADO_CODIGO"].ToString();
                        o.estado_nombre = dr["ESTADO_NOMBRE"].ToString();
                        o.observacion = dr["OBSERVACION"].ToString();
                        if (dr["toc_orden_trabajo"] != DBNull.Value) o.orden_trabajo = int.Parse(dr["toc_orden_trabajo"].ToString());

                        o.programacion = dr["PROGRAMACION_NOMBRE"].ToString();
                        if (dr["RESPONSABLE_ID"] != DBNull.Value) o.responsable_id = int.Parse(dr["RESPONSABLE_ID"].ToString());
                        o.responsable = dr["RESPONSABLE_NOMBRE"].ToString();
                        o.grupo = dr["GRUPO_NOMBRE"].ToString();

                        if (dr["EJECUCION_ID"] != DBNull.Value) o.ejecucion_id = int.Parse(dr["EJECUCION_ID"].ToString());
                        o.ejecutor = dr["EJECUTOR_NOMBRE"].ToString();
                        if (dr["EJECUCION_INICIO"] != DBNull.Value) o.inicio = (DateTime)dr["EJECUCION_INICIO"];
                        if (dr["EJECUCION_FIN"] != DBNull.Value) o.fin = (DateTime)dr["EJECUCION_FIN"];
                        if (dr["EJECUCION_MINUTOS"] != DBNull.Value) o.minutos = int.Parse(dr["EJECUCION_MINUTOS"].ToString());
                        o.resultado = dr["EJECUCION_RESULTADO"].ToString();
                        if (dr["EJECUCION_CONFORME"] != DBNull.Value) o.conforme = bool.Parse(dr["EJECUCION_CONFORME"].ToString());
                        o.dispositivo = dr["EJECUCION_DISPOSITIVO"].ToString();

                        o.comentarios = int.Parse(dr["COMENTARIOS"].ToString());
                        o.evidencias = int.Parse(dr["EVIDENCIAS"].ToString());

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
        /// TODAS las evidencias de la tarea, con la ocurrencia de la que vino
        /// cada una. Es lo que la galeria necesita para poder filtrar; el otro
        /// metodo, el de una sola ocurrencia, es para el panel de detalle.
        /// </summary>
        public List<TareaOcurrenciaArchivo> GetEvidenciasTarea(int tarea)
        {
            List<TareaOcurrenciaArchivo> lista = new List<TareaOcurrenciaArchivo>();

            if (tarea <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_TAREA_ARCHIVO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@TAREA", tarea);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        TareaOcurrenciaArchivo a = new TareaOcurrenciaArchivo();

                        a.arc_id = int.Parse(dr["arc_id"].ToString());
                        a.nombre = dr["arc_nombre_original"].ToString();
                        a.mime = dr["arc_mime"].ToString();
                        a.bytes = long.Parse(dr["arc_byte"].ToString());
                        if (dr["arc_fecha_creacion"] != DBNull.Value) a.fecha = (DateTime)dr["arc_fecha_creacion"];
                        a.titulo = dr["AVI_TITULO"].ToString();
                        a.descripcion = dr["AVI_DESCRIPCION"].ToString();
                        a.usuario = dr["USUARIO_NOMBRE"].ToString();
                        a.es_imagen = int.Parse(dr["ES_IMAGEN"].ToString()) == 1;
                        a.es_video = int.Parse(dr["ES_VIDEO"].ToString()) == 1;
                        a.es_audio = int.Parse(dr["ES_AUDIO"].ToString()) == 1;
                        a.ocurrencia = int.Parse(dr["OCURRENCIA_ID"].ToString());
                        if (dr["OCURRENCIA_FECHA"] != DBNull.Value) a.ocurrencia_fecha = (DateTime)dr["OCURRENCIA_FECHA"];

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

        public List<TareaOcurrenciaArchivo> GetEvidencias(int ocurrencia)
        {
            List<TareaOcurrenciaArchivo> lista = new List<TareaOcurrenciaArchivo>();

            if (ocurrencia <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_TAREA_OCURRENCIA_ARCHIVO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@OCURRENCIA", ocurrencia);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        TareaOcurrenciaArchivo a = new TareaOcurrenciaArchivo();

                        a.arc_id = int.Parse(dr["arc_id"].ToString());
                        a.nombre = dr["arc_nombre_original"].ToString();
                        a.mime = dr["arc_mime"].ToString();
                        a.bytes = long.Parse(dr["arc_byte"].ToString());
                        if (dr["arc_fecha_creacion"] != DBNull.Value) a.fecha = (DateTime)dr["arc_fecha_creacion"];
                        a.titulo = dr["AVI_TITULO"].ToString();
                        a.descripcion = dr["AVI_DESCRIPCION"].ToString();
                        a.usuario = dr["USUARIO_NOMBRE"].ToString();
                        a.es_imagen = int.Parse(dr["ES_IMAGEN"].ToString()) == 1;

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
