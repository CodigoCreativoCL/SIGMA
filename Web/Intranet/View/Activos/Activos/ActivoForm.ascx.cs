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
            ActivoId = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
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

                    ctrl.Items.Add(new RadComboBoxItem("Sin activo superior", ""));
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

        /* El centro las reparte en dos columnas -lo que se escribe a la
           izquierda, lo que se adjunta a la derecha-; el modal es angosto y
           las deja una debajo de otra. La diferencia es una clase. */
        pnlSecciones.CssClass = EnCentro ? "sg-a3-ficha-grid" : "";
        wucAuditoria.Visible = !EnCentro;

        CargarDatos();
        CargarModelos();   // depende del tipo ya seleccionado por CargarDatos
        // Las secciones nuevas van blindadas: si algo falla, no debe colgar ni
        // romper el modal del activo.
        try { CargarArchivos(); } catch { }        // documentos adjuntos
        try { CargarDatosTecnicos(); } catch { }   // valores de atributos (edición)
        Bloqueo();

        /* Guardar sube una imagen y unos PDF: un binario no sobrevive a un
           postback asincrono, asi que este boton recarga entero. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(EnCentro ? btnGuardarCentro : btnGuardar);
        udPanel.Update();
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
            }
        }

        // Datos nuevos (filas agregadas al vuelo): nombre + unidad + valor.
        // Se busca-o-crea el atributo en el tipo (aparece también en el catálogo).
        string[] noms = Request.Form.GetValues("nd_nombre");
        string[] unis = Request.Form.GetValues("nd_unidad");
        string[] vals = Request.Form.GetValues("nd_valor");
        if (noms != null)
            for (int i = 0; i < noms.Length; i++)
            {
                string nom = (noms[i] ?? "").Trim();
                if (nom == "") continue;   // la plantilla vacía y filas sin nombre se omiten
                int uni = 0; if (unis != null && i < unis.Length) int.TryParse(unis[i], out uni);
                string val = (vals != null && i < vals.Length) ? vals[i] : "";
                c.GrabarDato(activo, 0, nom, uni, val);
            }
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

    // Al elegir un modelo, se hereda su fabricante (el modelo manda la marca).
    protected void cboModelo_SelectedIndexChanged(object sender, EventArgs e)
    {
        int idModelo;
        if (int.TryParse(cboModelo.SelectedValue, out idModelo) && idModelo > 0)
        {
            ActivoModelo m = new ActivoModeloController().GetModelo(idModelo);
            if (m != null && !string.IsNullOrEmpty(m.amo_fabricante))
                txtFabricante.Text = m.amo_fabricante;
        }
    }

    /// <summary>
    /// Llena el combo de modelos con los del TIPO elegido (más los globales),
    /// preservando la selección entre postbacks. Sin tipo, el combo va vacío.
    /// </summary>
    protected void CargarModelos()
    {
        string sel = string.IsNullOrEmpty(_modeloEditar) ? cboModelo.SelectedValue : _modeloEditar;

        cboModelo.Items.Clear();
        cboModelo.Items.Add(new RadComboBoxItem("Sin modelo", ""));
        cboModelo.AppendDataBoundItems = true;

        int tipo;
        if (int.TryParse(cboTipo.SelectedValue, out tipo) && tipo > 0)
        {
            List<ActivoModelo> l = new ActivoModeloController().GetModelos(new ActivoModelo
            { filtro_cliente = SitioBase.Session.ClienteId(), filtro_activo_tipo = tipo, filtro_habilitado = true });
            if (l != null)
                foreach (ActivoModelo m in l)
                    cboModelo.Items.Add(new RadComboBoxItem(m.etiqueta, m.amo_id.ToString()));
        }

        RadComboBoxItem it = cboModelo.FindItemByValue(sel);
        if (it != null) it.Selected = true;
    }

    protected void CargarDatos()
    {
        if (IsPostBack && !_activoNuevo) return;

        if (ActivoId > 0)
        {
            ActivoController controller = new ActivoController();
            Activo entidad = controller.GetActivo(ActivoId);

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
            txtFabricante.Text = entidad.act_fabricante;
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
        if (item != null) item.Selected = true;
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
        txtFabricante.ReadOnly = !puedeEditar;
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
            if (string.IsNullOrEmpty(cboTipo.SelectedValue))
                throw new Exception("Debe elegir el tipo de activo.");
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
            entidad.act_activo_tipo = int.Parse(cboTipo.SelectedValue);
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

            if (!string.IsNullOrEmpty(cboModelo.SelectedValue))
                entidad.act_activo_modelo = int.Parse(cboModelo.SelectedValue);
            if (!string.IsNullOrEmpty(cboArea.SelectedValue))
                entidad.act_instalacion_area = int.Parse(cboArea.SelectedValue);
            if (!string.IsNullOrEmpty(cboCentroCosto.SelectedValue))
                entidad.act_centro_costo = int.Parse(cboCentroCosto.SelectedValue);
            if (!string.IsNullOrEmpty(cboPadre.SelectedValue))
                entidad.act_activo_padre = int.Parse(cboPadre.SelectedValue);

            if (!string.IsNullOrEmpty(txtSerie.Text.Trim()))
                entidad.act_numero_serie = txtSerie.Text.Trim();
            if (!string.IsNullOrEmpty(txtFabricante.Text.Trim()))
                entidad.act_fabricante = txtFabricante.Text.Trim();
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
                ActivoId = respuesta.codigo;

                // La imagen es opcional: si se eligió una, se sube y se enlaza
                // como imagen de referencia del activo. Un fallo aquí no anula
                // el guardado del activo; solo avisa.
                string avisoImg = GuardarImagen(ActivoId);
                GuardarArchivos(ActivoId);        // documentos adjuntos (opcional, varios)
                GuardarDatosTecnicos(ActivoId);   // valores de atributos técnicos

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
