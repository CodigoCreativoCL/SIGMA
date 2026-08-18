using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;

namespace SitioBase.Controller
{
    public class ArchivoController
    {
        private static readonly string[] EXTENSIONES_IMAGEN = { "JPG", "JPEG", "PNG", "GIF", "BMP", "WEBP" };

        public static bool EsImagen(string extension)
        {
            if (string.IsNullOrEmpty(extension)) return false;
             
            return EXTENSIONES_IMAGEN.Contains(extension.Trim().TrimStart('.').ToUpper());
        }

        public static string GetContentType(string extension)
        {
            switch ((extension ?? "").Trim().TrimStart('.').ToUpper())
            {
                case "JPG":
                case "JPEG":
                    return "image/jpeg";
                case "PNG":
                    return "image/png";
                case "GIF":
                    return "image/gif";
                case "BMP":
                    return "image/bmp";
                case "WEBP":
                    return "image/webp";
                default:
                    return "application/octet-stream";
            }
        }

        public Archivo GetListsArchivoBinario(Archivo item)
        {
            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_ARCHIVO";
                cmd.Parameters.AddWithValue("@ID", item.arc_id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        item = new Archivo();
                        item.arc_nombre_archivo = dr["ARC_NOMBRE_ARCHIVO"].ToString();
                        item.arc_descripcion = dr["ARC_DESCRIPCION"].ToString();
                        item.arc_contenido = dr["ARC_CONTENIDO"].ToString();
                        item.arc_extension = dr["ARC_EXTENSION"].ToString();
                        item.arc_tamano = dr["ARC_TAMANO"].ToString();
                        item.arc_archivo = int.Parse(dr["ARC_ARCHIVO"].ToString());

                        ArchivoBinario archivoBinario = new ArchivoBinario();
                        archivoBinario.abi_archivo_binario = (byte[])dr["ABI_ARCHIVO_BINARIO"];
                        item.archivoBinario = archivoBinario;
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                item = null;
            }
            return item;
        }

    }
}