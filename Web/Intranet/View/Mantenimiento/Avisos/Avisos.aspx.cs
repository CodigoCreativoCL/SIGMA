using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Serialization;

/// <summary>
/// Avisos: cáscara con las pestañas del lugar (rediseño de Mantenimiento en
/// cinco lugares). El servidor solo entrega la configuración; cada pestaña se
/// pinta en el navegador (Js/sigma-mant-lugar.js y el JS de su parte).
/// </summary>
public partial class View_Mantenimiento_Avisos_Avisos : System.Web.UI.Page
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
            lugar = "avisos",
            titulo = "Avisos",
            base_ = ResolveUrl("~/"),
            ws = ResolveUrl("~/WebService/WsAvisos.asmx/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            plantas = plantas.OrderBy(p => p.cin_nombre).Select(p => new { id = p.cin_id, n = p.cin_nombre }).ToList(),
            cliente = SitioBase.Session.ClienteId(),
            usuario = SitioBase.Session.UsuarioId(),
            tabs = new object[] {
                new { k = "avisos", n = "Avisos", parte = "b", hace = "Bandeja única: Generar OT, Vincular a una OT abierta o Descartar con motivo, y Reportar falla.", enlaces = new object[] { new { n = "Fallas", url = ResolveUrl("~/View/Mantenimiento/Fallas/Fallas.aspx?legacy=1") }, new { n = "Hallazgos de inspección", url = ResolveUrl("~/View/Mantenimiento/Hallazgos/ChecklistHallazgos.aspx?legacy=1") } } }
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
