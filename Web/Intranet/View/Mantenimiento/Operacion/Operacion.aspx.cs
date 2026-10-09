using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Serialization;

/// <summary>
/// Operación de mantenimiento: cáscara con las pestañas del lugar (rediseño de Mantenimiento en
/// cinco lugares). El servidor solo entrega la configuración; cada pestaña se
/// pinta en el navegador (Js/sigma-mant-lugar.js y el JS de su parte).
/// </summary>
public partial class View_Mantenimiento_Operacion_Operacion : System.Web.UI.Page
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
            lugar = "operacion",
            titulo = "Operación de mantenimiento",
            base_ = ResolveUrl("~/"),
            ws = ResolveUrl("~/WebService/WsOperacion.asmx/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            plantas = plantas.OrderBy(p => p.cin_nombre).Select(p => new { id = p.cin_id, n = p.cin_nombre }).ToList(),
            cliente = SitioBase.Session.ClienteId(),
            usuario = SitioBase.Session.UsuarioId(),
            tabs = new object[] {
                new { k = "hoy", n = "Hoy", parte = "d", hace = "Centro de control del día: seis indicadores, agenda por hora, atención requerida y tendencia.", enlaces = new object[] { new { n = "Ver ejecuciones", url = ResolveUrl("~/View/Mantenimiento/Planificacion.aspx#tab=ejecuciones") } } },
                new { k = "monitoreo", n = "Sala de control", parte = "d", hace = "Sala de control: áreas en mantención ahora, con parada, y el programa por ubicación.", enlaces = new object[] {  } },
                new { k = "ejecuciones", n = "Ejecuciones", parte = "d", hace = "Lista única de lo programado: planes, inspecciones y tareas, con Generar OT, Registrar y Hecha.", enlaces = new object[] { new { n = "Ver ejecuciones", url = ResolveUrl("~/View/Mantenimiento/Planificacion.aspx#tab=ejecuciones") }, new { n = "Tareas recurrentes", url = ResolveUrl("~/View/Mantenimiento/Tareas/Tareas.aspx?legacy=1") } } },
                new { k = "cumplimiento", n = "Cumplimiento", parte = "d", hace = "Cumplimiento de los últimos 40 días por tipo de trabajo, por plan y por activo.", enlaces = new object[] { new { n = "Ver cumplimiento", url = ResolveUrl("~/View/Mantenimiento/Planificacion.aspx#tab=cumplimiento") } } }
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
