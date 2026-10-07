using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un componente de activo (HU-036). La escritura la habilita
/// Token.Puede("CREAR EDITAR COMPONENTES"). Va directo en un activo o
/// subactivo, o dentro de otro componente; al editar no cambia de activo.
/// </summary>
public partial class View_Activos_Componentes_ActivoComponente : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// El activo ya viene decidido: la ficha se abrió desde el centro de ESE
    /// equipo. Entonces el combo no se ofrece, se fija. Pedirle a alguien que
    /// elija de una lista de cuarenta el equipo que acaba de abrir es una
    /// pregunta que ya tiene respuesta, y una oportunidad de equivocarse.
    /// </summary>
    public int ActivoFijo
    {
        get { return ViewState["ActivoFijo"] != null ? (int)ViewState["ActivoFijo"] : 0; }
        set { ViewState["ActivoFijo"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            ActivoFijo = SitioBase.Querystring.Entero(Request.QueryString["query"], "Activo");
            Precargar();
        }
    }

    /* ================================================================
       ABRIR RAPIDO (05-10-2026)

       La base esta en un hosting remoto: cada consulta es una ida y vuelta
       de ~250 ms. La ficha hacia ~14 en fila (activos, cinco combos, el
       componente, su placa, su imagen, su historial y sus posibles padres):
       3,5 a 4 s con el esqueleto en pantalla. Son independientes, asi que
       se piden EN PARALELO en dos tandas (todo lo que no depende de nada, y
       despues los padres, que dependen del activo) y la ficha queda en
       ~0,6 s. Cada hilo recibe el HttpContext de la peticion para que
       Session y Token respondan igual que en el hilo de la pagina.
       ================================================================ */
    private List<Activo> _activos;
    private List<ComponenteTipo> _tipos;
    private List<ActivoComponenteEstado> _estados;
    private List<CriticidadNivel> _criticidades;
    private List<ComponentePosicion> _posiciones;
    private List<FabricanteController.Fabricante> _marcas;
    private ActivoComponente _comp, _placa;
    private int _imagen;
    private List<ActivoComponenteEstadoHistorial> _historial;
    private List<ActivoComponente> _componentes;
    private bool _precargado;

    private static System.Threading.Tasks.Task<T> EnParalelo<T>(System.Web.HttpContext ctx, Func<T> f)
    {
        return System.Threading.Tasks.Task.Run(() =>
        {
            System.Web.HttpContext.Current = ctx;
            try { return f(); }
            finally { System.Web.HttpContext.Current = null; }
        });
    }

    private void Precargar()
    {
        try
        {
            System.Web.HttpContext ctx = System.Web.HttpContext.Current;
            int cliente = SitioBase.Session.ClienteId();

            var tActivos = EnParalelo(ctx, () => new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true }));
            var tTipos = EnParalelo(ctx, () => new ComponenteTipoController().GetTipos(new ComponenteTipo { filtro_cliente = cliente, filtro_habilitado = true }));
            var tEstados = EnParalelo(ctx, () => new ActivoComponenteEstadoController().GetEstados(new ActivoComponenteEstado { filtro_habilitado = true }));
            var tCrit = EnParalelo(ctx, () => new CriticidadNivelController().GetCriticidadNiveles(new CriticidadNivel { filtro_habilitado = true }));
            var tPos = EnParalelo(ctx, () => new ComponentePosicionController().GetPosiciones(new ComponentePosicion { filtro_cliente = cliente, filtro_habilitado = true }));
            var tMarcas = EnParalelo(ctx, () => new FabricanteController().Catalogo());
            // los componentes del cliente: de ellos sale "de que es parte" (activo, subactivo o componente)
            var tComps = EnParalelo(ctx, () => new ActivoComponenteController().GetComponentes(new ActivoComponente { aco_cliente = cliente, filtro_habilitado = true }));
            System.Threading.Tasks.Task<ActivoComponente> tComp = null, tPlaca = null;
            System.Threading.Tasks.Task<int> tImg = null;
            System.Threading.Tasks.Task<List<ActivoComponenteEstadoHistorial>> tHist = null;
            if (Id > 0)
            {
                tComp = EnParalelo(ctx, () => new ActivoComponenteController().GetComponente(Id));
                tPlaca = EnParalelo(ctx, () => new ActivoComponenteController().GetPlaca(Id, cliente));
                tImg = EnParalelo(ctx, () => new ActivoComponenteImagenController().GetImagenId(Id, cliente));
                tHist = EnParalelo(ctx, () => new ActivoComponenteController().GetHistorialEstado(Id, cliente));
            }
            // el prefijo del codigo: queda en el cache del sitio (CodigoModulo)
            var tPrefijo = EnParalelo(ctx, () => SitioBase.CodigoModulo.Prefijo("Activo_Componente"));

            /* Mientras la primera tanda viaja, el hilo de la pagina lee los
               permisos: es la consulta que despues usa la maestra para validar
               la pagina (Token.ExigirPagina). Antes iba sola y en fila, antes
               de lanzar la tanda. Se lee aca y no en una tarea porque se guarda
               en HttpContext.Items, que no es seguro entre hilos; ningun
               controller de la tanda consulta permisos. */
            Token.Permisos();

            _activos = tActivos.Result; _tipos = tTipos.Result; _estados = tEstados.Result; _criticidades = tCrit.Result;
            _posiciones = tPos.Result; _marcas = tMarcas.Result; tPrefijo.Wait();
            if (Id > 0) { _comp = tComp.Result; _placa = tPlaca.Result; _imagen = tImg.Result; _historial = tHist.Result; }
            _componentes = tComps.Result;
            _precargado = true;
        }
        catch (Exception)
        {
            /* Si algo falla en paralelo, la ficha sigue como antes: cada parte
               se pide en el hilo de la pagina. */
            _precargado = false;
            _comp = null; _componentes = null;
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboEstado":
                {
                    ActivoComponenteEstadoController c = new ActivoComponenteEstadoController();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = _precargado ? _estados : c.GetEstados(new ActivoComponenteEstado { filtro_habilitado = true });
                    ctrl.DataValueField = "ace_id"; ctrl.DataTextField = "ace_nombre"; ctrl.DataBind();
                    break;
                }
            case "cboCriticidad":
                {
                    CriticidadNivelController c = new CriticidadNivelController();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = _precargado ? _criticidades : c.GetCriticidadNiveles(new CriticidadNivel { filtro_habilitado = true });
                    ctrl.DataValueField = "crn_id"; ctrl.DataTextField = "crn_nombre"; ctrl.DataBind();
                    break;
                }
        }
    }

    /* ================================================================
       ¿DE QUE ES PARTE? (06-10-2026)

       Antes eran dos campos: el activo (fijo si se abria desde su centro) y
       "va dentro de otra parte", que solo ofrecia componentes de ESE activo.
       Ahora es uno: el activo, sus subactivos y los componentes de todos
       ellos, en orden de arbol. "a:<id>" lo deja directo en ese activo o
       subactivo; "c:<id>" lo pone dentro de ese componente, en el activo de
       ese componente (el SP exige que el padre sea del mismo activo).
       Al editar no cambia de activo: se ofrecen ese activo y sus
       componentes, sin el propio ni los que cuelgan de el.
       ================================================================ */
    private class Parte
    {
        public string id, n, sub, tipo = "a";
        public int activo, componente, nivel;
    }

    private List<Parte> _partes;

    private List<Activo> Activos()
    {
        if (_activos == null)
            _activos = new ActivoController().GetActivos(new Activo { act_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true }) ?? new List<Activo>();
        return _activos;
    }

    private List<ActivoComponente> Componentes()
    {
        if (_componentes == null)
            _componentes = new ActivoComponenteController().GetComponentes(new ActivoComponente { aco_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true }) ?? new List<ActivoComponente>();
        return _componentes;
    }

    private ActivoComponente Editado()
    {
        if (Id <= 0) return null;
        if (_comp == null) _comp = new ActivoComponenteController().GetComponente(Id);
        return _comp;
    }

    private List<Parte> Partes()
    {
        if (_partes != null) return _partes;
        _partes = new List<Parte>();
        List<Activo> activos = Activos();
        List<ActivoComponente> comps = Componentes();

        /* Al editar no se ofrece el propio componente ni lo que cuelga de el:
           quedaria dentro de si mismo. */
        HashSet<int> fuera = new HashSet<int>();
        ActivoComponente ed = Editado();
        if (ed != null)
        {
            fuera.Add(ed.aco_id);
            bool crecio = true;
            while (crecio)
            {
                crecio = false;
                foreach (ActivoComponente k in comps)
                    if (k.aco_componente_padre != null && fuera.Contains(k.aco_componente_padre.Value) && fuera.Add(k.aco_id)) crecio = true;
            }
        }

        Action<Activo, string, bool> agregar = null;
        agregar = (a, padre, conSubactivos) =>
        {
            _partes.Add(new Parte { id = "a:" + a.act_id, n = a.act_nombre + " · " + a.act_codigo,
                                    sub = padre == null ? "Directo en el activo" : "Subactivo de " + padre, activo = a.act_id,
                                    tipo = padre == null ? "a" : "s", nivel = padre == null ? 0 : 1 });
            List<ActivoComponente> suyos = comps.FindAll(k => k.aco_activo == a.act_id && !fuera.Contains(k.aco_id));
            suyos.Sort((x, y) => string.Compare(x.aco_nombre, y.aco_nombre, StringComparison.CurrentCultureIgnoreCase));
            foreach (ActivoComponente k in suyos)
                _partes.Add(new Parte { id = "c:" + k.aco_id, n = k.aco_nombre + " · " + k.aco_codigo,
                                        sub = "Componente de " + a.act_nombre, activo = a.act_id, componente = k.aco_id,
                                        tipo = "c", nivel = (padre == null ? 0 : 1) + 1 });
            if (!conSubactivos) return;
            foreach (Activo hijo in activos.FindAll(h => h.act_activo_padre == a.act_id))
                agregar(hijo, a.act_nombre, true);
        };

        if (ed != null)
        {
            Activo a = activos.Find(x => x.act_id == ed.aco_activo) ?? new ActivoController().GetActivo(ed.aco_activo);
            if (a != null) agregar(a, null, false);
        }
        else if (ActivoFijo > 0)
        {
            Activo a = activos.Find(x => x.act_id == ActivoFijo) ?? new ActivoController().GetActivo(ActivoFijo);
            if (a != null && a.act_cliente == SitioBase.Session.ClienteId()) agregar(a, null, true);
        }
        else
        {
            HashSet<int> ids = new HashSet<int>(activos.ConvertAll(x => x.act_id));
            foreach (Activo a in activos)
                if (a.act_activo_padre == null || !ids.Contains(a.act_activo_padre.Value)) agregar(a, null, true);
        }
        return _partes;
    }

    /// <summary>Las opciones de "de que es parte", como arreglo JS para SigmaCombo.</summary>
    public string PartesJson()
    {
        List<object> l = new List<object>();
        try
        {
            foreach (Parte x in Partes())
                l.Add(new Dictionary<string, object> { { "id", x.id }, { "n", x.n }, { "sub", x.sub },
                    { "tag", new Dictionary<string, object> { { "k", x.tipo }, { "t", x.tipo == "a" ? "Activo" : x.tipo == "s" ? "Subactivo" : "Componente" } } },
                    { "nivel", x.nivel } });
        }
        catch (Exception) { }
        /* Va dentro de un <script>: "</" se corta para que un nombre no cierre la etiqueta. */
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(l).Replace("</", "<\\/");
    }

    /* Las listas de los combos libres (tipo, donde va, marca y sus modelos), como JSON para el <script>. */
    private static string EnScript(object o)
    {
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(o).Replace("</", "<\\/");
    }
    public string TiposJson()
    {
        List<string> l = new List<string>();
        try
        {
            foreach (ComponenteTipo t in _precargado ? _tipos : new ComponenteTipoController().GetTipos(new ComponenteTipo { filtro_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true }) ?? new List<ComponenteTipo>())
                l.Add(t.cto_nombre);
        }
        catch (Exception) { }
        return EnScript(l);
    }
    public string LadosJson()
    {
        List<string> l = new List<string>();
        try
        {
            foreach (ComponentePosicion p in _precargado ? _posiciones : new ComponentePosicionController().GetPosiciones(new ComponentePosicion { filtro_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true }) ?? new List<ComponentePosicion>())
                l.Add(p.cpn_nombre);
        }
        catch (Exception) { }
        return EnScript(l);
    }
    public string MarcasJson()
    {
        List<object> l = new List<object>();
        try
        {
            foreach (FabricanteController.Fabricante f in (_precargado ? _marcas : new FabricanteController().Catalogo()) ?? new List<FabricanteController.Fabricante>())
                l.Add(new Dictionary<string, object> { { "n", f.nombre }, { "m", f.modelos ?? new List<string>() } });
        }
        catch (Exception) { }
        return EnScript(l);
    }

    private void FijarParte(string id)
    {
        Parte x = Partes().Find(o => o.id == id);
        if (x == null) return;
        hdnParte.Value = x.id; txtParte.Text = x.n;
    }

    /// <summary>El estado con que se abrio la ficha: si cambia, se pide el motivo.</summary>
    protected string EstadoOriginal
    {
        get { return ViewState["EstadoOriginal"] as string ?? ""; }
        set { ViewState["EstadoOriginal"] = value; }
    }

    /// <summary>La url de una hoja o un script con la fecha del archivo como version.</summary>
    protected string Asset(string ruta)
    {
        string f = Server.MapPath(ruta);
        return ResolveUrl(ruta) + "?v=" + (System.IO.File.Exists(f) ? System.IO.File.GetLastWriteTimeUtc(f).Ticks.ToString() : "1");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* Al crear, Siguiente manda hasta el ultimo paso (lo hace el JS con
           af-es-nuevo); al editar, Guardar es lo principal. */
        pnlForm.CssClass = "af af-modal" + (Id == 0 ? " af-es-nuevo" : "");
        btnGuardar.Text = Id > 0 ? "Guardar cambios" : "Guardar componente";
        CargarDatos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ActivoComponenteController c = new ActivoComponenteController();
            ActivoComponente x = _precargado && _comp != null ? _comp : c.GetComponente(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Activo_Componente", x.aco_codigo);
            txtNombre.Text = x.aco_nombre;
            txtDescripcion.Text = x.aco_descripcion;
            calInstalacion.Value = x.aco_fecha_instalacion;

            FijarParte(x.aco_componente_padre != null ? "c:" + x.aco_componente_padre.Value : "a:" + x.aco_activo);
            txtTipo.Text = x.tipo_nombre;
            SeleccionarCombo(cboEstado, x.aco_activo_componente_estado);
            EstadoOriginal = x.aco_activo_componente_estado.ToString();
            SeleccionarCombo(cboCriticidad, x.aco_criticidad_nivel);
            if (x.aco_componente_posicion != null) txtPosicion.Text = x.posicion_nombre;

            rdbSi.Checked = x.aco_habilitado;
            rdbNo.Checked = !x.aco_habilitado;

            /* La placa se lee con su propio SP: el SEL del componente lo
               comparte la app y no trae estas tres columnas. */
            ActivoComponente placa = _precargado && _placa != null ? _placa : c.GetPlaca(Id, SitioBase.Session.ClienteId());
            txtNumeroSerie.Text = placa.aco_numero_serie;
            txtMarca.Text = placa.aco_fabricante;
            txtModelo.Text = placa.aco_modelo;

            /* Quien la creo y quien la toco por ultima vez, al lado de los pasos. */
            pnlSobre.Visible = true;
            litSobre.Text = Pie("mdi-account-plus-outline", "Creado", x.usuario_creacion_nombre, x.aco_fecha_creacion) +
                            Pie("mdi-clock-outline", "Último cambio", x.usuario_actualizacion_nombre, x.aco_fecha_actualizacion);

            /* La imagen vigente, si tiene. El id va cifrado en la url que la
               sirve: el archivo vive en Blob Storage, no en la pagina. */
            int idImagen = _precargado ? _imagen : new ActivoComponenteImagenController().GetImagenId(Id, SitioBase.Session.ClienteId());
            pnlSinImagen.Visible = idImagen <= 0;
            pnlImagenActual.Visible = idImagen > 0;
            pnlQuitarImagen.Visible = idImagen > 0;
            if (idImagen > 0) imgActual.Src = UrlArchivo.Ver(idImagen);

            // HU-036 #3: al editar se puede cambiar el estado (con motivo) y se ve la historia
            pnlMotivoEstado.Visible = true;
            pnlHistorialEstado.Visible = true;
            List<ActivoComponenteEstadoHistorial> historial = _precargado ? _historial : c.GetHistorialEstado(Id, SitioBase.Session.ClienteId());
            rptHistorialEstado.DataSource = historial;
            rptHistorialEstado.DataBind();
            lblSinHistorial.Visible = historial == null || historial.Count == 0;
        }
        else
        {
            lblId.Text = "Nuevo";
            calInstalacion.Value = global::SitioBase.Hora.Hoy;
            SeleccionarCombo(cboEstado, 1);   // una pieza que se registra normalmente esta operativa
            if (ActivoFijo > 0)
            {
                FijarParte("a:" + ActivoFijo);
                /* Hereda la criticidad de su activo: casi siempre es la misma. */
                Activo a = _precargado && _activos != null ? _activos.Find(x => x.act_id == ActivoFijo) : null;
                if (a == null) a = new ActivoController().GetActivo(ActivoFijo);
                if (a != null && a.act_cliente == SitioBase.Session.ClienteId()) SeleccionarCombo(cboCriticidad, a.act_criticidad_nivel);
            }
        }
    }

    private string Pie(string icono, string etiqueta, string usuario, DateTime? fecha)
    {
        if (fecha == null && string.IsNullOrEmpty(usuario)) return "";
        return "<span class=\"sg-a3-pie-dato\"><i class=\"mdi " + icono + "\"></i><span><b>" + Server.HtmlEncode(etiqueta) + "</b>" +
               Server.HtmlEncode(string.IsNullOrEmpty(usuario) ? "Sin dato" : usuario) +
               (fecha == null ? "" : " · " + fecha.Value.ToString("dd MMM yyyy HH:mm")) + "</span></span>";
    }

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
        if (t == "" || t == c.EmptyMessage || t == "Seleccione..." || t == "Sin indicar") return null;
        return t;
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
        bool puedeEditar = Token.Puede("CREAR EDITAR COMPONENTES");

        // Al editar las opciones son solo las de su activo (Partes): no cambia de activo.
        txtParte.ReadOnly = !puedeEditar;
        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Activo_Componente");
        txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtNumeroSerie.ReadOnly = !puedeEditar;
        txtMarca.ReadOnly = !puedeEditar;
        txtModelo.ReadOnly = !puedeEditar;
        calInstalacion.Enabled = puedeEditar;
        txtTipo.ReadOnly = !puedeEditar;
        cboEstado.ReadOnly = !puedeEditar;
        cboCriticidad.ReadOnly = !puedeEditar;
        txtPosicion.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* De que es parte: solo una de las opciones ofrecidas. */
            Parte parte = Partes().Find(o => o.id == hdnParte.Value);
            if (parte == null) throw new Exception("Elige el activo, subactivo o componente del que es parte.");
            /* "Que es" y "donde va" se eligen o se escriben: lo que no existe se
               crea como propio de la empresa (bloques 343 y 345). */
            string tipoTxt = (txtTipo.Text ?? "").Trim();
            if (tipoTxt == "") throw new Exception("Elige o escribe qué es el componente.");
            int tipoId = new ComponenteTipoController().ResolverPorNombre(tipoTxt);
            if (tipoId <= 0) throw new Exception("No se pudo guardar «" + tipoTxt + "» como tipo de componente.");
            string posicionTxt = (txtPosicion.Text ?? "").Trim();
            int posicionId = posicionTxt != "" ? new ComponentePosicionController().ResolverPorNombre(posicionTxt) : 0;
            if (string.IsNullOrEmpty(cboEstado.SelectedValue)) throw new Exception("Elige el estado del componente.");
            if (string.IsNullOrEmpty(cboCriticidad.SelectedValue)) throw new Exception("Elige la criticidad del componente.");

            ActivoComponente x = new ActivoComponente();
            ActivoComponenteController c = new ActivoComponenteController();

            x.aco_id = Id;
            x.aco_cliente = SitioBase.Session.ClienteId();
            x.aco_activo = parte.activo;
            x.aco_componente_tipo = tipoId;
            x.aco_activo_componente_estado = int.Parse(cboEstado.SelectedValue);
            x.aco_criticidad_nivel = int.Parse(cboCriticidad.SelectedValue);
            x.aco_codigo = SitioBase.CodigoModulo.Componer("Activo_Componente", txtCodigo.Text);   // COM-<id> lo genera el SP
            x.aco_nombre = txtNombre.Text.Trim();
            x.aco_habilitado = rdbSi.Checked;

            if (posicionId > 0) x.aco_componente_posicion = posicionId;
            if (parte.componente > 0) x.aco_componente_padre = parte.componente;
            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.aco_descripcion = txtDescripcion.Text.Trim();
            if (!string.IsNullOrEmpty(txtMotivoEstado.Text.Trim())) x.aco_motivo_estado = txtMotivoEstado.Text.Trim();

            if (calInstalacion.Value != null && calInstalacion.Value.Value.Date > global::SitioBase.Hora.Hoy)
                throw new Exception("La fecha de instalación no puede ser futura.");
            x.aco_fecha_instalacion = calInstalacion.Value;

            Respuesta r = (Id > 0) ? c.UpdateComponente(x) : c.InsertComponente(x);

            if (!r.error)
            {
                Id = r.codigo;

                /* La imagen va DESPUES del componente: al crear, el vinculo
                   necesita el id que acaba de devolver el SP. Un fallo aca no
                   anula lo guardado, solo avisa. */
                string avisoImagen = GuardarImagen(Id);

                /* La placa va DESPUES, por lo mismo que la imagen: al crear,
                   el UPDATE de las tres columnas necesita el id que acaba de
                   devolver el SP. Se guarda siempre, tambien vacia: dejar los
                   campos en blanco es una forma de corregir lo que estaba mal. */
                ActivoComponente placa = new ActivoComponente();
                placa.aco_id = Id;
                placa.aco_numero_serie = txtNumeroSerie.Text.Trim();
                placa.aco_fabricante = (txtMarca.Text ?? "").Trim();
                placa.aco_modelo = txtModelo.Text.Trim();
                Respuesta rp = c.GuardarPlaca(placa);

                string avisoPlaca = rp.error ? " La placa no se pudo guardar: " + rp.detalle : "";

                Tools.tools.ClientAlert(r.detalle + avisoImagen + avisoPlaca, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(r.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Sube la imagen elegida y la deja como LA imagen del componente. Un
    /// fallo aca no anula el guardado, que ya esta hecho: solo avisa.
    /// </summary>
    private string GuardarImagen(int componente)
    {
        if (componente <= 0) return "";

        bool haySubida = fuImagenComp != null && fuImagenComp.HasFile;

        if (!haySubida)
        {
            if (chkQuitarImagen != null && chkQuitarImagen.Checked)
                new ActivoComponenteImagenController().DesvincularImagen(componente);
            return "";
        }

        try
        {
            byte[] contenido = fuImagenComp.FileBytes;
            if (contenido == null || contenido.Length == 0) return "";

            Archivo arc = new Archivo();
            arc.arc_cliente = SitioBase.Session.ClienteId();
            arc.arc_archivo_categoria = 10;   // REFERENCIA
            arc.arc_nombre_original = System.IO.Path.GetFileName(fuImagenComp.FileName);
            arc.arc_mime = fuImagenComp.PostedFile != null ? fuImagenComp.PostedFile.ContentType : null;
            arc.contenido = contenido;

            ArchivoController.Alivianar(arc);   // la foto llega liviana al blob
            Respuesta r = new ArchivoController().InsertArchivo(arc, "activos");
            if (r.error || r.codigo <= 0)
                return " (la imagen no se pudo guardar: " + r.detalle + ")";

            if (new ActivoComponenteImagenController().VincularImagen(componente, r.codigo) < 0)
                return " (la imagen se subió pero no se pudo enlazar al componente)";

            return "";
        }
        catch (Exception ex)
        {
            return " (la imagen no se pudo guardar: " + ex.Message + ")";
        }
    }
}
