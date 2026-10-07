using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
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

    /// <summary>
    /// Repuesto cuya ficha está en modo edición. Se guarda el id y no un
    /// booleano: al abrir otro repuesto la edición se cae sola.
    /// </summary>
    private bool EditandoFicha
    {
        get { object v = ViewState["EditandoRep"]; return v != null && (int)v == RepuestoId && RepuestoId > 0; }
        set { ViewState["EditandoRep"] = value ? (object)RepuestoId : null; }
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

        // Un postback asíncrono no lleva el archivo: Adjuntar debe enviar la página completa.
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkSubir);
        // El Excel sale en la respuesta: exportar no puede ser un postback asincrono.
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);
        /* La ficha (y su FileUpload) llega por un postback asíncrono, así que el
           <form> se pintó sin multipart y el navegador no enviaba el archivo. */
        Page.Form.Enctype = "multipart/form-data";
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

    /// <summary>El combo de planta del encabezado (aqui se llama como el filtro de siempre).</summary>
    private System.Web.UI.WebControls.DropDownList ddlPlanta { get { return selPlantaHero; } }

    /// <summary>
    /// Las plantas asignadas a la persona en este cliente, vigentes. Null = no tiene
    /// asignacion (por ejemplo, el administrador de SIGMA): ve todas. Igual que el Centro de activos.
    /// </summary>
    private HashSet<int> PlantasPermitidas()
    {
        if (_mias != null || _miasLeidas) return _mias;
        _miasLeidas = true;
        int u; if (!int.TryParse(SitioBase.Session.UsuarioId(), out u)) return null;
        List<ClienteUsuarioPlanta> l;
        try { l = new ClienteUsuarioController().PlantasDelUsuario(u, SitioBase.Session.ClienteId()) ?? new List<ClienteUsuarioPlanta>(); }
        catch (Exception) { return null; }
        if (l.Count == 0) return null;
        DateTime hoy = global::SitioBase.Hora.Hoy;
        _mias = new HashSet<int>(l.FindAll(pl => pl.habilitada && (pl.fecha_inicio == null || pl.fecha_inicio.Value.Date <= hoy) && (pl.fecha_fin == null || pl.fecha_fin.Value.Date >= hoy))
                                  .ConvertAll(pl => pl.instalacion));
        return _mias;
    }
    private HashSet<int> _mias; private bool _miasLeidas;

    /// <summary>Plantas de la persona, deducidas de las bodegas. El combo solo se ve si hay mas de una.</summary>
    private void CargarPlantas()
    {
        ddlPlanta.Items.Clear();
        ddlPlanta.Items.Add(new System.Web.UI.WebControls.ListItem("Todas las plantas", ""));
        HashSet<int> vistas = new HashSet<int>();
        foreach (Bodega b in Bodegas())
            if (b.bod_cliente_instalacion > 0 && !string.IsNullOrEmpty(b.planta_nombre) && vistas.Add(b.bod_cliente_instalacion))
                ddlPlanta.Items.Add(new System.Web.UI.WebControls.ListItem(b.planta_nombre, b.bod_cliente_instalacion.ToString()));
        pnlPlantaHero.Style["display"] = vistas.Count >= 1 ? "" : "none";
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
            _bodegas = (new BodegaController().GetBodegas(new Bodega { bod_habilitado = true }) ?? new List<Bodega>())
                       .FindAll(b => PlantasPermitidas() == null || PlantasPermitidas().Contains(b.bod_cliente_instalacion));
        return _bodegas;
    }

    private static int Entero(string v) { int n; return int.TryParse(v, out n) ? n : 0; }


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
            "',title:'Carga masiva de repuestos',width:1080,initialHeight:640,onClose:refresh});";
        // La clasificacion masiva necesita seleccion multiple: eso vive en el
        // listado clasico, que sigue existiendo. El centro no la pierde.
        lnkClasificar.OnClientClick =
            "return SigmaModal.open({url:'" + ResolveUrl("~/View/Inventario/Repuestos/ClasificarRepuestos.aspx") +
            "',title:'Clasificar repuestos',width:760,initialHeight:620,onClose:refresh});";
        // Etiquetas de todo lo que hay en el catalogo: el centro de etiquetas, ya en REPUESTO.
        hlEtiquetas.Visible = SitioBase.Token.Puede("IMPRIMIR ETIQUETAS");
        hlEtiquetas.NavigateUrl = ResolveUrl("~/View/Comun/Impresion/CentroEtiquetas.aspx") + "?query=" +
            Server.UrlEncode(Tools.Crypto.Encrypt("Origen=" + EtiquetaOrigen.Repuesto));
        // SIGMA Twin: el mapa 3D de las bodegas, como una pestaña mas que lleva a su menu.
        hlTwin.Visible = SitioBase.Token.Puede("VER BODEGAS");
        hlTwin.NavigateUrl = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx");

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
        Dictionary<int, List<object>> saldosPorRep = new Dictionary<int, List<object>>();
        foreach (InventarioSaldo x in (new InventarioController().GetSaldos(new InventarioSaldo())
                                       ?? new List<InventarioSaldo>()))
        {
            if (x.bajo_minimo) alerta[x.isa_repuesto] = "bajo";
            else if (x.sobre_maximo && !alerta.ContainsKey(x.isa_repuesto)) alerta[x.isa_repuesto] = "sobre";
            /* Cada saldo con su umbral y su estante: la tarjeta muestra los
               umbrales y el «Mapa por ubicación» pone el repuesto en su rack. */
            if (!saldosPorRep.ContainsKey(x.isa_repuesto)) saldosPorRep[x.isa_repuesto] = new List<object>();
            saldosPorRep[x.isa_repuesto].Add(new
            {
                bodega = x.isa_bodega,
                cant = x.isa_cantidad,
                cantTxt = Num(x.isa_cantidad),
                min = x.rbs_stock_minimo,
                max = x.rbs_stock_maximo,
                rep = x.rbs_punto_reposicion,
                bajo = x.bajo_minimo,
                sobre = x.sobre_maximo,
                ubic = x.ubicacion_codigo ?? "",
                ubicTxt = x.ubicacion_texto ?? ""
            });
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

        // ---- KPIs (los del Centro de activos: icono, numero y una nota) ----
        int conStock = 0, sinStock = 0, conLote = 0, enAlerta = 0;
        foreach (Repuesto r in lista)
        {
            if (r.existencia_total > 0) conStock++; else sinStock++;
            if (r.rep_controla_lote) conLote++;
            if (alerta.ContainsKey(r.rep_id)) enAlerta++;
        }
        StringBuilder k = new StringBuilder();
        k.Append(KpiV3("<path d=\"M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8\"/>", "#F2EFFF", "#6732F4",
                       "Repuestos", lista.Count.ToString(CL), Contexto()));
        k.Append(KpiV3("<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M8 12.5l2.7 2.7L16 9.5\"/>", "#E7F5EE", "#12704C",
                       "Con existencia", conStock.ToString(CL), "Hay en al menos una bodega"));
        k.Append(KpiV3("<circle cx=\"12\" cy=\"12\" r=\"9\"/><path d=\"M12 7v6M12 16.5v.5\"/>", sinStock > 0 ? "#FFF3E3" : "#F4F6FA", sinStock > 0 ? "#9A4D00" : "#5F6A80",
                       "Sin existencia", sinStock.ToString(CL), "No hay en ninguna bodega"));
        k.Append(KpiV3("<path d=\"M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0\"/>", enAlerta > 0 ? "#FDECEA" : "#EAF4FF", enAlerta > 0 ? "#C7352B" : "#0662BC",
                       "Fuera de umbral", enAlerta.ToString(CL), enAlerta > 0 ? "Bajo el mínimo o sobre el máximo" : "Todo dentro de su mínimo y máximo"));
        litKpis.Text = k.ToString();

        // ---- pestañas y filtros activos ----
        litNumRep.Text = lista.Count.ToString(CL);
        litNumTipos.Text = Math.Max(0, ddlTipo.Items.Count - 1).ToString(CL);
        litNumBodegas.Text = Math.Max(0, ddlBodega.Items.Count - 1).ToString(CL);
        int filtros = (Entero(ddlPlanta.SelectedValue) > 0 ? 1 : 0) + (Entero(ddlBodega.SelectedValue) > 0 ? 1 : 0)
                    + (Entero(ddlTipo.SelectedValue) > 0 ? 1 : 0) + (string.IsNullOrEmpty(ddlEstado.SelectedValue) ? 0 : 1)
                    + (chkLote.Checked ? 1 : 0) + (chkInhabilitados.Checked ? 1 : 0);
        litNumFiltros.Text = filtros > 0 ? "<b class=\"rcx-nfil\">" + filtros + "</b>" : "";

        // ---- los datos de las dos vistas: Js de la pagina dibuja Lista y Tarjetas ----
        List<object> datos = new List<object>();
        foreach (Repuesto r in lista)
        {
            List<RepuestoFoto> suyas;
            List<string> urls = new List<string>();
            if (fotosPorRep.TryGetValue(r.rep_id, out suyas))
                foreach (RepuestoFoto f in suyas)
                    if (string.IsNullOrEmpty(f.mime) || f.mime.StartsWith("image/"))
                        urls.Add(SitioBase.UrlArchivo.Ver(f.archivo));
            int archivo;
            string portada = portadas.TryGetValue(r.rep_id, out archivo) && archivo > 0 ? SitioBase.UrlArchivo.Ver(archivo) : "";

            List<string> compat = new List<string>();
            List<RepuestoCompatibilidad> cs;
            if (compatPorRep.TryGetValue(r.rep_id, out cs))
                foreach (RepuestoCompatibilidad x in cs) compat.Add(x.alcance_nombre);

            string umb;
            alerta.TryGetValue(r.rep_id, out umb);
            datos.Add(new
            {
                id = r.rep_id,
                q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + r.rep_id)),
                codigo = r.rep_codigo ?? "",
                nombre = r.rep_nombre ?? "",
                tipo = r.repuesto_tipo_nombre ?? "",
                fabricante = r.rep_fabricante ?? "",
                modelo = r.rep_modelo ?? "",
                stock = r.existencia_total,
                stockTxt = Num(r.existencia_total),
                unidad = r.unidad_simbolo ?? "",
                bodegas = r.bodegas_con_saldo,
                lote = r.rep_controla_lote,
                habilitado = r.rep_habilitado,
                umbral = umb ?? "",
                compat = compat,
                foto = portada,
                fotos = urls,
                saldos = saldosPorRep.ContainsKey(r.rep_id) ? saldosPorRep[r.rep_id] : new List<object>()
            });
        }
        /* Las pestañas Tipos y Bodegas se ven dentro del centro, como los
           catalogos del Centro de activos: crear y editar abren su modal. */
        Dictionary<int, int> porTipo = new Dictionary<int, int>();
        foreach (Repuesto r in (new RepuestoController().GetRepuestos(new Repuesto { filtro_habilitado = true }) ?? new List<Repuesto>()))
        {
            int c; porTipo.TryGetValue(r.rep_repuesto_tipo, out c); porTipo[r.rep_repuesto_tipo] = c + 1;
        }
        List<object> tipos = new List<object>();
        foreach (RepuestoTipo t in (new RepuestoTipoController().GetRepuestoTipos(new RepuestoTipo { filtro_habilitado = true }) ?? new List<RepuestoTipo>()))
        {
            int c; porTipo.TryGetValue(t.rti_id, out c);
            tipos.Add(new { id = t.rti_id, q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + t.rti_id)), codigo = t.rti_codigo ?? "", nombre = t.rti_nombre ?? "", descripcion = t.rti_descripcion ?? "", repuestos = c });
        }
        List<object> bodegas = new List<object>();
        foreach (Bodega b in Bodegas())
            bodegas.Add(new { plantaId = b.bod_cliente_instalacion, id = b.bod_id, q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + b.bod_id)), codigo = b.bod_codigo ?? "", nombre = b.bod_nombre ?? "", planta = b.planta_nombre ?? "", descripcion = b.bod_descripcion ?? "", ubicaciones = b.ubicaciones, repuestos = b.repuestos_con_saldo });

        List<object> plantasJson = new List<object>();
        HashSet<int> plantasVistas = new HashSet<int>();
        int plantasUnica = 0;
        foreach (Bodega b in Bodegas())
            if (b.bod_cliente_instalacion > 0 && plantasVistas.Add(b.bod_cliente_instalacion))
            {
                plantasJson.Add(new { id = b.bod_cliente_instalacion, nombre = b.planta_nombre ?? "" });
                plantasUnica = b.bod_cliente_instalacion;
            }
        int plantasVistasN = plantasVistas.Count;

        litLista.Text = "<script type=\"application/json\" id=\"rcDatos\">"
            + new System.Web.Script.Serialization.JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Serialize(new
            {
                puedeEditar = puedeCrear,
                urlTwin = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx"),
                planta = Entero(ddlPlanta.SelectedValue) > 0 ? Entero(ddlPlanta.SelectedValue) : (plantasVistasN == 1 ? plantasUnica : 0),
                puedeBodegas = SitioBase.Token.Puede("CREAR EDITAR BODEGAS"),
                plantas = plantasJson,
                items = datos,
                tipos = tipos,
                bodegas = bodegas
            }).Replace("</", "<\\/")
            + "</script>";
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
        /* La portada en la cabecera, como en la ficha del activo. */
        Dictionary<int, int> portadasHero = new RepuestoFotoController().GetPortadas() ?? new Dictionary<int, int>();
        int fotoHero;
        litHeroFoto.Text = portadasHero.TryGetValue(r.rep_id, out fotoHero) && fotoHero > 0
            ? "<span class=\"sg-a3-foto\"><img src=\"" + Esc(SitioBase.UrlArchivo.Ver(fotoHero)) + "\" alt=\"" + Esc(r.rep_nombre) + "\" /></span>"
            : "<span class=\"sg-a3-foto es-vacia\" data-sec=\"evidencia\" title=\"Agregar fotos en Evidencia\"><i class=\"mdi mdi-camera-plus-outline\"></i>Sin foto</span>";
        litHeroSub.Text = Esc(r.rep_codigo)
            + (string.IsNullOrEmpty(r.repuesto_tipo_nombre) ? "" : " · " + Esc(r.repuesto_tipo_nombre))
            + (string.IsNullOrEmpty(r.rep_fabricante) ? "" : " · " + Esc(r.rep_fabricante))
            + (r.rep_habilitado ? "" : " · <span class=\"rc-badge es-off\">Deshabilitado</span>");

        hlEtiqueta.Visible = SitioBase.Token.Puede("IMPRIMIR ETIQUETAS");
        if (hlEtiqueta.Visible)
            hlEtiqueta.Attributes["onclick"] = "return abrirEtiquetas('" +
                Server.UrlEncode(Tools.Crypto.Encrypt("Origen=" + EtiquetaOrigen.Repuesto + "&Ids=" + r.rep_id)) + "');";

        /* Editar no abre un modal: vuelve editable la pestaña Ficha. */
        bool editando = puedeCrear && EditandoFicha;
        lnkEditar.Visible = puedeCrear && !editando;
        pnlFichaVer.Visible = !editando;
        pnlFichaEditar.Visible = editando;
        litFichaTitulo.Text = editando ? "Editar ficha del repuesto" : "Ficha del repuesto";
        if (editando)
            litFabCatalogo.Text = "<script type=\"application/json\" id=\"sgFabCatalogo\">" +
                new System.Web.Script.Serialization.JavaScriptSerializer()
                    .Serialize(new FabricanteController().Catalogo()).Replace("</", "<\\/") + "</script>";
        lnkNuevaCompat.Visible = puedeCrear;
        lnkNuevaCompat.OnClientClick = "return abrirCompatibilidad('" + queryNuevoDe + "');";
        lnkNuevoMov.Visible = SitioBase.Token.Puede("REGISTRAR MOVIMIENTOS DE INVENTARIO");
        pnlSubir.Visible = puedeCrear;
        lnkNuevoMov.OnClientClick = "return abrirMovimiento('" + queryNuevoDe + "');";

        // el mapa 3D vuela a sus cajas (BodegaMapa3D lee ?ir= con el token de la etiqueta)
        hlMapa.Visible = SitioBase.Token.Puede("VER BODEGAS");
        hlMapa.NavigateUrl = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx") + "?ir=REP-" + r.rep_id;

        // lo que sabe la bodega de este repuesto (bloques 326 a 330)
        RepuestoAlmacenamientoController alm = new RepuestoAlmacenamientoController();
        DataTable almacen = alm.Almacenamiento(r.rep_id);
        DataTable consumo = alm.Consumo(r.rep_id, 90);
        DataRow fichaBod = alm.Ficha(r.rep_id);

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

        /* Consumo de 90 dias y cuando se agota a ese ritmo: lo mismo que el
           mapa 3D muestra como "quiebre proyectado". */
        decimal salidas = 0;
        foreach (DataRow c in consumo.Rows) salidas += Convert.ToDecimal(c["SALIDAS"]);
        decimal diario = salidas / 90m;
        decimal? diasQuiebre = diario > 0 ? r.existencia_total / diario : (decimal?)null;
        k.Append(Kpi("chart-timeline-variant", diasQuiebre.HasValue && diasQuiebre < 30 ? "alerta" : "teal", "Consumo 90 días",
                     Num(salidas) + " " + Esc(r.unidad_simbolo),
                     diasQuiebre.HasValue ? "Se agota en ~" + Math.Round(diasQuiebre.Value).ToString(CL) + " días" : "Sin salidas en el período"));
        litKpisFicha.Text = k.ToString();

        RenderResumen(r, saldos, fichaBod, almacen);
        RenderCompatibilidades(compat, puedeCrear);
        RenderExistencias(r, saldos, almacen);
        RenderPosiciones(r, saldos, almacen);
        RenderReposicion(r, saldos);
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

    private void RenderResumen(Repuesto r, List<InventarioSaldo> saldos, DataRow fichaBod, DataTable almacen)
    {
        int portada = new RepuestoFotoController().GetPortadas().ContainsKey(r.rep_id)
                      ? new RepuestoFotoController().GetPortadas()[r.rep_id] : 0;
        litFotoResumen.Text = portada > 0
            ? "<span class=\"rc-foto-grande\"><img src=\"" + Esc(SitioBase.UrlArchivo.Ver(portada))
              + "\" alt=\"" + Esc(r.rep_nombre) + "\" /></span>"
            : "<span class=\"rc-foto-grande\"><i class=\"mdi mdi-image-off-outline\"></i></span>";

        string unidad = r.unidad_nombre + (string.IsNullOrEmpty(r.unidad_simbolo) ? "" : " (" + r.unidad_simbolo + ")");
        string peso = fichaBod != null && fichaBod["PESO"] != DBNull.Value ? Num(Convert.ToDecimal(fichaBod["PESO"])) + " kg" : "";

        StringBuilder s = new StringBuilder();
        s.Append(string.IsNullOrWhiteSpace(r.rep_descripcion)
            ? "<p class=\"rc-ficha-desc es-vacia\">Sin descripción.</p>"
            : "<p class=\"rc-ficha-desc\">" + Esc(r.rep_descripcion) + "</p>");
        s.Append("<div class=\"rc-grupos\">");
        s.Append(Grupo("tag-outline", "Identificación",
            Fila("Código", r.rep_codigo) + Fila("Tipo", r.repuesto_tipo_nombre) +
            Fila("Unidad", unidad) + Fila("Estado", r.rep_habilitado ? "Habilitado" : "Deshabilitado")));
        s.Append(Grupo("factory", "Fabricante y costo",
            Fila("Fabricante", r.rep_fabricante) + Fila("Modelo", r.rep_modelo) +
            Fila("Costo de referencia", r.rep_costo_referencia == null ? "" :
                Num(r.rep_costo_referencia.Value) + " " + (r.moneda_codigo ?? ""))));
        s.Append(Grupo("cog-outline", "Cómo se opera",
            "<div class=\"rc-chips-op\">" + ChipOp("Controla lote", r.rep_controla_lote) +
            ChipOp("Consumible", r.rep_es_consumible) + ChipOp("Reparable", r.rep_es_reparable) + "</div>"));
        s.Append(Grupo("timer-sand", "Vida útil declarada",
            Fila("Horas", r.rep_vida_util_hora == null ? "" : Num(r.rep_vida_util_hora.Value)) +
            Fila("Días", r.rep_vida_util_dia == null ? "" : r.rep_vida_util_dia.Value.ToString(CL)) +
            Fila("Ciclos", r.rep_vida_util_ciclo == null ? "" : Num(r.rep_vida_util_ciclo.Value))));
        s.Append(Grupo("warehouse", "Almacenamiento",
            Fila("Método de salida", MetodoTexto(fichaBod, almacen)) +
            Fila("Medidas", MedidasTexto(fichaBod)) + Fila("Peso", peso)));
        s.Append("</div>");
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

    private void RenderExistencias(Repuesto r, List<InventarioSaldo> saldos, DataTable almacen)
    {
        bool puedeMover = SitioBase.Token.Puede("REGISTRAR MOVIMIENTOS DE INVENTARIO");
        if (saldos.Count == 0)
            litExistencias.Text = Vacio("warehouse", "Sin existencia", "No hay saldo en ninguna bodega.");
        else
        {
            Dictionary<int, string> metodoBod = new Dictionary<int, string>();
            foreach (DataRow a in almacen.Rows) metodoBod[Convert.ToInt32(a["BOD_ID"])] = Convert.ToString(a["METODO"]);
            StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Bodega</th><th>Planta</th><th>Salida</th>"
                + "<th class=\"num\">Cantidad</th><th class=\"num\">Reservado</th><th class=\"num\">Disponible</th>"
                + "<th>Último movimiento</th><th></th></tr>");
            foreach (InventarioSaldo x in saldos)
            {
                // Existencia.aspx abre el detalle DEL REPUESTO (sus bodegas, cubos y
                // movimientos), asi que recibe el id del repuesto, no el del saldo.
                string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + r.rep_id));
                string met;
                metodoBod.TryGetValue(x.isa_bodega, out met);
                s.Append("<tr><td>").Append(Esc(x.bodega_nombre)).Append("</td><td>").Append(Esc(x.planta_nombre))
                 .Append("</td><td>").Append(string.IsNullOrEmpty(met) ? "—" : "<span class=\"rc-badge es-info\">" + Esc(met) + "</span>")
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
    private void RenderPosiciones(Repuesto r, List<InventarioSaldo> saldos, DataTable almacen)
    {
        if (almacen.Rows.Count == 0)
        {
            litPosiciones.Text = Vacio("map-marker-off-outline", "Sin existencia en ninguna bodega",
                "La posicion aparece cuando el repuesto tiene saldo en una bodega.");
            return;
        }

        /* Una fila por caja (bodega + rack): la posicion del planograma si el
           rack la tiene fijada, cuando entro y vence lo que hay, y cuando se
           conto por ultima vez. El icono del cubo abre el mapa en ese rack. */
        string mapa = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx");
        bool verMapa = SitioBase.Token.Puede("VER BODEGAS");
        StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Bodega</th><th>Rack</th><th>Posición</th>"
            + "<th class=\"num\">Cantidad</th><th>Ingreso</th><th>Vence</th><th>Último conteo</th><th></th></tr>");
        foreach (DataRow a in almacen.Rows)
        {
            bool conRack = a["BUB_ID"] != DBNull.Value;
            string pos = a["NIVEL"] != DBNull.Value
                ? "<span class=\"rc-badge es-ok\">" + Convert.ToInt32(a["NIVEL"]) + "-" + Convert.ToInt32(a["POSICION"]).ToString("00")
                  + (Convert.ToInt32(a["FILA"]) == 1 ? " · atrás" : "") + "</span>"
                : "<span class=\"rc-badge es-off\">Sin fijar</span>";
            string conteo = "—";
            if (a["CONTEO_FECHA"] != DBNull.Value)
            {
                decimal dif = Convert.ToDecimal(a["CONTEO_DIFERENCIA"]);
                conteo = Fecha(Convert.ToDateTime(a["CONTEO_FECHA"])) + " · "
                       + (dif == 0 ? "<span class=\"rc-badge es-ok\">coincidió</span>"
                                   : "<span class=\"rc-badge es-bajo\">" + (dif > 0 ? "+" : "") + Num(dif) + "</span>");
            }
            s.Append("<tr><td>").Append(Esc(Convert.ToString(a["BOD_NOMBRE"])))
             .Append("</td><td>").Append(conRack ? "<b>" + Esc(Convert.ToString(a["BUB_CODIGO"])) + "</b>" : "<span class=\"rc-badge es-off\">Recepción</span>")
             .Append("</td><td>").Append(conRack ? pos : "—")
             .Append("</td><td class=\"num\">").Append(Num(Convert.ToDecimal(a["CANTIDAD"])))
             .Append("</td><td>").Append(a["INGRESO"] == DBNull.Value ? "—" : Fecha(Convert.ToDateTime(a["INGRESO"])))
             .Append("</td><td>").Append(a["VENCE"] == DBNull.Value ? "—" : Fecha(Convert.ToDateTime(a["VENCE"])))
             .Append("</td><td>").Append(conteo)
             .Append("</td><td style=\"text-align:right;white-space:nowrap\">");
            if (verMapa && conRack)
                s.Append("<a class=\"link\" target=\"_blank\" title=\"Ver este rack en el mapa 3D\" href=\"").Append(mapa).Append("?ir=UBI-")
                 .Append(Convert.ToInt32(a["BUB_ID"])).Append("\"><i class=\"mdi mdi-cube-scan\"></i></a> ");
            string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + Convert.ToInt32(a["BOD_ID"])));
            s.Append("<a href=\"#\" class=\"link\" onclick=\"return abrirBodega('").Append(q)
             .Append("')\" title=\"Ubicaciones de la bodega\"><i class=\"mdi mdi-cog-outline\"></i></a></td></tr>");
        }
        s.Append("</table>");
        s.Append("<p style=\"margin:10px 0 0;font-size:12px;color:#68738A\">")
         .Append("La posición nivel-posición es el planograma del rack: se fija en el mapa 3D (rack › Fijar posiciones). ")
         .Append("El stock sigue siendo del rack; la posición dice dónde va dentro de él.</p>");
        litPosiciones.Text = s.ToString();
    }

    /// <summary>El metodo propio del repuesto, o el que trae cada bodega donde esta.</summary>
    private static string MetodoTexto(DataRow ficha, DataTable almacen)
    {
        if (ficha != null && ficha["METODO"] != DBNull.Value && !string.IsNullOrEmpty(Convert.ToString(ficha["METODO"])))
            return Convert.ToString(ficha["METODO"]) + " (propio del repuesto)";
        List<string> m = new List<string>();
        foreach (DataRow a in almacen.Rows) { string x = Convert.ToString(a["METODO"]); if (!m.Contains(x)) m.Add(x); }
        return m.Count == 0 ? "Según la bodega" : "Según la bodega: " + string.Join(" / ", m.ToArray());
    }

    private static string MedidasTexto(DataRow f)
    {
        if (f == null || f["LARGO"] == DBNull.Value) return "";
        return Num(Convert.ToDecimal(f["LARGO"])) + " × " + Num(Convert.ToDecimal(f["ANCHO"] == DBNull.Value ? 0 : f["ANCHO"]))
             + " × " + Num(Convert.ToDecimal(f["ALTO"] == DBNull.Value ? 0 : f["ALTO"])) + " cm";
    }

    // ------------------------------------------------------- reposicion y conteos

    private void RenderReposicion(Repuesto r, List<InventarioSaldo> saldos)
    {
        RepuestoAlmacenamientoController alm = new RepuestoAlmacenamientoController();

        pnlRepoNueva.Visible = SitioBase.Token.Puede("GESTIONAR STOCK");
        if (pnlRepoNueva.Visible && cboRepoBodega.Items.Count == 0)
        {
            foreach (Bodega b in new BodegaController().GetBodegas(new Bodega { filtro_habilitado = true }) ?? new List<Bodega>())
                cboRepoBodega.Items.Add(new RadComboBoxItem(b.bod_nombre, b.bod_id.ToString()));
            // por defecto, la bodega donde esta bajo minimo (o la primera con saldo)
            InventarioSaldo critico = saldos.FirstOrDefault(x => x.bajo_minimo) ?? saldos.FirstOrDefault();
            if (critico != null) { RadComboBoxItem it = cboRepoBodega.FindItemByValue(critico.isa_bodega.ToString()); if (it != null) it.Selected = true; }
        }

        DataTable sol = alm.Reposiciones(r.rep_id);
        if (sol.Rows.Count == 0)
            litReposiciones.Text = Vacio("cart-outline", "Sin solicitudes", "Todavía no se ha pedido reposición de este repuesto.");
        else
        {
            StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>N°</th><th>Fecha</th><th>Bodega</th>"
                + "<th class=\"num\">Solicitado</th><th class=\"num\">Stock al pedir</th><th>Estado</th><th>Quién</th></tr>");
            foreach (DataRow x in sol.Rows)
            {
                string est = Convert.ToString(x["ESTADO"]);
                string clase = est == "RECIBIDA" ? "es-ok" : est == "ANULADA" ? "es-off" : est == "ENVIADA" ? "es-info" : "es-alto";
                s.Append("<tr><td><b>").Append(Convert.ToInt32(x["NUMERO"])).Append("</b></td><td>").Append(Fecha(Convert.ToDateTime(x["FECHA"])))
                 .Append("</td><td>").Append(Esc(Convert.ToString(x["BODEGA"])))
                 .Append("</td><td class=\"num\">").Append(Num(Convert.ToDecimal(x["CANTIDAD"])))
                 .Append("</td><td class=\"num\">").Append(x["STOCK"] == DBNull.Value ? "—" : Num(Convert.ToDecimal(x["STOCK"])))
                 .Append("</td><td><span class=\"rc-badge ").Append(clase).Append("\">").Append(Esc(est.ToLowerInvariant())).Append("</span>")
                 .Append("</td><td>").Append(Esc(Convert.ToString(x["USUARIO"]))).Append("</td></tr>");
            }
            s.Append("</table>");
            litReposiciones.Text = s.ToString();
        }

        DataTable con = alm.Conteos(r.rep_id);
        if (con.Rows.Count == 0)
            litConteos.Text = Vacio("clipboard-check-outline", "Sin conteos", "Este repuesto todavía no se ha contado. Se cuenta desde el recorrido del mapa 3D (rack › Contar este rack).");
        else
        {
            StringBuilder s = new StringBuilder("<table class=\"rc-tabla\"><tr><th>Fecha</th><th>Conteo</th><th>Bodega · rack</th>"
                + "<th class=\"num\">Sistema</th><th class=\"num\">Contado</th><th class=\"num\">Diferencia</th><th>Quién</th></tr>");
            foreach (DataRow x in con.Rows)
            {
                decimal dif = Convert.ToDecimal(x["DIFERENCIA"]);
                s.Append("<tr><td>").Append(Fecha(Convert.ToDateTime(x["FECHA"])))
                 .Append("</td><td>N° ").Append(Convert.ToInt32(x["CONTEO"])).Append(" · ").Append(Esc(Convert.ToString(x["ALCANCE"])))
                 .Append("</td><td>").Append(Esc(Convert.ToString(x["BODEGA"]))).Append(" · <b>").Append(Esc(Convert.ToString(x["UBICACION"]))).Append("</b>")
                 .Append("</td><td class=\"num\">").Append(Num(Convert.ToDecimal(x["SISTEMA"])))
                 .Append("</td><td class=\"num\">").Append(Num(Convert.ToDecimal(x["CONTADO"])))
                 .Append("</td><td class=\"num\">").Append(dif == 0 ? "<span class=\"rc-badge es-ok\">0</span>" : "<span class=\"rc-badge es-bajo\">" + (dif > 0 ? "+" : "") + Num(dif) + "</span>")
                 .Append("</td><td>").Append(Esc(Convert.ToString(x["USUARIO"]))).Append("</td></tr>");
            }
            s.Append("</table>");
            litConteos.Text = s.ToString();
        }
    }

    protected void lnkSolicitar_Click(object sender, EventArgs e)
    {
        hdnSeccion.Value = "reposicion";
        if (!SitioBase.Token.Puede("GESTIONAR STOCK")) return;
        int bodega;
        if (!int.TryParse(cboRepoBodega.SelectedValue, out bodega) || bodega <= 0)
        { litRepoAviso.Text = "<p class=\"rc-resultado\" style=\"color:#C7352B\">Elija la bodega.</p>"; return; }
        string t = (txtRepoCant.Text ?? "").Trim().Replace(" ", "");
        if (t.Contains(",") && !t.Contains(".")) t = t.Replace(",", ".");
        decimal cant;
        if (!decimal.TryParse(t, NumberStyles.Number, CultureInfo.InvariantCulture, out cant) || cant <= 0)
        { litRepoAviso.Text = "<p class=\"rc-resultado\" style=\"color:#C7352B\">Indique una cantidad mayor que cero.</p>"; return; }

        // la foto del momento: stock y umbrales de esa bodega quedan en la solicitud
        InventarioSaldo sal = (new InventarioController().GetSaldos(new InventarioSaldo { isa_repuesto = RepuestoId }) ?? new List<InventarioSaldo>())
                                .FirstOrDefault(x => x.isa_bodega == bodega);
        RepuestoBodegaStock umb = (new RepuestoController().GetUmbrales(new RepuestoBodegaStock { rbs_repuesto = RepuestoId }) ?? new List<RepuestoBodegaStock>())
                                .FirstOrDefault(x => x.rbs_bodega == bodega);
        Respuesta r = new RepuestoAlmacenamientoController().CrearReposicion(bodega, RepuestoId, cant,
            sal != null ? (decimal?)sal.isa_cantidad : 0, umb != null ? (decimal?)umb.rbs_stock_minimo : null,
            umb != null ? umb.rbs_stock_maximo : null, (txtRepoObs.Text ?? "").Trim());
        litRepoAviso.Text = "<p class=\"rc-resultado\" style=\"color:" + (r.error ? "#C7352B" : "#16855B") + ";font-weight:700\">" + Esc(r.detalle) + "</p>";
        if (!r.error) { txtRepoCant.Text = ""; txtRepoObs.Text = ""; }
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
            bool puede = SitioBase.Token.Puede("CREAR EDITAR REPUESTOS");
            // Todas las URL viajan en cada foto: el visor recorre la galería sin pedir nada al servidor.
            List<string> urls = imagenes.ConvertAll(x => SitioBase.UrlArchivo.Ver(x.archivo));
            string todas = Esc(string.Join("|", urls));
            StringBuilder s = new StringBuilder("<div class=\"rc-fotos\">");
            for (int i = 0; i < imagenes.Count; i++)
            {
                RepuestoFoto f = imagenes[i];
                s.Append("<div class=\"rc-foto\"><a href=\"#\" class=\"rc-foto-ver\" title=\"Ampliar\" onclick=\"return rcVisor(this);\"")
                 .Append(" data-fotos=\"").Append(todas).Append("\" data-pos=\"").Append(i)
                 .Append("\" data-titulo=\"").Append(Esc(r.rep_nombre)).Append("\">")
                 .Append("<img src=\"").Append(UrlArchivo(f.archivo)).Append("\" alt=\"").Append(Esc(r.rep_nombre)).Append("\" />")
                 .Append("<span class=\"rc-foto-zoom\"><i class=\"mdi mdi-magnify-plus-outline\"></i></span></a>")
                 .Append("<div class=\"pie\"><span>").Append(f.orden == 1 ? "<span class=\"rc-chip-portada\">Portada</span>" : Esc(f.titulo)).Append("</span>");
                if (puede)
                {
                    s.Append("<span class=\"rc-foto-acc\">");
                    if (f.orden != 1)
                        s.Append("<a href=\"#\" title=\"Usar como portada\" onclick=\"return rcAccion('portada',").Append(f.vinculo).Append(");\"><i class=\"mdi mdi-star-outline\"></i></a>");
                    s.Append("<a href=\"#\" class=\"es-peligro\" title=\"Eliminar\" onclick=\"return rcAccion('quitar',").Append(f.vinculo).Append(");\"><i class=\"mdi mdi-trash-can-outline\"></i></a></span>");
                }
                s.Append("</div></div>");
            }
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
             .Append(Esc(SitioBase.UrlArchivo.Ver(a.archivo))).Append("\" title=\"Ver\"><i class=\"mdi mdi-eye-outline\"></i></a>")
             .Append("<a class=\"link\" target=\"_blank\" href=\"").Append(Esc(SitioBase.UrlArchivo.Descargar(a.archivo))).Append("\" title=\"Descargar\"><i class=\"mdi mdi-download\"></i></a>")
             .Append(SitioBase.Token.Puede("CREAR EDITAR REPUESTOS")
                 ? "<a class=\"link es-peligro\" href=\"#\" title=\"Eliminar\" onclick=\"return rcAccion('quitar'," + a.vinculo + ");\"><i class=\"mdi mdi-trash-can-outline\"></i></a>" : "")
             .Append("</td></tr>");
        d.Append("</table>");
        litDocumentos.Text = d.ToString();
    }

    /// <summary>
    /// Adjunta una foto o un documento al repuesto, desde el propio centro.
    /// Se apoya en RepuestoFotoController, que enlaza por Archivo_Vinculo: no
    /// hay un segundo origen de archivos, es el mismo que ya usa la ficha.
    /// </summary>
    /// <summary>Quitar un archivo o dejar una foto de portada (botones de cada tarjeta).</summary>
    protected void lnkAccionArchivo_Click(object sender, EventArgs e)
    {
        litSubirAviso.Text = "";
        try
        {
            if (!SitioBase.Token.Puede("CREAR EDITAR REPUESTOS"))
                throw new Exception("No tiene permiso para modificar los archivos del repuesto.");
            int vinculo = Entero(hdnVinculo.Value);
            if (vinculo <= 0) return;
            RepuestoFotoController c = new RepuestoFotoController();
            Respuesta res = hdnAccion.Value == "portada" ? c.HacerPortada(vinculo) : c.Quitar(vinculo);
            if (res.error) throw new Exception(res.detalle);
            litSubirAviso.Text = "<p class=\"rc-resultado\" style=\"color:#16855B\"><i class=\"mdi mdi-check-circle-outline\"></i> "
                               + Esc(hdnAccion.Value == "portada" ? "Portada actualizada." : "Archivo eliminado.") + "</p>";
        }
        catch (Exception ex)
        {
            litSubirAviso.Text = "<p class=\"rc-resultado\" style=\"color:#C7352B\"><i class=\"mdi mdi-alert-circle-outline\"></i> " + Esc(ex.Message) + "</p>";
        }
    }

    // ------------------------------------------------------- ficha: edición en el lugar

    /// <summary>Editar (único, en el encabezado): lleva a la pestaña Ficha en modo formulario, sin modal.</summary>
    protected void lnkEditar_Click(object sender, EventArgs e)
    {
        if (!SitioBase.Token.Puede("CREAR EDITAR REPUESTOS")) return;
        Repuesto r = new RepuestoController().GetRepuesto(RepuestoId);
        if (r == null || r.rep_id == 0) return;

        LlenarFormulario(r);
        litFichaAviso.Text = "";
        EditandoFicha = true;
        hdnSeccion.Value = "resumen";
    }

    protected void lnkCancelarFicha_Click(object sender, EventArgs e)
    {
        EditandoFicha = false;
        litFichaAviso.Text = "";
    }

    private void LlenarFormulario(Repuesto r)
    {
        litEdCodigo.Text = Esc(r.rep_codigo);
        txtEdNombre.Text = r.rep_nombre;
        txtEdDescripcion.Text = r.rep_descripcion;

        cboEdTipo.Items.Clear();
        cboEdTipo.Items.Add(new RadComboBoxItem("Sin clasificar", ""));
        foreach (RepuestoTipo t in new RepuestoTipoController().GetRepuestoTipos(new RepuestoTipo { filtro_habilitado = true }) ?? new List<RepuestoTipo>())
            cboEdTipo.Items.Add(new RadComboBoxItem(t.rti_nombre, t.rti_id.ToString()));
        Elegir(cboEdTipo, r.rep_repuesto_tipo > 0 ? r.rep_repuesto_tipo.ToString() : "");

        cboEdUnidad.Items.Clear();
        cboEdUnidad.DataSource = new UnidadMedidaController().GetUnidades();
        cboEdUnidad.DataValueField = "ume_id";
        cboEdUnidad.DataTextField = "etiqueta";
        cboEdUnidad.DataBind();
        Elegir(cboEdUnidad, r.rep_unidad_medida.ToString());

        /* Combos SIGMA con texto libre (bloque 333): la lista sale del catálogo y
           el valor guardado se muestra aunque no esté en ella. */
        List<FabricanteController.Fabricante> catalogo = new FabricanteController().Catalogo();
        cboFabricante.Items.Clear();
        foreach (FabricanteController.Fabricante f in catalogo) cboFabricante.Items.Add(new RadComboBoxItem(f.nombre, f.nombre));
        cboFabricante.Text = r.rep_fabricante;
        cboModelo.Items.Clear();
        FabricanteController.Fabricante fab = catalogo.Find(x => string.Compare(x.nombre, (r.rep_fabricante ?? "").Trim(),
            CultureInfo.InvariantCulture, CompareOptions.IgnoreCase | CompareOptions.IgnoreNonSpace) == 0);
        if (fab != null) foreach (string m in fab.modelos) cboModelo.Items.Add(new RadComboBoxItem(m, m));
        cboModelo.Text = r.rep_modelo;

        txtEdCosto.Text = Dec(r.rep_costo_referencia);
        txtEdVidaHora.Text = Dec(r.rep_vida_util_hora);
        txtEdVidaDia.Text = r.rep_vida_util_dia == null ? "" : r.rep_vida_util_dia.Value.ToString(CultureInfo.InvariantCulture);
        txtEdVidaCiclo.Text = Dec(r.rep_vida_util_ciclo);

        rdbEdHabSi.Checked = r.rep_habilitado; rdbEdHabNo.Checked = !r.rep_habilitado;
        rdbEdLoteSi.Checked = r.rep_controla_lote; rdbEdLoteNo.Checked = !r.rep_controla_lote;
        rdbEdConsSi.Checked = r.rep_es_consumible; rdbEdConsNo.Checked = !r.rep_es_consumible;
        rdbEdRepSi.Checked = r.rep_es_reparable; rdbEdRepNo.Checked = !r.rep_es_reparable;

        DataRow alm = new RepuestoAlmacenamientoController().Ficha(r.rep_id);
        Elegir(cboEdMetodo, alm != null ? Convert.ToString(alm["METODO"]) : "");
        txtEdLargo.Text = alm == null ? "" : Med(alm["LARGO"]);
        txtEdAncho.Text = alm == null ? "" : Med(alm["ANCHO"]);
        txtEdAlto.Text = alm == null ? "" : Med(alm["ALTO"]);
        txtEdPeso.Text = alm == null ? "" : Med(alm["PESO"]);
    }

    /// <summary>
    /// Guarda la ficha con los mismos métodos que la ficha modal (Repuesto.aspx):
    /// baja por DEL_REPUESTO, datos por UPD_REPUESTO y almacenamiento por sus SP.
    /// </summary>
    protected void lnkGuardarFicha_Click(object sender, EventArgs e)
    {
        litFichaAviso.Text = "";
        try
        {
            if (!SitioBase.Token.Puede("CREAR EDITAR REPUESTOS"))
                throw new Exception("No tiene permiso para editar repuestos.");
            RepuestoController controller = new RepuestoController();
            Repuesto actual = controller.GetRepuesto(RepuestoId);
            if (actual == null || actual.rep_id == 0) throw new Exception("El repuesto ya no existe.");
            if (string.IsNullOrWhiteSpace(txtEdNombre.Text)) throw new Exception("Escriba el nombre del repuesto.");
            if (string.IsNullOrEmpty(cboEdUnidad.SelectedValue)) throw new Exception("Elija la unidad de medida.");

            Repuesto e2 = new Repuesto();
            e2.rep_id = actual.rep_id;
            e2.rep_codigo = actual.rep_codigo;     // no cambia: está impreso en su etiqueta
            e2.rep_nombre = txtEdNombre.Text.Trim();
            e2.rep_fabricante = cboFabricante.Text.Trim();
            e2.rep_modelo = cboModelo.Text.Trim();
            e2.rep_descripcion = txtEdDescripcion.Text.Trim();
            e2.rep_unidad_medida = int.Parse(cboEdUnidad.SelectedValue);
            int tipo;
            e2.rep_repuesto_tipo = int.TryParse(cboEdTipo.SelectedValue, out tipo) ? tipo : 0;
            e2.rep_costo_referencia = LeerDecimal(txtEdCosto.Text, "costo de referencia");
            e2.rep_vida_util_hora = LeerDecimal(txtEdVidaHora.Text, "vida útil en horas");
            e2.rep_vida_util_ciclo = LeerDecimal(txtEdVidaCiclo.Text, "vida útil en ciclos");
            decimal? dias = LeerDecimal(txtEdVidaDia.Text, "vida útil en días");
            if (dias != null)
            {
                if (dias.Value != Math.Floor(dias.Value))
                    throw new Exception("La vida útil en días tiene que ser un número entero.");
                e2.rep_vida_util_dia = (int)dias.Value;
            }
            e2.limpia_vida_util = true;            // al editar, vacío es borrar
            e2.rep_controla_lote = rdbEdLoteSi.Checked;
            e2.rep_es_consumible = rdbEdConsSi.Checked;
            e2.rep_es_reparable = rdbEdRepSi.Checked;
            e2.rep_habilitado = rdbEdHabSi.Checked;

            decimal? largo = LeerDecimal(txtEdLargo.Text, "largo");
            decimal? ancho = LeerDecimal(txtEdAncho.Text, "ancho");
            decimal? alto = LeerDecimal(txtEdAlto.Text, "alto");
            decimal? peso = LeerDecimal(txtEdPeso.Text, "peso");

            // La baja pasa por DEL_REPUESTO, que rechaza si queda existencia.
            if (actual.rep_habilitado && !e2.rep_habilitado)
            {
                Respuesta baja = controller.DeleteRepuesto(actual.rep_id);
                if (baja.error) throw new Exception(baja.detalle);
            }

            Respuesta res = controller.UpdateRepuesto(e2);
            if (res.error) throw new Exception(res.detalle);

            RepuestoAlmacenamientoController alm = new RepuestoAlmacenamientoController();
            Respuesta rm = alm.GuardarMetodo(actual.rep_id, cboEdMetodo.SelectedValue);
            Respuesta rd = rm.error ? rm : alm.GuardarMedidas(actual.rep_id, largo, ancho, alto, peso);
            if (rd.error) throw new Exception("El repuesto se guardó, pero el almacenamiento no: " + rd.detalle);

            EditandoFicha = false;
            Tools.tools.ClientAlert(res.detalle, "ok");
        }
        catch (Exception ex)
        {
            litFichaAviso.Text = "<p class=\"rc-resultado\" style=\"color:#C7352B\"><i class=\"mdi mdi-alert-circle-outline\"></i> "
                               + Esc(ex.Message) + "</p>";
        }
    }

    private static void Elegir(RadComboBox2 c, string valor)
    {
        c.ClearSelection();
        RadComboBoxItem it = c.FindItemByValue(valor ?? "");
        if (it != null) it.Selected = true;
    }

    private static string Dec(decimal? v)
    {
        return v == null ? "" : v.Value.ToString("0.##", CultureInfo.InvariantCulture);
    }

    private static string Med(object v)
    {
        return v == null || v == DBNull.Value ? "" : Convert.ToDecimal(v).ToString("0.###", CultureInfo.InvariantCulture);
    }

    /// <summary>Acepta coma y punto: en un teclado chileno la coma es lo natural.</summary>
    private static decimal? LeerDecimal(string texto, string campo)
    {
        if (string.IsNullOrWhiteSpace(texto)) return null;
        decimal valor;
        if (!decimal.TryParse(texto.Trim().Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El campo '" + campo + "' no es un número válido.");
        return valor;
    }

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
    // Archivo.aspx no existe: el visor del sitio es VerArchivo.aspx (SitioBase.UrlArchivo).
    private string UrlArchivo(int archivo) { return Esc(SitioBase.UrlArchivo.Ver(archivo)); }

    /// <summary>
    /// Tarjeta de indicador. Usa las clases reales de sigma-activo360
    /// (etq/val/pie): sin ellas el numero y la etiqueta se pegan, que era el
    /// "8Repuestos" del primer intento.
    /// </summary>
    /// <summary>Indicador con el diseño del Centro de activos (.sgap .kpi).</summary>
    private static string KpiV3(string svg, string fondo, string color, string etiqueta, string valor, string nota)
    {
        return "<div class=\"kpi\"><span class=\"kpi-ico\" style=\"--kb:" + fondo + ";--kc:" + color + "\">"
             + "<svg width=\"22\" height=\"22\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"1.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">" + svg + "</svg></span>"
             + "<div><span>" + Esc(etiqueta) + "</span><strong>" + valor + "</strong><small>" + Esc(nota) + "</small></div></div>";
    }

    private static string Kpi(string icono, string tono, string etiqueta, string valor, string pie)
    {
        return "<div class=\"sg-a3-kpi\"><span class=\"sg-a3-kpi-ico es-" + tono + "\">"
             + "<i class=\"mdi mdi-" + icono + "\"></i></span><div class=\"sg-a3-kpi-txt\">"
             + "<span class=\"sg-a3-kpi-etq\">" + Esc(etiqueta) + "</span>"
             + "<span class=\"sg-a3-kpi-val\">" + valor + "</span>"
             + (string.IsNullOrEmpty(pie) ? "" : "<span class=\"sg-a3-kpi-pie\">" + Esc(pie) + "</span>")
             + "</div></div>";
    }

    private static string Grupo(string icono, string titulo, string cuerpo)
    {
        return "<div class=\"rc-grupo\"><div class=\"rc-grupo-tit\"><i class=\"mdi mdi-" + icono + "\"></i>"
             + Esc(titulo) + "</div>" + cuerpo + "</div>";
    }

    private static string Fila(string k, string v)
    {
        bool vacio = string.IsNullOrWhiteSpace(v);
        return "<div class=\"rc-fila\"><span class=\"k\">" + Esc(k) + "</span><span class=\"v" + (vacio ? " es-vacio" : "")
             + "\">" + (vacio ? "Sin dato" : Esc(v)) + "</span></div>";
    }

    private static string ChipOp(string texto, bool si)
    {
        return "<span class=\"rc-chip-op " + (si ? "es-si" : "es-no") + "\"><i class=\"mdi mdi-"
             + (si ? "check" : "minus") + "\"></i>" + Esc(texto) + "</span>";
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
