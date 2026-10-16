using SitioBase;
using System;
using System.Web.Script.Serialization;

/// <summary>
/// Centro Comercial: la cáscara. El servidor entrega la configuración (hoy,
/// la URL del servicio, la pestaña y el lead pedidos por la URL); el resto lo
/// pide el navegador a WsComercial.asmx, que valida sesión y permiso en cada
/// llamada. Sin postback: el ViewState va apagado.
///
/// ?tab=resumen|pipeline|clientes abre una pestaña; ?lead=ID abre la ficha
/// (es el enlace que llega en el correo de lead nuevo).
/// </summary>
public partial class View_Comercial_CentroComercial : System.Web.UI.Page
{
    public string ConfigJson { get; private set; }

    protected void Page_Init(object sender, EventArgs e)
    {
        EnableViewState = false;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        int lead;
        int.TryParse(Request.QueryString["lead"], out lead);
        string tab = (Request.QueryString["tab"] ?? "").ToLowerInvariant();
        if (tab != "pipeline" && tab != "clientes" && tab != "suscripciones") tab = "resumen";
        string sub = (Request.QueryString["sub"] ?? "").ToLowerInvariant();
        if (sub != "suscripciones" && sub != "periodos" && sub != "pagos" && sub != "planes" && sub != "empresas" && sub != "concretados") sub = "";
        // ?abrir=sus:12 | per:5 | pago:3 | plan:2 | cli:1 | emitir:0 abre el cajón (enlaces de correos y de las pantallas antiguas).
        string abrir = System.Text.RegularExpressions.Regex.IsMatch(Request.QueryString["abrir"] ?? "", @"^(sus|per|pago|plan|cli|emitir):\d{1,9}$") ? Request.QueryString["abrir"] : "";

        ConfigJson = new JavaScriptSerializer().Serialize(new
        {
            ws = ResolveUrl("~/WebService/WsComercial.asmx/"),
            wsCobros = ResolveUrl("~/WebService/WsCobros.asmx/"),
            base_ = ResolveUrl("~/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            tab = tab,
            sub = sub,
            abrir = abrir,
            lead = lead > 0 ? (int?)lead : null,
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
