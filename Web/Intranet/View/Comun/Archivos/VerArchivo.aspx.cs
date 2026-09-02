using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web;

/// <summary>
/// Entrega un archivo: para VERLO en el navegador o para DESCARGARLO.
///
/// UNA SOLA PANTALLA PARA TODOS LOS DOCUMENTOS
///   Cada módulo que adjunta algo —el comprobante de pago, el permiso de
///   trabajo firmado, lo que venga— necesita lo mismo: abrirlo y bajarlo.
///   Repetir ese código en cada ficha son N sitios donde arreglar la misma
///   comprobación de permiso el día que cambie.
///
/// LO QUE VIAJA ES EL ID CIFRADO, NUNCA LA RUTA
///   Si el navegador conociera `sigma/0001-hamburgo/…/x.pdf` podría pedir
///   cualquier otra ruta cambiando el texto. Acá llega un id, se resuelve
///   contra la base —que dice de qué cliente es— y recién entonces se pide
///   el archivo. La ruta no sale nunca del servidor.
///
/// LA COMPROBACION DE CLIENTE NO ES OPCIONAL
///   `ArchivoController.Descargar` ya rechaza el archivo de otro cliente, y
///   acá se vuelve a comprobar antes de pedir la vista. Adivinar un id
///   correlativo es barato: es la misma clase de agujero que tenía Pago.aspx
///   y se corrigió en el bloque 52.
///
/// EL TIPO DE CONTENIDO LO DECIDE LA API, NO ESTA PAGINA
///   La API tiene una lista blanca —PDF, imágenes de mapa de bits, texto— y
///   devuelve octet-stream para todo lo demás. Servir `text/html` subido por
///   un usuario desde nuestro dominio sería ejecutar su javascript con
///   nuestro origen. Acá se respeta lo que la API haya decidido.
/// </summary>
public partial class View_Comun_Archivos_VerArchivo : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        int id = 0;
        string modo = "";

        try
        {
            /* Querystring.Entero descifra por dentro: recibe el valor tal
               como viene de la URL. Descifrarlo antes lo hace descifrar dos
               veces, la segunda falla, y como el helper no lanza devuelve 0
               en silencio. */
            id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            modo = SitioBase.Querystring.Texto(Request.QueryString["query"], "Modo");
        }
        catch (Exception)
        {
            Fallar(400, "La dirección del archivo no es válida.");
            return;
        }

        if (id <= 0)
        {
            Fallar(400, "Falta el archivo que se quiere abrir.");
            return;
        }

        try
        {
            if (!Token.TokenSeguridad())
            {
                Fallar(401, "La sesión expiró. Vuelva a entrar.");
                return;
            }

            ArchivoController controller = new ArchivoController();
            Archivo archivo = controller.GetArchivo(new Archivo { arc_id = id });

            if (archivo == null || archivo.arc_id == 0)
            {
                Fallar(404, "El archivo no existe.");
                return;
            }

            if (archivo.arc_cliente != SitioBase.Session.ClienteId())
            {
                /* 404 y no 403: decir "existe pero no es tuyo" confirma que
                   ese id existe, que es justo lo que alguien probando
                   números quiere averiguar. */
                Fallar(404, "El archivo no existe.");
                return;
            }

            if (!Services.Disponible)
            {
                Fallar(503, Services.Motivo);
                return;
            }

            bool verlo = (modo ?? "").ToUpper() == "VER";

            Response.Clear();
            Response.Buffer = true;

            if (verlo)
            {
                ArchivoVisto visto = ServicioArchivos.Ver(archivo.arc_ruta);

                /* Si la API dijo que este tipo no se muestra inline, se ofrece
                   como descarga en vez de forzarlo: el usuario igual accede al
                   archivo y no se abre el agujero. */
                Response.ContentType = visto.puede_verse && !string.IsNullOrEmpty(visto.mime)
                                     ? visto.mime : "application/octet-stream";

                Response.AddHeader("Content-Disposition",
                                   (visto.puede_verse ? "inline" : "attachment") +
                                   "; filename=\"" + Limpio(archivo.arc_nombre_original) + "\"");

                Response.AddHeader("X-Content-Type-Options", "nosniff");
                Response.BinaryWrite(visto.contenido);
            }
            else
            {
                byte[] contenido = ServicioArchivos.Descargar(archivo.arc_ruta);

                Response.ContentType = "application/octet-stream";
                Response.AddHeader("Content-Disposition",
                                   "attachment; filename=\"" + Limpio(archivo.arc_nombre_original) + "\"");
                Response.BinaryWrite(contenido);
            }

            Response.Flush();
            Response.SuppressContent = true;
            HttpContext.Current.ApplicationInstance.CompleteRequest();
        }
        catch (Exception ex)
        {
            Fallar(500, ex.Message);
        }
    }

    /// <summary>
    /// Un salto de línea o una comilla en el nombre parten la cabecera
    /// Content-Disposition en dos y dejan inyectar cabeceras propias.
    /// </summary>
    private string Limpio(string nombre)
    {
        if (string.IsNullOrEmpty(nombre)) return "archivo";

        return nombre.Replace("\r", "").Replace("\n", "").Replace("\"", "'");
    }

    /// <summary>
    /// El error se escribe como texto y no se lanza: esta página se abre en
    /// una pestaña nueva, y una pantalla amarilla de ASP.NET no le dice nada
    /// a quien solo quería ver un PDF.
    /// </summary>
    private void Fallar(int codigo, string mensaje)
    {
        Response.Clear();
        Response.StatusCode = codigo;
        Response.ContentType = "text/html; charset=utf-8";

        Response.Write("<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\">" +
                       "<title>No se pudo abrir el archivo</title></head>" +
                       "<body style=\"font-family:system-ui,-apple-system,Segoe UI,sans-serif;" +
                       "padding:40px;color:#333;\">" +
                       "<h2 style=\"margin:0 0 8px;font-size:18px;\">No se pudo abrir el archivo</h2>" +
                       "<p style=\"margin:0;color:#666;font-size:14px;\">" +
                       Server.HtmlEncode(mensaje ?? "") + "</p></body></html>");

        Response.Flush();
        Response.SuppressContent = true;
        HttpContext.Current.ApplicationInstance.CompleteRequest();
    }
}
