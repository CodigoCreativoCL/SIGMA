using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

/// <summary>
/// Planificación 360, dentro del módulo Centro de Mantenimiento: lo que hay
/// que hacer hoy, lo que está planificado y cada cuánto se dispara, en siete
/// pestañas (Resumen, Bandeja, Calendario, Planes, Programaciones,
/// Cumplimiento y Cobertura).
///
/// ESTA PÁGINA SOLO PINTA LA CÁSCARA
///   El servidor arma la cabecera (plantas y períodos). Los números y cada
///   pestaña los pide el navegador a WsPlanificacion360.asmx cuando hacen
///   falta, con la misma validación de sesión y permiso que el resto del
///   sitio. Así cambiar de pestaña no hace postback y la página no carga lo
///   que nadie mira.
///
/// POR QUÉ NO HAY UpdatePanel NI RadGrid2 ACÁ
///   El análisis de viabilidad midió 80 KB de ViewState en Programaciones y
///   34 KB en la Bandeja, casi todo estructura de controles Telerik. Esta
///   página corre con ViewState apagado y sin controles de servidor
///   interactivos: no hay nada que un postback pueda perder.
///
/// LOS EDITORES SE ABREN APARTE
///   El Centro del plan, la OT y la ficha del activo se abren en otra
///   pestaña del navegador; el wizard de Programación y Reprogramar, en modal.
///   Ninguno se incrusta aquí.
/// </summary>
public partial class View_Mantenimiento_Planificacion : System.Web.UI.Page
{
    private static readonly string[] MESES = { "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre" };

    public string HoyIso { get { return Hora.Hoy.ToString("yyyy-MM-dd"); } }

    protected void Page_Init(object sender, EventArgs e)
    {
        EnableViewState = false;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        // Sin "if (IsPostBack) return": la página no tiene eventos de servidor
        // y el ViewState va apagado; si algo la envía (el cambio de cliente
        // del master), se vuelve a pintar entera.
        Plantas(SitioBase.Session.ClienteId());
        Periodos();
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

    private void Plantas(int cliente)
    {
        List<ClienteInstalacion> plantas = new ClienteInstalacionController().GetClienteInstalaciones(
            new ClienteInstalacion { cin_cliente = cliente, filtro_habilitado = "1" }) ?? new List<ClienteInstalacion>();
        StringBuilder s = new StringBuilder("<option value=\"0\">Todas las plantas</option>");
        foreach (ClienteInstalacion p in plantas)
            s.Append("<option value=\"").Append(p.cin_id).Append("\">").Append(Server.HtmlEncode(p.cin_nombre)).Append("</option>");
        litPlantas.Text = s.ToString();
    }

    /// <summary>
    /// El período es un mes: el Calendario muestra ese mes y Cumplimiento
    /// mide su cohorte. Desde enero del año pasado hasta diciembre del
    /// próximo; parte en el mes en curso.
    /// </summary>
    private void Periodos()
    {
        DateTime hoy = Hora.Hoy;
        StringBuilder s = new StringBuilder();
        for (DateTime m = new DateTime(hoy.Year - 1, 1, 1); m <= new DateTime(hoy.Year + 1, 12, 1); m = m.AddMonths(1))
        {
            string v = m.ToString("yyyy-MM", CultureInfo.InvariantCulture);
            s.Append("<option value=\"").Append(v).Append("\"")
             .Append(m.Year == hoy.Year && m.Month == hoy.Month ? " selected" : "")
             .Append(">").Append(MESES[m.Month - 1]).Append(' ').Append(m.Year).Append("</option>");
        }
        litPeriodos.Text = s.ToString();
    }
}
