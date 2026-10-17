using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Script.Serialization;

/// <summary>
/// Indicadores de gestión: cáscara con las pestañas del lugar. El servidor solo entrega la configuración;
/// cada pestaña se pinta en el navegador (Js/sigma-indicadores.js) con lo que devuelve WsIndicadores.
/// </summary>
public partial class View_Mantenimiento_Indicadores_Indicadores : System.Web.UI.Page
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
            lugar = "indicadores",
            titulo = "Indicadores de gestión",
            base_ = ResolveUrl("~/"),
            ws = ResolveUrl("~/WebService/WsIndicadores.asmx/"),
            hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
            plantas = plantas.OrderBy(p => p.cin_nombre).Select(p => new { id = p.cin_id, n = p.cin_nombre }).ToList(),
            cliente = SitioBase.Session.ClienteId(),
            usuario = SitioBase.Session.UsuarioId(),
            cliente_nombre = SitioBase.Session.ClienteNombre(),
            tabs = new object[] {
                new { k = "tablero", n = "Tablero", parte = "", hace = "Cumplimiento, disponibilidad, tiempo medio entre fallas, tiempo medio de reparación y órdenes pendientes de cierre.", enlaces = new object[] { } },
                new { k = "costos", n = "Costos", parte = "", hace = "Costo de repuestos, mano de obra y servicios por equipo y por centro de costo, por moneda.", enlaces = new object[] { } }
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
