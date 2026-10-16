using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Serialization;
using SitioBase;

/// <summary>
/// Página pública de pago (bloque 462). Se abre desde el correo de cobro o
/// desde la página de firma con ?t=enlace. Webpay vuelve aquí mismo (GET) con
/// token_ws, o con TBK_TOKEN si la persona anuló.
///
/// SE ABRE SIN SESIÓN: la protege el enlace (32 bytes al azar, en la base solo
/// su SHA-256, con vencimiento). El navegador nunca ve ids de suscripción.
/// </summary>
public partial class Pagar : System.Web.UI.Page
{
    public string ModeloJson { get; private set; }

    protected void Page_Load(object sender, EventArgs e)
    {
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
        Response.Cache.SetNoStore();
        Response.AddHeader("X-Robots-Tag", "noindex, nofollow");
        Response.AddHeader("Referrer-Policy", "no-referrer");

        string t = Request.QueryString["t"] ?? "";
        object modelo;
        try
        {
            string tokenWs = Request.QueryString["token_ws"] ?? Request.Form["token_ws"];
            string tbk = Request.QueryString["TBK_TOKEN"] ?? Request.Form["TBK_TOKEN"];
            string orden = Request.QueryString["TBK_ORDEN_COMPRA"] ?? Request.Form["TBK_ORDEN_COMPRA"];
            if (!string.IsNullOrEmpty(tokenWs) || !string.IsNullOrEmpty(tbk))
            {
                Cobros.Resultado r = Cobros.ProcesarRetorno(tokenWs, tbk, orden);
                modelo = new
                {
                    estado = r.Estado == "AUTORIZADA" ? "aprobado" : r.Estado == "ANULADA" ? "anulado" : r.Estado == "RECHAZADA" ? "rechazado" : "error",
                    mensaje = r.Mensaje, prueba = Webpay.EsPrueba(),
                    monto = r.Pago != null && r.Pago.ContainsKey("MONTO") ? Cobros.Clp(r.Pago["MONTO"]) : "", moneda = "CLP",
                    autorizacion = r.Pago != null ? Comercial.Txt(r.Pago, "AUTORIZACION") : "",
                    tarjeta = r.Pago != null ? Comercial.Txt(r.Pago, "TARJETA") : "",
                    orden = r.Pago != null ? Comercial.Txt(r.Pago, "BUY_ORDER") : "",
                    correo = r.Correo, t = t
                };
            }
            else modelo = Estado(t);
        }
        catch (Exception ex)
        {
            Correo.Registrar("Pagar.aspx", ex.ToString());
            modelo = new { estado = "error", mensaje = ex.Message, prueba = Webpay.EsPrueba(), t = t };
        }
        ModeloJson = new JavaScriptSerializer().Serialize(modelo).Replace("</", "<\\/");
    }

    /// <summary>Lo que se ve al abrir el enlace: lo pendiente y el total.</summary>
    public static object Estado(string t)
    {
        bool vencido; int sus = Cobros.SuscripcionDeEnlace(t, out vencido);
        if (sus == 0) return new { estado = "invalido", prueba = Webpay.EsPrueba() };
        if (vencido) return new { estado = "vencido", prueba = Webpay.EsPrueba() };
        Cobros.Estado e = Cobros.Leer(sus);
        Dictionary<string, object> h = e.Cabecera;
        bool usd = e.EsUsd;
        // «Informado»: ya transfirió y lo transferido cubre lo pendiente; solo falta que se verifique.
        bool informado = e.PorVerificarN > 0 && e.PorVerificarMonto >= e.Total - 1;
        return new
        {
            estado = e.Pendientes.Count == 0 ? "aldia" : informado ? "informado" : "pendiente", prueba = !usd && Webpay.EsPrueba(), t = t, moneda = usd ? "USD" : "CLP",
            referencia = e.Pendientes.Count > 0 ? Cobros.Referencia(e) : "",
            datos = Cobros.DatosTransferencia(usd).Select(d => new { k = d.Key, v = d.Value }).ToList(),
            montoNum = e.Total, informadoMonto = Cobros.Monto(e.PorVerificarMonto, usd),
            empresa = Comercial.Txt(h, "EMPRESA"), plan = Comercial.Txt(h, "PLAN_NOMBRE"), contacto = Comercial.Txt(h, "CONTACTO"),
            ejecutivo = Comercial.Txt(h, "EJECUTIVO"), ejecutivoCorreo = Comercial.Txt(h, "EJECUTIVO_CORREO"),
            total = Cobros.Monto(e.Total, usd),
            items = e.Pendientes.Select(p => new { n = Cobros.Periodo(p), uf = usd ? "Sin conversión" : Comercial.UF2(p["UF"]), monto = Cobros.Monto(p["SALDO"], usd) }).ToList()
        };
    }
}
