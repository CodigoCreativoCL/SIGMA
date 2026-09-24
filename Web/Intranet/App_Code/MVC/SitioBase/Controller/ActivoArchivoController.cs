using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;

namespace SitioBase.Controller
{
    /// <summary>Un documento adjunto de un activo (PDF, manual, plano…).</summary>
    [Serializable]
    public class ActivoArchivo
    {
        public int arc_id { get; set; }
        public string arc_nombre { get; set; }
        public string arc_mime { get; set; }
        public long arc_byte { get; set; }
        public bool es_imagen { get; set; }
    }

    /// <summary>
    /// Un archivo del equipo con SU ORIGEN. Puede ser un documento colgado de
    /// la ficha, la foto del equipo, o algo que alguien fotografio en terreno
    /// resolviendo una orden, pasando una inspeccion o ejecutando una tarea.
    /// </summary>
    [Serializable]
    public class ActivoArchivoOrigen
    {
        public int arc_id { get; set; }
        public string nombre { get; set; }
        public string mime { get; set; }
        public long bytes { get; set; }
        public DateTime? fecha { get; set; }
        public string origen { get; set; }          // FOTO | DOCUMENTO | ORDEN | INSPECCION | TAREA
        public string origen_nombre { get; set; }
        public string origen_codigo { get; set; }
        public int? orden_id { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
        public string usuario { get; set; }

        public bool es_imagen { get { return (mime ?? "").StartsWith("image", StringComparison.OrdinalIgnoreCase); } }

        /// <summary>Lo que el terreno adjunto, contra lo que vive en la ficha.</summary>
        public bool es_evidencia { get { return origen == "ORDEN" || origen == "INSPECCION" || origen == "TAREA"; } }

        public string etiqueta { get { return !string.IsNullOrEmpty(titulo) ? titulo : nombre; } }

        public string origen_etiqueta
        {
            get
            {
                if (!string.IsNullOrEmpty(origen_codigo)) return origen_nombre + " · " + origen_codigo;
                return origen_nombre;
            }
        }
    }

    /// <summary>
    /// Documentos opcionales de un activo (PDF, manuales, planos…). Reutiliza el
    /// sistema Archivo (Azure) y los enlaza por Archivo_Vinculo (avi_activo con
    /// avi_es_referencia = 0, para no mezclarse con la imagen del activo). Un
    /// activo puede tener VARIOS.
    /// </summary>
    public class ActivoArchivoController
    {
        /// <summary>
        /// TODOS los archivos del equipo, no solo los suyos.
        ///
        /// POR QUE NO BASTA GetArchivos
        ///   SEL_ACTIVO_ARCHIVO devuelve los documentos colgados del activo y
        ///   deja fuera su imagen a proposito. Para el centro eso se lee como
        ///   "este equipo no tiene archivos", cuando tiene su foto y todo lo
        ///   que el terreno fotografio en sus ordenes, inspecciones y tareas.
        ///   Ese es el material que alguien busca al abrir la galeria.
        /// </summary>
        public List<ActivoArchivoOrigen> GetTodos(int activo, int cliente)
        {
            List<ActivoArchivoOrigen> lista = new List<ActivoArchivoOrigen>();

            if (activo <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ACTIVO_ARCHIVO_TODO";
                cmd.Parameters.AddWithValue("@CLIENTE", cliente);
                cmd.Parameters.AddWithValue("@ACTIVO", activo);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        ActivoArchivoOrigen a = new ActivoArchivoOrigen();

                        a.arc_id = int.Parse(dr["ARC_ID"].ToString());
                        a.nombre = dr["NOMBRE"].ToString();
                        a.mime = dr["MIME"].ToString();
                        if (dr["BYTES"] != DBNull.Value) a.bytes = long.Parse(dr["BYTES"].ToString());
                        if (dr["FECHA"] != DBNull.Value) a.fecha = (DateTime)dr["FECHA"];
                        a.origen = dr["ORIGEN"].ToString();
                        a.origen_nombre = dr["ORIGEN_NOMBRE"].ToString();
                        a.origen_codigo = dr["ORIGEN_CODIGO"].ToString();
                        if (dr["ORDEN_ID"] != DBNull.Value) a.orden_id = int.Parse(dr["ORDEN_ID"].ToString());
                        a.titulo = dr["TITULO"].ToString();
                        a.descripcion = dr["DESCRIPCION"].ToString();
                        a.usuario = dr["USUARIO_NOMBRE"].ToString();

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

        public List<ActivoArchivo> GetArchivos(int activo, int cliente)
        {
            List<ActivoArchivo> lista = new List<ActivoArchivo>();
            if (activo <= 0) return lista;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_ACTIVO_ARCHIVO";
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@CLIENTE", cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ActivoArchivo a = new ActivoArchivo();
                            a.arc_id = int.Parse(dr["ARC_ID"].ToString());
                            a.arc_nombre = dr["ARC_NOMBRE"].ToString();
                            a.arc_mime = dr["ARC_MIME"] != DBNull.Value ? dr["ARC_MIME"].ToString() : "";
                            if (dr["ARC_BYTE"] != DBNull.Value) a.arc_byte = long.Parse(dr["ARC_BYTE"].ToString());
                            a.es_imagen = a.arc_mime.StartsWith("image", StringComparison.OrdinalIgnoreCase);
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
                    lista = null;
                }
            }
            return lista;
        }

        /// <summary>Enlaza un Archivo ya subido como documento del activo.</summary>
        public int Vincular(int activo, int archivo)
        {
            int id = -1;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    int salida = 0;
                    cmd = Conexion.GetCommand("VIN_ACTIVO_ARCHIVO");
                    cmd.Parameters.AddWithValue("@ID", salida).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@ARCHIVO", archivo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    id = (int)cmd.Parameters["@ID"].Value;
                }
                catch (Exception)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    id = -1;
                }
            }
            return id;
        }

        /// <summary>Quita (baja lógica) un documento del activo.</summary>
        public bool Desvincular(int activo, int archivo)
        {
            bool ok = false;
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;
                try
                {
                    cmd = Conexion.GetCommand("DEL_ACTIVO_ARCHIVO");
                    cmd.Parameters.AddWithValue("@ACTIVO", activo);
                    cmd.Parameters.AddWithValue("@ARCHIVO", archivo);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();
                    ok = true;
                }
                catch (Exception)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    ok = false;
                }
            }
            return ok;
        }
    }
}
