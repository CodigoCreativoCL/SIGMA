using System;
using System.Configuration;
using System.Security.Cryptography;
using System.Text;

/// <summary>
/// La puerta de los jobs programados (bloque 461). La llama la tarea programada
/// de Plesk cada 5–15 minutos:
///
///   curl -s -H "X-Sigma-Jobs: CLAVE" https://sigma.codigocreativo.tech/Jobs.aspx
///
/// Sin la clave (appSettings JobsClave) responde 403 y no hace nada. La clave
/// también se acepta como ?clave= para tareas que no pueden mandar cabeceras.
/// ?job=CODIGO fuerza un job aunque no le toque (para probarlo).
/// Responde texto plano con lo que corrió.
/// </summary>
public partial class JobsPagina : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "text/plain; charset=utf-8";
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        string esperada = ConfigurationManager.AppSettings["JobsClave"];
        string recibida = Request.Headers["X-Sigma-Jobs"] ?? Request.QueryString["clave"];
        if (string.IsNullOrWhiteSpace(esperada) || string.IsNullOrEmpty(recibida) || !Iguales(esperada.Trim(), recibida.Trim()))
        {
            Response.StatusCode = 403;
            Response.Write("Prohibido.");
            return;
        }
        Server.ScriptTimeout = 900;
        Response.Write(SitioBase.Jobs.Ejecutar(Request.QueryString["job"]));
    }

    /// <summary>Comparación en tiempo constante (no revela cuántos caracteres acertó).</summary>
    private static bool Iguales(string a, string b)
    {
        using (SHA256 s = SHA256.Create())
        {
            byte[] x = s.ComputeHash(Encoding.UTF8.GetBytes(a)), y = s.ComputeHash(Encoding.UTF8.GetBytes(b));
            int d = 0; for (int i = 0; i < x.Length; i++) d |= x[i] ^ y[i];
            return d == 0;
        }
    }
}
