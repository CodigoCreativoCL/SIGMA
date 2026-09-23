using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>Un archivo de la orden: lo que el tecnico mando desde la app.</summary>
    [Serializable]
    public class OrdenTrabajoArchivo
    {
        public int arc_id { get; set; }
        public string nombre { get; set; }
        public string mime { get; set; }
        public long bytes { get; set; }
        public DateTime? fecha { get; set; }
        public string categoria_codigo { get; set; }
        public string categoria_nombre { get; set; }
        public string titulo { get; set; }
        public string descripcion { get; set; }
        public int? paso_id { get; set; }
        public int paso_orden { get; set; }
        public string paso_nombre { get; set; }
        public string usuario { get; set; }
        public bool es_imagen { get; set; }
        public bool es_video { get; set; }
        public bool es_audio { get; set; }

        /// <summary>Lo que no es imagen ni video ni audio: un PDF, una planilla.</summary>
        public bool es_documento { get { return !es_imagen && !es_video && !es_audio; } }

        /// <summary>El titulo que se muestra: el que puso quien lo subio, o el nombre del archivo.</summary>
        public string etiqueta
        {
            get { return !string.IsNullOrEmpty(titulo) ? titulo : nombre; }
        }
    }

    /// <summary>
    /// Las evidencias de una orden de trabajo.
    ///
    /// DE DONDE SALEN
    ///   Del telefono. El tecnico saca la foto en terreno, la app la sube al
    ///   blob y la enlaza por Archivo_Vinculo contra la orden o contra el paso
    ///   que estaba ejecutando. La web no las crea -salvo la firma del cierre-:
    ///   las lee y las ordena por paso.
    ///
    /// NO VIAJAN LOS BYTES
    ///   El SP devuelve metadatos. La imagen se pide despues por
    ///   VerArchivo.aspx con el id cifrado, y el navegador la cachea. Traer los
    ///   binarios en la consulta haria que abrir una orden con seis fotos
    ///   costara seis megas de HTML.
    /// </summary>
    public class OrdenTrabajoArchivoController
    {
        /// <summary>Categoria 8 del catalogo Archivo_Categoria.</summary>
        public const int CATEGORIA_FIRMA = 8;

        public List<OrdenTrabajoArchivo> GetEvidencias(int orden)
        {
            List<OrdenTrabajoArchivo> lista = new List<OrdenTrabajoArchivo>();

            if (orden <= 0 || !Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ORDEN_TRABAJO_ARCHIVO";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ORDEN", orden);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        OrdenTrabajoArchivo a = new OrdenTrabajoArchivo();

                        a.arc_id = int.Parse(dr["arc_id"].ToString());
                        a.nombre = dr["arc_nombre_original"].ToString();
                        a.mime = dr["arc_mime"].ToString();
                        a.bytes = long.Parse(dr["arc_byte"].ToString());
                        if (dr["arc_fecha_creacion"] != DBNull.Value) a.fecha = DateTime.Parse(dr["arc_fecha_creacion"].ToString());
                        a.categoria_codigo = dr["CATEGORIA_CODIGO"].ToString();
                        a.categoria_nombre = dr["CATEGORIA_NOMBRE"].ToString();
                        a.titulo = dr["AVI_TITULO"].ToString();
                        a.descripcion = dr["AVI_DESCRIPCION"].ToString();
                        if (dr["PASO_ID"] != DBNull.Value) a.paso_id = int.Parse(dr["PASO_ID"].ToString());
                        a.paso_orden = int.Parse(dr["PASO_ORDEN"].ToString());
                        a.paso_nombre = dr["PASO_NOMBRE"].ToString();
                        a.usuario = dr["USUARIO_NOMBRE"].ToString();
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

        /// <summary>
        /// Guarda la firma del cierre.
        ///
        /// La firma se dibuja en un canvas y llega como PNG en base64. Se
        /// guarda como un archivo mas -categoria FIRMA, enlazado a la orden-
        /// y no en una columna de Orden_Trabajo: asi vive donde viven todos los
        /// respaldos, se descarga con el mismo visor y no obliga a arrastrar
        /// una imagen dentro de cada SELECT de la orden.
        /// </summary>
        public Respuesta GuardarFirma(int orden, string dataUrl)
        {
            Respuesta r = new Respuesta();

            try
            {
                if (string.IsNullOrEmpty(dataUrl)) throw new Exception("No se dibujó ninguna firma.");

                int coma = dataUrl.IndexOf(',');
                string base64 = coma >= 0 ? dataUrl.Substring(coma + 1) : dataUrl;
                byte[] bytes = Convert.FromBase64String(base64);

                if (bytes.Length == 0) throw new Exception("La firma llegó vacía.");

                Archivo a = new Archivo();
                a.arc_cliente = Session.ClienteId();
                a.arc_archivo_categoria = CATEGORIA_FIRMA;
                a.arc_nombre_original = "firma-cierre-ot-" + orden + ".png";
                a.arc_mime = "image/png";
                a.contenido = bytes;

                Respuesta sub = new ArchivoController().InsertArchivo(a, "firmas");
                if (sub.error) return sub;

                return Sql.Ejecutar("VIN_ORDEN_TRABAJO_ARCHIVO", "Firma guardada.", cmd =>
                {
                    cmd.Parameters.AddWithValue("@ORDEN", orden);
                    cmd.Parameters.AddWithValue("@ARCHIVO", sub.codigo);
                    cmd.Parameters.AddWithValue("@PASO", DBNull.Value);
                    cmd.Parameters.AddWithValue("@TITULO", "Firma del cierre");
                    cmd.Parameters.AddWithValue("@DESCRIPCION", DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                }, true);
            }
            catch (Exception ex)
            {
                r.codigo = -1; r.detalle = ex.Message; r.error = true;
                return r;
            }
        }
    }
}
