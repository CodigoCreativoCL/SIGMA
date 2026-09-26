using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;

/// <summary>
/// Planificación: la puerta de entrada única a Programaciones, Plan de
/// mantenimiento y Bandeja de mantenciones, dentro del módulo Centro de
/// Mantenimiento.
///
/// SE LLAMA "PLANIFICACIÓN" Y NO "CENTRO DE MANTENIMIENTO"
///   Ese nombre es del módulo completo (el nodo padre del menú, que también
///   agrupa Procedimientos, Pautas, Tareas, Hallazgos y Órdenes). Esta vista
///   reúne solo la parte de planificar: cada cuánto, qué y qué toca hoy.
///
/// ESTO ES UN HUB, NO UN CUARTO MÓDULO
///   No repite lógica de negocio ni escribe nada: solo pide a los tres
///   controllers que ya existen los números que ya calculan, y arma tres
///   tarjetas que llevan a las pantallas reales. Cada módulo sigue siendo su
///   propia página, con su propio postback y su propio ciclo de vida.
///
/// POR QUÉ NO HAY UpdatePanel NI RadGrid2 ACÁ
///   El análisis de viabilidad de esta unificación midió que Programaciones
///   (80 KB de ViewState, listado vacío) y el Centro del plan (25 KB) ya son
///   las pantallas más pesadas del sitio, sin ninguna optimización aplicada.
///   Fusionar su contenido dentro de esta página multiplicaría ese peso en
///   cada postback. Esta página se queda deliberadamente liviana: literales
///   de servidor y enlaces, nada que dependa de ViewState para funcionar.
///
/// EL MENÚ DE PROGRAMACIONES / PLANES / BANDEJA QUEDA OCULTO
///   Las tres siguen existiendo con su propia fila en Menus y su propio
///   permiso -no cambia quién puede verlas- pero salen del árbol lateral
///   (mnu_visible = 0), igual que las fichas satélite del plan. Se llega a
///   ellas desde acá, que es ahora el nodo "Planificación".
/// </summary>
public partial class View_Mantenimiento_Planificacion : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (IsPostBack) return;

        int cliente = SitioBase.Session.ClienteId();

        Kpis(cliente);
        ResumenProgramaciones(cliente);
        ResumenPlanes(cliente);
        ResumenBandeja(cliente);
    }

    /// <summary>
    /// La URL de un archivo del sitio con la fecha del archivo colgada, para
    /// que el navegador no sirva una versión vieja del CSS.
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

    /// <summary>
    /// Los cuatro números de arriba, todos calculados por SP que ya existen:
    /// nada nuevo, solo una vista consolidada de lo que cada módulo ya sabe.
    /// </summary>
    private void Kpis(int cliente)
    {
        BandejaResumen resumen;
        new PlanOcurrenciaController().GetBandeja(new PlanOcurrencia { solo_abiertas = true }, out resumen);

        litUrgente.Text = (resumen.vencidas + resumen.atrasadas).ToString();
        litDisponibles.Text = resumen.disponibles.ToString();

        List<PlanMantenimiento> planes = new PlanMantenimientoController().GetPlanesMantenimiento(
            new PlanMantenimiento { pma_cliente = cliente, filtro_habilitado = true }) ?? new List<PlanMantenimiento>();
        litPlanes.Text = planes.Count.ToString();

        int publicados = planes.FindAll(p => string.Equals(p.version_estado_codigo, "PUBLICADO", StringComparison.OrdinalIgnoreCase)).Count;
        litPlanesPie.Text = publicados == planes.Count
            ? "Todos publicados"
            : publicados + " de " + planes.Count + " publicados";

        List<Programacion> programaciones = new ProgramacionController().GetProgramaciones(
            new Programacion { filtro_habilitado = true }) ?? new List<Programacion>();
        litProgramaciones.Text = programaciones.Count.ToString();
    }

    /// <summary>
    /// Una línea que dice si hay algo urgente o si la planta está al día,
    /// para no repetir la lógica de "0 pendientes" en cuatro lugares.
    /// </summary>
    private void Contexto(int urgente)
    {
        litContexto.Text = urgente > 0
            ? "<p class=\"sg-plan-anio\"><i class=\"mdi mdi-alert-outline\"></i> <strong>" + urgente + "</strong> "
              + (urgente == 1 ? "mantención requiere" : "mantenciones requieren") + " atención en la Bandeja.</p>"
            : "<p class=\"sg-plan-anio\"><i class=\"mdi mdi-check-circle-outline\"></i> Nada vencido ni atrasado: la planta está al día.</p>";
    }

    private void ResumenProgramaciones(int cliente)
    {
        List<Programacion> lista = new ProgramacionController().GetProgramaciones(
            new Programacion { filtro_habilitado = true }) ?? new List<Programacion>();

        if (lista.Count == 0)
        {
            litProgramacionesResumen.Text = "<p class=\"sg-ot-vacio-txt\">Sin programaciones definidas todavía.</p>";
            return;
        }

        // Por tipo, para que la tarjeta diga algo más que un número.
        Dictionary<string, int> porTipo = new Dictionary<string, int>();
        foreach (Programacion p in lista)
        {
            string tipo = string.IsNullOrEmpty(p.tipo_nombre) ? "Sin tipo" : p.tipo_nombre;
            porTipo[tipo] = porTipo.ContainsKey(tipo) ? porTipo[tipo] + 1 : 1;
        }

        StringBuilder s = new StringBuilder("<div class=\"sg-a3-ident\">");
        foreach (KeyValuePair<string, int> par in porTipo)
            s.Append("<div><dt>").Append(Server.HtmlEncode(par.Key)).Append("</dt><dd>")
             .Append(par.Value).Append(par.Value == 1 ? " programación" : " programaciones").Append("</dd></div>");
        s.Append("</div>");

        litProgramacionesResumen.Text = s.ToString();
    }

    private void ResumenPlanes(int cliente)
    {
        List<PlanMantenimiento> lista = new PlanMantenimientoController().GetPlanesMantenimiento(
            new PlanMantenimiento { pma_cliente = cliente, filtro_habilitado = true }) ?? new List<PlanMantenimiento>();

        if (lista.Count == 0)
        {
            litPlanesResumen.Text = "<p class=\"sg-ot-vacio-txt\">Sin planes de mantenimiento todavía.</p>";
            return;
        }

        int borrador = lista.FindAll(p => string.Equals(p.version_estado_codigo, "BORRADOR", StringComparison.OrdinalIgnoreCase)).Count;
        int publicado = lista.FindAll(p => string.Equals(p.version_estado_codigo, "PUBLICADO", StringComparison.OrdinalIgnoreCase)).Count;

        StringBuilder s = new StringBuilder("<div class=\"sg-a3-ident\">");
        s.Append("<div><dt>Total</dt><dd>").Append(lista.Count).Append("</dd></div>");
        s.Append("<div><dt>Publicados</dt><dd>").Append(publicado).Append("</dd></div>");
        if (borrador > 0)
            s.Append("<div><dt>Con borrador abierto</dt><dd><span class=\"grid-estado-chip is-advertencia\">")
             .Append(borrador).Append("</span></dd></div>");
        s.Append("</div>");

        litPlanesResumen.Text = s.ToString();
    }

    private void ResumenBandeja(int cliente)
    {
        BandejaResumen resumen;
        new PlanOcurrenciaController().GetBandeja(new PlanOcurrencia { solo_abiertas = true }, out resumen);

        Contexto(resumen.vencidas + resumen.atrasadas);

        StringBuilder s = new StringBuilder("<div class=\"sg-a3-ident\">");

        if (resumen.vencidas > 0)
            s.Append("<div><dt>Vencidas</dt><dd><span class=\"grid-estado-chip is-error\">")
             .Append(resumen.vencidas).Append("</span></dd></div>");

        if (resumen.atrasadas > 0)
            s.Append("<div><dt>Atrasadas</dt><dd><span class=\"grid-estado-chip is-advertencia\">")
             .Append(resumen.atrasadas).Append("</span></dd></div>");

        s.Append("<div><dt>Disponibles</dt><dd>").Append(resumen.disponibles).Append("</dd></div>");

        if (resumen.con_parada > 0)
            s.Append("<div><dt>Con parada</dt><dd>").Append(resumen.con_parada).Append("</dd></div>");

        if (resumen.vencidas == 0 && resumen.atrasadas == 0 && resumen.disponibles == 0)
        {
            s.Append("</div>");
            litBandejaResumen.Text = "<p class=\"sg-ot-vacio-txt\">Nada pendiente por ahora.</p>";
            return;
        }

        s.Append("</div>");
        litBandejaResumen.Text = s.ToString();
    }
}
