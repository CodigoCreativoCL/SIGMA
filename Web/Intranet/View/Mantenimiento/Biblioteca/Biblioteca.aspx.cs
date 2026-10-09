using System;
using System.Web.Script.Serialization;

/// <summary>
/// Recursos: cáscara con las pestañas del lugar (rediseño de Mantenimiento en
/// cinco lugares). El servidor solo entrega la configuración; cada pestaña se
/// pinta en el navegador (Js/sigma-mant-lugar.js y el JS de su parte).
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
        ConfigJson = new JavaScriptSerializer().Serialize(new
        {
            lugar = "biblioteca",
            titulo = "Recursos",
            base_ = ResolveUrl("~/"),
            cliente = SitioBase.Session.ClienteId(),
            usuario = SitioBase.Session.UsuarioId(),
            tabs = new object[] {
                new { k = "procedimientos", n = "Procedimientos", parte = "e", hace = "Los procedimientos reutilizables de los planes.", enlaces = new object[] { new { n = "Abrir procedimientos", url = ResolveUrl("~/View/Mantenimiento/Planificacion.aspx#tab=biblioteca&lib=proc") } } },
                new { k = "pautas", n = "Pautas de inspección", parte = "e", hace = "Pautas con secciones, ítems críticos, umbrales y versiones.", enlaces = new object[] { new { n = "Pautas de inspección", url = ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistCentro.aspx?legacy=1") } } },
                new { k = "calendarios", n = "Calendarios compartidos", parte = "e", hace = "Calendarios compartidos entre planes, inspecciones y tareas.", enlaces = new object[] { new { n = "Abrir calendarios", url = ResolveUrl("~/View/Mantenimiento/Planificacion.aspx#tab=biblioteca&lib=cal") } } },
                new { k = "ajustes", n = "Ajustes", parte = "e", hace = "Categorías de tarea, tipos de OT y motivos de descarte, con su conteo de uso.", enlaces = new object[] { new { n = "Categorías de tarea", url = ResolveUrl("~/View/Mantenimiento/Tareas/TareaCategorias.aspx?legacy=1") } } }
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
