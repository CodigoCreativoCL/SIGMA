using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
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

            GridCalendario.AddSelectColumn();
            GridCalendario.AddTemplateColumn("FECHA", "", "FECHA", Width: "11%");
            GridCalendario.AddColumn("HITO_CODIGO", "HITO", Width: "11%");
            GridCalendario.AddColumn("HITO_NOMBRE", "", Width: "20%");
            GridCalendario.AddColumn("ACTIVO_CODIGO", "EQUIPO", Width: "8%");
            GridCalendario.AddColumn("ACTIVO_NOMBRE", "", Width: "14%");
            GridCalendario.AddColumn("COMPONENTE_NOMBRE", "COMPONENTE", Width: "10%");
            GridCalendario.AddTemplateColumn("MARCAS", "", "", Width: "9%");
            GridCalendario.AddTemplateColumn("SITUACION", "", "SITUACIÓN", Width: "9%");
            GridCalendario.AddTemplateColumn("OT", "", "OT", Width: "8%");

            GridVersiones.AddTemplateColumn("VERSION", "", "VERSIÓN", Width: "14%");
            GridVersiones.AddColumn("HITOS", "HITOS", Width: "7%");
            GridVersiones.AddColumn("ACTIVOS", "EQUIPOS", Width: "7%");
            GridVersiones.AddColumn("OCURRENCIAS", "OCURR.", Width: "7%");
            GridVersiones.AddTemplateColumn("PUBLICACION", "", "PUBLICADA", Width: "22%");
            GridVersiones.AddTemplateColumn("CREACION", "", "CREADA", Width: "20%");
            GridVersiones.AddColumn("PMV_OBSERVACION", "OBSERVACIÓN", Width: "23%");
        }

        Tools.tools.RegisterPostBackScript(GridCalendario);
        Tools.tools.RegisterPostBackScript(GridVersiones);
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

        /* Un plan nuevo no tiene version todavia -la crea el SP al guardar-,
           asi que no hay donde colgar hitos ni equipos. Se muestra solo la
           configuracion: una pestaña que al abrirla no tiene nada se lee
           como que la pantalla se rompio. */
        pnlNav.CssClass = conPlan ? "sg-a3-nav" : "sg-a3-nav es-solo-configuracion";
        if (!conPlan) hdnSeccion.Value = "configuracion";

        if (conPlan)
        {
            bool puedeEscribir = Token.PuedeFuncion("Crear y editar");

            PlanMantenimiento plan = new PlanMantenimientoController().GetPlanMantenimiento(
                new PlanMantenimiento { pma_id = Id });

            /* Solo los de LA VERSION QUE MANDA -la publicada, o la ultima si
               no hay publicada-. La grilla vieja mostraba los de todas las
               versiones con un chip al lado, y el plan se leia con el doble
               de hitos de los que en realidad se ejecutan. Las versiones
               anteriores estan en Configuracion, que es donde se comparan. */
            List<PlanHito> hitos = new PlanHitoController().GetPlanHitos(
                new PlanHito { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id, filtro_version = plan.version_id })
                ?? new List<PlanHito>();

            List<PlanActivo> equipos = new PlanActivoController().GetPlanActivos(
                new PlanActivo { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id, filtro_version = plan.version_id })
                ?? new List<PlanActivo>();

            /* El año completo alimenta la cabecera y el resumen. El
               calendario de abajo usa SU filtro: son dos preguntas -como
               viene el año y que pasa en mayo- y mezclarlas daria una
               cabecera que cambia cada vez que alguien filtra. */
            List<PlanOcurrencia> anio = new PlanOcurrenciaController().GetCalendario(new PlanOcurrencia
            {
                filtro_plan = Id,
                filtro_desde = new DateTime(global::SitioBase.Hora.Ahora.Year, 1, 1),
                filtro_hasta = new DateTime(global::SitioBase.Hora.Ahora.Year, 12, 31)
            }) ?? new List<PlanOcurrencia>();

            Cabecera(plan);
            Kpis(plan, hitos, equipos, anio);
            Resumen360(plan, hitos, equipos, anio);
            Hitos(hitos, puedeEscribir);
            Equipos(plan, equipos, puedeEscribir);

            lnkNuevoHito.Visible = puedeEscribir;
            lnkNuevoActivo.Visible = puedeEscribir;

            ConfigurarFiltrosCalendario();
            CargarCalendario();
            CargarVersiones();
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

            Cabecera(entidad);

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.pma_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.pma_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
            litHeroNombre.Text = "Nuevo plan de mantenimiento";
            litHeroSub.Text = "Guarde la ficha y aparecerán los hitos, los equipos y el calendario.";
            litVersion.Text = "<span class=\"sigma-modal-ayuda\">Se crea la versión 1 en borrador al guardar.</span>";
        }
    }

    /// <summary>
    /// El encabezado del centro: de que plan estamos hablando, en que version
    /// y si esta habilitado. Se vuelve a pintar cuando cambia la version que
    /// manda -publicar o abrir un borrador la cambia-.
    /// </summary>
    private void Cabecera(PlanMantenimiento entidad)
    {
        litVersion.Text = TextoVersion(entidad);

        litHeroCodigo.Text = Server.HtmlEncode(Texto(entidad.pma_codigo));
        litHeroNombre.Text = Server.HtmlEncode(Texto(entidad.pma_nombre));
        litHeroSub.Text = Server.HtmlEncode(Resumen(entidad));

        litBadges.Text = ChipVersionCentro(entidad.version_numero, entidad.version_estado_codigo)
                       + (entidad.pma_habilitado
                            ? "<span class=\"sg-ot-chip es-ok\"><i class=\"mdi mdi-check-circle-outline\"></i>Habilitado</span>"
                            : "<span class=\"sg-ot-chip es-neutro\"><i class=\"mdi mdi-pause-circle-outline\"></i>Deshabilitado</span>");

        hlVolver.NavigateUrl = ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimientos.aspx");
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
        /* La version NO va aca: el chip del encabezado ya la dice, y
           repetirla deja la misma palabra dos veces en dos renglones. */
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

    /// <summary>
    /// Que se le hace al equipo y cada cuanto. La fila se despliega en su
    /// lugar con la programacion, las marcas y las actividades: abrir la
    /// ficha del hito es un clic mas, pero "que hace este hito" se responde
    /// sin salir.
    /// </summary>
    private void Hitos(List<PlanHito> hitos, bool puedeEscribir)
    {
        litTabHitos.Text = hitos.Count == 0 ? "" : "<b>" + hitos.Count + "</b>";

        litHitosEstado.Text = hitos.Count == 0 || hitos[0].version_editable
            ? ""
            : "<span class=\"sg-ot-chip es-neutro\"><i class=\"mdi mdi-lock-outline\"></i>Versión publicada · solo lectura</span>";

        if (hitos.Count == 0)
        {
            litHitos.Text = Vacio("mdi-format-list-checks", "Este plan todavía no tiene hitos",
                                  "Un hito dice qué se hace y cada cuánto. Sin hitos el plan no genera nada.");
            litHitosResumen.Text = "<p class=\"sg-ot-vacio-txt\">Sin hitos definidos.</p>";
            return;
        }

        StringBuilder s = new StringBuilder();

        s.Append("<div class=\"sg-a3-tabla-cab sg-plan-hito-cab\">")
         .Append("<span>Hito</span><span>Programación</span><span>Condiciones</span>")
         .Append("<span>Actividades</span><span>Estado</span><span></span></div>");

        foreach (PlanHito h in hitos)
        {
            string clave = "hito-" + h.pmh_id;
            string query = Cifrar("Id=" + h.pmh_id + "&Plan=" + Id);

            s.Append("<div class=\"sg-a3-tabla-fila sg-a3-rev sg-plan-hito\" data-rev=\"").Append(clave).Append("\">")

             .Append("<span class=\"c-cod\">").Append(Server.HtmlEncode(Texto(h.pmh_nombre)))
             .Append("<span>").Append(Server.HtmlEncode(Texto(h.pmh_codigo))).Append("</span></span>")

             .Append("<span class=\"c-dato\"><i class=\"mdi mdi-calendar-outline\"></i>")
             .Append(Server.HtmlEncode(Texto(h.programacion_nombre)))
             .Append("<span class=\"sg-plan-sub\">").Append(Server.HtmlEncode(Texto(h.programacion_tipo_nombre))).Append("</span></span>")

             .Append("<span class=\"c-dato\">").Append(Marcas(h.pmh_requiere_parada, h.pmh_es_overhaul)).Append("</span>")

             .Append("<span class=\"c-dato\"><i class=\"mdi mdi-format-list-bulleted\"></i>")
             .Append(h.actividades).Append(h.actividades == 1 ? " actividad" : " actividades").Append("</span>")

             .Append("<span class=\"c-dato\">")
             .Append(h.pmh_habilitado
                    ? "<span class=\"sg-ot-chip es-ok\"><i class=\"mdi mdi-check-circle-outline\"></i>Activo</span>"
                    : "<span class=\"sg-ot-chip es-neutro\">Inactivo</span>")
             .Append("</span>")

             .Append("<span class=\"c-acc\"><i class=\"mdi mdi-chevron-down sg-a3-rev-flecha\"></i></span>")
             .Append("</div>");

            // ---- el detalle que se despliega ----
            s.Append("<div class=\"sg-a3-ot-detalle sg-a3-rev-detalle\" id=\"rev-").Append(clave).Append("\">");

            s.Append(DetItem("mdi-calendar-outline", "Programación",
                     Texto(h.programacion_nombre) +
                     (string.IsNullOrEmpty(h.programacion_tipo_nombre) ? "" : " · " + h.programacion_tipo_nombre)));

            s.Append(DetItem("mdi-power", "Requiere parada", h.pmh_requiere_parada ? "Sí" : "No"));

            s.Append(DetItem("mdi-wrench-outline", "Tipo de trabajo",
                     h.pmh_es_overhaul ? "Overhaul" : Texto(h.ot_tipo_nombre)));

            s.Append(DetItem("mdi-timer-outline", "Duración estimada",
                     h.pmh_duracion_estimada_minuto == null ? "" : Duracion(h.pmh_duracion_estimada_minuto.Value)));

            if (h.pmh_valor_medidor != null)
                s.Append(DetItem("mdi-counter", "Cada",
                         h.pmh_valor_medidor.Value.ToString("0.##") + " " + Texto(h.unidad_simbolo)));

            s.Append(DetItem("mdi-text-long", "Descripción", Texto(h.pmh_descripcion)));

            s.Append("<div class=\"sg-a3-ot-det-acc\">");
            if (puedeEscribir && h.version_editable)
                s.Append("<a class=\"sg-ot-btn es-plano\" href=\"javascript:void(0)\" onclick=\"abrirPlanHito('")
                 .Append(query).Append("')\"><i class=\"mdi mdi-pencil-outline\"></i>Editar hito</a>");
            else
                s.Append("<span class=\"sg-ot-vacio-txt\">Los hitos se editan en una versión en borrador.</span>");
            s.Append("</div></div>");
        }

        litHitos.Text = s.ToString();

        // ---- el mismo hito, resumido, en la portada ----
        StringBuilder r = new StringBuilder();

        foreach (PlanHito h in hitos)
            r.Append(Fila("mdi-wrench-outline", "",
                     Texto(h.pmh_nombre),
                     Texto(h.pmh_codigo),
                     "<span class=\"sg-ot-chip es-tipo\"><i class=\"mdi mdi-calendar-outline\"></i>" +
                     Server.HtmlEncode(Texto(h.programacion_nombre)) + "</span>" +
                     Marcas(h.pmh_requiere_parada, h.pmh_es_overhaul)));

        litHitosResumen.Text = r.ToString();
    }

    private string Marcas(bool parada, bool overhaul)
    {
        string m = "";
        if (parada) m += "<span class=\"sg-ot-chip es-aviso\" title=\"Requiere parada del equipo\"><i class=\"mdi mdi-pause-circle-outline\"></i>Parada</span>";
        if (overhaul) m += "<span class=\"sg-ot-chip es-tipo\" title=\"Overhaul: intervención mayor\"><i class=\"mdi mdi-cog-outline\"></i>Overhaul</span>";
        return m.Length == 0 ? "<span class=\"sg-ot-vacio-txt\">—</span>" : m;
    }

    #endregion

    #region Equipos

    /// <summary>
    /// A que maquinas se le aplica el plan. Van como tarjetas y no como
    /// filas: lo que se comprueba aca es que el equipo sea EL equipo -su
    /// foto, su planta, su componente-, y eso no se lee en una grilla.
    /// </summary>
    private void Equipos(PlanMantenimiento p, List<PlanActivo> equipos, bool puedeEscribir)
    {
        litTabEquipos.Text = equipos.Count == 0 ? "" : "<b>" + equipos.Count + "</b>";

        litEquiposEstado.Text = equipos.Count == 0 || equipos[0].version_editable
            ? ""
            : "<span class=\"sg-ot-chip es-neutro\"><i class=\"mdi mdi-lock-outline\"></i>Versión publicada · solo lectura</span>";

        litAlcanceChips.Text =
            "<div class=\"sg-plan-alcance\">" +
            ChipAlcance("mdi-factory", "Planta", string.IsNullOrEmpty(p.planta_nombre) ? "Cualquiera" : p.planta_nombre) +
            ChipAlcance("mdi-cog-outline", "Tipo", string.IsNullOrEmpty(p.tipo_nombre) ? "Cualquiera" : p.tipo_nombre) +
            ChipAlcance("mdi-layers-outline", "Modelo", string.IsNullOrEmpty(p.modelo_nombre) ? "Cualquier modelo" : p.modelo_nombre) +
            "</div>";

        if (equipos.Count == 0)
        {
            litEquipos.Text = Vacio("mdi-account-group-outline", "Ningún equipo asociado",
                                    "Un plan sin equipos no se publica: no tendría para qué máquina generar.");
            litEquiposResumen.Text = "<p class=\"sg-ot-vacio-txt\">Sin equipos asociados.</p>";
            return;
        }

        ActivoImagenController imagenes = new ActivoImagenController();
        StringBuilder s = new StringBuilder("<div class=\"sg-plan-equipos\">");

        foreach (PlanActivo v in equipos)
        {
            string query = Cifrar("Id=" + v.pac_id + "&Plan=" + Id);
            int foto = imagenes.GetImagenId(v.pac_activo, SitioBase.Session.ClienteId());

            s.Append("<div class=\"sg-plan-equipo\">")
             .Append(foto > 0
                    ? "<span class=\"sg-plan-foto\"><img src=\"" + Server.HtmlEncode(UrlArchivo.Ver(foto)) + "\" alt=\"Imagen del equipo\" /></span>"
                    : "<span class=\"sg-plan-foto es-vacia\"><i class=\"mdi mdi-image-off-outline\"></i></span>")

             .Append("<div class=\"sg-plan-equipo-txt\">")
             .Append("<header><div><h4>").Append(Server.HtmlEncode(Texto(v.activo_nombre))).Append("</h4>")
             .Append("<span class=\"sg-a3-codigo\">").Append(Server.HtmlEncode(Texto(v.activo_codigo))).Append("</span></div>")
             .Append("<a class=\"sg-ot-btn es-plano\" href=\"").Append(UrlActivo(v.pac_activo))
             .Append("\">Ver ficha del activo<i class=\"mdi mdi-open-in-new\"></i></a></header>")

             .Append("<dl class=\"sg-a3-ident\">")
             .Append(Dato2("Planta", Texto(v.planta_nombre)))
             .Append(Dato2("Tipo", Texto(v.tipo_nombre)))
             .Append(Dato2("Componente", string.IsNullOrEmpty(v.componente_nombre) ? "Equipo completo" : v.componente_nombre))
             .Append(Dato2("Medidor", string.IsNullOrEmpty(v.medidor_nombre) ? "No asociado" : v.medidor_nombre))
             .Append("</dl>");

            if (puedeEscribir && v.version_editable)
                s.Append("<div class=\"sg-plan-equipo-acc\">")
                 .Append("<a class=\"sg-ot-btn es-plano\" href=\"javascript:void(0)\" onclick=\"abrirPlanActivo('")
                 .Append(query).Append("')\"><i class=\"mdi mdi-pencil-outline\"></i>Editar vínculo</a>")
                 .Append("</div>");

            s.Append("</div></div>");
        }

        litEquipos.Text = s.Append("</div>").ToString();

        // ---- los mismos equipos, en la portada ----
        StringBuilder r = new StringBuilder();

        foreach (PlanActivo v in equipos)
            r.Append(Fila("mdi-cog-outline", "",
                     Texto(v.activo_nombre),
                     Texto(v.activo_codigo),
                     Boton(UrlActivo(v.pac_activo), "Ver ficha")));

        litEquiposResumen.Text = r.ToString();
    }

    private string ChipAlcance(string icono, string etiqueta, string valor)
    {
        return "<div class=\"sg-plan-alcance-chip\"><i class=\"mdi " + icono + "\"></i>" +
               "<div><span>" + Server.HtmlEncode(etiqueta) + "</span>" +
               "<b>" + Server.HtmlEncode(valor) + "</b></div></div>";
    }

    private string UrlActivo(int activo)
    {
        return ResolveUrl("~/View/Activos/Ficha/ActivoFicha.aspx") + "?query=" +
               Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + activo));
    }

    #endregion

    #region Portada del centro

    /// <summary>
    /// Los cuatro numeros de la cabecera. Vencidas y disponibles van juntas a
    /// proposito: el plan que importa no es el que tiene muchos hitos, es el
    /// que tiene trabajo esperando.
    /// </summary>
    private void Kpis(PlanMantenimiento p, List<PlanHito> hitos, List<PlanActivo> equipos, List<PlanOcurrencia> anio)
    {
        int vencidas = anio.FindAll(o => o.situacion == "VENCIDA").Count;
        int atrasadas = anio.FindAll(o => o.situacion == "ATRASADA").Count;
        int disponibles = anio.FindAll(o => o.situacion == "DISPONIBLE").Count;
        int cerradas = anio.FindAll(o => o.situacion == "CERRADA").Count;

        StringBuilder k = new StringBuilder("<div class=\"sg-a3-kpis\">");

        k.Append(Kpi("mdi-account-group-outline", equipos.Count.ToString(), "Equipos asociados", "", "es-lila"));
        k.Append(Kpi("mdi-format-list-checks", hitos.Count.ToString(), "Hitos del plan", "", "es-azul"));
        k.Append(Kpi("mdi-alert-outline", (vencidas + atrasadas).ToString(), "Vencidas y atrasadas",
                 vencidas + atrasadas == 0 ? "Nada corriendo" : "Del año en curso", "es-rojo"));
        k.Append(Kpi("mdi-play-circle-outline", disponibles.ToString(), "Disponibles",
                 disponibles == 0 ? "Nada para ejecutar hoy" : "Listas para ejecutar", "es-verde"));

        k.Append("</div>");

        k.Append("<p class=\"sg-plan-anio\"><i class=\"mdi mdi-calendar-blank-outline\"></i>")
         .Append(global::SitioBase.Hora.Ahora.Year).Append(" · ").Append(anio.Count)
         .Append(anio.Count == 1 ? " ocurrencia" : " ocurrencias")
         .Append(" · ").Append(cerradas).Append(" cerradas")
         .Append(" · ").Append(anio.Count - cerradas - vencidas - atrasadas - disponibles).Append(" futuras</p>");

        litKpis.Text = k.ToString();
    }

    /// <summary>
    /// La portada: lo que hay que mirar hoy, el alcance y con que equipos.
    ///
    /// "Requiere atencion" muestra lo VENCIDO y lo ATRASADO, no todo lo
    /// abierto: una lista con las cuarenta ocurrencias del año no dice por
    /// donde empezar.
    /// </summary>
    private void Resumen360(PlanMantenimiento p, List<PlanHito> hitos, List<PlanActivo> equipos, List<PlanOcurrencia> anio)
    {
        List<PlanOcurrencia> urgentes = anio.FindAll(o => o.situacion == "VENCIDA" || o.situacion == "ATRASADA");
        int disponibles = anio.FindAll(o => o.situacion == "DISPONIBLE").Count;

        StringBuilder a = new StringBuilder();

        if (urgentes.Count == 0)
            a.Append("<p class=\"sg-ot-vacio-txt\">Nada vencido ni atrasado en el año. Lo que viene está en el calendario.</p>");
        else
            foreach (PlanOcurrencia o in urgentes.GetRange(0, Math.Min(6, urgentes.Count)))
                a.Append(Fila("mdi-wrench-outline", o.situacion == "VENCIDA" ? "es-rojo" : "es-ambar",
                         Texto(o.hito_nombre),
                         Texto(o.hito_codigo) + " · " + Texto(o.activo_nombre) + " · " + Texto(o.activo_codigo) +
                         " · " + o.fecha_programada.ToString("dd MMM yyyy"),
                         ChipSituacionCentro(o.situacion) +
                         (o.orden_trabajo_id == null ? "" : Boton(UrlOrden(o.orden_trabajo_id.Value), "OT-" + o.orden_trabajo_correlativo))));

        if (disponibles > 0)
            a.Append("<div class=\"sg-ot-nota es-ok\"><i class=\"mdi mdi-play-circle-outline\"></i><span>")
             .Append(disponibles).Append(disponibles == 1 ? " ocurrencia disponible" : " ocurrencias disponibles")
             .Append(" para ejecutar.</span></div>");

        litAtencion.Text = a.ToString();

        // ---- alcance ----
        StringBuilder al = new StringBuilder();
        al.Append(Dato2("Planta", string.IsNullOrEmpty(p.planta_nombre) ? "Cualquier planta" : p.planta_nombre));
        al.Append(Dato2("Tipo de activo", string.IsNullOrEmpty(p.tipo_nombre) ? "Cualquier tipo" : p.tipo_nombre));
        al.Append(Dato2("Modelo", string.IsNullOrEmpty(p.modelo_nombre) ? "Cualquier modelo" : p.modelo_nombre));
        al.Append(Dato2("Planificador", Texto(p.planificador_nombre)));
        litAlcance.Text = al.ToString();

        litNotaVersion.Text = hitos.Count > 0 && !hitos[0].version_editable
            ? "<div class=\"sg-ot-nota es-chica\"><i class=\"mdi mdi-lock-outline\"></i>" +
              "<span>Versión publicada · los hitos y equipos se editan en una versión en borrador.</span></div>"
            : "";
    }

    #endregion

    #region Presentacion

    private string Texto(string v) { return string.IsNullOrEmpty(v) ? "" : v; }

    private string Vacio(string icono, string titulo, string detalle)
    {
        return "<div class=\"sg-ot-vacio\"><i class=\"mdi " + icono + "\"></i><p>" +
               Server.HtmlEncode(titulo) + "</p><span>" + Server.HtmlEncode(detalle) + "</span></div>";
    }

    private string Kpi(string icono, string valor, string etiqueta, string pie, string clase)
    {
        return "<div class=\"sg-a3-kpi\"><span class=\"sg-a3-kpi-ico " + clase + "\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-a3-kpi-etq\">" + Server.HtmlEncode(etiqueta) + "</span>" +
               "<span class=\"sg-a3-kpi-val" + (valor.Length > 12 ? " es-chico" : "") + "\">" + Server.HtmlEncode(valor) + "</span>" +
               (string.IsNullOrEmpty(pie) ? "" : "<span class=\"sg-a3-kpi-pie\">" + Server.HtmlEncode(pie) + "</span>") +
               "</div></div>";
    }

    private string Fila(string icono, string clase, string titulo, string sub, string acciones)
    {
        return "<div class=\"sg-a3-fila\"><span class=\"sg-a3-fila-ico " + clase + "\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div class=\"sg-a3-fila-txt\"><span class=\"sg-a3-fila-tit\">" + Server.HtmlEncode(titulo) + "</span>" +
               (string.IsNullOrEmpty(sub) ? "" : "<span class=\"sg-a3-fila-sub\">" + Server.HtmlEncode(sub) + "</span>") +
               "</div><div class=\"sg-a3-fila-acc\">" + acciones + "</div></div>";
    }

    private string Dato2(string etiqueta, string valor)
    {
        return "<dt>" + Server.HtmlEncode(etiqueta) + "</dt><dd>" +
               Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "Sin registrar" : valor) + "</dd>";
    }

    private string DetItem(string icono, string titulo, string valor)
    {
        return "<div class=\"sg-a3-ot-det-item\"><strong><i class=\"mdi " + icono + "\"></i>" +
               Server.HtmlEncode(titulo) + "</strong><span>" +
               Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "Sin registrar" : valor) + "</span></div>";
    }

    private string Boton(string url, string texto)
    {
        return "<a class=\"sg-ot-btn es-plano\" href=\"" + url + "\">" +
               Server.HtmlEncode(texto) + "<i class=\"mdi mdi-open-in-new\"></i></a>";
    }

    private string UrlOrden(int id)
    {
        return ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" +
               Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
    }

    private static string Duracion(int minutos)
    {
        if (minutos <= 0) return "";
        if (minutos < 60) return minutos + " min";
        int h = minutos / 60, m = minutos % 60;
        return m == 0 ? h + " h" : h + " h " + m + " min";
    }

    /// <summary>
    /// La situacion de una ocurrencia con los chips del centro. La grilla del
    /// calendario tiene los suyos y se quedan: son de Telerik y viven dentro
    /// de la tabla.
    /// </summary>
    private static string ChipSituacionCentro(string situacion)
    {
        switch (situacion)
        {
            case "VENCIDA":    return "<span class=\"sg-ot-chip es-rojo\"><i class=\"mdi mdi-alert-circle-outline\"></i>Vencida</span>";
            case "ATRASADA":   return "<span class=\"sg-ot-chip es-aviso\"><i class=\"mdi mdi-clock-alert-outline\"></i>Atrasada</span>";
            case "DISPONIBLE": return "<span class=\"sg-ot-chip es-ok\"><i class=\"mdi mdi-play-circle-outline\"></i>Disponible</span>";
            case "CERRADA":    return "<span class=\"sg-ot-chip es-neutro\"><i class=\"mdi mdi-check\"></i>Cerrada</span>";
            default:           return "<span class=\"sg-ot-chip es-neutro\"><i class=\"mdi mdi-calendar-blank-outline\"></i>Futura</span>";
        }
    }

    /// <summary>El chip de version con el vocabulario del centro.</summary>
    private static string ChipVersionCentro(int? numero, string estadoCodigo)
    {
        string n = "v" + (numero ?? 0);
        switch ((estadoCodigo ?? "").ToUpperInvariant())
        {
            case "PUBLICADO": return "<span class=\"sg-ot-chip es-ok\"><i class=\"mdi mdi-check-circle-outline\"></i>" + n + " publicada</span>";
            case "RETIRADO": return "<span class=\"sg-ot-chip es-neutro\"><i class=\"mdi mdi-archive-outline\"></i>" + n + " retirada</span>";
            default: return "<span class=\"sg-ot-chip es-aviso\"><i class=\"mdi mdi-pencil-outline\"></i>" + n + " borrador</span>";
        }
    }

    /// <summary>Recarga el centro cuando un modal de hito o equipo se cierra.</summary>
    protected void lnkRecargar_Click(object sender, EventArgs e) { }

    #endregion

    #region Versiones (HU-084)

    private void CargarVersiones()
    {
        List<PlanVersion> lista = new PlanVersionController().GetPlanVersiones(
            new PlanVersion { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id }) ?? new List<PlanVersion>();

        bool hayBorrador = lista.Exists(v => v.pmv_plan_version_estado == 1);
        bool puedeEscribir = Token.PuedeFuncion("Crear y editar");

        GridVersiones.DataSource = lista;
        GridVersiones.DataBind();

        if (!puedeEscribir)
            GridVersiones.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        /* Solo se ofrece lo que aplica: con un borrador abierto se publica;
           sin borrador se abre uno. Ofrecer los dos siempre es ofrecer uno
           que el SP va a rechazar. */
        foreach (GridItem it in GridVersiones.MasterTableView.GetItems(GridItemType.CommandItem))
        {
            Control nueva = it.FindControl("lnkNuevaVersion");
            Control publicar = it.FindControl("lnkPublicar");
            if (nueva != null) nueva.Visible = !hayBorrador;
            if (publicar != null) publicar.Visible = hayBorrador;
            // Postback completo: la cabecera (titulo y version) esta fuera del UpdatePanel.
            if (nueva != null) ScriptManager.GetCurrent(Page).RegisterPostBackControl(nueva);
            if (publicar != null) ScriptManager.GetCurrent(Page).RegisterPostBackControl(publicar);
        }
    }

    protected void GridVersiones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem && e.Item.ItemType != GridItemType.Item) return;
        if (!(e.Item is GridDataItem)) return;

        GridDataItem item = e.Item as GridDataItem;
        PlanVersion v = item.DataItem as PlanVersion;
        if (v == null) return;

        item["VERSION"].Controls.Add(new Literal { Text = ChipVersion(v.pmv_numero, v.estado_codigo) });

        string pub = "";
        if (v.pmv_fecha_publicacion != null)
            pub = v.pmv_fecha_publicacion.Value.ToString("dd-MM-yyyy HH:mm") + "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(v.usuario_publicacion_nombre) + "</span>";
        if (v.pmv_fecha_retiro != null)
            pub += "<br/><span class=\"sigma-inv-vacio\">retirada " + v.pmv_fecha_retiro.Value.ToString("dd-MM-yyyy") + "</span>";
        if (pub.Length == 0) pub = "<span class=\"sigma-inv-vacio\">—</span>";
        item["PUBLICACION"].Controls.Add(new Literal { Text = pub });

        item["CREACION"].Controls.Add(new Literal
        {
            Text = (v.pmv_fecha_creacion == null ? "" : v.pmv_fecha_creacion.Value.ToString("dd-MM-yyyy HH:mm"))
                 + "<br/><span class=\"sigma-inv-vacio\">" + Server.HtmlEncode(v.usuario_creacion_nombre) + "</span>"
        });
    }

    protected void lnkNuevaVersion_Click(object sender, EventArgs e)
    {
        hdnSeccion.Value = "configuracion";
        Respuesta r = new PlanVersionController().AbrirVersionNueva(Id, txtObservacionVersion.Text.Trim());
        if (!r.error) { txtObservacionVersion.Text = ""; Cabecera(new PlanMantenimientoController().GetPlanMantenimiento(new PlanMantenimiento { pma_id = Id })); }
        Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
    }

    protected void lnkPublicar_Click(object sender, EventArgs e)
    {
        hdnSeccion.Value = "configuracion";
        List<PlanVersion> lista = new PlanVersionController().GetPlanVersiones(
            new PlanVersion { filtro_cliente = SitioBase.Session.ClienteId(), filtro_plan = Id }) ?? new List<PlanVersion>();
        PlanVersion borrador = lista.Find(v => v.pmv_plan_version_estado == 1);

        if (borrador == null)
        {
            Tools.tools.ClientAlert("Este plan no tiene un borrador que publicar.", "alerta");
            return;
        }

        Respuesta r = new PlanVersionController().Publicar(borrador.pmv_id, txtObservacionVersion.Text.Trim());
        if (!r.error) { txtObservacionVersion.Text = ""; Cabecera(new PlanMantenimientoController().GetPlanMantenimiento(new PlanMantenimiento { pma_id = Id })); }
        Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
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

        int anio = global::SitioBase.Hora.Ahora.Year;
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
        if (!int.TryParse(cboAnio.SelectedValue, out anio) || anio < 2000) anio = global::SitioBase.Hora.Ahora.Year;
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

    /// <summary>
    /// Carga por semana (HU-085 criterio 3): horas estimadas de lo que cae en
    /// cada semana ISO del periodo, con lo que hay abierto. Se calcula aqui
    /// sobre la lista ya traida: es una suma, no otra consulta.
    /// </summary>
    private string CargaPorSemana(List<PlanOcurrencia> lista)
    {
        SortedDictionary<string, int> minutos = new SortedDictionary<string, int>();
        System.Globalization.Calendar cal = System.Globalization.CultureInfo.InvariantCulture.Calendar;
        foreach (PlanOcurrencia o in lista)
        {
            if (o.situacion == "CERRADA") continue;
            int semana = cal.GetWeekOfYear(o.fecha_programada, System.Globalization.CalendarWeekRule.FirstFourDayWeek, DayOfWeek.Monday);
            string clave = o.fecha_programada.Year + "-S" + semana.ToString("00");
            int m; minutos.TryGetValue(clave, out m);
            minutos[clave] = m + (o.duracion_estimada_minuto ?? 0);
        }
        if (minutos.Count == 0) return "";

        StringBuilder sb = new StringBuilder("<span class=\"sigma-inv-vacio\">Horas estimadas por semana (abiertas):</span> ");
        foreach (KeyValuePair<string, int> kv in minutos)
            sb.Append("<span class=\"grid-estado-chip is-neutro\">" + kv.Key + " · " + (kv.Value / 60.0).ToString("0.#") + " h</span> ");
        return sb.ToString();
    }

    private void CargarCalendario()
    {
        List<PlanOcurrencia> lista = new PlanOcurrenciaController().GetCalendario(FiltroCalendario()) ?? new List<PlanOcurrencia>();

        // «Solo con parada» (HU-085 criterio 2) se aplica sobre lo traido: es una marca del hito.
        if (chkSoloParada.Checked) lista = lista.FindAll(o => o.requiere_parada);

        litSemanas.Text = CargaPorSemana(lista);

        GridCalendario.DataSource = lista;
        GridCalendario.DataBind();

        // El boton de descarga es un postback completo: entrega un archivo.
        // Generar ordenes exige el permiso de crear OT, ademas de editar planes.
        bool puedeGenerar = Token.Puede("CREAR ORDEN TRABAJO");
        foreach (GridItem it in GridCalendario.MasterTableView.GetItems(GridItemType.CommandItem))
        {
            Control lnk = it.FindControl("lnkDescargarCal");
            if (lnk != null) ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnk);
            Control gen = it.FindControl("lnkGenerarOT");
            if (gen != null) gen.Visible = puedeGenerar;
            Control ocu = it.FindControl("btnGenerarOcurrencias");
            if (ocu != null) ocu.Visible = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO");
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
    protected void btnFiltrarCal_Click(object sender, EventArgs e) { hdnSeccion.Value = "calendario"; }

    /// <summary>
    /// HU-111: una orden por cada ocurrencia seleccionada. El SP decide -y
    /// devuelve la existente si ya la tenia-, aqui solo se informa el
    /// resultado de cada una (criterio 3): que se genero, que ya existia y
    /// que rebota y por que. Una que rebota no detiene a las demas.
    /// </summary>
    protected void lnkGenerarOT_Click(object sender, EventArgs e)
    {
        hdnSeccion.Value = "calendario";
        try
        {
            if (!Token.Puede("CREAR ORDEN TRABAJO"))
                throw new Exception("No tiene permiso para crear órdenes de trabajo.");

            if (GridCalendario.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Seleccione al menos una ocurrencia.");
                return;
            }

            PlanOcurrenciaController controller = new PlanOcurrenciaController();
            System.Text.StringBuilder sb = new System.Text.StringBuilder();
            int generadas = 0, existentes = 0, rechazadas = 0;

            foreach (string indice in GridCalendario.SelectedIndexes)
            {
                GridDataItem fila = (GridDataItem)GridCalendario.MasterTableView.Items[Int32.Parse(indice)];
                int ocurrencia = Int32.Parse(GridCalendario.MasterTableView.DataKeyValues[Int32.Parse(indice)]["pmo_id"].ToString());
                string etiqueta = Server.HtmlEncode(fila["HITO_CODIGO"].Text + " · " + fila["ACTIVO_CODIGO"].Text);

                Respuesta r = controller.GenerarOrden(ocurrencia);
                if (r.error) { rechazadas++; sb.Append("<div><span class=\"grid-estado-chip is-alerta\">rechazada</span> " + etiqueta + " — " + Server.HtmlEncode(r.detalle) + "</div>"); }
                else if (r.detalle.Contains("ya existía")) { existentes++; sb.Append("<div><span class=\"grid-estado-chip is-neutro\">" + Server.HtmlEncode(r.detalle) + "</span> " + etiqueta + "</div>"); }
                else { generadas++; sb.Append("<div><span class=\"grid-estado-chip is-exito\">" + Server.HtmlEncode(r.detalle) + "</span> " + etiqueta + "</div>"); }
            }

            pnlResultadoOT.Visible = true;
            litResultadoOT.Text = "<strong>" + generadas + " generada" + (generadas == 1 ? "" : "s") + " · " + existentes + " ya existía" + (existentes == 1 ? "" : "n")
                                + " · " + rechazadas + " rechazada" + (rechazadas == 1 ? "" : "s") + "</strong>" + sb.ToString();

            CargarCalendario();
            Tools.tools.ClientAlert(generadas + " orden(es) generada(s).", rechazadas > 0 ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>HU-076: el generador a mano desde el plan; el mismo SP que usara el job nocturno.</summary>
    protected void btnGenerarOcurrencias_Click(object sender, EventArgs e)
    {
        hdnSeccion.Value = "calendario";
        try
        {
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
                throw new Exception("No tiene permiso para generar ocurrencias.");

            int horizonte;
            if (!int.TryParse(cboHorizonte.SelectedValue, out horizonte)) horizonte = 90;

            Respuesta r = new PlanOcurrenciaController().GenerarOcurrencias(Id, horizonte);
            if (r.error) { Tools.tools.ClientAlert(r.detalle, "alerta"); return; }

            pnlResultadoOT.Visible = true;
            litResultadoOT.Text = "<strong>Generación de ocurrencias</strong><br/>" + r.detalle;
            CargarCalendario();
            Tools.tools.ClientAlert(r.codigo + " ocurrencia(s) generada(s).", "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
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
