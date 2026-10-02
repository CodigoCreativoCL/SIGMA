using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Centro de repuestos.
///
/// POR QUE UN CENTRO Y NO SEIS MENUS
///   La información de un repuesto estaba repartida en cinco pantallas:
///   el maestro, las compatibilidades, las existencias, los movimientos y la
///   vida útil. Para responder «¿me conviene seguir comprando este rodamiento?»
///   había que abrir cinco menús y cruzarlos a mano. Acá se mira entero.
///
///   Es el mismo patrón del centro del activo y del centro de la pauta: un
///   listado, y al entrar un hero con KPIs y pestañas. Las altas y ediciones
///   siguen en su ficha modal de siempre: el centro reúne, no reemplaza a los
///   mantenedores.
///
/// EL CENTRO NO ES UNA PANTALLA MAS DE PERMISOS
///   Cada pestaña se arma solo si la persona tiene el permiso de ese dato, y
///   los botones de alta aparecen solo con el permiso de escritura. El control
///   real vive en el servidor, no en ocultar el botón.
/// </summary>
public partial class View_Inventario_Repuestos_RepuestoCentro : System.Web.UI.Page
{
    private static readonly CultureInfo CL = CultureInfo.GetCultureInfo("es-CL");

    /// <summary>Repuesto abierto (rep_id). 0 = mostrar el listado.</summary>
    public int RepuestoId
    {
        get { int v; return int.TryParse(hdnRepuesto.Value, out v) ? v : 0; }
        set { hdnRepuesto.Value = value.ToString(); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        SitioBase.Token.ExigirPagina();

        // Enlace directo desde otra pantalla: ?query cifrado con el Id.
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            int id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            if (id > 0) RepuestoId = id;
        }

        /* Los combos del filtro estan dentro de la plantilla del wuc: recien
           existen cuando esta se instancia, asi que se llenan en el PreRender
           y no aca. */
        if (!IsPostBack) CargarTiposMovimiento();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack) { CargarPlantas(); CargarBodegas(); CargarTipos(); }

        bool puedeCrear = SitioBase.Token.Puede("CREAR EDITAR REPUESTOS");

        if (RepuestoId > 0)
        {
            pnlLista.Visible = false;
            pnlFicha.Visible = true;
            CargarFicha(puedeCrear);
        }
        else
        {
            pnlLista.Visible = true;
            pnlFicha.Visible = false;
            CargarLista(puedeCrear);
        }
    }

    protected void lnkRecargar_Click(object sender, EventArgs e) { /* el PreRender repinta */ }

    protected void Filtro_Changed(object sender, EventArgs e)
    {
        RepuestoId = 0;     // cambiar el filtro siempre devuelve al listado
    }

    /// <summary>Al cambiar la planta, la lista de bodegas se acota a ella.</summary>
    protected void Planta_Changed(object sender, EventArgs e)
    {
        RepuestoId = 0;
        CargarBodegas();
    }

    /// <summary>
    /// Exporta a Excel lo que muestra el filtro, no el maestro completo:
    /// bajar mil repuestos cuando se buscaban tres es un archivo inutil.
    /// </summary>
    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!SitioBase.Token.Puede("VER REPUESTOS"))
                throw new Exception("No tiene permiso para ver repuestos.");
            new RepuestoController().ExportarRepuestos(FiltroActual());
        }
        catch (System.Threading.ThreadAbortException) { }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    // ===================================================================== listado

    /// <summary>Plantas del cliente, deducidas de sus bodegas.</summary>
    private void CargarPlantas()
    {
        ddlPlanta.Items.Clear();
        ddlPlanta.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
        HashSet<int> vistas = new HashSet<int>();
        foreach (Bodega b in Bodegas())
            if (b.bod_cliente_instalacion > 0 && !string.IsNullOrEmpty(b.planta_nombre)
                && vistas.Add(b.bod_cliente_instalacion))
                ddlPlanta.Items.Add(new RadComboBoxItem(
                    b.planta_nombre, b.bod_cliente_instalacion.ToString()));
    }

    /// <summary>Bodegas, acotadas a la planta elegida si hay una.</summary>
    private void CargarBodegas()
    {
        int planta = Entero(ddlPlanta.SelectedValue);
        ddlBodega.Items.Clear();
        ddlBodega.Items.Add(new RadComboBoxItem("Todas las bodegas", ""));
        foreach (Bodega b in Bodegas())
            if (planta == 0 || b.bod_cliente_instalacion == planta)
                ddlBodega.Items.Add(new RadComboBoxItem(
                    b.bod_nombre, b.bod_id.ToString()));
    }

    private List<Bodega> _bodegas;
    private List<Bodega> Bodegas()
    {
        if (_bodegas == null)
            _bodegas = new BodegaController().GetBodegas(new Bodega { bod_habilitado = true })
                       ?? new List<Bodega>();
        return _bodegas;
    }

    private static int Entero(string v) { int n; return int.TryParse(v, out n) ? n : 0; }

    /* Los controles del filtro viven dentro de la plantilla del wuc, asi que
       no son campos de la pagina: hay que pedirlos por su id. */
    private RadComboBox2 Cbo(string id) { return (RadComboBox2)wucFiltro.FindControl(id); }
    private System.Web.UI.WebControls.CheckBox Chk(string id)
    { return (System.Web.UI.WebControls.CheckBox)wucFiltro.FindControl(id); }

    private RadComboBox2 ddlPlanta { get { return Cbo("ddlPlanta"); } }
    private RadComboBox2 ddlBodega { get { return Cbo("ddlBodega"); } }
    private RadComboBox2 ddlTipo { get { return Cbo("ddlTipo"); } }
    private RadComboBox2 ddlEstado { get { return Cbo("ddlEstado"); } }
    private System.Web.UI.WebControls.CheckBox chkLote { get { return Chk("chkLote"); } }
    private System.Web.UI.WebControls.CheckBox chkInhabilitados { get { return Chk("chkInhabilitados"); } }

    /// <summary>Tipos de movimiento, para filtrar la pestana Movimientos.</summary>
    private void CargarTiposMovimiento()
    {
        ddlMovTipo.Items.Clear();
        ddlMovTipo.Items.Add(new RadComboBoxItem("Todos los movimientos", ""));
        List<InventarioMovimientoTipo> tipos = new InventarioController().GetTipos();
        if (tipos != null)
            foreach (InventarioMovimientoTipo t in tipos)
                ddlMovTipo.Items.Add(new RadComboBoxItem(t.imt_nombre, t.imt_id.ToString()));
    }

    protected void Mov_Changed(object sender, EventArgs e) { /* el PreRender repinta la ficha */ }

    private void CargarTipos()
    {
        ddlTipo.Items.Clear();
        ddlTipo.Items.Add(new RadComboBoxItem("Todos los tipos", ""));
        List<RepuestoTipo> tipos = new RepuestoTipoController().GetRepuestoTipos(
            new RepuestoTipo { filtro_habilitado = true });
        if (tipos != null)
            foreach (RepuestoTipo t in tipos)
                ddlTipo.Items.Add(new RadComboBoxItem(t.rti_nombre, t.rti_id.ToString()));
    }

    /// <summary>El filtro del maestro, tal como lo arma la barra.</summary>
    private Repuesto FiltroActual()
    {
        Repuesto f = new Repuesto();
        if (!chkInhabilitados.Checked) f.filtro_habilitado = true;
        if (!string.IsNullOrWhiteSpace(wucFiltro.Filtro())) f.filtro = wucFiltro.Filtro().Trim();
        int tipo = Entero(ddlTipo.SelectedValue);
        if (tipo > 0) f.rep_repuesto_tipo = tipo;
        return f;
    }

    private void CargarLista(bool puedeCrear)
    {
        lnkNuevo.Visible = puedeCrear;
        lnkCargaMasiva.Visible = puedeCrear;
        lnkClasificar.Visible = puedeCrear;
        lnkCargaMasiva.OnClientClick =
            "return SigmaModal.open({url:'" + ResolveUrl("~/View/Inventario/Repuestos/CargaMasivaRepuestos.aspx") +
            "',title:'Carga masiva de repuestos',width:900,initialHeight:600,onClose:refresh});";
        // La clasificacion masiva necesita seleccion multiple: eso vive en el
        // listado clasico, que sigue existiendo. El centro no la pierde.
        lnkClasificar.OnClientClick =
            "return SigmaModal.open({url:'" + ResolveUrl("~/View/Inventario/Repuestos/Repuestos.aspx") +
            "',title:'Clasificar repuestos',width:1100,initialHeight:680,onClose:refresh});";
        hlBodegas.NavigateUrl = ResolveUrl("~/View/Inventario/Bodegas/Bodegas.aspx");
        hlTipos.NavigateUrl = ResolveUrl("~/View/Inventario/Repuestos/RepuestoTipos.aspx");

        List<Repuesto> lista = new RepuestoController().GetRepuestos(FiltroActual()) ?? new List<Repuesto>();

        // ---- filtros que se resuelven por los saldos ----
        int planta = Entero(ddlPlanta.SelectedValue);
        int bodega = Entero(ddlBodega.SelectedValue);
        string estado = ddlEstado.SelectedValue;

        if (planta > 0 || bodega > 0 || estado == "bajo" || estado == "sobre")
        {
            InventarioSaldo fs = new InventarioSaldo();
            if (bodega > 0) fs.isa_bodega = bodega;
            else if (planta > 0) fs.filtro_instalacion = planta;
            List<InventarioSaldo> saldos = new InventarioController().GetSaldos(fs) ?? new List<InventarioSaldo>();

            HashSet<int> ids = new HashSet<int>();
            foreach (InventarioSaldo x in saldos)
            {
                if (estado == "bajo" && !x.bajo_minimo) continue;
                if (estado == "sobre" && !x.sobre_maximo) continue;
                ids.Add(x.isa_repuesto);
            }
            lista = lista.FindAll(r => ids.Contains(r.rep_id));
        }

        if (estado == "con") lista = lista.FindAll(r => r.existencia_total > 0);
        else if (estado == "sin") lista = lista.FindAll(r => r.existencia_total <= 0);
        if (chkLote.Checked) lista = lista.FindAll(r => r.rep_controla_lote);

        // Indices para las tarjetas y los KPIs: una lectura para todo el
        // listado, no una por repuesto.
        Dictionary<int, int> portadas = new RepuestoFotoController().GetPortadas()
                                        ?? new Dictionary<int, int>();
        /* Las imagenes de cada tarjeta, para el visor. SEL_REPUESTO_FOTO pide
           un repuesto a la vez, asi que se consulta solo para los que TIENEN
           portada -los demas no tienen ninguna- y hasta un tope: en un listado
           largo no vale la pena pagar una consulta por tarjeta para una lupa. */
        Dictionary<int, List<RepuestoFoto>> fotosPorRep = new Dictionary<int, List<RepuestoFoto>>();
        if (portadas.Count > 0 && lista.Count <= 60)
        {
            RepuestoFotoController fc = new RepuestoFotoController();
            foreach (Repuesto rr in lista)
                if (portadas.ContainsKey(rr.rep_id))
                    fotosPorRep[rr.rep_id] = fc.GetFotos(rr.rep_id) ?? new List<RepuestoFoto>();
        }

        // Una lectura para todo el listado, no una por tarjeta.
        Dictionary<int, string> alerta = new Dictionary<int, string>();
        foreach (InventarioSaldo x in (new InventarioController().GetSaldos(new InventarioSaldo())
                                       ?? new List<InventarioSaldo>()))
        {
            if (x.bajo_minimo) alerta[x.isa_repuesto] = "bajo";
            else if (x.sobre_maximo && !alerta.ContainsKey(x.isa_repuesto)) alerta[x.isa_repuesto] = "sobre";
        }

        Dictionary<int, List<RepuestoCompatibilidad>> compatPorRep =
            new Dictionary<int, List<RepuestoCompatibilidad>>();
        foreach (RepuestoCompatibilidad x in (new RepuestoCompatibilidadController()
                                              .GetCompatibilidades(new RepuestoCompatibilidad())
                                              ?? new List<RepuestoCompatibilidad>()))
        {
            if (!compatPorRep.ContainsKey(x.rco_repuesto))
                compatPorRep[x.rco_repuesto] = new List<RepuestoCompatibilidad>();
            compatPorRep[x.rco_repuesto].Add(x);
        }

        // ---- KPIs ----
        int conStock = 0, sinStock = 0, conLote = 0;
        decimal unidades = 0;
        foreach (Repuesto r in lista)
        {
            if (r.existencia_total > 0) { conStock++; unidades += r.existencia_total; } else sinStock++;
            if (r.rep_controla_lote) conLote++;
        }
        StringBuilder k = new StringBuilder();
        k.Append(Kpi("package-variant-closed", "lila", "Repuestos", lista.Count.ToString(CL), Contexto()));
        k.Append(Kpi("check-circle-outline", "ok", "Con existencia", conStock.ToString(CL), ""));
        k.Append(Kpi(sinStock > 0 ? "alert-circle-outline" : "circle-outline",
                     sinStock > 0 ? "ambar" : "teal", "Sin existencia", sinStock.ToString(CL), ""));
        int enAlerta = 0;
        foreach (Repuesto r in lista) if (alerta.ContainsKey(r.rep_id)) enAlerta++;
        k.Append(Kpi(enAlerta > 0 ? "bell-alert-outline" : "counter", enAlerta > 0 ? "alerta" : "azul",
                     enAlerta > 0 ? "Fuera de umbral" : "Unidades en bodega",
                     enAlerta > 0 ? enAlerta.ToString(CL) : Num(unidades),
                     enAlerta > 0 ? "Revisar minimo y maximo" : (conLote > 0 ? conLote + " controlan lote" : "")));
        litKpis.Text = k.ToString();

        // ---- tarjetas, con la foto de portada del repuesto ----
        pnlListaVacia.Visible = lista.Count == 0;
        litResultado.Text = lista.Count == 0 ? "" :
            "<p class=\"rc-resultado\">" + lista.Count.ToString(CL) + " repuesto" +
            (lista.Count == 1 ? "" : "s") + "</p>";
        if (lista.Count == 0) { litLista.Text = ""; return; }

        StringBuilder s2 = new StringBuilder("<div class=\"rc-grid\">");
        foreach (Repuesto r in lista)
        {
            // Las imagenes del repuesto viajan en la tarjeta para que el visor
            // no tenga que ir a buscarlas al abrirse.
            List<RepuestoFoto> suyas;
            List<string> urls = new List<string>();
            if (fotosPorRep.TryGetValue(r.rep_id, out suyas))
                foreach (RepuestoFoto f in suyas)
                    if (string.IsNullOrEmpty(f.mime) || f.mime.StartsWith("image/"))
                        urls.Add(SitioBase.UrlArchivo.Ver(f.archivo));

            int archivo;
            string foto;
            if (portadas.TryGetValue(r.rep_id, out archivo) && archivo > 0)
            {
                string srcs = Esc(string.Join("|", urls.ToArray()));
                foto = "<span class=\"rc-thumb\" data-fotos=\"" + srcs + "\" data-titulo=\"" + Esc(r.rep_nombre)
                     + "\" onclick=\"return rcVisor(this);\">"
                     + "<img src=\"" + Esc(SitioBase.UrlArchivo.Ver(archivo)) + "\" alt=\"" + Esc(r.rep_nombre) + "\" />"
                     + "<i class=\"mdi mdi-magnify-plus-outline rc-lupa\"></i></span>";
            }
            else
            {
                foto = "<span class=\"rc-thumb es-vacia\"><i class=\"mdi mdi-image-off-outline\"></i></span>";
            }

            string chipTipo = string.IsNullOrEmpty(r.repuesto_tipo_nombre) ? "" :
                "<span class=\"rc-badge es-tipo\">" + Esc(r.repuesto_tipo_nombre) + "</span>";
            string chipStock = r.existencia_total > 0
                ? "<span class=\"rc-badge es-ok\">En " + r.bodegas_con_saldo + " bodega" + (r.bodegas_con_saldo == 1 ? "" : "s") + "</span>"
                : "<span class=\"rc-badge es-off\">Sin existencia</span>";
            string chipLote = r.rep_controla_lote ? "<span class=\"rc-badge es-lote\">Por lote</span>" : "";
            string chipOff = r.rep_habilitado ? "" : "<span class=\"rc-badge es-off\">Deshabilitado</span>";

            // El aviso de umbral va en la tarjeta: es lo que hace entrar.
            string chipUmbral = "";
            string umb;
            if (alerta.TryGetValue(r.rep_id, out umb))
                chipUmbral = umb == "bajo"
                    ? "<span class=\"rc-badge es-bajo\"><i class=\"mdi mdi-arrow-down-bold-outline\"></i> Bajo el minimo</span>"
                    : "<span class=\"rc-badge es-alto\"><i class=\"mdi mdi-arrow-up-bold-outline\"></i> Sobre el maximo</span>";

            // Con que calza, sin entrar al repuesto.
            string compatHtml = "";
            List<RepuestoCompatibilidad> cs;
            if (compatPorRep.TryGetValue(r.rep_id, out cs) && cs.Count > 0)
            {
                StringBuilder li = new StringBuilder();
                foreach (RepuestoCompatibilidad x in cs)
                    li.Append("<li><span class=\"rc-badge es-info\">")
                      .Append(Esc(string.IsNullOrEmpty(x.alcance_etiqueta) ? x.alcance : x.alcance_etiqueta))
                      .Append("</span> ").Append(Esc(x.alcance_nombre)).Append("</li>");
                compatHtml = "<details class=\"rc-compat\" onclick=\"event.stopPropagation();\">"
                           + "<summary><i class=\"mdi mdi-puzzle-outline\"></i> Compatible con "
                           + cs.Count + (cs.Count == 1 ? " equipo" : " equipos") + "</summary>"
                           + "<ul>" + li + "</ul></details>";
            }
            else
            {
                compatHtml = "<div class=\"rc-compat es-vacia\"><i class=\"mdi mdi-puzzle-outline\"></i> "
                           + "Sin compatibilidades declaradas</div>";
            }

            s2.Append("<div class=\"rc-item\" onclick=\"abrirCentroRepuesto(").Append(r.rep_id).Append(")\">")
              .Append("<div class=\"rc-item-top\">").Append(foto).Append("<div class=\"rc-item-id\">")
              .Append("<div class=\"cod\">").Append(Esc(r.rep_codigo)).Append("</div>")
              .Append("<div class=\"nom\">").Append(Esc(r.rep_nombre)).Append("</div>")
              .Append("</div></div>")
              .Append("<div class=\"rc-item-chips\">").Append(chipTipo).Append(chipLote)
              .Append(chipUmbral).Append(chipOff).Append("</div>")
              .Append(compatHtml)
              .Append("<div class=\"pie\">")
              .Append("<div class=\"stock\">").Append(Num(r.existencia_total))
              .Append("<small>").Append(Esc(r.unidad_simbolo)).Append("</small></div>")
              .Append(chipStock)
              .Append("</div></div>");
        }
        s2.Append("</div>");
        litLista.Text = s2.ToString();
    }

    /// <summary>Texto del contexto de filtro, para el pie del primer KPI.</summary>
    private string Contexto()
    {
        List<string> p = new List<string>();
        if (Entero(ddlPlanta.SelectedValue) > 0) p.Add(ddlPlanta.SelectedItem.Text);
        if (Entero(ddlBodega.SelectedValue) > 0) p.Add(ddlBodega.SelectedItem.Text);
        if (Entero(ddlTipo.SelectedValue) > 0) p.Add(ddlTipo.SelectedItem.Text);
        return p.Count == 0 ? "Todo el maestro" : string.Join(" · ", p.ToArray());
    }

    // ======================================================================= ficha

    private void CargarFicha(bool puedeCrear)
    {
        Repuesto r = new RepuestoController().GetRepuesto(RepuestoId);
        if (r == null || r.rep_id == 0) { RepuestoId = 0; return; }

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + r.rep_id));
        string queryNuevoDe = Server.UrlEncode(Tools.Crypto.Encrypt("Repuesto=" + r.rep_id));

        litMiga.Text = Esc(r.rep_codigo);
        litHeroNombre.Text = Esc(r.rep_nombre);
        litHeroSub.Text = Esc(r.rep_codigo)
            + (string.IsNullOrEmpty(r.repuesto_tipo_nombre) ? "" : " · " + Esc(r.repuesto_tipo_nombre))
            + (string.IsNullOrEmpty(r.rep_fabricante) ? "" : " · " + Esc(r.rep_fabricante))
            + (r.rep_habilitado ? "" : " · <span class=\"rc-badge es-off\">Deshabilitado</span>");

        lnkEditar.Visible = puedeCrear;
        lnkEditar.OnClientClick = "return abrirRepuesto('" + query + "');";
        lnkNuevaCompat.Visible = puedeCrear;
        lnkNuevaCompat.OnClientClick = "return abrirCompatibilidad('" + queryNuevoDe + "');";
        lnkNuevoMov.Visible = SitioBase.Token.Puede("REGISTRAR MOVIMIENTOS DE INVENTARIO");
        pnlSubir.Visible = puedeCrear;
        lnkNuevoMov.OnClientClick = "return abrirMovimiento('" + queryNuevoDe + "');";

        // ---- datos para los KPIs y los paneles ----
        List<InventarioSaldo> saldos = new InventarioController()
            .GetSaldos(new InventarioSaldo { isa_repuesto = r.rep_id }) ?? new List<InventarioSaldo>();
        List<RepuestoVidaUtil> vida = new RepuestoController()
            .GetVidaUtil(new RepuestoVidaUtil { filtro_repuesto = r.rep_id }) ?? new List<RepuestoVidaUtil>();
        List<RepuestoCompatibilidad> compat = new RepuestoCompatibilidadController()
            .GetCompatibilidades(new RepuestoCompatibilidad { filtro_repuesto = r.rep_id }) ?? new List<RepuestoCompatibilidad>();

        int bajoMinimo = 0;
        foreach (InventarioSaldo x in saldos) if (x.bajo_minimo) bajoMinimo++;

        StringBuilder k = new StringBuilder();
        k.Append(Kpi("counter", "lila", "Existencia total",
                     Num(r.existencia_total) + " " + Esc(r.unidad_simbolo), VidaDeclarada(r)));
        k.Append(Kpi("warehouse", "teal", "Bodegas con saldo", saldos.Count.ToString(CL), ""));
        k.Append(Kpi(bajoMinimo > 0 ? "alert-outline" : "check-circle-outline",
                     bajoMinimo > 0 ? "alerta" : "ok", "Bajo el minimo", bajoMinimo.ToString(CL),
                     bajoMinimo > 0 ? "Hay que reponer" : "Todo en rango"));
        k.Append(Kpi("puzzle-outline", "azul", "Compatibilidades", compat.Count.ToString(CL),
                     vida.Count > 0 ? vida.Count + " instalaciones" : ""));
        litKpisFicha.Text = k.ToString();

        RenderResumen(r, saldos);
        RenderCompatibilidades(compat, puedeCrear);
        RenderExistencias(r, saldos);
        RenderPosiciones(r, saldos);
        RenderMovimientos(r);
        RenderVidaUtil(r, vida);
        RenderEvidencia(r);

        // El panel inicial se marca activo en el servidor: si el JS no alcanza
        // a engancharse -paso en el primer intento- las pestañas quedaban todas
        // cerradas y el centro se veia vacio.
        string sec = string.IsNullOrEmpty(hdnSeccion.Value) ? "resumen" : hdnSeccion.Value;
        ClientScript.RegisterStartupScript(GetType(), "rcSec",
            "(function(){var s='" + sec.Replace("'", "") + "';" +
            "var t=document.querySelectorAll('.sg-a3-tab[data-sec]');" +
            "for(var i=0;i<t.length;i++)t[i].classList.toggle('es-activa',t[i].getAttribute('data-sec')===s);" +
            "var p=document.querySelectorAll('.sg-a3-panel[data-panel]');" +
            "for(var j=0;j<p.length;j++)p[j].classList.toggle('es-activo',p[j].getAttribute('data-panel')===s);})();",
            true);
    }

    // --------------------------------------------------------------- resumen

    private void RenderResumen(Repuesto r, List<InventarioSaldo> saldos)
    {
        int portada = new RepuestoFotoController().GetPortadas().ContainsKey(r.rep_id)
                      ? new RepuestoFotoController().GetPortadas()[r.rep_id] : 0;
        litFotoResumen.Text = portada > 0
            ? "<span class=\"rc-foto-grande\"><img src=\"" + Esc(SitioBase.UrlArchivo.Ver(portada))
              + "\" alt=\"" + Esc(r.rep_nombre) + "\" /></span>"
            : "<span class=\"rc-foto-grande\"><i class=\"mdi mdi-image-off-outline\"></i></span>";

        StringBuilder s = new StringBuilder("<div class=\"rc-datos\">");
        s.Append(Dato("Código", r.rep_codigo));
        s.Append(Dato("Nombre", r.rep_nombre));
        s.Append(Dato("Tipo", r.repuesto_tipo_nombre));
        s.Append(Dato("Fabricante", r.rep_fabricante));
        s.Append(Dato("Modelo", r.rep_modelo));
        s.Append(Dato("Unidad de medida", r.unidad_nombre + (string.IsNullOrEmpty(r.unidad_simbolo) ? "" : " (" + r.unidad_simbolo + ")")));
        s.Append(Dato("Costo de referencia", r.rep_costo_referencia == null ? "" :
            Num(r.rep_costo_referencia.Value) + " " + (r.moneda_codigo ?? "")));
        s.Append(Dato("Reparable", r.rep_es_reparable ? "Sí" : "No"));
        s.Append(Dato("Consumible", r.rep_es_consumible ? "Sí" : "No"));
        s.Append(Dato("Controla lote", r.rep_controla_lote ? "Sí" : "No"));
        s.Append(Dato("Vida útil declarada", VidaDeclarada(r)));
        s.Append("</div>");
        if (!string.IsNullOrWhiteSpace(r.rep_descripcion))
            s.Append("<p style=\"margin:12px 0 0;font-size:13px;color:#17223B;line-height:1.5\">")
             .Append(Esc(r.rep_descripcion)).Append("</p>");
        litResumen.Text = s.ToString();

        if (saldos.Count == 0)
        {
            litResumenStock.Text = Vacio("warehouse", "Sin existencia registrada",
                "Este repuesto todavía no tiene saldo en ninguna bodega.");
            return;
        }
        StringBuilder t = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Bodega</th><th>Planta</th>"
            + "<th class=\"num\">Disponible</th><th class=\"num\">Reservado</th><th></th></tr>");
        foreach (InventarioSaldo x in saldos)
            t.Append("<tr><td>").Append(Esc(x.bodega_nombre)).Append("</td><td>").Append(Esc(x.planta_nombre))
             .Append("</td><td class=\"num\">").Append(Num(x.cantidad_disponible))
             .Append("</td><td class=\"num\">").Append(Num(x.isa_cantidad_reservada))
             .Append("</td><td>").Append(ChipSaldo(x)).Append("</td></tr>");
        t.Append("</table>");
        litResumenStock.Text = t.ToString();
    }

    private static string VidaDeclarada(Repuesto r)
    {
        List<string> p = new List<string>();
        if (r.rep_vida_util_hora != null) p.Add(Num(r.rep_vida_util_hora.Value) + " h");
        if (r.rep_vida_util_dia != null) p.Add(r.rep_vida_util_dia.Value.ToString(CL) + " días");
        if (r.rep_vida_util_ciclo != null) p.Add(Num(r.rep_vida_util_ciclo.Value) + " ciclos");
        return p.Count == 0 ? "" : string.Join(" · ", p.ToArray());
    }

    // ------------------------------------------------------- compatibilidades

    private void RenderCompatibilidades(List<RepuestoCompatibilidad> lista, bool puedeCrear)
    {
        if (lista.Count == 0)
        {
            litCompatibilidades.Text = Vacio("puzzle-outline", "Sin compatibilidades declaradas",
                "Declarar con qué tipo, modelo o componente calza evita pedir el repuesto equivocado.");
            return;
        }
        StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Alcance</th><th>Aplica a</th>"
            + "<th>Observación</th><th></th></tr>");
        foreach (RepuestoCompatibilidad c in lista)
        {
            string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + c.rco_id));
            s.Append("<tr><td><span class=\"rc-badge es-info\">")
             .Append(Esc(string.IsNullOrEmpty(c.alcance_etiqueta) ? c.alcance : c.alcance_etiqueta))
             .Append("</span></td><td>").Append(Esc(c.alcance_nombre))
             .Append("</td><td>").Append(Esc(c.rco_observacion)).Append("</td><td style=\"text-align:right\">");
            if (puedeCrear)
                s.Append("<a href=\"#\" class=\"link\" onclick=\"return abrirCompatibilidad('").Append(q)
                 .Append("')\"><i class=\"mdi mdi-pencil-outline\"></i></a>");
            s.Append("</td></tr>");
        }
        s.Append("</table>");
        litCompatibilidades.Text = s.ToString();
    }

    // ------------------------------------------------------------ existencias

    /// <summary>Ingreso por compra y salida por consumo (Inventario_Movimiento_Tipo).</summary>
    private const int TIPO_INGRESO = 1;
    private const int TIPO_SALIDA = 2;

    /// <summary>
    /// Boton de ingreso o salida sobre una fila de existencia. Abre la ficha de
    /// movimiento con el repuesto, la bodega y el tipo ya puestos: lo que se
    /// esta mirando no se vuelve a preguntar.
    /// </summary>
    private string AccionSaldo(int repuesto, int bodega, int tipo, string icono, string titulo, string clase)
    {
        string q = Server.UrlEncode(Tools.Crypto.Encrypt(
            "Repuesto=" + repuesto + "&Bodega=" + bodega + "&Tipo=" + tipo));
        return " <a href=\"#\" class=\"rc-accion " + clase + "\" title=\"" + Esc(titulo)
             + "\" onclick=\"return abrirMovimiento('" + q + "')\"><i class=\"mdi mdi-" + icono + "\"></i></a>";
    }

    private void RenderExistencias(Repuesto r, List<InventarioSaldo> saldos)
    {
        bool puedeMover = SitioBase.Token.Puede("REGISTRAR MOVIMIENTOS DE INVENTARIO");
        if (saldos.Count == 0)
            litExistencias.Text = Vacio("warehouse", "Sin existencia", "No hay saldo en ninguna bodega.");
        else
        {
            StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Bodega</th><th>Planta</th>"
                + "<th class=\"num\">Cantidad</th><th class=\"num\">Reservado</th><th class=\"num\">Disponible</th>"
                + "<th>Último movimiento</th><th></th></tr>");
            foreach (InventarioSaldo x in saldos)
            {
                // Existencia.aspx abre el detalle DEL REPUESTO (sus bodegas, cubos y
                // movimientos), asi que recibe el id del repuesto, no el del saldo.
                string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + r.rep_id));
                s.Append("<tr><td>").Append(Esc(x.bodega_nombre)).Append("</td><td>").Append(Esc(x.planta_nombre))
                 .Append("</td><td class=\"num\">").Append(Num(x.isa_cantidad))
                 .Append("</td><td class=\"num\">").Append(Num(x.isa_cantidad_reservada))
                 .Append("</td><td class=\"num\"><b>").Append(Num(x.cantidad_disponible)).Append("</b>")
                 .Append("</td><td>").Append(Fecha(x.isa_fecha_ultimo_movimiento))
                 .Append("</td><td style=\"text-align:right;white-space:nowrap\">").Append(ChipSaldo(x))
                 .Append(puedeMover ? AccionSaldo(r.rep_id, x.isa_bodega, TIPO_INGRESO,
                                                  "plus-circle-outline", "Ingresar", "es-entra") : "")
                 .Append(puedeMover ? AccionSaldo(r.rep_id, x.isa_bodega, TIPO_SALIDA,
                                                  "minus-circle-outline", "Dar salida", "es-sale") : "")
                 .Append(" <a href=\"#\" class=\"link\" onclick=\"return abrirExistencia('").Append(q)
                 .Append("')\" title=\"Ver el detalle de la existencia\"><i class=\"mdi mdi-open-in-new\"></i></a></td></tr>");
            }
            s.Append("</table>");
            litExistencias.Text = s.ToString();
        }

        List<RepuestoBodegaStock> umb = new RepuestoController()
            .GetUmbrales(new RepuestoBodegaStock { rbs_repuesto = r.rep_id }) ?? new List<RepuestoBodegaStock>();
        if (umb.Count == 0)
            litUmbrales.Text = Vacio("tune-variant", "Sin umbrales definidos",
                "Sin mínimo ni punto de reposición el sistema no puede avisar cuando queda poco.");
        else
        {
            StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Bodega</th>"
                + "<th class=\"num\">Mínimo</th><th class=\"num\">Punto de reposición</th><th class=\"num\">Máximo</th></tr>");
            foreach (RepuestoBodegaStock u in umb)
                s.Append("<tr><td>").Append(Esc(u.bodega_nombre))
                 .Append("</td><td class=\"num\">").Append(Num(u.rbs_stock_minimo))
                 .Append("</td><td class=\"num\">").Append(u.rbs_punto_reposicion == null ? "—" : Num(u.rbs_punto_reposicion.Value))
                 .Append("</td><td class=\"num\">").Append(u.rbs_stock_maximo == null ? "—" : Num(u.rbs_stock_maximo.Value))
                 .Append("</td></tr>");
            s.Append("</table>");
            litUmbrales.Text = s.ToString();
        }

        // Los lotes solo tienen sentido si el repuesto los controla.
        pnlLotes.Visible = r.rep_controla_lote;
        if (!r.rep_controla_lote) return;
        List<RepuestoLote> lotes = new RepuestoController()
            .GetLotes(new RepuestoLote { rlo_repuesto = r.rep_id }) ?? new List<RepuestoLote>();
        if (lotes.Count == 0)
        {
            litLotes.Text = Vacio("barcode", "Sin lotes registrados",
                "Este repuesto controla lote, pero todavía no se ha ingresado ninguno.");
            return;
        }
        StringBuilder l = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Lote</th><th>Ingreso</th>"
            + "<th>Vencimiento</th><th class=\"num\">Costo unitario</th></tr>");
        foreach (RepuestoLote x in lotes)
            l.Append("<tr><td>").Append(Esc(x.rlo_codigo)).Append("</td><td>").Append(Fecha(x.rlo_fecha_ingreso))
             .Append("</td><td>").Append(Fecha(x.rlo_fecha_vencimiento))
             .Append("</td><td class=\"num\">").Append(x.rlo_costo_unitario == null ? "—" : Num(x.rlo_costo_unitario.Value))
             .Append("</td></tr>");
        l.Append("</table>");
        litLotes.Text = l.ToString();
    }

    private static string ChipSaldo(InventarioSaldo x)
    {
        if (x.bajo_minimo) return "<span class=\"rc-badge es-bajo\">Bajo el mínimo</span>";
        if (x.sobre_maximo) return "<span class=\"rc-badge es-alto\">Sobre el máximo</span>";
        return "<span class=\"rc-badge es-ok\">En rango</span>";
    }

    // ------------------------------------------------------------- posiciones

    /// <summary>
    /// Donde esta fisicamente el repuesto dentro de cada bodega.
    ///
    /// La posicion sale del SALDO, no del movimiento: el saldo es el dato
    /// vigente y ya trae la ubicacion -y resuelve el caso de varios estantes
    /// con ubicacion_texto-, mientras que el movimiento es historia. Deducirla
    /// del ultimo movimiento seria dar un rodeo por el dato equivocado.
    ///
    /// Las ubicaciones de una bodega se crean en la ficha de la bodega, que ya
    /// tiene su pestana Ubicaciones. Aqui se enlaza a ella en vez de duplicar
    /// el mantenedor: un dato, un lugar donde se mantiene.
    /// </summary>
    private void RenderPosiciones(Repuesto r, List<InventarioSaldo> saldos)
    {
        if (saldos.Count == 0)
        {
            litPosiciones.Text = Vacio("map-marker-off-outline", "Sin existencia en ninguna bodega",
                "La posicion aparece cuando el repuesto tiene saldo en una bodega.");
            return;
        }

        StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Bodega</th><th>Planta</th>"
            + "<th>Posicion</th><th class=\"num\">Cantidad</th><th></th></tr>");
        foreach (InventarioSaldo x in saldos)
        {
            string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + x.isa_bodega));
            bool tiene = !string.IsNullOrEmpty(x.ubicacion_codigo) || x.ubicaciones > 0;
            s.Append("<tr><td>").Append(Esc(x.bodega_nombre))
             .Append("</td><td>").Append(Esc(x.planta_nombre))
             .Append("</td><td>")
             .Append(tiene
                ? "<span class=\"rc-badge es-info\"><i class=\"mdi mdi-map-marker-outline\"></i> "
                  + Esc(x.ubicacion_texto) + "</span>"
                : "<span class=\"rc-badge es-off\">Sin estante asignado</span>")
             .Append("</td><td class=\"num\">").Append(Num(x.isa_cantidad))
             .Append("</td><td style=\"text-align:right\">")
             .Append("<a href=\"#\" class=\"link\" onclick=\"return abrirBodega('").Append(q)
             .Append("')\" title=\"Crear o editar las ubicaciones de esta bodega\">")
             .Append("<i class=\"mdi mdi-cog-outline\"></i> Ubicaciones de la bodega</a>")
             .Append("</td></tr>");
        }
        s.Append("</table>");
        s.Append("<p style=\"margin:10px 0 0;font-size:12px;color:#68738A\">")
         .Append("El estante se asigna al mover el repuesto: en el movimiento se indica la ubicacion de destino. ")
         .Append("Las ubicaciones disponibles de cada bodega se crean en la ficha de la bodega.</p>");
        litPosiciones.Text = s.ToString();
    }

    // ------------------------------------------------------------ movimientos

    /// <summary>
    /// Los movimientos del repuesto.
    ///
    /// EL BADGE DICE QUE LE HACE AL SALDO
    ///   "Devolucion" y "Salida por consumo" se distinguen por el nombre, pero
    ///   lo que importa de un vistazo es si entra o sale. El modelo ya trae
    ///   'signo' y 'familia', asi que el color sale de ahi y no de comparar
    ///   textos: si manana se agrega un tipo nuevo, se pinta solo.
    ///
    /// DE DONDE VIENE EL MOVIMIENTO
    ///   Un consumo casi siempre nace de una orden de trabajo. Mostrar el
    ///   correlativo y enlazar a la orden responde la pregunta que sigue a
    ///   "salio una unidad": para que salio.
    /// </summary>
    private void RenderMovimientos(Repuesto r)
    {
        InventarioMovimiento f = new InventarioMovimiento { imo_repuesto = r.rep_id };
        int tipo = Entero(ddlMovTipo.SelectedValue);
        if (tipo > 0) f.filtro_tipo = tipo;

        List<InventarioMovimiento> mov = new InventarioController().GetMovimientos(f)
                                         ?? new List<InventarioMovimiento>();

        if (mov.Count == 0)
        {
            litMovResumen.Text = "";
            litMovimientos.Text = Vacio("swap-horizontal", "Sin movimientos",
                tipo > 0 ? "No hay movimientos de ese tipo para este repuesto."
                         : "Todavia no hay entradas ni salidas registradas para este repuesto.");
            return;
        }

        // ---- orden elegido ----
        switch (ddlMovOrden.SelectedValue)
        {
            case "fecha_asc":
                mov.Sort((a, b) => a.imo_fecha_movimiento_utc.CompareTo(b.imo_fecha_movimiento_utc)); break;
            case "tipo":
                mov.Sort((a, b) => {
                    int t = string.Compare(a.tipo_nombre, b.tipo_nombre, StringComparison.Ordinal);
                    return t != 0 ? t : b.imo_fecha_movimiento_utc.CompareTo(a.imo_fecha_movimiento_utc);
                }); break;
            case "cantidad":
                mov.Sort((a, b) => b.imo_cantidad.CompareTo(a.imo_cantidad)); break;
            default:
                mov.Sort((a, b) => b.imo_fecha_movimiento_utc.CompareTo(a.imo_fecha_movimiento_utc)); break;
        }

        // ---- resumen: cuanto entro y cuanto salio ----
        decimal entro = 0, salio = 0;
        Dictionary<string, int> porTipo = new Dictionary<string, int>();
        foreach (InventarioMovimiento m in mov)
        {
            if (m.signo > 0) entro += m.imo_cantidad; else if (m.signo < 0) salio += m.imo_cantidad;
            string k = m.tipo_nombre ?? "";
            porTipo[k] = porTipo.ContainsKey(k) ? porTipo[k] + 1 : 1;
        }
        StringBuilder res = new StringBuilder("<div class=\"rc-mov-resumen\">");
        res.Append("<span class=\"rc-badge es-entra\">Entro ").Append(Num(entro)).Append(" ")
           .Append(Esc(r.unidad_simbolo)).Append("</span>");
        res.Append("<span class=\"rc-badge es-sale\">Salio ").Append(Num(salio)).Append(" ")
           .Append(Esc(r.unidad_simbolo)).Append("</span>");
        foreach (KeyValuePair<string, int> kv in porTipo)
            res.Append("<span class=\"rc-badge es-off\">").Append(Esc(kv.Key)).Append(": ")
               .Append(kv.Value.ToString(CL)).Append("</span>");
        res.Append("</div>");
        litMovResumen.Text = res.ToString();

        // ---- el correlativo de las ordenes citadas, en una sola lectura ----
        Dictionary<int, string> ordenes = new Dictionary<int, string>();
        foreach (OrdenTrabajoCombo o in (new InventarioController().GetOrdenesAbiertas()
                                         ?? new List<OrdenTrabajoCombo>()))
            ordenes[o.orden_id] = o.correlativo;

        StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Fecha</th><th>Tipo</th>"
            + "<th>Bodega</th><th>Posicion</th><th class=\"num\">Cantidad</th><th>Origen</th>"
            + "<th>Quien</th><th>Observacion</th></tr>");
        int n = 0;
        foreach (InventarioMovimiento m in mov)
        {
            if (++n > 100) break;
            s.Append("<tr><td>").Append(Fecha(m.imo_fecha_movimiento_utc))
             .Append("</td><td>").Append(BadgeMovimiento(m))
             .Append("</td><td>").Append(Esc(m.bodega_nombre))
             .Append(string.IsNullOrEmpty(m.bodega_destino_nombre) ? "" :
                     " <i class=\"mdi mdi-arrow-right\"></i> " + Esc(m.bodega_destino_nombre))
             .Append("</td><td>").Append(string.IsNullOrEmpty(m.ubicacion_codigo) ? "—" : Esc(m.ubicacion_codigo))
             .Append("</td><td class=\"num\">")
             .Append(m.signo > 0 ? "+" : (m.signo < 0 ? "−" : "")).Append(Num(m.imo_cantidad))
             .Append("</td><td>").Append(Origen(m, ordenes))
             .Append("</td><td>").Append(Esc(m.usuario_nombre))
             .Append("</td><td>").Append(Esc(m.imo_observacion)).Append("</td></tr>");
        }
        s.Append("</table>");
        if (mov.Count > 100)
            s.Append("<p style=\"margin:8px 0 0;font-size:12px;color:#68738A\">Se muestran los 100 primeros de ")
             .Append(mov.Count.ToString(CL)).Append(". Acote con el filtro de tipo.</p>");
        litMovimientos.Text = s.ToString();
    }

    /// <summary>El color sale del efecto sobre el saldo, no del nombre.</summary>
    private static string BadgeMovimiento(InventarioMovimiento m)
    {
        string cod = (m.tipo_codigo ?? "").ToUpperInvariant();
        string clase, icono;
        if (cod.Contains("REUBICACION")) { clase = "es-ubica"; icono = "map-marker-outline"; }
        else if (cod.Contains("TRASLADO")) { clase = "es-mueve"; icono = "swap-horizontal"; }
        else if (cod.Contains("AJUSTE")) { clase = "es-ajuste"; icono = "tune"; }
        else if (m.signo > 0) { clase = "es-entra"; icono = "arrow-down-bold-outline"; }
        else if (m.signo < 0) { clase = "es-sale"; icono = "arrow-up-bold-outline"; }
        else { clase = "es-off"; icono = "circle-small"; }
        return "<span class=\"rc-badge " + clase + "\"><i class=\"mdi mdi-" + icono + "\"></i> "
             + Esc(m.tipo_nombre) + "</span>";
    }

    /// <summary>De donde nace el movimiento: la orden de trabajo, si la hay.</summary>
    private string Origen(InventarioMovimiento m, Dictionary<int, string> ordenes)
    {
        if (m.imo_orden_trabajo == null || m.imo_orden_trabajo.Value <= 0) return "—";
        int id = m.imo_orden_trabajo.Value;
        string corr;
        string texto = ordenes.TryGetValue(id, out corr) && !string.IsNullOrEmpty(corr)
                       ? "OT " + corr : "OT #" + id;
        string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
        return "<a class=\"link\" target=\"_blank\" href=\""
             + ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" + q
             + "\"><i class=\"mdi mdi-clipboard-text-outline\"></i> " + Esc(texto) + "</a>";
    }

    // -------------------------------------------------------------- vida útil

    private void RenderVidaUtil(Repuesto r, List<RepuestoVidaUtil> vida)
    {
        if (vida.Count == 0)
        {
            litVidaUtilResumen.Text = Vacio("timer-sand", "Sin instalaciones registradas",
                "La vida útil real se calcula con las instalaciones y retiros que registra el técnico.");
            litVidaUtil.Text = "";
            return;
        }

        RepuestoVidaUtil x = vida[0];
        StringBuilder s = new StringBuilder("<div class=\"rc-datos\">");
        s.Append(Dato("Declarada por el fabricante", VidaDeclarada(r)));
        s.Append(Dato("Promedio real", x.promedio_dias == null ? "" : x.promedio_dias.Value.ToString(CL) + " días"));
        s.Append(Dato("Mínimo observado", x.minimo_dias == null ? "" : x.minimo_dias.Value.ToString(CL) + " días"));
        s.Append(Dato("Máximo observado", x.maximo_dias == null ? "" : x.maximo_dias.Value.ToString(CL) + " días"));
        s.Append(Dato("Instalaciones cerradas", x.instalaciones_cerradas.ToString(CL)));
        s.Append(Dato("Instalaciones totales", x.instalaciones_total.ToString(CL)));
        s.Append("</div>");
        // Comparar lo declarado con lo real es justamente el valor del centro.
        if (r.rep_vida_util_dia != null && x.promedio_dias != null && x.instalaciones_cerradas > 0)
        {
            int dec = r.rep_vida_util_dia.Value, real = x.promedio_dias.Value;
            if (real < dec * 0.8)
                s.Append("<p style=\"margin:12px 0 0\"><span class=\"rc-badge es-bajo\">Dura menos de lo declarado</span> ")
                 .Append("El fabricante declara ").Append(dec.ToString(CL)).Append(" días y en planta promedia ")
                 .Append(real.ToString(CL)).Append(". Conviene revisar la condición de uso o el proveedor.</p>");
            else if (real > dec * 1.2)
                s.Append("<p style=\"margin:12px 0 0\"><span class=\"rc-badge es-ok\">Dura más de lo declarado</span> ")
                 .Append("Promedia ").Append(real.ToString(CL)).Append(" días contra ").Append(dec.ToString(CL))
                 .Append(" declarados: se puede espaciar su reemplazo preventivo.</p>");
        }
        litVidaUtilResumen.Text = s.ToString();

        StringBuilder t = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Equipo / componente</th>"
            + "<th class=\"num\">Cantidad</th><th>Instalación</th><th>Retiro</th><th class=\"num\">Duración</th><th></th></tr>");
        foreach (RepuestoVidaUtil v in vida)
            t.Append("<tr><td>").Append(Esc(v.componente_nombre ?? v.activo_nombre))
             .Append("</td><td class=\"num\">").Append(Num(v.cri_cantidad))
             .Append("</td><td>").Append(Fecha(v.fecha_instalacion))
             .Append("</td><td>").Append(v.fecha_retiro == null ? "<span class=\"rc-badge es-ok\">Instalado</span>" : Fecha(v.fecha_retiro))
             .Append("</td><td class=\"num\">").Append(v.vida_util_dias > 0 ? v.vida_util_dias.ToString(CL) + " d" : "—")
             .Append("</td><td>").Append(v.cri_fallo ? "<span class=\"rc-badge es-bajo\">Falló</span>" : "")
             .Append("</td></tr>");
        t.Append("</table>");
        litVidaUtil.Text = t.ToString();
    }

    // -------------------------------------------------------------- evidencia

    /// <summary>
    /// Evidencia del repuesto. Los archivos del repuesto se enlazan por
    /// Archivo_Vinculo.avi_repuesto y los entrega RepuestoFotoController; aca
    /// se separan por su mime: lo que es imagen va a la galeria y el resto
    /// -ficha tecnica, certificado del proveedor- a la lista de documentos.
    /// No hay dos origenes de datos, hay uno mirado de dos formas.
    /// </summary>
    private void RenderEvidencia(Repuesto r)
    {
        List<RepuestoFoto> todos = new RepuestoFotoController().GetFotos(r.rep_id) ?? new List<RepuestoFoto>();
        List<RepuestoFoto> imagenes = new List<RepuestoFoto>();
        List<RepuestoFoto> documentos = new List<RepuestoFoto>();
        foreach (RepuestoFoto f in todos)
        {
            if (!string.IsNullOrEmpty(f.mime) && f.mime.StartsWith("image/")) imagenes.Add(f);
            else documentos.Add(f);
        }

        if (imagenes.Count == 0)
            litFotos.Text = Vacio("image-multiple-outline", "Sin fotografias",
                "Una foto del repuesto evita que en bodega entreguen el que no era.");
        else
        {
            StringBuilder s = new StringBuilder("<div class=\"rc-fotos\">");
            foreach (RepuestoFoto f in imagenes)
                s.Append("<div class=\"rc-foto\"><img src=\"").Append(UrlArchivo(f.archivo))
                 .Append("\" alt=\"").Append(Esc(r.rep_nombre)).Append("\" />")
                 .Append("<div class=\"pie\">")
                 .Append(f.orden == 1 ? "Portada" : Esc(f.titulo))
                 .Append("</div></div>");
            s.Append("</div>");
            litFotos.Text = s.ToString();
        }

        if (documentos.Count == 0)
        {
            litDocumentos.Text = Vacio("file-document-outline", "Sin documentos",
                "La ficha tecnica y el certificado del proveedor se adjuntan acá.");
            return;
        }
        StringBuilder d = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Documento</th><th>Tipo</th>"
            + "<th>Subido</th><th>Por</th><th></th></tr>");
        foreach (RepuestoFoto a in documentos)
            d.Append("<tr><td>").Append(Esc(string.IsNullOrEmpty(a.titulo) ? a.nombre : a.titulo))
             .Append("</td><td>").Append(Esc(a.mime))
             .Append("</td><td>").Append(Fecha(a.fecha))
             .Append("</td><td>").Append(Esc(a.usuario))
             .Append("</td><td style=\"text-align:right\"><a class=\"link\" target=\"_blank\" href=\"")
             .Append(UrlArchivo(a.archivo)).Append("\"><i class=\"mdi mdi-download\"></i></a></td></tr>");
        d.Append("</table>");
        litDocumentos.Text = d.ToString();
    }

    /// <summary>
    /// Adjunta una foto o un documento al repuesto, desde el propio centro.
    /// Se apoya en RepuestoFotoController, que enlaza por Archivo_Vinculo: no
    /// hay un segundo origen de archivos, es el mismo que ya usa la ficha.
    /// </summary>
    protected void lnkSubir_Click(object sender, EventArgs e)
    {
        litSubirAviso.Text = "";
        try
        {
            if (!SitioBase.Token.Puede("CREAR EDITAR REPUESTOS"))
                throw new Exception("No tiene permiso para adjuntar archivos al repuesto.");
            if (RepuestoId <= 0) throw new Exception("Abra un repuesto para adjuntar.");
            if (!fupArchivo.HasFile) throw new Exception("Elija un archivo.");

            byte[] contenido = fupArchivo.FileBytes;
            Respuesta r = new RepuestoFotoController().Adjuntar(
                RepuestoId, contenido, fupArchivo.FileName,
                fupArchivo.PostedFile.ContentType, txtTituloArchivo.Text.Trim());

            if (r != null && r.codigo < 0) throw new Exception(r.detalle);

            txtTituloArchivo.Text = "";
            hdnSeccion.Value = "evidencia";
            litSubirAviso.Text = "<p class=\"rc-resultado\" style=\"color:#16855B\">"
                               + "<i class=\"mdi mdi-check-circle-outline\"></i> Archivo adjuntado.</p>";
        }
        catch (Exception ex)
        {
            litSubirAviso.Text = "<p class=\"rc-resultado\" style=\"color:#C7352B\">"
                               + "<i class=\"mdi mdi-alert-circle-outline\"></i> " + Esc(ex.Message) + "</p>";
        }
    }

    // ==================================================================== apoyo

    /// <summary>URL de un asset con cache-busting por fecha del archivo.</summary>
    protected string Asset(string ruta)
    {
        string url = ResolveUrl(ruta);
        try
        {
            string fisica = Server.MapPath(ruta);
            if (System.IO.File.Exists(fisica))
                return url + "?v=" + System.IO.File.GetLastWriteTimeUtc(fisica).Ticks;
        }
        catch (Exception) { }
        return url;
    }

    /// <summary>Descarga de un archivo por su id, por el manejador del sitio.</summary>
    private string UrlArchivo(int archivo)
    {
        return ResolveUrl("~/Archivo.aspx?query=")
             + Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + archivo));
    }

    /// <summary>
    /// Tarjeta de indicador. Usa las clases reales de sigma-activo360
    /// (etq/val/pie): sin ellas el numero y la etiqueta se pegan, que era el
    /// "8Repuestos" del primer intento.
    /// </summary>
    private static string Kpi(string icono, string tono, string etiqueta, string valor, string pie)
    {
        return "<div class=\"sg-a3-kpi\"><span class=\"sg-a3-kpi-ico es-" + tono + "\">"
             + "<i class=\"mdi mdi-" + icono + "\"></i></span><div class=\"sg-a3-kpi-txt\">"
             + "<span class=\"sg-a3-kpi-etq\">" + Esc(etiqueta) + "</span>"
             + "<span class=\"sg-a3-kpi-val\">" + valor + "</span>"
             + (string.IsNullOrEmpty(pie) ? "" : "<span class=\"sg-a3-kpi-pie\">" + Esc(pie) + "</span>")
             + "</div></div>";
    }

    private static string Dato(string k, string v)
    {
        return "<div class=\"rc-dato\"><div class=\"k\">" + Esc(k) + "</div><div class=\"v\">"
             + (string.IsNullOrWhiteSpace(v) ? "—" : Esc(v)) + "</div></div>";
    }

    private static string Vacio(string icono, string titulo, string detalle)
    {
        return "<div class=\"rc-vacio\"><i class=\"mdi mdi-" + icono + "\"></i><p>" + Esc(titulo)
             + "</p><span>" + Esc(detalle) + "</span></div>";
    }

    private static string Num(decimal v)
    {
        return v == Math.Floor(v) ? ((long)v).ToString("N0", CL) : v.ToString("N2", CL);
    }

    private static string Fecha(DateTime? f)
    {
        return f == null ? "—" : f.Value.ToString("dd-MM-yyyy", CL);
    }

    private static string Esc(string s)
    {
        return string.IsNullOrEmpty(s) ? "" : System.Web.HttpUtility.HtmlEncode(s);
    }
}
