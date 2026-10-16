using SitioBase;
using System;
using System.Web.Script.Serialization;

/// <summary>
/// Mi suscripción y su renovación (ANEXO F §6.6 · HU-193), rediseñada en el Centro Comercial V2 (P6).
///
/// Es la única pantalla que sigue abierta cuando la suscripción venció. Por eso está en
/// `SuscripcionAcceso.EXENTAS` y en `Token.EXENTAS`: bloquear sin dejar a dónde ir sería encerrar al
/// cliente, que no podría ni ver cuánto debe ni a quién escribirle.
///
/// La cáscara solo entrega la configuración; el resto lo pide sigma-mi-suscripcion.js a
/// WsMiSuscripcion.asmx, que toma SIEMPRE el cliente de la sesión. La versión anterior (grillas de
/// WebForms y un modal para declarar el pago) quedó respaldada fuera del repositorio.
/// </summary>
public partial class Renovar : System.Web.UI.Page
{
    public string ConfigJson { get; private set; }

    protected void Page_Init(object sender, EventArgs e)
    {
        EnableViewState = false;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        ConfigJson = new JavaScriptSerializer().Serialize(new
        {
            ws = ResolveUrl("~/WebService/WsMiSuscripcion.asmx/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            usuario = SitioBase.Session.UsuarioId()
        }).Replace("</", "<\\/");
    }

    protected string Asset(string ruta)
    {
        string url = ResolveUrl(ruta);
        try
        {
            string fisica = Server.MapPath(ruta);
            if (System.IO.File.Exists(fisica))
                return url + "?v=" + System.IO.File.GetLastWriteTimeUtc(fisica).Ticks;
        }
        catch (Exception)
        {
            // Sin la fecha, la URL sin versión igual sirve la página.
        }
        return url;
    }
}
