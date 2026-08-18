using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Web;

namespace SitioBase
{
    public class SitioBase
    {
        public enum TipoPefil
        {
            Sistema = 1,
            Cliente = 2
        }
        public enum Perfil
        {
            root = 1,
            Soporte = 2,
            Gerente_Comercial = 3,
            Coordinador = 4,
            Supervisor = 5,
            Administrativo_Cliente = 6,
            Administrador_Cliente = 7
        }


        public static string PdfWriteTemp(byte[] binarioArchivo, int idArchivo)
        {
            System.IO.FileStream archivo = null;

            string ruta = "";

            string error = "";

            try
            {

                //1.-Armo las rutas necesarias
                string rutaTemporal = HttpContext.Current.Server.MapPath(ConfigurationManager.AppSettings["DirectorioTemporal"]) + "Pdf\\";
                string rutaTemporalArchivo = rutaTemporal + idArchivo.ToString() + ".pdf";

                //Creo el Directorio de pdf si no existe
                if (!Directory.Exists(rutaTemporal))
                {
                    Directory.CreateDirectory(rutaTemporal);
                }

                error += "1.- ok; ";

                //2.-Verifico que el repositorio contenga archivos, si tiene elimino los con 1 día de antiguedad
                if (Directory.GetFiles(rutaTemporal).Length > 0)
                {
                    string[] archivosExistentes = Directory.GetFiles(rutaTemporal);

                    foreach (string archivoExistente in archivosExistentes)
                    {
                        FileInfo fi = new FileInfo(archivoExistente);
                        if (fi.CreationTime < DateTime.Now.AddDays(-1))
                        {
                            fi.Delete();
                        }
                    }
                }

                error += "2.- ok; ";

                //3.-Verifico si existe el mismo archivo, si existe lo elimino
                if (File.Exists(rutaTemporalArchivo))
                {
                    File.Delete(rutaTemporalArchivo);
                }

                error += "3.- ok; ";

                //4.Creo el archivo
                archivo = System.IO.File.Create(rutaTemporalArchivo);

                if (archivo == null) throw new Exception("fallo Filestream");
                if (binarioArchivo == null) throw new Exception("fallo Binario");

                archivo.Write(binarioArchivo, 0, binarioArchivo.Length);
                archivo.Dispose();
                archivo.Close();

                error += "4.- ok; ";

                ruta = "Pdf/" + idArchivo.ToString() + ".pdf";

            }
            catch (Exception ex)
            {
                archivo.Dispose();
                archivo.Close();
                Tools.tools.ClientAlert(ex.Message + "****" + error);
            }

            return ruta;
        }

        //Reduce tamaño imagen
        /// <summary>
        /// Tags EXIF que se conservan al redimensionar. Es una LISTA BLANCA a
        /// propósito, no una copia completa.
        ///
        /// El motivo es Orientation (0x0112): GDI+ no aplica la rotación EXIF al
        /// dibujar, así que el bitmap resultante tiene los píxeles en el orden
        /// original. Si copiáramos ese tag, el visor volvería a rotar la imagen y
        /// las fotos tomadas en vertical se verían giradas — una regresión visual
        /// en todo el sistema. Copiando solo metadatos informativos, la imagen se
        /// sigue viendo exactamente igual que hoy.
        /// </summary>
        private static readonly int[] EXIF_CONSERVAR = new int[]
        {
            0x9003,  // DateTimeOriginal  — cuándo se tomó la foto
            0x9004,  // DateTimeDigitized
            0x0132,  // DateTime
            0x010F,  // Make   (fabricante del dispositivo)
            0x0110,  // Model  (modelo del dispositivo)
            0x0001, 0x0002, 0x0003, 0x0004   // GPS: lat/long con sus referencias
        };

        /// <summary>
        /// Traslada los metadatos elegidos del original a la imagen redimensionada.
        ///
        /// Sin esto, ReducirImagen los perdía TODOS: crea un Bitmap nuevo y dibuja
        /// encima, y ese flujo no arrastra los PropertyItems. Por eso las fotos
        /// llegaban a la base sin fecha de captura.
        ///
        /// Best-effort: si un tag falla, se omite; nunca debe impedir que la
        /// imagen se guarde.
        /// </summary>
        private static void CopiarMetadatos(System.Drawing.Image origen, System.Drawing.Image destino)
        {
            if (origen == null || destino == null) return;
            try
            {
                int[] presentes = origen.PropertyIdList;
                if (presentes == null || presentes.Length == 0) return;

                foreach (int id in EXIF_CONSERVAR)
                {
                    if (Array.IndexOf(presentes, id) < 0) continue;
                    try { destino.SetPropertyItem(origen.GetPropertyItem(id)); }
                    catch { }   // tag inválido para el formato destino
                }
            }
            catch { }   // la imagen no soporta metadatos (p. ej. BMP)
        }

        public static byte[] ReducirImagen(byte[] imageBytes, int pAncho, int pAlto)
        {
            System.Drawing.Image pImagen = null;

            //1.-Convert byte[] to Image
            using (var ms = new System.IO.MemoryStream(imageBytes, 0, imageBytes.Length))
            {
                pImagen = System.Drawing.Image.FromStream(ms, true);
            }
            //FIn  Convierto el base64 a Imagen

            //2.- creamos un bitmap con el nuevo tamaño
            Bitmap vBitmap = new Bitmap(pAncho, pAlto);

            //creamos un graphics tomando como base el nuevo Bitmap
            using (Graphics vGraphics = Graphics.FromImage((System.Drawing.Image)vBitmap))
            {
                //especificamos el tipo de transformación, se escoge esta para no perder calidad.
                vGraphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                //Se dibuja la nueva imagen

                vGraphics.DrawImage(pImagen, 0, 0, pAncho, pAlto);
            }

            // Antes de perder la referencia al original: traspasar los metadatos
            // (fecha de captura, dispositivo, GPS) al bitmap redimensionado.
            CopiarMetadatos(pImagen, vBitmap);

            //retornamos la nueva imagen
            pImagen = (System.Drawing.Image)vBitmap;

            //3.- Convert to array
            using (var ms = new System.IO.MemoryStream())
            {
                pImagen.Save(ms, System.Drawing.Imaging.ImageFormat.Jpeg);
                imageBytes = ms.ToArray();
            }


            //4.- Retorno el binario
            return imageBytes;

        }

        // Reduce tamaño imagen con calidad JPEG controlada (0-100)
        public static byte[] ReducirImagen(byte[] imageBytes, int pAncho, int pAlto, int calidad)
        {
            System.Drawing.Image pImagen = null;

            using (var ms = new MemoryStream(imageBytes, 0, imageBytes.Length))
            {
                pImagen = System.Drawing.Image.FromStream(ms, true);
            }

            Bitmap vBitmap = new Bitmap(pAncho, pAlto);
            using (Graphics vGraphics = Graphics.FromImage((System.Drawing.Image)vBitmap))
            {
                vGraphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                vGraphics.DrawImage(pImagen, 0, 0, pAncho, pAlto);
            }

            // Ídem que en la sobrecarga sin calidad: los metadatos se copian
            // mientras todavía existe la referencia a la imagen original.
            CopiarMetadatos(pImagen, vBitmap);

            pImagen = (System.Drawing.Image)vBitmap;

            var jpegCodec = System.Drawing.Imaging.ImageCodecInfo.GetImageEncoders()
                .First(c => c.MimeType == "image/jpeg");
            var encoderParams = new System.Drawing.Imaging.EncoderParameters(1);
            encoderParams.Param[0] = new System.Drawing.Imaging.EncoderParameter(
                System.Drawing.Imaging.Encoder.Quality, (long)calidad);

            using (var ms = new MemoryStream())
            {
                pImagen.Save(ms, jpegCodec, encoderParams);
                imageBytes = ms.ToArray();
            }

            return imageBytes;
        }

        public static string Parametros(string codigo)
        {
            string valor = "";

            using (SqlDataReader dr = Conexion.GetDataReader("SEL_PARAMETROS @CODIGO='" + codigo + "'"))
            {
                if (dr.Read())
                {
                    valor = dr["PAR_VALOR"].ToString();
                }
            }

            return valor;
        }

        public static Respuesta MaterialApoyo(byte[] binarioArchivo, string nombreArchivo, string contenedor = "", bool remplazarArchivo = false, string rutaAnteriorArchivo = "")
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                // Evita cache de navegador en respuesta HTTP, con el fin de remplazar la imagen y visualizar la nueva correctamente.
                HttpContext.Current.Response.Cache.SetCacheability(HttpCacheability.NoCache);
                HttpContext.Current.Response.Cache.SetNoStore();
                HttpContext.Current.Response.Cache.SetExpires(DateTime.UtcNow.AddDays(-1));

                // 0. Ruta de Capsulas
                string rutaCapsulas = HttpContext.Current.Server.MapPath(ConfigurationManager.AppSettings["MaterialApoyo"]);

                // 1. Normalizar contenedor y construir ruta base (unificar separadores,eliminar caracteres innecesarios)
                string contenedorNormalizado = (contenedor ?? string.Empty).Replace("/", "\\").TrimStart('~', '\\');
                string rutaBase = string.IsNullOrEmpty(contenedorNormalizado) ? rutaCapsulas : Path.Combine(rutaCapsulas, contenedorNormalizado);

                // 2. Crear todas las carpetas intermedias necesarias
                if (!Directory.Exists(rutaBase))
                    Directory.CreateDirectory(rutaBase);

                // 3. Eliminar archivo anterior si corresponde
                if (remplazarArchivo && !string.IsNullOrEmpty(rutaAnteriorArchivo))
                {
                    try
                    {
                        string rutaAnteriorNormalizada = rutaAnteriorArchivo.Replace("/", "\\").TrimStart('~', '\\');
                        string fullPathAnterior = HttpContext.Current.Server.MapPath("~/" + rutaAnteriorNormalizada);

                        if (File.Exists(fullPathAnterior))
                            File.Delete(fullPathAnterior);
                    }
                    catch (Exception exDel)
                    {
                        respuesta.codigo = -1;
                        respuesta.error = true;
                        respuesta.detalle = exDel.Message;
                        return respuesta;
                    }
                }

                // 4. Crear o reemplazar el nuevo archivo
                string rutaNueva = Path.Combine(rutaBase, nombreArchivo);

                // Normaliza el path final por seguridad
                rutaNueva = Path.GetFullPath(rutaNueva);

                if (File.Exists(rutaNueva))
                {
                    if (remplazarArchivo)
                    {
                        File.Delete(rutaNueva);
                        File.WriteAllBytes(rutaNueva, binarioArchivo);
                    }
                    else
                    {
                        respuesta.codigo = -1;
                        respuesta.error = true;
                        respuesta.detalle = "El archivo ya existe en el directorio.";
                        return respuesta;
                    }
                }
                else
                {
                    File.WriteAllBytes(rutaNueva, binarioArchivo);
                }

                respuesta.codigo = 0;
                respuesta.error = false;
                respuesta.detalle = "";
            }
            catch (Exception e)
            {
                respuesta.codigo = -1;
                respuesta.error = true;
                respuesta.detalle = e.Message;
            }

            return respuesta;
        }
    }
}
