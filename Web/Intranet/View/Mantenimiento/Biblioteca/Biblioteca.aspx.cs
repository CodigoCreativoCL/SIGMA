using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Serialization;

/// <summary>
/// Recursos: Procedimientos · Pautas de inspección · Calendarios compartidos · Ajustes
/// (rediseño de Mantenimiento en cinco lugares, parte e). El servidor solo entrega la
/// configuración; todo se pinta en el navegador (Js/sigma-mant-recursos.js, WsRecursos.asmx).
/// </summary>
public partial class View_Mantenimiento_Biblioteca_Biblioteca : System.Web.UI.Page
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
            lugar = "biblioteca",
            titulo = "Recursos",
            base_ = ResolveUrl("~/"),
            ws = ResolveUrl("~/WebService/WsRecursos.asmx/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            plantas = plantas.OrderBy(p => p.cin_nombre).Select(p => new { id = p.cin_id, n = p.cin_nombre }).ToList(),
            cliente = SitioBase.Session.ClienteId(),
            usuario = SitioBase.Session.UsuarioId(),
            tabs = new object[] {
                new { k = "procedimientos", n = "Procedimientos" },
                new { k = "pautas", n = "Pautas de inspección" },
                new { k = "calendarios", n = "Calendarios compartidos" },
                new { k = "ajustes", n = "Ajustes" }
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
