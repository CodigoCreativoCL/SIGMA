using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Una foto de la galería de un repuesto.
    ///
    /// NO HAY TABLA PROPIA
    ///   Se apoya en `Archivo_Vinculo`, que ya tenía `avi_repuesto`. Crear una
    ///   tabla nueva habría significado dos formas distintas de adjuntar en el
    ///   mismo producto.
    /// </summary>
    [Serializable]
    public class RepuestoFoto
    {
        /// <summary>Id del VÍNCULO, no del archivo: es lo que se borra.</summary>
        public int vinculo { get; set; }

        public int archivo { get; set; }
        public int orden { get; set; }
        public string titulo { get; set; }
        public string nombre { get; set; }
        public string mime { get; set; }
        public long bytes { get; set; }
        public int ancho { get; set; }
        public int alto { get; set; }
        public DateTime? fecha { get; set; }
        public string usuario { get; set; }

        /// <summary>La de orden menor es la que se ve en el listado.</summary>
        public bool es_portada { get; set; }
    }


    public class RepuestoFotoController
    {
        /// <summary>Las fotos de un repuesto, ya ordenadas.</summary>
        public List<RepuestoFoto> GetFotos(int repuesto)
        {
            List<RepuestoFoto> lista = new List<RepuestoFoto>();

            if (!Token.TokenSeguridad() || repuesto <= 0) return lista;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_REPUESTO_FOTO");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@REPUESTO", repuesto);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        RepuestoFoto f = new RepuestoFoto();

                        f.vinculo = int.Parse(dr["VINCULO"].ToString());
                        f.archivo = int.Parse(dr["ARCHIVO"].ToString());
                        f.orden = int.Parse(dr["ORDEN"].ToString());
                        f.titulo = dr["TITULO"].ToString();
                        f.nombre = dr["NOMBRE"].ToString();
                        f.mime = dr["MIME"].ToString();
                        f.bytes = long.Parse(dr["BYTES"].ToString());
                        f.ancho = int.Parse(dr["ANCHO"].ToString());
                        f.alto = int.Parse(dr["ALTO"].ToString());
                        f.usuario = dr["USUARIO"].ToString();

                        if (dr["FECHA"] != DBNull.Value)
                            f.fecha = DateTime.Parse(dr["FECHA"].ToString());

                        lista.Add(f);
                    }
                }

                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            /* La primera es la portada. Se marca acá y no en el SP porque es
               una consecuencia del orden, no un dato guardado: si fuera una
               columna habría que garantizar que solo una la tenga. */
            if (lista.Count > 0) lista[0].es_portada = true;

            return lista;
        }

        /// <summary>
        /// La portada de CADA repuesto del cliente, en un solo viaje.
        ///
        /// La grilla la necesita por fila, y pedirla de a una serían
        /// trescientas consultas para dibujar una página.
        /// </summary>
        public Dictionary<int, int> GetPortadas()
        {
            Dictionary<int, int> mapa = new Dictionary<int, int>();

            if (!Token.TokenSeguridad()) return mapa;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_REPUESTO_PORTADA");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                        mapa[int.Parse(dr["REPUESTO"].ToString())] =
                            int.Parse(dr["ARCHIVO"].ToString());
                }

                cmd.Connection.Close();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            return mapa;
        }

        /// <summary>
        /// Sube la imagen y la vincula al repuesto.
        ///
        /// EL ARCHIVO SE GUARDA CON EL MISMO CAMINO QUE EL RESTO
        ///   `ArchivoController.InsertArchivo` es quien habla con el
        ///   almacenamiento. Duplicar esa lógica acá significaría dos formas
        ///   de escribir un archivo y dos sitios donde arreglar el día que
        ///   cambie el proveedor.
        /// </summary>
        public Respuesta Agregar(int repuesto, byte[] contenido, string nombre,
                                 string mime, string titulo)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
                return respuesta;
            }

            if (contenido == null || contenido.Length == 0)
            {
                respuesta.codigo = -1;
                respuesta.detalle = "Elija una imagen.";
                respuesta.error = true;
                return respuesta;
            }

            /* Se rechaza acá y no solo en el SP para no subir al
               almacenamiento algo que la base va a rechazar después: el blob
               quedaría huérfano, ocupando espacio y sin nada que lo apunte. */
            if (string.IsNullOrEmpty(mime) || !mime.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            {
                respuesta.codigo = -1;
                respuesta.detalle = "Solo se pueden agregar imágenes a la galería.";
                respuesta.error = true;
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                Archivo archivo = new Archivo();
                archivo.arc_cliente = Session.ClienteId();
                archivo.arc_archivo_categoria = 10;   // Imagen de referencia
                archivo.arc_nombre_original = nombre;
                archivo.arc_mime = mime;
                archivo.contenido = contenido;

                Respuesta subida = new ArchivoController().InsertArchivo(archivo, "REPUESTO");

                if (subida.error) return subida;

                cmd = Conexion.GetCommand("INS_REPUESTO_FOTO");
                cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@REPUESTO", repuesto);
                cmd.Parameters.AddWithValue("@ARCHIVO", subida.codigo);
                cmd.Parameters.AddWithValue("@TITULO", (object)titulo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                respuesta.detalle = "Imagen agregada.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta Quitar(int vinculo)
        {
            return Ejecutar("DEL_REPUESTO_FOTO", vinculo, "Imagen quitada de la galería.");
        }

        public Respuesta HacerPortada(int vinculo)
        {
            return Ejecutar("UPD_REPUESTO_FOTO_PORTADA", vinculo, "Portada actualizada.");
        }

        /// <summary>
        /// Quitar y hacer portada reciben lo mismo y devuelven lo mismo: solo
        /// cambia el procedimiento y el mensaje.
        /// </summary>
        private Respuesta Ejecutar(string sp, int vinculo, string ok)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.codigo = -1;
                respuesta.detalle = "La sesion no es valida o expiro. Vuelva a entrar y repita la operacion.";
                respuesta.error = true;
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand(sp);
                cmd.Parameters.AddWithValue("@VINCULO", vinculo);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = vinculo;
                respuesta.detalle = ok;
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }
    }
}
