using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web.Script.Serialization;

/// <summary>
/// Centro de Planificación, dentro del módulo Centro de Mantenimiento: los
/// planes de mantenimiento preventivo (qué, sobre qué, cómo, cuándo y quién),
/// sus ejecuciones, el cumplimiento, la cobertura de activos y la biblioteca
/// de procedimientos y calendarios, en cinco pestañas.
///
/// ESTA PÁGINA SOLO PINTA LA CÁSCARA
///   El servidor entrega la configuración (plantas, períodos, hoy y las URL
///   de los servicios). Todo lo demás lo pide el navegador a
///   WsCentroPlanificacion.asmx y a WsPlanificacion360.asmx, con la misma
///   validación de sesión y permiso que el resto del sitio. Cambiar de
///   pestaña o editar un plan no hace postback: el ViewState va apagado.
///
/// LO QUE ANTES ERAN PÁGINAS
///   El Centro del plan (PlanMantenimiento.aspx) y las pestañas de
///   Planificación 360 viven aquí como ficha, paneles laterales y
///   confirmaciones. La OT y la ficha del activo se siguen abriendo aparte.
/// </summary>
public partial class View_Mantenimiento_Planificacion : System.Web.UI.Page
{
    private static readonly string[] MESES = { "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre" };

    /// <summary>La configuración del JS, serializada.</summary>
    public string ConfigJson { get; private set; }

    protected void Page_Init(object sender, EventArgs e)
    {
        EnableViewState = false;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        // Sin "if (IsPostBack) return": la página no tiene eventos de servidor;
        // si algo la envía (el cambio de cliente del master), se pinta entera.
        int cliente = SitioBase.Session.ClienteId();
        DateTime hoy = Hora.Hoy;

        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = cliente, filtro_habilitado = "1" }) ?? new List<ClienteInstalacion>();

        var periodos = new List<object>();
        for (DateTime m = new DateTime(hoy.Year - 1, 1, 1); m <= new DateTime(hoy.Year + 1, 12, 1); m = m.AddMonths(1))
            periodos.Add(new { id = m.ToString("yyyy-MM", CultureInfo.InvariantCulture), n = MESES[m.Month - 1] + " " + m.Year });

        ConfigJson = new JavaScriptSerializer().Serialize(new
        {
            ws = ResolveUrl("~/WebService/WsCentroPlanificacion.asmx/"),
            p360 = ResolveUrl("~/WebService/WsPlanificacion360.asmx/"),
            base_ = ResolveUrl("~/"),
            hoy = hoy.ToString("yyyy-MM-dd"),
            periodo = hoy.ToString("yyyy-MM", CultureInfo.InvariantCulture),
            plantas = plantas.OrderBy(p => p.cin_nombre).Select(p => new { id = p.cin_id, n = p.cin_nombre }).ToList(),
            periodos = periodos,
            usuario = SitioBase.Session.UsuarioId(),
            puedeVer = Token.Puede("VER PLANES MANTENIMIENTO")
        }).Replace("</", "<\\/");
    }

    /// <summary>
    /// La URL de un archivo del sitio con la fecha del archivo colgada, para
    /// que el navegador no sirva una versión vieja del CSS o del JS.
    /// </summary>
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
