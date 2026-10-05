using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// El formulario de un activo (HU-035), como control compartido.
///
/// DOS PANTALLAS, UN FORMULARIO
///   Lo muestran el modal de alta y la pestaña Ficha del centro del activo.
///   Cambia el vestido -las acciones al pie contra una barra fija- y nada
///   mas: si fueran dos formularios, cada campo nuevo habria que agregarlo
///   dos veces.
///
/// SEGURIDAD EN EL SERVIDOR
///   La escritura la habilita Token.Puede("CREAR EDITAR ACTIVOS"), no el
///   esconder el botón: Bloqueo() pone en solo lectura los controles y
///   oculta Guardar cuando el usuario no tiene el permiso. El acceso a la
///   ficha misma lo resolvió ya el master con Token.ExigirPagina().
/// </summary>
public partial class View_Activos_Activos_ActivoForm : System.Web.UI.UserControl
{
    /// <summary>
    /// El activo que muestra el formulario. NO se llama Id: en el markup ID es
    /// el nombre del control, y ASP.NET intentaria meter "frmActivo" en un int.
    /// </summary>
    public int ActivoId
    {
        get { return ViewState["ActivoId"] != null ? (int)ViewState["ActivoId"] : 0; }
        set { ViewState["ActivoId"] = value; }
    }

    // Modelo a preseleccionar al abrir en edición (solo el primer render).
    private string _modeloEditar = null;

    /* El centro elige el activo haciendo clic en su lista, o sea EN UN
       POSTBACK. Los "if (IsPostBack) return" que protegen lo tecleado dejaban
       el formulario en blanco justo cuando recien se abria el equipo. Esta
       bandera dice "este postback trae un activo distinto: hay que cargarlo". */
    private bool _activoNuevo = false;

    /// <summary>
    /// Donde se esta mostrando el formulario. En el centro las acciones van en
    /// una barra fija y guardar no cierra nada, porque no hay nada que cerrar.
    /// </summary>
    public bool EnCentro
    {
        get { return ViewState["EnCentro"] != null && (bool)ViewState["EnCentro"]; }
        set { ViewState["EnCentro"] = value; }
    }

    /// <summary>
    /// El activo que debe mostrar cuando lo aloja el centro. El modal no la
    /// usa: el suyo viene en el querystring.
    /// </summary>
    public int ActivoDelCentro { get; set; }

    /// <summary>Lo levanta el centro despues de guardar, para repintar su cabecera.</summary>
    public event EventHandler Guardado;

    protected void Page_Load(object sender, EventArgs e)
    {
        // Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
        // descifra por dentro. Descifrarlo antes lo haría descifrar dos veces
        // y la ficha se abriría en blanco como si fuera nueva.
        if (!IsPostBack)
        {
            ActivoId = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            // "Agregar subactivo" desde el centro: la maquina principal ya se sabe.
            if (ActivoId == 0) PadreFijo = SitioBase.Querystring.Entero(Request.QueryString["query"], "Padre");
            // Recien creado en el modal: se muestra la confirmacion con el proximo paso.
            _recienCreado = ActivoId > 0 && SitioBase.Querystring.Entero(Request.QueryString["query"], "Creado") == 1;
        }
    }

    /// <summary>El activo se acaba de crear en el modal: toca la confirmacion.</summary>
    private bool _recienCreado = false;

    /// <summary>El activo leido por CargarDatos, para la confirmacion y el panel del centro.</summary>
    private Activo _entidad;

    /* Lo que cuelga del activo, para "Sobre esta ficha". Lo informa el centro,
       que ya leyo la estructura para dibujar su diagrama: -1 = no se sabe. */
    public int NSubactivos = -1;
    public int NComponentes = -1;
    public int NRepuestos = -1;

    /// <summary>Maquina principal impuesta al crear un subactivo desde el asistente. 0 = se elige.</summary>
    public int PadreFijo
    {
        get { return ViewState["PadreFijo"] != null ? (int)ViewState["PadreFijo"] : 0; }
        set { ViewState["PadreFijo"] = value; }
    }

    /// <summary>
    /// Puebla los combos. Los catálogos NO se escriben a mano en el markup:
    /// se leen de su SEL_ (el estándar lo exige). Cada combo lleva su opción
    /// vacía cuando es opcional.
    /// </summary>
    /// <summary>
    /// Puebla los combos. Corre en el Load de cada uno, antes de que el centro
    /// diga de que activo habla: por eso la seleccion la hace CargarDatos y no
    /// este metodo.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboTipo":
                {
                    ActivoTipoController controller = new ActivoTipoController();
                    List<ActivoTipo> lista = controller.GetActivoTipos(
                        new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "ati_id";
                    ctrl.DataTextField = "ati_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboEstado":
                {
                    ActivoEstadoController controller = new ActivoEstadoController();
                    List<ActivoEstado> lista = controller.GetActivoEstados(
                        new ActivoEstado { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "aes_id";
                    ctrl.DataTextField = "aes_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboCriticidad":
                {
                    CriticidadNivelController controller = new CriticidadNivelController();
                    List<CriticidadNivel> lista = controller.GetCriticidadNiveles(
                        new CriticidadNivel { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "crn_id";
                    ctrl.DataTextField = "crn_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboPlanta":
                {
                    ClienteInstalacionController controller = new ClienteInstalacionController();

                    // Este modelo trae los filtros como string (convención
                    // heredada de ClienteInstalacion); se respeta tal cual.
                    ClienteInstalacion filtro = new ClienteInstalacion();
                    filtro.filtro_cliente = cliente.ToString();
                    filtro.filtro_habilitado = "1";

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                    ctrl.DataValueField = "cin_id";
                    ctrl.DataTextField = "cin_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboArea":
                {
                    InstalacionAreaController controller = new InstalacionAreaController();
                    List<InstalacionArea> lista = controller.GetInstalacionAreas(
                        new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin área", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "iar_id";
                    ctrl.DataTextField = "ruta";
                    ctrl.DataBind();
                    break;
                }

            case "cboCentroCosto":
                {
                    CentroCostoController controller = new CentroCostoController();
                    List<CentroCosto> lista = controller.GetCentrosCosto(
                        new CentroCosto { cco_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Sin centro de costo", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "cco_id";
                    ctrl.DataTextField = "ruta";
                    ctrl.DataBind();
                    break;
                }

            case "cboFabricante":
                {
                    // El catalogo de marcas compartido con repuestos (bloque 333/342).
                    foreach (FabricanteController.Fabricante f in new FabricanteController().Catalogo())
                        ctrl.Items.Add(new RadComboBoxItem(f.nombre, f.nombre));
                    break;
                }

            case "cboAnio":
                {
                    // Años del actual hacia atrás: la maquinaria industrial
                    // rara vez es anterior a 1950. Elegir de una lista evita
                    // tipeos como "20226" o un año futuro.
                    ctrl.Items.Add(new RadComboBoxItem("Sin dato", ""));
                    for (int anio = global::SitioBase.Hora.Hoy.Year; anio >= 1950; anio--)
                        ctrl.Items.Add(new RadComboBoxItem(anio.ToString(), anio.ToString()));
                    break;
                }

            case "cboPadre":
                {
                    ActivoController controller = new ActivoController();
                    List<Activo> lista = controller.GetActivos(
                        new Activo { act_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Ninguna: es una máquina principal", ""));
                    ctrl.AppendDataBoundItems = true;

                    if (lista != null)
                    {
                        // Un activo no puede ser su propio padre: se quita de
                        // la lista al editar. Los descendientes los rechaza
                        // igual el SP; aquí se evita solo el caso evidente.
                        if (ActivoId > 0) lista.RemoveAll(x => x.act_id == ActivoId);

                        foreach (Activo a in lista)
                            ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
                    }

                    break;
                }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* El centro dice de que activo habla y lo dice tarde -su propio
           PreRender corre antes que el de sus controles-, asi que se recoge
           aqui, antes de cargar nada. */
        if (EnCentro && ActivoDelCentro > 0 && ActivoId != ActivoDelCentro)
        {
            ActivoId = ActivoDelCentro;
            _activoNuevo = true;
        }

        pnlAccionesModal.Visible = !EnCentro;
        pnlAccionesCentro.Visible = EnCentro;

        /* El mismo asistente en los dos lados; en el centro con ancho
           controlado y la barra del pie pegada abajo. Al crear, Siguiente es
           lo principal hasta el ultimo paso (lo maneja el JS con af-es-nuevo). */
        pnlSecciones.CssClass = "af" + (EnCentro ? " af-centro" : " af-modal") + (ActivoId == 0 ? " af-es-nuevo" : "");

        /* Quien lo creo y cuando va en "Sobre esta ficha", al lado de los
           pasos: el control de auditoria del pie quedaba debajo de los botones. */
        wucAuditoria.Visible = false;
        pnlSobre.Visible = ActivoId > 0;
        btnGuardar.Text = ActivoId > 0 ? "Guardar cambios" : "Guardar activo";

        CargarDatos();
        CargarModelos();   // depende del tipo ya seleccionado por CargarDatos
        // Las secciones nuevas van blindadas: si algo falla, no debe colgar ni
        // romper el modal del activo.
        try { CargarArchivos(); } catch { }        // documentos adjuntos
        try { CargarDatosTecnicos(); } catch { }   // valores de atributos (edición)
        try { CargarComponentes(); } catch { }     // los componentes que ya tiene
        try { CargarVariablesMedidores(); } catch { }   // lo que ya mide y cuenta
        SobreEstructura();
        Confirmacion();
        Bloqueo();

        /* Guardar sube una imagen y unos PDF: un binario no sobrevive a un
           postback asincrono, asi que este boton recarga entero. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(EnCentro ? btnGuardarCentro : btnGuardar);
        udPanel.Update();
    }

    /// <summary>
    /// "Depende de este equipo": cuantos subactivos, componentes y repuestos
    /// tiene, con un enlace al diagrama. Solo cuando el centro lo informo.
    /// </summary>
    private void SobreEstructura()
    {
        litSobreEstructura.Text = "";
        if (!EnCentro || NSubactivos < 0) return;

        System.Text.StringBuilder b = new System.Text.StringBuilder("<div class=\"af-sobre-chips\">");
        b.Append("<span class=\"es-sub\">").Append(NSubactivos).Append(NSubactivos == 1 ? " subactivo" : " subactivos").Append("</span>");
        b.Append("<span class=\"es-comp\">").Append(NComponentes).Append(NComponentes == 1 ? " parte" : " partes").Append("</span>");
        b.Append("<span class=\"es-rep\">").Append(NRepuestos).Append(NRepuestos == 1 ? " repuesto" : " repuestos").Append("</span></div>");
        b.Append("<a href=\"#\" onclick=\"if (window.sigmaActivo360) sigmaActivo360.irA('componentes'); return false;\">")
         .Append("Ver de qué está hecho <i class=\"mdi mdi-arrow-right\"></i></a>");
        litSobreEstructura.Text = b.ToString();
    }

    /// <summary>
    /// Recien creado en el modal: en vez de cerrar a ciegas, dice que quedo
    /// creado y ofrece lo que normalmente sigue.
    /// </summary>
    private void Confirmacion()
    {
        pnlListo.Visible = _recienCreado && !EnCentro;
        if (!pnlListo.Visible) return;

        pnlSecciones.CssClass += " af-oculto";
        Activo a = _entidad ?? new ActivoController().GetActivo(ActivoId);
        bool esSub = a != null && a.act_activo_padre != null;

        litListoTitulo.Text = esSub ? "Listo, el subactivo quedó creado" : "Listo, el equipo quedó creado";
        litListoTexto.Text = a == null ? "" :
            "<b>" + Server.HtmlEncode(a.act_nombre) + "</b> · " + Server.HtmlEncode(a.act_codigo) +
            (string.IsNullOrEmpty(a.planta_nombre) ? " ya está en la lista de activos." : " ya está en la lista de activos de " + Server.HtmlEncode(a.planta_nombre) + ".");

        hlListoRepuestos.NavigateUrl = ResolveUrl("~/View/Inventario/Compatibilidades/RepuestoCompatibilidad.aspx") +
            "?query=" + Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Activo=" + ActivoId));

        string centro = ResolveUrl("~/View/Activos/Ficha/ActivoFicha.aspx") + "?query=" + Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + ActivoId));
        hlListoCentro.Attributes["onclick"] = "return afAbrirCentro('" + centro + "');";

        hlListoOtro.NavigateUrl = ResolveUrl("~/View/Activos/Activos/Activo.aspx") + "?query=" +
            (esSub ? Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&Padre=" + a.act_activo_padre.Value)) : "0");
    }

    /// <summary>
    /// La url de una hoja o un script con la fecha del archivo como version:
    /// con un "?v=1" fijo el navegador se queda con la copia vieja.
    /// </summary>
    protected string Asset(string ruta)
    {
        string f = Server.MapPath(ruta);
        return ResolveUrl(ruta) + "?v=" + (System.IO.File.Exists(f) ? System.IO.File.GetLastWriteTimeUtc(f).Ticks.ToString() : "1");
    }

    /// <summary>URL para ver/descargar un documento del activo.</summary>
    public string VerUrl(int idArchivo) { return UrlArchivo.Ver(idArchivo); }

    /// <summary>
    /// Datos técnicos del activo: los atributos de su tipo con su valor. Solo en
    /// edición (el activo ya existe). Se enlaza una vez (!IsPostBack) para que los
    /// valores tecleados sobrevivan el postback de Guardar.
    /// </summary>
    private System.Collections.Generic.List<UnidadMedida> _unidades;
    private string _unidadOptionsCache;

    /// <summary>Unidades cargadas una sola vez por request (evita consultas repetidas).</summary>
    private System.Collections.Generic.List<UnidadMedida> Unidades()
    {
        if (_unidades == null)
            _unidades = new UnidadMedidaController().GetUnidades()
                        ?? new System.Collections.Generic.List<UnidadMedida>();
        return _unidades;
    }

    /// <summary>Opciones &lt;option&gt; de unidad para las filas nuevas (plantilla JS).</summary>
    public string BuildUnidadOptions()
    {
        if (_unidadOptionsCache != null) return _unidadOptionsCache;
        System.Text.StringBuilder sb = new System.Text.StringBuilder();
        foreach (UnidadMedida u in Unidades())
        {
            string txt = u.ume_nombre + (string.IsNullOrEmpty(u.ume_simbolo) ? "" : " (" + u.ume_simbolo + ")");
            sb.Append("<option value=\"").Append(u.ume_id).Append("\">")
              .Append(Server.HtmlEncode(txt)).Append("</option>");
        }
        _unidadOptionsCache = sb.ToString();
        return _unidadOptionsCache;
    }

    protected void CargarDatosTecnicos()
    {
        pnlDatosTecnicos.Visible = true;   // siempre: se pueden agregar datos nuevos
        if (IsPostBack && !_activoNuevo) return;

        System.Collections.Generic.List<ActivoAtributoValor> l = ActivoId > 0
            ? new ActivoAtributoController().GetValores(ActivoId, SitioBase.Session.ClienteId())
            : null;
        if (l == null) l = new System.Collections.Generic.List<ActivoAtributoValor>();
        rptDatos.DataSource = l;
        rptDatos.DataBind();
    }

    /// <summary>Llena el combo de unidad de cada fila y selecciona la actual.</summary>
    protected void rptDatos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (!(e.Item.ItemType == ListItemType.Item || e.Item.ItemType == ListItemType.AlternatingItem)) return;

        ActivoAtributoValor a = e.Item.DataItem as ActivoAtributoValor;
        DropDownList ddl = e.Item.FindControl("ddlUnidad") as DropDownList;
        if (ddl == null) return;

        ddl.Items.Add(new ListItem("— sin unidad", ""));
        foreach (UnidadMedida u in Unidades())
        {
            string txt = u.ume_nombre + (string.IsNullOrEmpty(u.ume_simbolo) ? "" : " (" + u.ume_simbolo + ")");
            ddl.Items.Add(new ListItem(txt, u.ume_id.ToString()));
        }

        if (a != null && a.unidad_id > 0)
        {
            ListItem sel = ddl.Items.FindByValue(a.unidad_id.ToString());
            if (sel != null) sel.Selected = true;
        }
    }

    /// <summary>Graba el valor + unidad de cada atributo (lee los inputs del repeater).</summary>
    private void GuardarDatosTecnicos(int activo)
    {
        if (activo <= 0) return;
        ActivoAtributoController c = new ActivoAtributoController();

        // Datos existentes (del tipo): valor + unidad.
        foreach (RepeaterItem it in rptDatos.Items)
        {
            HiddenField h = it.FindControl("hdnAte") as HiddenField;
            TextBox t = it.FindControl("txtValor") as TextBox;
            DropDownList ddl = it.FindControl("ddlUnidad") as DropDownList;
            int ate, uni = 0;
            if (h != null && t != null && int.TryParse(h.Value, out ate))
            {
                if (ddl != null) int.TryParse(ddl.SelectedValue, out uni);
                c.GrabarDato(activo, ate, null, uni, t.Text);

                /* La foto del dato queda en los documentos del equipo con el
                   nombre del dato: "Potencia.jpg". */
                FileUpload fu = it.FindControl("fuDato") as FileUpload;
                string nombreDato = it.DataItem is ActivoAtributoValor ? ((ActivoAtributoValor)it.DataItem).ate_nombre : NombreDatoFila(it);
                if (fu != null && fu.HasFile)
                {
                    int arc = SubirImagen(fu.PostedFile, nombreDato);
                    if (arc > 0) new ActivoArchivoController().Vincular(activo, arc);
                }
            }
        }

        // Datos nuevos (filas agregadas al vuelo): nombre + unidad + valor.
        // Se busca-o-crea el atributo en el tipo (aparece también en el catálogo).
        string[] noms = Request.Form.GetValues("nd_nombre");
        string[] unis = Request.Form.GetValues("nd_unidad");
        string[] vals = Request.Form.GetValues("nd_valor");
        IList<System.Web.HttpPostedFile> fotos = Request.Files.GetMultiple("nd_foto");
        if (noms != null)
            for (int i = 0; i < noms.Length; i++)
            {
                string nom = (noms[i] ?? "").Trim();
                if (nom == "") continue;   // la plantilla vacía y filas sin nombre se omiten
                int uni = 0; if (unis != null && i < unis.Length) int.TryParse(unis[i], out uni);
                string val = (vals != null && i < vals.Length) ? vals[i] : "";
                c.GrabarDato(activo, 0, nom, uni, val);
                if (fotos != null && i < fotos.Count)
                {
                    int arc = SubirImagen(fotos[i], nom);
                    if (arc > 0) new ActivoArchivoController().Vincular(activo, arc);
                }
            }
    }

    /// <summary>El nombre del dato de una fila del repeater (su rotulo).</summary>
    private static string NombreDatoFila(RepeaterItem it)
    {
        foreach (Control c in it.Controls)
        {
            LiteralControl l = c as LiteralControl;
            if (l == null) continue;
            System.Text.RegularExpressions.Match m = System.Text.RegularExpressions.Regex.Match(l.Text, "<label>(.*?)</label>", System.Text.RegularExpressions.RegexOptions.Singleline);
            if (m.Success) return System.Web.HttpUtility.HtmlDecode(m.Groups[1].Value).Trim();
        }
        return "Dato de placa";
    }

    // ============================================================ bloque 342

    /// <summary>Id del item elegido, o del que coincide con lo escrito; 0 si es texto nuevo.</summary>
    private static int ValorCombo(RadComboBox2 c)
    {
        int v;
        string t = (c.Text ?? "").Trim();
        if (c.SelectedItem != null && string.Equals(c.SelectedItem.Text, t, StringComparison.OrdinalIgnoreCase)
            && int.TryParse(c.SelectedValue, out v)) return v;
        foreach (RadComboBoxItem it in c.Items)
            if (string.Equals(it.Text.Trim(), t, StringComparison.OrdinalIgnoreCase) && int.TryParse(it.Value, out v)) return v;
        return 0;
    }

    /// <summary>Lo escrito en el combo, sin el mensaje de ayuda ni las opciones vacias.</summary>
    private static string TextoCombo(RadComboBox2 c)
    {
        string t = (c.Text ?? "").Trim();
        if (t == "" || t == c.EmptyMessage || t == "Seleccione..." || t == "Sin modelo") return null;
        return t;
    }

    private List<ComponenteTipo> _tiposComp;
    private List<ComponenteTipo> TiposComponente()
    {
        return _tiposComp ?? (_tiposComp = new ComponenteTipoController().GetTipos(new ComponenteTipo()) ?? new List<ComponenteTipo>());
    }

    /// <summary>
    /// Sugerencias de "qué es" (datalist): los comunes de SIGMA y los propios
    /// de la empresa. Lo que no esta se escribe y se crea al guardar.
    /// </summary>
    public string OpcionesComponenteTipo()
    {
        int cli = SitioBase.Session.ClienteId();
        System.Text.StringBuilder b = new System.Text.StringBuilder();
        foreach (ComponenteTipo t in TiposComponente())
            if (t.cto_habilitado && (Convert.ToInt32(t.cto_cliente) == 0 || Convert.ToInt32(t.cto_cliente) == cli))
                b.Append("<option value=\"").Append(Server.HtmlEncode(t.cto_nombre)).Append("\"></option>");
        return b.ToString();
    }

    /// <summary>&lt;option&gt; de "dónde va" (lado motor, entrada...).</summary>
    public string OpcionesComponenteLado()
    {
        System.Text.StringBuilder b = new System.Text.StringBuilder();
        foreach (ComponentePosicion p in new ComponentePosicionController().GetPosiciones(new ComponentePosicion()) ?? new List<ComponentePosicion>())
            if (p.cpn_habilitado)
                b.Append("<option value=\"").Append(p.cpn_id).Append("\">").Append(Server.HtmlEncode(p.cpn_nombre)).Append("</option>");
        return b.ToString().Replace("'", "&#39;");
    }

    /// <summary>Las partes que el activo ya tiene, como chips (edición).</summary>
    protected void CargarComponentes()
    {
        litComponentes.Text = "";
        litPartesRail.Text = "Motor, rodamientos…";
        if (ActivoId <= 0) return;
        List<ActivoComponente> l = new ActivoComponenteController().GetComponentes(new ActivoComponente { filtro_activo = ActivoId });
        if (l != null) l.RemoveAll(c => !c.aco_habilitado);
        if (l == null || l.Count == 0) return;
        litPartesRail.Text = l.Count == 1 ? "1 componente" : l.Count + " componentes";
        System.Text.StringBuilder b = new System.Text.StringBuilder("<div class=\"af-ya\" style=\"margin-bottom:12px\"><span>Ya tiene:</span>");
        foreach (ActivoComponente c in l)
            b.Append("<span class=\"sigma-co-chip\"><i class=\"mdi mdi-puzzle-outline\"></i>").Append(Server.HtmlEncode(c.aco_nombre)).Append("</span>");
        b.Append("</div>");
        litComponentes.Text = b.ToString();
    }

    /// <summary>
    /// Botones "+ Rodamiento", "+ Motor"... con los tipos de parte comunes de
    /// SIGMA: tocar uno agrega la fila ya escrita.
    /// </summary>
    public string OpcionesPartesComunes()
    {
        System.Text.StringBuilder b = new System.Text.StringBuilder();
        int n = 0, cli = SitioBase.Session.ClienteId();
        List<string> nombres = new List<string>();
        foreach (ComponenteTipo t in TiposComponente() ?? new List<ComponenteTipo>())
            if (t.cto_habilitado && (Convert.ToInt32(t.cto_cliente) == 0 || Convert.ToInt32(t.cto_cliente) == cli) && !string.IsNullOrEmpty(t.cto_nombre)
                && !string.Equals(t.cto_nombre.Trim(), "Otro", StringComparison.OrdinalIgnoreCase) && !nombres.Contains(t.cto_nombre.Trim()))
                nombres.Add(t.cto_nombre.Trim());
        if (nombres.Count == 0)
            nombres.AddRange(new[] { "Motor", "Rodamiento", "Correa", "Válvula", "Sensor", "Ventilador", "Bomba", "Filtro" });
        foreach (string nombre in nombres)
        {
            string nom = Server.HtmlEncode(nombre);
            b.Append("<button type=\"button\" class=\"af-sug\" data-nombre=\"").Append(nom)
             .Append("\" onclick=\"coSugerir(this)\"><i class=\"mdi mdi-plus\"></i>").Append(nom).Append("</button>");
            if (++n == 10) break;
        }
        return b.ToString();
    }

    /// <summary>Crea las partes agregadas en la ficha (filas co_*). Una fila sin nombre se ignora.</summary>
    private void GuardarComponentes(int activo, int criticidad)
    {
        if (activo <= 0) return;
        string[] noms = Request.Form.GetValues("co_nombre");
        string[] tipos = Request.Form.GetValues("co_tipo");
        string[] lados = Request.Form.GetValues("co_lado");
        if (noms == null) return;
        /* Una foto por fila: el navegador manda una parte por cada input,
           elegida o no, asi que el indice calza con el de los nombres. */
        IList<System.Web.HttpPostedFile> fotos = Request.Files.GetMultiple("co_foto");
        ActivoComponenteController c = new ActivoComponenteController();
        for (int i = 0; i < noms.Length; i++)
        {
            string nom = (noms[i] ?? "").Trim();
            string queEs = tipos != null && i < tipos.Length ? (tipos[i] ?? "").Trim() : "";
            string dondeVa = lados != null && i < lados.Length ? (lados[i] ?? "").Trim() : "";
            if (nom == "") continue;
            if (queEs == "") queEs = "Otro";
            /* "Que es" y "Donde va" se eligen o se escriben: lo que no existe
               se crea como propio de la empresa (bloques 343 y 345). */
            int tipo = new ComponenteTipoController().ResolverPorNombre(queEs);
            if (tipo <= 0) continue;
            ActivoComponente e = new ActivoComponente();
            e.aco_cliente = SitioBase.Session.ClienteId();
            e.aco_activo = activo;
            e.aco_componente_tipo = tipo;
            if (dondeVa != "")
            {
                int lado = new ComponentePosicionController().ResolverPorNombre(dondeVa);
                if (lado > 0) e.aco_componente_posicion = lado;
            }
            e.aco_criticidad_nivel = criticidad;
            e.aco_activo_componente_estado = 1;   // operativo
            e.aco_codigo = "AUTO";
            e.aco_nombre = nom;
            e.aco_fecha_instalacion = global::SitioBase.Hora.Hoy;
            Respuesta r = c.InsertComponente(e);

            if (!r.error && r.codigo > 0 && fotos != null && i < fotos.Count)
            {
                int arc = SubirImagen(fotos[i], null);
                if (arc > 0) new ActivoComponenteImagenController().VincularImagen(r.codigo, arc);
            }
        }
    }

    /// <summary>
    /// Sube una imagen elegida en una fila y devuelve el id del archivo (0 si
    /// no habia o fallo). Con nombre, el archivo queda guardado con ese nombre
    /// y la extension original: "Potencia.jpg".
    /// </summary>
    private int SubirImagen(System.Web.HttpPostedFile f, string nombre)
    {
        if (f == null || f.ContentLength == 0 || string.IsNullOrEmpty(f.FileName)) return 0;
        try
        {
            byte[] contenido;
            using (System.IO.MemoryStream ms = new System.IO.MemoryStream()) { f.InputStream.CopyTo(ms); contenido = ms.ToArray(); }
            if (contenido.Length == 0) return 0;

            string original = System.IO.Path.GetFileName(f.FileName);
            Archivo arc = new Archivo();
            arc.arc_cliente = SitioBase.Session.ClienteId();
            arc.arc_archivo_categoria = 10;   // REFERENCIA
            arc.arc_nombre_original = string.IsNullOrWhiteSpace(nombre) ? original
                : string.Join("_", nombre.Trim().Split(System.IO.Path.GetInvalidFileNameChars())) + System.IO.Path.GetExtension(original);
            arc.arc_mime = f.ContentType;
            arc.contenido = contenido;

            Respuesta r = new ArchivoController().InsertArchivo(arc, "activos");
            return !r.error && r.codigo > 0 ? r.codigo : 0;
        }
        catch (Exception) { return 0; }
    }

    // ============================================================ variables y medidores (bloque 345)

    private static decimal? Numero(string t)
    {
        t = (t ?? "").Trim();
        if (t == "") return null;
        decimal d;
        if (decimal.TryParse(t, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.GetCultureInfo("es-CL"), out d)) return d;
        if (decimal.TryParse(t, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out d)) return d;
        return null;
    }

    /// <summary>
    /// Variables de condicion agregadas en el asistente: que se mide (se
    /// elige o se escribe y se crea), su unidad y el rango normal.
    /// </summary>
    private string GuardarVariables(int activo)
    {
        string[] noms = Request.Form.GetValues("va_nombre");
        string[] unis = Request.Form.GetValues("va_unidad");
        string[] mins = Request.Form.GetValues("va_min");
        string[] maxs = Request.Form.GetValues("va_max");
        if (activo <= 0 || noms == null) return "";
        List<string> avisos = new List<string>();
        for (int i = 0; i < noms.Length; i++)
        {
            string nom = (noms[i] ?? "").Trim();
            if (nom == "") continue;
            int uni = 0; if (unis != null && i < unis.Length) int.TryParse(unis[i], out uni);
            int variable = new VariableMedicionController().ResolverPorNombre(nom, uni);
            if (variable <= 0) { avisos.Add(nom + " (falta la unidad)"); continue; }

            ActivoVariable v = new ActivoVariable();
            v.ava_activo = activo;
            v.ava_variable_medicion = variable;
            if (uni > 0) v.ava_unidad_medida = uni;
            v.ava_valor_minimo = mins != null && i < mins.Length ? Numero(mins[i]) : null; v.quita_minimo = v.ava_valor_minimo == null;
            v.ava_valor_maximo = maxs != null && i < maxs.Length ? Numero(maxs[i]) : null; v.quita_maximo = v.ava_valor_maximo == null;
            v.quita_advertencia = v.quita_critico = v.quita_frecuencia = true;
            v.ava_habilitado = true;
            Respuesta r = new ActivoVariableController().Insert(v);
            if (r.error) avisos.Add(nom + " (" + r.detalle + ")");
        }
        return avisos.Count == 0 ? "" : " No se pudo agregar la variable: " + string.Join(", ", avisos.ToArray()) + ".";
    }

    /// <summary>Medidores (contadores) agregados en el asistente, con la lectura de hoy.</summary>
    private string GuardarMedidores(int activo)
    {
        string[] noms = Request.Form.GetValues("me_nombre");
        string[] unis = Request.Form.GetValues("me_unidad");
        string[] vals = Request.Form.GetValues("me_valor");
        if (activo <= 0 || noms == null) return "";
        List<string> avisos = new List<string>();
        for (int i = 0; i < noms.Length; i++)
        {
            string nom = (noms[i] ?? "").Trim();
            if (nom == "") continue;
            int uni = 0; if (unis != null && i < unis.Length) int.TryParse(unis[i], out uni);
            if (uni <= 0) { avisos.Add(nom + " (falta la unidad)"); continue; }

            ActivoMedidor m = new ActivoMedidor();
            m.ame_cliente = SitioBase.Session.ClienteId();
            m.ame_activo = activo;
            m.ame_unidad_medida = uni;
            m.ame_codigo = SitioBase.CodigoModulo.Componer("Activo_Medidor", "");
            m.ame_nombre = nom;
            decimal? valor = vals != null && i < vals.Length ? Numero(vals[i]) : null;
            m.ame_valor_actual = valor != null && valor.Value > 0 ? valor.Value : 0m;
            m.ame_permite_reinicio = false;
            m.ame_habilitado = true;
            Respuesta r = new ActivoMedidorController().InsertActivoMedidor(m);
            if (r.error) avisos.Add(nom + " (" + r.detalle + ")");
        }
        return avisos.Count == 0 ? "" : " No se pudo agregar el medidor: " + string.Join(", ", avisos.ToArray()) + ".";
    }

    /// <summary>Lo que el activo ya mide y ya cuenta, como chips (edicion).</summary>
    private void CargarVariablesMedidores()
    {
        litVariables.Text = litMedidores.Text = "";
        if (ActivoId <= 0) return;

        List<ActivoVariable> vs = new ActivoVariableController().GetVariables(new ActivoVariable { filtro_activo = ActivoId, filtro_habilitado = true }) ?? new List<ActivoVariable>();
        if (vs.Count > 0)
        {
            litVarsRail.Text = vs.Count == 1 ? "1 variable" : vs.Count + " variables";
            System.Text.StringBuilder b = new System.Text.StringBuilder("<div class=\"af-ya\" style=\"margin-bottom:12px\"><span>Ya mide:</span>");
            foreach (ActivoVariable v in vs)
                b.Append("<span class=\"sigma-co-chip\"><i class=\"mdi mdi-pulse\"></i>").Append(Server.HtmlEncode(v.variable_nombre))
                 .Append(string.IsNullOrEmpty(v.unidad_simbolo) ? "" : " (" + Server.HtmlEncode(v.unidad_simbolo) + ")").Append("</span>");
            litVariables.Text = b.Append("</div>").ToString();
        }

        List<ActivoMedidor> ms = new ActivoMedidorController().GetActivoMedidores(new ActivoMedidor { filtro_activo = ActivoId, filtro_habilitado = true }) ?? new List<ActivoMedidor>();
        if (ms.Count > 0)
        {
            litMedsRail.Text = ms.Count == 1 ? "1 medidor" : ms.Count + " medidores";
            System.Text.StringBuilder b = new System.Text.StringBuilder("<div class=\"af-ya\" style=\"margin-bottom:12px\"><span>Ya cuenta:</span>");
            foreach (ActivoMedidor m in ms)
                b.Append("<span class=\"sigma-co-chip\"><i class=\"mdi mdi-counter\"></i>").Append(Server.HtmlEncode(m.ame_nombre))
                 .Append(" · ").Append(m.ame_valor_actual.ToString("#,0.##")).Append(string.IsNullOrEmpty(m.unidad_simbolo) ? "" : " " + Server.HtmlEncode(m.unidad_simbolo)).Append("</span>");
            litMedidores.Text = b.Append("</div>").ToString();
        }
    }

    /// <summary>
    /// Las opciones de los combos con texto libre del asistente, como objeto
    /// JS: que es un componente, donde va, que se mide y que cuenta.
    /// </summary>
    public string OpcionesCombosJson()
    {
        int cli = SitioBase.Session.ClienteId();
        List<string> tipos = new List<string>(), lados = new List<string>(), vars = new List<string>();
        try
        {
            foreach (ComponenteTipo t in TiposComponente())
                if (t.cto_habilitado && (Convert.ToInt32(t.cto_cliente) == 0 || Convert.ToInt32(t.cto_cliente) == cli) && !tipos.Contains(t.cto_nombre)) tipos.Add(t.cto_nombre);
            foreach (ComponentePosicion p in new ComponentePosicionController().GetPosiciones(new ComponentePosicion()) ?? new List<ComponentePosicion>())
                if (p.cpn_habilitado && (Convert.ToInt32(p.cpn_cliente) == 0 || Convert.ToInt32(p.cpn_cliente) == cli) && !lados.Contains(p.cpn_nombre)) lados.Add(p.cpn_nombre);
            foreach (VariableMedicion v in new VariableMedicionController().GetVariables(cli) ?? new List<VariableMedicion>())
                if (!vars.Contains(v.vme_nombre)) vars.Add(v.vme_nombre);
        }
        catch (Exception) { }
        tipos.Sort(StringComparer.CurrentCultureIgnoreCase);
        lados.Sort(StringComparer.CurrentCultureIgnoreCase);
        vars.Sort(StringComparer.CurrentCultureIgnoreCase);
        List<string> meds = new List<string> { "Horas de marcha", "Ciclos", "Arranques", "Kilómetros", "Litros bombeados", "Unidades producidas" };

        Dictionary<string, object> d = new Dictionary<string, object>();
        d["tipos"] = tipos; d["lados"] = lados; d["vars"] = vars; d["meds"] = meds;
        /* El JSON va dentro de un <script>: "</" se corta para que un nombre
           escrito por alguien no pueda cerrar la etiqueta. */
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(d).Replace("</", "<\\/");
    }

    /// <summary>Lista los documentos adjuntos del activo (edición).</summary>
    protected void CargarArchivos()
    {
        System.Collections.Generic.List<ActivoArchivo> l =
            new ActivoArchivoController().GetArchivos(ActivoId, SitioBase.Session.ClienteId());
        if (l == null) l = new System.Collections.Generic.List<ActivoArchivo>();
        rptArchivos.DataSource = l;
        rptArchivos.DataBind();
    }

    /// <summary>El "Quitar" hace postback completo (el form es multipart por el uploader).</summary>
    protected void rptArchivos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType == ListItemType.Item || e.Item.ItemType == ListItemType.AlternatingItem)
            foreach (Control ctl in e.Item.Controls)
                if (ctl is LinkButton)
                    ScriptManager.GetCurrent(Page).RegisterPostBackControl((LinkButton)ctl);
    }

    protected void rptArchivos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName == "quitar")
        {
            int idArchivo;
            if (int.TryParse(Convert.ToString(e.CommandArgument), out idArchivo) && ActivoId > 0)
                new ActivoArchivoController().Desvincular(ActivoId, idArchivo);
            CargarArchivos();
        }
    }

    /// <summary>
    /// Sube los documentos elegidos (opcional, varios) y los enlaza al activo.
    /// Reutiliza el sistema Archivo (Azure). PDF -> DOCUMENTO, imagen -> REFERENCIA.
    /// </summary>
    private void GuardarArchivos(int activo)
    {
        if (activo <= 0 || fuDocs == null || !fuDocs.HasFiles) return;

        foreach (System.Web.HttpPostedFile f in fuDocs.PostedFiles)
        {
            if (f == null || f.ContentLength == 0) continue;
            try
            {
                byte[] contenido;
                using (System.IO.MemoryStream ms = new System.IO.MemoryStream()) { f.InputStream.CopyTo(ms); contenido = ms.ToArray(); }
                if (contenido.Length == 0) continue;

                string mime = f.ContentType ?? "";
                bool esImagen = mime.StartsWith("image", StringComparison.OrdinalIgnoreCase);

                Archivo arc = new Archivo();
                arc.arc_cliente = SitioBase.Session.ClienteId();
                arc.arc_archivo_categoria = esImagen ? 10 : 9;   // 10 REFERENCIA / 9 DOCUMENTO
                arc.arc_nombre_original = System.IO.Path.GetFileName(f.FileName);
                arc.arc_mime = mime;
                arc.contenido = contenido;

                Respuesta r = new ArchivoController().InsertArchivo(arc, "activos");
                if (!r.error && r.codigo > 0)
                    new ActivoArchivoController().Vincular(activo, r.codigo);
            }
            catch (Exception) { /* un archivo que falla no anula el guardado del activo */ }
        }
    }

    // Al cambiar el tipo, el postback recarga y CargarModelos ofrece solo los
    // modelos de ese tipo.
    protected void cboTipo_SelectedIndexChanged(object sender, EventArgs e) { }

    // Al cambiar el fabricante, el PreRender vuelve a armar los modelos de ese tipo y esa marca.
    protected void cboFabricante_Changed(object sender, EventArgs e) { }

    // Al elegir un modelo, se hereda su fabricante (el modelo manda la marca).
    protected void cboModelo_SelectedIndexChanged(object sender, EventArgs e)
    {
        int idModelo;
        if (int.TryParse(cboModelo.SelectedValue, out idModelo) && idModelo > 0)
        {
            ActivoModelo m = new ActivoModeloController().GetModelo(idModelo);
            if (m != null && !string.IsNullOrEmpty(m.amo_fabricante))
                cboFabricante.Text = m.amo_fabricante;
        }
    }

    /// <summary>
    /// Llena el combo de modelos con los del TIPO elegido (más los globales),
    /// preservando la selección entre postbacks. Sin tipo, el combo va vacío.
    /// </summary>
    protected void CargarModelos()
    {
        string sel = string.IsNullOrEmpty(_modeloEditar) ? cboModelo.SelectedValue : _modeloEditar;
        string escrito = (cboModelo.Text ?? "").Trim();   // un modelo nuevo escrito a mano no se pierde

        cboModelo.Items.Clear();
        cboModelo.Items.Add(new RadComboBoxItem("Sin modelo", ""));
        cboModelo.AppendDataBoundItems = true;

        int tipo;
        if (int.TryParse(cboTipo.SelectedValue, out tipo) && tipo > 0)
        {
            List<ActivoModelo> l = new ActivoModeloController().GetModelos(new ActivoModelo
            { filtro_cliente = SitioBase.Session.ClienteId(), filtro_activo_tipo = tipo, filtro_habilitado = true });
            /* Del tipo Y del fabricante escrito (bloque 342): con "Grundfos"
               no se ofrecen modelos de Pedrollo. Un modelo sin marca se ofrece
               siempre. */
            string fab = (cboFabricante.Text ?? "").Trim();
            if (fab == cboFabricante.EmptyMessage) fab = "";
            if (l != null)
                foreach (ActivoModelo m in l)
                    if (fab == "" || string.IsNullOrEmpty(m.amo_fabricante)
                        || string.Compare(m.amo_fabricante.Trim(), fab, System.Globalization.CultureInfo.InvariantCulture,
                               System.Globalization.CompareOptions.IgnoreCase | System.Globalization.CompareOptions.IgnoreNonSpace) == 0)
                        cboModelo.Items.Add(new RadComboBoxItem(m.etiqueta, m.amo_id.ToString()));
        }

        RadComboBoxItem it = cboModelo.FindItemByValue(sel);
        if (it != null) it.Selected = true;
        else if (escrito != "" && escrito != "Sin modelo" && escrito != cboModelo.EmptyMessage)
            cboModelo.Text = escrito;
    }

    protected void CargarDatos()
    {
        if (IsPostBack && !_activoNuevo) return;

        if (ActivoId > 0)
        {
            ActivoController controller = new ActivoController();
            Activo entidad = controller.GetActivo(ActivoId);
            _entidad = entidad;

            lblId.Text = ActivoId.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Activo", entidad.act_codigo);
            txtNombre.Text = entidad.act_nombre;

            SeleccionarCombo(cboTipo, entidad.act_activo_tipo);
            SeleccionarCombo(cboEstado, entidad.act_activo_estado);
            SeleccionarCombo(cboCriticidad, entidad.act_criticidad_nivel);
            SeleccionarCombo(cboPlanta, entidad.act_cliente_instalacion);

            if (entidad.act_instalacion_area != null) SeleccionarCombo(cboArea, entidad.act_instalacion_area.Value);
            if (entidad.act_centro_costo != null) SeleccionarCombo(cboCentroCosto, entidad.act_centro_costo.Value);
            if (entidad.act_activo_padre != null) SeleccionarCombo(cboPadre, entidad.act_activo_padre.Value);
            // El modelo lo selecciona CargarModelos (corre después y ya conoce el tipo).
            if (entidad.act_activo_modelo != null) _modeloEditar = entidad.act_activo_modelo.Value.ToString();

            txtSerie.Text = entidad.act_numero_serie;
            cboFabricante.Text = entidad.act_fabricante;
            if (entidad.act_anio_fabricacion != null) SeleccionarCombo(cboAnio, entidad.act_anio_fabricacion.Value);
            calPuestaMarcha.Value = entidad.act_fecha_puesta_marcha;
            txtDescripcion.Text = entidad.act_descripcion;

            rdbSi.Checked = entidad.act_habilitado;
            rdbNo.Checked = !entidad.act_habilitado;

            /* En el centro la auditoria va en la barra fija de abajo, al lado
               de Guardar: es el dato que se mira justo antes de tocar algo
               -quien fue el ultimo que lo cambio- y no al final de la ficha. */
            litAuditoriaPie.Text =
                Pie("mdi-account-plus-outline", "Creado", entidad.usuario_creacion_nombre, entidad.act_fecha_creacion) +
                Pie("mdi-clock-outline", "Última edición", entidad.usuario_actualizacion_nombre, entidad.act_fecha_actualizacion);

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.act_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.act_fecha_actualizacion);

            // Vista previa de la imagen actual, si la tiene.
            int idImagen = new ActivoImagenController().GetImagenId(ActivoId, SitioBase.Session.ClienteId());
            pnlSinImagen.Visible = idImagen <= 0;
            pnlQuitarImagen.Visible = idImagen > 0;
            if (idImagen > 0)
            {
                imgActual.Src = UrlArchivo.Ver(idImagen);
                /* El enlace lleva a la misma imagen: dentro del centro la
                   amplia el visor, y en el modal -donde ese visor no existe- se
                   abre en una pestaña nueva. */
                lnkImagenActual.HRef = UrlArchivo.Ver(idImagen);
                pnlImagenActual.Visible = true;
            }
        }
        else
        {
            lblId.Text = "Nuevo";

            /* Lo que casi siempre es igual ya viene puesto: un equipo que se
               da de alta normalmente esta operativo, y una empresa con una
               sola planta no tiene que elegirla. Todo se puede cambiar. */
            if (string.IsNullOrEmpty(cboEstado.SelectedValue))
                foreach (RadComboBoxItem it in cboEstado.Items)
                    if (it.Value != "" && it.Text.IndexOf("operativ", StringComparison.OrdinalIgnoreCase) >= 0)
                    { SeleccionarCombo(cboEstado, int.Parse(it.Value)); break; }
            if (string.IsNullOrEmpty(cboPlanta.SelectedValue) && cboPlanta.Items.Count == 2)
            {
                int planta;
                if (int.TryParse(cboPlanta.Items[1].Value, out planta)) SeleccionarCombo(cboPlanta, planta);
            }

            /* Subactivo desde el asistente: queda colgado de su maquina
               principal y hereda donde esta. Todo se puede cambiar. */
            if (PadreFijo > 0)
            {
                Activo p = new ActivoController().GetActivo(PadreFijo);
                if (p != null && p.act_cliente == SitioBase.Session.ClienteId())
                {
                    SeleccionarCombo(cboPadre, p.act_id);
                    SeleccionarCombo(cboPlanta, p.act_cliente_instalacion);
                    if (p.act_instalacion_area != null) SeleccionarCombo(cboArea, p.act_instalacion_area.Value);
                    if (p.act_centro_costo != null) SeleccionarCombo(cboCentroCosto, p.act_centro_costo.Value);
                    SeleccionarCombo(cboCriticidad, p.act_criticidad_nivel);
                }
            }
        }
    }

    /// <summary>
    /// Selecciona un valor en un combo solo si la opción existe. Evita la
    /// excepción de RadComboBox cuando el id ya no está en la lista (por
    /// ejemplo, un tipo deshabilitado después de haberse asignado).
    /// </summary>
    /// <summary>Un dato de la barra de abajo: quien y cuando.</summary>
    private string Pie(string icono, string etiqueta, string usuario, DateTime? fecha)
    {
        if (fecha == null && string.IsNullOrEmpty(usuario)) return "";

        return "<span class=\"sg-a3-pie-dato\"><i class=\"mdi " + icono + "\"></i>" +
               "<span><b>" + Server.HtmlEncode(etiqueta) + "</b>" +
               Server.HtmlEncode(string.IsNullOrEmpty(usuario) ? "Sin registro" : usuario) +
               (fecha == null ? "" : " · " + fecha.Value.ToString("dd MMM yyyy HH:mm")) +
               "</span></span>";
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null)
        {
            combo.ClearSelection();
            item.Selected = true;
            if (combo.AllowCustomText) combo.Text = item.Text;   // si no, se ve el mensaje vacio
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR ACTIVOS");

        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Activo");
            txtCodigo.ReadOnly = ActivoId > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtSerie.ReadOnly = !puedeEditar;
        cboFabricante.ReadOnly = !puedeEditar;
        cboAnio.ReadOnly = !puedeEditar;
        calPuestaMarcha.Enabled = puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;

        cboTipo.ReadOnly = !puedeEditar;
        cboModelo.ReadOnly = !puedeEditar;
        cboEstado.ReadOnly = !puedeEditar;
        cboCriticidad.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboArea.ReadOnly = !puedeEditar;
        cboCentroCosto.ReadOnly = !puedeEditar;
        cboPadre.ReadOnly = !puedeEditar;

        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
        btnGuardarCentro.Visible = puedeEditar;

        chkQuitarImagen.Enabled = puedeEditar;
        fuImagen.Visible = puedeEditar;
        pnlSubirDocs.Visible = puedeEditar;
    }

    /// <summary>En el centro, Cancelar vuelve a la ficha guardada: se recarga y ya.</summary>
    protected void btnCancelar_Click(object sender, EventArgs e)
    {
        Response.Redirect(Request.RawUrl);
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Tipo y modelo con texto libre (bloque 342): lo que no existe se
               crea aqui, en una llamada, antes de guardar el activo. */
            int tipoId = ValorCombo(cboTipo), modeloId = ValorCombo(cboModelo);
            string tipoTxt = TextoCombo(cboTipo), modeloTxt = TextoCombo(cboModelo);
            if (tipoId == 0 && tipoTxt == null)
                throw new Exception("Elija o escriba el tipo de activo.");
            string errCat = new ActivoTipoController().ResolverCatalogo(ref tipoId, tipoTxt, ref modeloId,
                modeloId == 0 ? modeloTxt : null, string.IsNullOrWhiteSpace(cboFabricante.Text) ? null : cboFabricante.Text.Trim());
            if (errCat != null) throw new Exception(errCat);
            if (string.IsNullOrEmpty(cboEstado.SelectedValue))
                throw new Exception("Debe elegir el estado del activo.");
            if (string.IsNullOrEmpty(cboCriticidad.SelectedValue))
                throw new Exception("Debe elegir la criticidad del activo.");
            if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
                throw new Exception("Debe elegir la planta a la que pertenece el activo.");

            Activo entidad = new Activo();
            ActivoController controller = new ActivoController();

            entidad.act_id = ActivoId;
            entidad.act_cliente = SitioBase.Session.ClienteId();
            entidad.act_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            entidad.act_activo_tipo = tipoId;
            entidad.act_activo_estado = int.Parse(cboEstado.SelectedValue);
            entidad.act_criticidad_nivel = int.Parse(cboCriticidad.SelectedValue);
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como ACT-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.act_codigo = SitioBase.CodigoModulo.Componer("Activo", txtCodigo.Text);
            entidad.act_nombre = txtNombre.Text.Trim();
            entidad.act_habilitado = rdbSi.Checked;

            if (modeloId > 0) entidad.act_activo_modelo = modeloId;
            if (!string.IsNullOrEmpty(cboArea.SelectedValue))
                entidad.act_instalacion_area = int.Parse(cboArea.SelectedValue);
            if (!string.IsNullOrEmpty(cboCentroCosto.SelectedValue))
                entidad.act_centro_costo = int.Parse(cboCentroCosto.SelectedValue);
            if (!string.IsNullOrEmpty(cboPadre.SelectedValue))
                entidad.act_activo_padre = int.Parse(cboPadre.SelectedValue);

            if (!string.IsNullOrEmpty(txtSerie.Text.Trim()))
                entidad.act_numero_serie = txtSerie.Text.Trim();
            if (!string.IsNullOrEmpty(cboFabricante.Text.Trim()))
                entidad.act_fabricante = cboFabricante.Text.Trim();
            if (!string.IsNullOrEmpty(cboAnio.SelectedValue))
                entidad.act_anio_fabricacion = int.Parse(cboAnio.SelectedValue);

            // El calendario ya entrega un DateTime? válido; solo se rechaza
            // una fecha futura, que para una puesta en marcha no tiene sentido.
            if (calPuestaMarcha.Value != null && calPuestaMarcha.Value.Value.Date > global::SitioBase.Hora.Hoy)
                throw new Exception("La fecha de puesta en marcha no puede ser futura.");
            entidad.act_fecha_puesta_marcha = calPuestaMarcha.Value;

            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim()))
                entidad.act_descripcion = txtDescripcion.Text.Trim();

            Respuesta respuesta = (ActivoId > 0)
                ? controller.UpdateActivo(entidad)
                : controller.InsertActivo(entidad);

            if (!respuesta.error)
            {
                bool eraNuevo = ActivoId == 0;
                ActivoId = respuesta.codigo;

                // La imagen es opcional: si se eligió una, se sube y se enlaza
                // como imagen de referencia del activo. Un fallo aquí no anula
                // el guardado del activo; solo avisa.
                string avisoImg = GuardarImagen(ActivoId);
                GuardarArchivos(ActivoId);        // documentos adjuntos (opcional, varios)
                GuardarDatosTecnicos(ActivoId);   // valores de atributos técnicos
                GuardarComponentes(ActivoId, entidad.act_criticidad_nivel);   // componentes agregados en la ficha
                avisoImg += GuardarVariables(ActivoId);                      // que se mide (bloque 345)
                avisoImg += GuardarMedidores(ActivoId);                      // que cuenta (bloque 345)

                /* Alta en el modal: se recarga la ficha ya guardada con la
                   confirmacion y el proximo paso sugerido. Si la foto fallo, se
                   avisa como antes para que el aviso no se pierda en el viaje. */
                if (eraNuevo && !EnCentro && avisoImg == "")
                {
                    Response.Redirect(Request.Path + "?query=" +
                        Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + ActivoId + "&Creado=1")), false);
                    Context.ApplicationInstance.CompleteRequest();
                    return;
                }

                /* En el modal el tercer parametro cierra la ventana y refresca
                   el listado de atras. En el centro no hay ventana que cerrar:
                   cerrarla dejaria al usuario mirando otra pantalla. */
                Tools.tools.ClientAlert(respuesta.detalle + avisoImg, "ok", !EnCentro);

                if (EnCentro && Guardado != null) Guardado(this, EventArgs.Empty);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Sube la imagen elegida (si la hay) y la deja como imagen del activo.
    /// Devuelve "" si todo fue bien o no había imagen, o un aviso si falló la
    /// carga —sin echar abajo el guardado del activo, que ya está hecho—.
    /// </summary>
    private string GuardarImagen(int activo)
    {
        if (activo <= 0) return "";

        bool haySubida = fuImagen != null && fuImagen.HasFile;

        // Sin imagen nueva: si marcó "quitar la imagen actual", se desvincula.
        if (!haySubida)
        {
            if (chkQuitarImagen != null && chkQuitarImagen.Checked)
                new ActivoImagenController().DesvincularImagen(activo);
            return "";
        }

        try
        {
            byte[] contenido = fuImagen.FileBytes;
            if (contenido == null || contenido.Length == 0) return "";

            Archivo arc = new Archivo();
            arc.arc_cliente = SitioBase.Session.ClienteId();
            arc.arc_archivo_categoria = 10;   // REFERENCIA (imagen de referencia)
            arc.arc_nombre_original = System.IO.Path.GetFileName(fuImagen.FileName);
            arc.arc_mime = fuImagen.PostedFile != null ? fuImagen.PostedFile.ContentType : null;
            arc.contenido = contenido;

            Respuesta r = new ArchivoController().InsertArchivo(arc, "activos");
            if (r.error || r.codigo <= 0)
                return " (la imagen no se pudo guardar: " + r.detalle + ")";

            int vin = new ActivoImagenController().VincularImagen(activo, r.codigo);
            if (vin < 0)
                return " (la imagen se subió pero no se pudo enlazar al activo)";

            return "";
        }
        catch (Exception ex)
        {
            return " (la imagen no se pudo guardar: " + ex.Message + ")";
        }
    }
}
