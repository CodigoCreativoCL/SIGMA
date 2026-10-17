using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Serialization;

/// <summary>
/// SIGMA AI · Desempeño: cáscara con las pestañas del lugar. El servidor solo entrega la configuración;
/// cada pestaña se pinta en el navegador (Js/sigma-ai-desempeno.js) con lo que devuelve WsAiDesempeno.
/// </summary>
public partial class View_SigmaAI_Desempeno : System.Web.UI.Page
{
    public string ConfigJson { get; private set; }

    protected void Page_Init(object sender, EventArgs e)
    {
        EnableViewState = false;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = "1" }) ?? new List<ClienteInstalacion>();
        ConfigJson = new JavaScriptSerializer().Serialize(new
        {
            lugar = "desempeno",
            titulo = "Desempeño del modelo",
            base_ = ResolveUrl("~/"),
            ws = ResolveUrl("~/WebService/WsAiDesempeno.asmx/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            plantas = new object[0],
            cliente = SitioBase.Session.ClienteId(),
            usuario = SitioBase.Session.UsuarioId(),
            cliente_nombre = SitioBase.Session.ClienteNombre(),
            tabs = new object[] {
                new { k = "evaluar", n = "Por evaluar", parte = "", hace = "Predicciones cuyo horizonte venció y aún no se evalúan.", enlaces = new object[] { } },
                new { k = "desempeno", n = "Desempeño", parte = "", hace = "Cómo rinde cada versión del modelo, mes a mes.", enlaces = new object[] { } }
            }
        }).Replace("</", "<\\/");
    }

    /// <summary>La URL de un archivo del sitio con su fecha, para que el navegador no sirva una versión vieja.</summary>
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
