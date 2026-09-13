using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// El plan de mantenimiento como centro de operaciones (HU-080, 081, 083).
///
/// UNA PANTALLA, TRES PESTAÑAS
///   Ficha (que es el plan), Hitos (que se le hace y cada cuanto) y Equipos
///   (a que maquinas). Tres pantallas sueltas obligaban a ir al menu tres
///   veces para armar un plan y a elegir el mismo plan tres veces. Ahora se
///   entra al plan y todo lo suyo esta aqui.
///
///   Va en Default.master, con el menu lateral a la vista, porque no es una
///   ficha que se abre un momento sobre un listado: es donde el planificador
///   trabaja. Las fichas de hito y de equipo si son modales: se abren un
///   segundo sobre esta pantalla y se vuelve a ella.
///
/// LAS PESTAÑAS QUE NO APLICAN SE OCULTAN ENTERAS
///   Un plan nuevo no tiene version todavia -la crea el SP al guardar-, asi
///   que no hay donde colgar hitos ni equipos. Se esconden las pestañas, no
///   se muestran vacias: una pestaña que al abrirla no tiene nada se lee
///   como que la pantalla se rompio.
///
/// LOS IDS NUNCA VIAJAN A LA VISTA
///   El querystring va cifrado, como en todo el sitio. Los modales reciben
///   «Id=<hito>&Plan=<este>» ya cifrado desde aqui.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanMantenimiento : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>Al editar el plan se guardo con tipo/modelo; para reseleccionar el modelo.</summary>
    private string _modeloEditar = null;

    /// <summary>Los querystring cifrados para «nuevo hito» y «nuevo equipo» de ESTE plan.</summary>
    protected string QueryNuevoHito { get { return Id > 0 ? Cifrar("Id=0&Plan=" + Id) : "0"; } }
    protected string QueryNuevoActivo { get { return Id > 0 ? Cifrar("Id=0&Plan=" + Id) : "0"; } }

    private string Cifrar(string texto) { return Server.UrlEncode(Tools.Crypto.Encrypt(texto)); }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["query"] != null)
            {
                string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

                foreach (string arr in query)
                {
                    string[] array = arr.ToString().Split('=');
                    switch (array[0].ToString())
                    {
                        case "Id":
                            Id = Int32.Parse(array[1].ToString());
                            break;
                    }
                }
            }

            GridHitos.AddSelectColumn();
            GridHitos.AddColumn("PMH_ID", "", Width: "3%");
            GridHitos.AddTemplateColumn("VERSION", "", "VERSIÓN", Width: "11%");
            GridHitos.AddColumn("PMH_ORDEN", "#", Width: "3%");
            GridHitos.AddColumn("PMH_CODIGO", "CÓDIGO", Width: "11%");
            GridHitos.AddColumn("PMH_NOMBRE", "HITO", Width: "24%");
            GridHitos.AddColumn("PROGRAMACION_NOMBRE", "CADA CUÁNTO", Width: "18%");
            GridHitos.AddTemplateColumn("MARCAS", "", "", Width: "12%");
            GridHitos.AddColumn("ACTIVIDADES", "ACTIV.", Width: "5%");
            GridHitos.AddCheckboxColumn("PMH_HABILITADO", "HABILITADO");

            GridActivos.AddSelectColumn();
            GridActivos.AddColumn("PAC_ID", "", Width: "3%");
            GridActivos.AddTemplateColumn("VERSION", "", "VERSIÓN", Width: "11%");
            GridActivos.AddColumn("ACTIVO_CODIGO", "CÓDIGO", Width: "10%");
            GridActivos.AddColumn("ACTIVO_NOMBRE", "EQUIPO", Width: "22%");
            GridActivos.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "11%");
            GridActivos.AddColumn("TIPO_NOMBRE", "TIPO", Width: "11%");
            GridActivos.AddColumn("COMPONENTE_NOMBRE", "COMPONENTE", Width: "15%");
            GridActivos.AddColumn("MEDIDOR_NOMBRE", "MEDIDOR", Width: "12%");

            GridCalendario.AddTemplateColumn("FECHA", "", "FECHA", Width: "11%");
            GridCalendario.AddColumn("HITO_CODIGO", "HITO", Width: "11%");
            GridCalendario.AddColumn("HITO_NOMBRE", "", Width: "20%");
            GridCalendario.AddColumn("ACTIVO_CODIGO", "EQUIPO", Width: "8%");
            GridCalendario.AddColumn("ACTIVO_NOMBRE", "", Width: "14%");
            GridCalendario.AddColumn("COMPONENTE_NOMBRE", "COMPONENTE", Width: "10%");
            GridCalendario.AddTemplateColumn("MARCAS", "", "", Width: "9%");
            GridCalendario.AddTemplateColumn("SITUACION", "", "SITUACIÓN", Width: "9%");
            GridCalendario.AddTemplateColumn("OT", "", "OT", Width: "8%");
        }

        Tools.tools.RegisterPostBackScript(GridHitos);
        Tools.tools.RegisterPostBackScript(GridActivos);
        Tools.tools.RegisterPostBackScript(GridCalendario);
    }

    #region Combos de la ficha

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        if (!(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboPlanta":
                {
                    ClienteInstalacion filtro = new ClienteInstalacion();
                    filtro.filtro_cliente = cliente.ToString();
                    filtro.filtro_habilitado = "1";

                    ctrl.Items.Add(new RadComboBoxItem("Cualquier planta", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(filtro);
                    ctrl.DataValueField = "cin_id";
                    ctrl.DataTextField = "cin_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboPlanificador":
                {
                    ClienteUsuario filtro = new ClienteUsuario();
                    filtro.ucl_id_cliente = cliente;
                    filtro.usu_habilitado = true;
                    // Cadenas vacias y no null: el controlador manda el
                    // parametro con `if (campo != "")`, y un null lo enviaria nulo.
                    filtro.id_perfiles = "";
                    filtro.filtro = "";

                    ctrl.Items.Add(new RadComboBoxItem("Sin planificador", ""));

                    List<ClienteUsuario> usuarios = new ClienteUsuarioController().GetClienteUsuarios(filtro);
                    if (usuarios != null)
                        foreach (ClienteUsuario u in usuarios)
                        {
                            string nombre = !string.IsNullOrEmpty(u.nombre_completo)
                                          ? u.nombre_completo.Trim()
                                          : (u.usu_nombres + " " + u.usu_apellido_paterno).Trim();
                            if (!string.IsNullOrEmpty(u.perfiles)) nombre += "  ·  " + u.perfiles;
                            ctrl.Items.Add(new RadComboBoxItem(nombre, u.usu_id.ToString()));
                        }
                    break;
                }

            case "cboTipo":
                {
                    List<ActivoTipo> lista = new ActivoTipoController().GetActivoTipos(
                        new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "ati_id";
                    ctrl.DataTextField = "ati_nombre";
                    ctrl.DataBind();
                    break;
                }
        }
    }

    protected void cboTipo_SelectedIndexChanged(object sender, EventArgs e) { }

    /// <summary>Modelos del tipo elegido, preservando la seleccion entre postbacks.</summary>
    protected void CargarModelos()
    {
        string sel = string.IsNullOrEmpty(_modeloEditar) ? cboModelo.SelectedValue : _modeloEditar;

        cboModelo.Items.Clear();
        cboModelo.Items.Add(new RadComboBoxItem("Cualquier modelo", ""));
        cboModelo.AppendDataBoundItems = true;

        int tipo;
        if (int.TryParse(cboTipo.SelectedValue, out tipo) && tipo > 0)
        {
            List<ActivoModelo> lista = new ActivoModeloController().GetModelos(new ActivoModelo
            { filtro_cliente = SitioBase.Session.ClienteId(), filtro_activo_tipo = tipo, filtro_habilitado = true });

            if (lista != null)
                foreach (ActivoModelo m in lista)
                    cboModelo.Items.Add(new RadComboBoxItem(m.etiqueta, m.amo_id.ToString()));
        }

        RadComboBoxItem it = cboModelo.FindItemByValue(sel ?? "");
        if (it != null) it.Selected = true;
    }

    #endregion

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarModelos();
        Bloqueo();

        bool conPlan = Id > 0;
        tabHitos.Visible = conPlan;
        tabEquipos.Visible = conPlan;
        tabCalendario.Visible = conPlan;

        if (conPlan)
        {
            // Los botones de las grillas dependen de la funcion de ESTA pagina.
            bool puedeEscribir = Token.PuedeFuncion("Crear y editar");
            if (!puedeEscribir)
            {
                GridHitos.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
                GridActivos.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
            }

            GridHitos.DataSource = new PlanHitoController().GetPlanHitos(
                new PlanHito { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id });
            GridHitos.DataBind();

            GridActivos.DataSource = new PlanActivoController().GetPlanActivos(
                new PlanActivo { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id });
            GridActivos.DataBind();

            ConfigurarFiltrosCalendario();
            CargarCalendario();
        }

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnVolver);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            PlanMantenimiento entidad = new PlanMantenimientoController().GetPlanMantenimiento(new PlanMantenimiento { pma_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Plan_Mantenimiento", entidad.pma_codigo);
            txtNombre.Text = entidad.pma_nombre;
            txtDescripcion.Text = entidad.pma_descripcion;

            if (entidad.pma_cliente_instalacion != null) Seleccionar(cboPlanta, entidad.pma_cliente_instalacion.Value.ToString());
            if (entidad.pma_usuario_planificador != null) Seleccionar(cboPlanificador, entidad.pma_usuario_planificador.Value.ToString());
            if (entidad.pma_activo_tipo != null) Seleccionar(cboTipo, entidad.pma_activo_tipo.Value.ToString());
            if (entidad.pma_activo_modelo != null) _modeloEditar = entidad.pma_activo_modelo.Value.ToString();

            rdbSi.Checked = entidad.pma_habilitado;
            rdbNo.Checked = !entidad.pma_habilitado;

            litVersion.Text = TextoVersion(entidad);
            litTitulo.Text = Server.HtmlEncode(entidad.pma_codigo + " · " + entidad.pma_nombre);
            litSubtitulo.Text = Server.HtmlEncode(Resumen(entidad));

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.pma_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.pma_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
            litTitulo.Text = "Nuevo plan de mantenimiento";
            litSubtitulo.Text = "Guarde la ficha y aparecerán las pestañas de hitos y equipos.";
            litVersion.Text = "<span class=\"sigma-modal-ayuda\">Se crea la versión 1 en borrador al guardar.</span>";
        }
    }

    private string TextoVersion(PlanMantenimiento p)
    {
        if (p.version_numero == null) return "Sin versión";
        string estado = string.IsNullOrEmpty(p.version_estado_nombre) ? "Borrador" : p.version_estado_nombre;
        return "<strong>v" + p.version_numero + "</strong> · " + Server.HtmlEncode(estado)
             + " · " + p.hitos + (p.hitos == 1 ? " hito" : " hitos")
             + " · " + p.activos + (p.activos == 1 ? " equipo" : " equipos");
    }

    /// <summary>La frase del subtitulo: alcance y estado, para leer sin abrir nada.</summary>
    private string Resumen(PlanMantenimiento p)
    {
        List<string> partes = new List<string>();
        partes.Add(string.IsNullOrEmpty(p.planta_nombre) ? "Cualquier planta" : p.planta_nombre);
        partes.Add(string.IsNullOrEmpty(p.tipo_nombre) ? "cualquier tipo de equipo" : p.tipo_nombre);
        if (!string.IsNullOrEmpty(p.modelo_nombre)) partes.Add(p.modelo_nombre);
        if (p.version_numero != null)
            partes.Add("v" + p.version_numero + " " + (p.version_estado_nombre ?? "").ToLower());
        return string.Join(" · ", partes.ToArray());
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO");

        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Plan_Mantenimiento");
        txtCodigo.ReadOnly = Id > 0;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboPlanificador.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        cboModelo.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/View/Mantenimiento/Planes/PlanMantenimientos.aspx");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            PlanMantenimiento entidad = new PlanMantenimiento();
            PlanMantenimientoController controller = new PlanMantenimientoController();

            entidad.pma_id = Id;
            entidad.pma_cliente = SitioBase.Session.ClienteId();
            entidad.pma_codigo = SitioBase.CodigoModulo.Componer("Plan_Mantenimiento", txtCodigo.Text);
            entidad.pma_nombre = txtNombre.Text.Trim();
            entidad.pma_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            entidad.pma_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue)) entidad.pma_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            else entidad.quita_instalacion = true;

            if (!string.IsNullOrEmpty(cboPlanificador.SelectedValue)) entidad.pma_usuario_planificador = int.Parse(cboPlanificador.SelectedValue);
            else entidad.quita_planificador = true;

            if (!string.IsNullOrEmpty(cboTipo.SelectedValue)) entidad.pma_activo_tipo = int.Parse(cboTipo.SelectedValue);
            else entidad.quita_tipo = true;

            if (!string.IsNullOrEmpty(cboModelo.SelectedValue)) entidad.pma_activo_modelo = int.Parse(cboModelo.SelectedValue);
            else entidad.quita_modelo = true;

            bool nuevo = Id == 0;
            Respuesta respuesta = nuevo
                ? controller.InsertPlanMantenimiento(entidad)
                : controller.UpdatePlanMantenimiento(entidad);

            if (!respuesta.error)
            {
                /* Al crear, se vuelve a entrar al centro con el id nuevo: asi
                   aparecen las pestañas de hitos y equipos y la barra con el
                   nombre del plan, sin pedirle a la persona que vuelva al
                   listado y lo busque. */
                if (nuevo)
                    Response.Redirect("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx?query=" + Cifrar("Id=" + respuesta.codigo));

                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    #region Hitos

    protected void GridHitos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanHito hito = item.DataItem as PlanHito;
        if (hito == null) return;

        string id = item.GetDataKeyValue("pmh_id").ToString();
        string query = Cifrar("Id=" + id + "&Plan=" + Id);

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditarHito" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirPlanHito('" + query + "')");
        item["pmh_id"].Controls.Add(Editar);

        if (!string.IsNullOrEmpty(hito.programacion_tipo_nombre))
            item["PROGRAMACION_NOMBRE"].Text = Server.HtmlEncode(hito.programacion_nombre)
                + "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(hito.programacion_tipo_nombre) + "</span>";

        item["VERSION"].Controls.Add(new Literal { Text = ChipVersion(hito.version_numero, hito.version_estado_codigo) });

        string marcas = "";
        if (hito.pmh_requiere_parada)
            marcas += "<span class=\"grid-estado-chip is-alerta\" title=\"Requiere parada del equipo\"><i class=\"mdi mdi-power\"></i>Parada</span> ";
        if (hito.pmh_es_overhaul)
            marcas += "<span class=\"grid-estado-chip is-advertencia\" title=\"Overhaul: intervención mayor\"><i class=\"mdi mdi-wrench\"></i>Overhaul</span>";
        item["MARCAS"].Controls.Add(new Literal { Text = marcas });
    }

    protected void lnkEliminarHito_Click(object sender, EventArgs e)
    {
        Pestana(tabHitos, pvHitos);
        Eliminar(GridHitos, "pmh_id", id => new PlanHitoController().DeletePlanHito(new PlanHito { pmh_id = id }));
    }

    #endregion

    #region Equipos

    protected void GridActivos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanActivo v = item.DataItem as PlanActivo;
        if (v == null) return;

        string id = item.GetDataKeyValue("pac_id").ToString();
        string query = Cifrar("Id=" + id + "&Plan=" + Id);

        HyperLink Editar = new HyperLink();
        Editar.ID = "lnkEditarActivo" + id;
        Editar.CssClass = "icono_Editar";
        Editar.NavigateUrl = "javascript:void(0)";
        Editar.Attributes.Add("onclick", "abrirPlanActivo('" + query + "')");
        item["pac_id"].Controls.Add(Editar);

        if (string.IsNullOrEmpty(v.componente_nombre))
            item["COMPONENTE_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">equipo completo</span>";
        if (string.IsNullOrEmpty(v.medidor_nombre))
            item["MEDIDOR_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">—</span>";

        item["VERSION"].Controls.Add(new Literal { Text = ChipVersion(v.version_numero, v.version_estado_codigo) });
    }

    protected void lnkEliminarActivo_Click(object sender, EventArgs e)
    {
        Pestana(tabEquipos, pvEquipos);
        Eliminar(GridActivos, "pac_id", id => new PlanActivoController().DeletePlanActivo(new PlanActivo { pac_id = id }));
    }

    #endregion

    #region Calendario (HU-085)

    /// <summary>
    /// Los combos del calendario se arman una vez. El año en curso y «todo
    /// el año» son el arranque: es la pregunta de la historia, «que le toca
    /// a la planta este año».
    /// </summary>
    private void ConfigurarFiltrosCalendario()
    {
        if (IsPostBack) return;

        int anio = DateTime.Now.Year;
        for (int a = anio - 1; a <= anio + 2; a++)
            cboAnio.Items.Add(new RadComboBoxItem(a.ToString(), a.ToString()) { Selected = a == anio });

        cboMes.Items.Add(new RadComboBoxItem("Todo el año", ""));
        string[] meses = { "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre" };
        for (int m = 1; m <= 12; m++) cboMes.Items.Add(new RadComboBoxItem(meses[m - 1], m.ToString()));

        // Solo los equipos de este plan: elegir uno de otra planta daria una
        // lista vacia sin explicar por que.
        cboActivoCal.Items.Add(new RadComboBoxItem("Todos los equipos", ""));
        List<PlanActivo> activos = new PlanActivoController().GetPlanActivos(
            new PlanActivo { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id });
        if (activos != null)
        {
            HashSet<int> vistos = new HashSet<int>();
            foreach (PlanActivo a in activos)
                if (vistos.Add(a.pac_activo))
                    cboActivoCal.Items.Add(new RadComboBoxItem(a.activo_codigo + " — " + a.activo_nombre, a.pac_activo.ToString()));
        }

        // Plan_Ocurrencia_Estado es un catalogo fijo del bloque 14 (BD/14_PLANES).
        cboEstadoCal.Items.Add(new RadComboBoxItem("Cualquier estado", ""));
        cboEstadoCal.Items.Add(new RadComboBoxItem("Pendiente", "1"));
        cboEstadoCal.Items.Add(new RadComboBoxItem("Disponible", "2"));
        cboEstadoCal.Items.Add(new RadComboBoxItem("En ejecución", "3"));
        cboEstadoCal.Items.Add(new RadComboBoxItem("Completada", "4"));
        cboEstadoCal.Items.Add(new RadComboBoxItem("Omitida", "5"));
        cboEstadoCal.Items.Add(new RadComboBoxItem("Cancelada", "6"));
        cboEstadoCal.Items.Add(new RadComboBoxItem("Reprogramada", "7"));
    }

    /// <summary>El mismo filtro para la grilla y para la descarga.</summary>
    private PlanOcurrencia FiltroCalendario()
    {
        PlanOcurrencia f = new PlanOcurrencia { filtro_plan = Id };

        int anio, mes;
        if (!int.TryParse(cboAnio.SelectedValue, out anio) || anio < 2000) anio = DateTime.Now.Year;
        int.TryParse(cboMes.SelectedValue, out mes);

        if (mes >= 1 && mes <= 12)
        {
            f.filtro_desde = new DateTime(anio, mes, 1);
            f.filtro_hasta = f.filtro_desde.Value.AddMonths(1).AddDays(-1);
        }
        else
        {
            f.filtro_desde = new DateTime(anio, 1, 1);
            f.filtro_hasta = new DateTime(anio, 12, 31);
        }

        int activo, estado;
        if (int.TryParse(cboActivoCal.SelectedValue, out activo) && activo > 0) f.filtro_activo = activo;
        if (int.TryParse(cboEstadoCal.SelectedValue, out estado) && estado > 0) f.filtro_estado = estado;

        return f;
    }

    private void CargarCalendario()
    {
        List<PlanOcurrencia> lista = new PlanOcurrenciaController().GetCalendario(FiltroCalendario()) ?? new List<PlanOcurrencia>();

        GridCalendario.DataSource = lista;
        GridCalendario.DataBind();

        // El boton de descarga es un postback completo: entrega un archivo.
        foreach (GridItem it in GridCalendario.MasterTableView.GetItems(GridItemType.CommandItem))
        {
            Control lnk = it.FindControl("lnkDescargarCal");
            if (lnk != null) ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnk);
        }

        litResumenCal.Text = ResumenCalendario(lista);
    }

    /// <summary>
    /// Una linea con los totales por situacion, para leer el año sin
    /// recorrer la grilla: «28 ocurrencias · 18 cerradas · 2 vencidas · …».
    /// </summary>
    private string ResumenCalendario(List<PlanOcurrencia> lista)
    {
        if (lista.Count == 0)
            return "<span class=\"sigma-inv-vacio\">Sin ocurrencias en el período. Se generan al publicar la versión.</span>";

        int cerradas = 0, vencidas = 0, atrasadas = 0, disponibles = 0, futuras = 0;
        foreach (PlanOcurrencia o in lista)
            switch (o.situacion)
            {
                case "CERRADA": cerradas++; break;
                case "VENCIDA": vencidas++; break;
                case "ATRASADA": atrasadas++; break;
                case "DISPONIBLE": disponibles++; break;
                default: futuras++; break;
            }

        string r = "<strong>" + lista.Count + "</strong> " + (lista.Count == 1 ? "ocurrencia" : "ocurrencias");
        if (cerradas > 0)    r += " · " + ChipSituacion("CERRADA", cerradas + " cerradas");
        if (vencidas > 0)    r += " · " + ChipSituacion("VENCIDA", vencidas + " vencidas");
        if (atrasadas > 0)   r += " · " + ChipSituacion("ATRASADA", atrasadas + " atrasadas");
        if (disponibles > 0) r += " · " + ChipSituacion("DISPONIBLE", disponibles + " disponibles");
        if (futuras > 0)     r += " · " + ChipSituacion("FUTURA", futuras + " futuras");
        return r;
    }

    protected void GridCalendario_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanOcurrencia o = item.DataItem as PlanOcurrencia;
        if (o == null) return;

        string[] dias = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" };
        string fecha = "<strong>" + o.fecha_programada.ToString("dd-MM-yyyy") + "</strong> <span class=\"sigma-inv-vacio\">" + dias[(int)o.fecha_programada.DayOfWeek] + "</span>";
        if (o.fue_reprogramada) fecha += " <i class=\"mdi mdi-calendar-refresh\" title=\"Reprogramada\"></i>";
        item["FECHA"].Controls.Add(new Literal { Text = fecha });

        if (string.IsNullOrEmpty(o.componente_nombre))
            item["COMPONENTE_NOMBRE"].Text = "<span class=\"sigma-inv-vacio\">equipo completo</span>";

        string marcas = "";
        if (o.requiere_parada) marcas += "<span class=\"grid-estado-chip is-alerta\" title=\"Requiere parada\"><i class=\"mdi mdi-power\"></i>Parada</span> ";
        if (o.es_overhaul) marcas += "<span class=\"grid-estado-chip is-advertencia\" title=\"Overhaul\"><i class=\"mdi mdi-wrench\"></i>Overhaul</span>";
        item["MARCAS"].Controls.Add(new Literal { Text = marcas });

        string situacion = o.situacion == "CERRADA" ? ChipSituacion("CERRADA", o.estado_nombre) : ChipSituacion(o.situacion, null);
        if (o.situacion != "CERRADA" && o.fecha_limite != null)
            situacion += "<br/><span class=\"sigma-inv-vacio\">límite " + o.fecha_limite.Value.ToString("dd-MM") + "</span>";
        item["SITUACION"].Controls.Add(new Literal { Text = situacion });

        item["OT"].Controls.Add(new Literal
        {
            Text = o.orden_trabajo_correlativo != null
                 ? "<span title=\"" + Server.HtmlEncode(o.orden_trabajo_titulo ?? "") + "\">OT-" + o.orden_trabajo_correlativo + "</span>"
                 : "<span class=\"sigma-inv-vacio\">—</span>"
        });
    }

    private static string ChipSituacion(string situacion, string texto)
    {
        switch (situacion)
        {
            case "CERRADA":    return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-check\"></i>" + (texto ?? "Cerrada") + "</span>";
            case "VENCIDA":    return "<span class=\"grid-estado-chip is-alerta\"><i class=\"mdi mdi-alert-circle-outline\"></i>" + (texto ?? "Vencida") + "</span>";
            case "ATRASADA":   return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-clock-alert-outline\"></i>" + (texto ?? "Atrasada") + "</span>";
            case "DISPONIBLE": return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-play-circle-outline\"></i>" + (texto ?? "Disponible") + "</span>";
            default:           return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-calendar-blank-outline\"></i>" + (texto ?? "Futura") + "</span>";
        }
    }

    /// <summary>Page_PreRender recarga con el filtro nuevo; aqui solo se sostiene la pestaña.</summary>
    protected void btnFiltrarCal_Click(object sender, EventArgs e) { Pestana(tabCalendario, pvCalendario); }

    /// <summary>
    /// Un postback desde una pestaña tiene que volver a esa pestaña. El
    /// tabstrip no lo hace solo cuando las pestañas se muestran y esconden
    /// en PreRender, asi que se fija a mano.
    /// </summary>
    private void Pestana(RadTab tab, RadPageView vista)
    {
        tab.Selected = true;
        vista.Selected = true;
    }

    protected void lnkDescargarCal_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("VER PLANES MANTENIMIENTO"))
                throw new Exception("No tiene permiso para ver planes de mantenimiento.");

            PlanMantenimiento plan = new PlanMantenimientoController().GetPlanMantenimiento(new PlanMantenimiento { pma_id = Id });
            new PlanOcurrenciaController().ExportarCalendario(FiltroCalendario(), plan.pma_codigo);
        }
        catch (System.Threading.ThreadAbortException)
        {
            /* Response.End() la lanza siempre: es como termina una descarga, no un fallo. */
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion

    /// <summary>
    /// Borra los seleccionados de una grilla. El primero que rebota corta: el
    /// mensaje del SP dice cual y por que, y seguir con el resto lo taparia.
    /// </summary>
    private void Eliminar(RadGrid2 grid, string clave, Func<int, Respuesta> borrar)
    {
        try
        {
            if (grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta respuesta = new Respuesta();

            foreach (string indice in grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                respuesta = borrar(Int32.Parse(value[clave].ToString()));
                if (respuesta.error) break;
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }

    private static string ChipVersion(int? numero, string estadoCodigo)
    {
        string n = "v" + (numero ?? 0);
        switch ((estadoCodigo ?? "").ToUpperInvariant())
        {
            case "PUBLICADO": return "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-check-circle\"></i>" + n + " publicada</span>";
            case "RETIRADO": return "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-archive-outline\"></i>" + n + " retirada</span>";
            default: return "<span class=\"grid-estado-chip is-advertencia\"><i class=\"mdi mdi-pencil-outline\"></i>" + n + " borrador</span>";
        }
    }
}
