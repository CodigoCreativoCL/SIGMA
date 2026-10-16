using System;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using SitioBase;
using SitioBase.Controller;

/// <summary>
/// Página pública de firma del contrato (Centro Comercial, diseño H/I).
///
/// SE ABRE SIN SESIÓN
///   No usa el master: no pasa por Token.ExigirPagina ni por la compuerta de
///   suscripción. Lo que la protege es el token del enlace: 32 bytes al azar
///   de los que la base guarda solo el SHA-256, con vencimiento y de un solo
///   uso. El id del contrato nunca viaja.
///
/// ?pdf=1 DEVUELVE EL DOCUMENTO
///   El visor y la descarga piden el PDF con el mismo token. Mientras el
///   contrato espera firma se sirve el original; ya firmado, la copia con la
///   hoja de constancia.
/// </summary>
public partial class Firma : System.Web.UI.Page
{
    public string TokenJson { get; private set; }

    protected void Page_Load(object sender, EventArgs e)
    {
        string t = Request.QueryString["t"] ?? "";
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        Response.Cache.SetNoStore();
        Response.AddHeader("X-Robots-Tag", "noindex, nofollow");
        Response.AddHeader("Referrer-Policy", "no-referrer");

        if (Request.QueryString["pdf"] == "1")
        {
            ServirPdf(t);
            return;
        }
        TokenJson = new JavaScriptSerializer().Serialize(t).Replace("</", "<\\/");
    }

    private void ServirPdf(string t)
    {
        Dictionary<string, object> c = t.Length >= 30 ? SoporteDatos.Fila("SEL_CONTRATO_TOKEN", "@TOKEN_HASH", Comercial.HashToken(t)) : new Dictionary<string, object>();
        if (!c.ContainsKey("ID") || Comercial.Txt(c, "ESTADO") == "ANULADO" || Convert.ToInt32(c["VENCIDO"]) == 1 && Comercial.Txt(c, "ESTADO") != "FIRMADO")
        {
            Response.StatusCode = 404;
            Response.End();
            return;
        }
        bool firmado = Comercial.Txt(c, "ESTADO") == "FIRMADO";
        Dictionary<string, object> d = SoporteDatos.Fila("SEL_CONTRATO_PDF", "@ID", Convert.ToInt32(c["ID"]), "@FIRMADO", firmado);
        byte[] pdf = d.ContainsKey("PDF") ? d["PDF"] as byte[] : null;
        if (pdf == null) { Response.StatusCode = 404; Response.End(); return; }

        string nombre = "Contrato_SIGMA_v" + Comercial.Txt(c, "VERSION") + (firmado ? "_Firmado" : "") + ".pdf";
        Response.Clear();
        Response.ContentType = "application/pdf";
        Response.AddHeader("Content-Disposition", (Request.QueryString["bajar"] == "1" ? "attachment" : "inline") + "; filename=\"" + nombre + "\"");
        Response.BinaryWrite(pdf);
        Response.Flush();
        Context.ApplicationInstance.CompleteRequest();
    }
}
