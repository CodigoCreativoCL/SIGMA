using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using OfficeOpenXml;

/// <summary>
/// La tarea recurrente como centro (HU-102, HU-103, HU-104): Configuracion
/// (que se hace, donde y cada cuanto), Ocurrencias (lo que se genero y lo que
/// se ejecuto) y Comentarios (la conversacion de cada ejecucion).
///
/// LAS OCURRENCIAS SE VEIAN SOLO DESDE EL TELEFONO
///   La pantalla tenia Ficha, Programaciones y Comentarios: lo que la tarea
///   habia generado y quien la ejecuto no aparecia por ninguna parte, porque
///   el unico SP que las leia -SEL_TAREA_EJECUCION- filtra por usuario y por
///   planta asignada, que sirve para descargar al dispositivo y no para
///   revisar desde el escritorio. Ahora hay SEL_TAREA_OCURRENCIA (bloque 264)
///   y una pestaña que muestra historial, proximas y el detalle de cada una.
///
/// NADA RECARGA LA PANTALLA
///   Cambiar de pestaña y buscar en los comentarios los resuelve el navegador;
///   lo que escribe va por el UpdatePanel. Lo unico que recarga es Exportar,
///   que devuelve un binario.
/// </summary>
public partial class View_Mantenimiento_Tareas_Tarea : System.Web.UI.Page
{
    #region Estado

    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>La ocurrencia abierta en el panel de la derecha.</summary>
    public int Ocurrencia
    {
        get { return ViewState["Ocurrencia"] != null ? (int)ViewState["Ocurrencia"] : 0; }
        set { ViewState["Ocurrencia"] = value; }
    }

    private string _areaEditar = null, _activoEditar = null;
    private Tarea _tarea = null;
    private List<TareaOcurrencia> _ocurrencias = null;

    protected string QueryNuevaProgramacion { get { return Id > 0 ? Cifrar("Id=0&Tarea=" + Id) : "0"; } }

    private string Cifrar(string texto) { return Server.UrlEncode(Tools.Crypto.Encrypt(texto)); }

    private Tarea LaTarea()
    {
        if (_tarea == null) _tarea = new TareaController().GetTarea(new Tarea { tar_id = Id });
        return _tarea;
    }

    /// <summary>
    /// Las ocurrencias del periodo elegido. Se leen UNA vez por pedido: la
    /// pestaña las usa para la lista, para los contadores, para el detalle y
    /// para llenar el combo de la conversacion.
    /// </summary>
    private List<TareaOcurrencia> Ocurrencias()
    {
        if (_ocurrencias == null)
        {
            DateTime? desde = null, hasta = null;
            Periodo(out desde, out hasta);

            int? estado = string.IsNullOrEmpty(cboEstado.SelectedValue) ? (int?)null : int.Parse(cboEstado.SelectedValue);
            int? responsable = string.IsNullOrEmpty(cboResponsable.SelectedValue) ? (int?)null : int.Parse(cboResponsable.SelectedValue);

            _ocurrencias = new TareaOcurrenciaController().Get(Id, desde, hasta, estado, responsable);
        }

        return _ocurrencias;
    }

    private void Periodo(out DateTime? desde, out DateTime? hasta)
    {
        desde = null; hasta = null;

        DateTime hoy = global::SitioBase.Hora.Hoy;

        switch (cboPeriodo.SelectedValue)
        {
            case "90": desde = hoy.AddDays(-90); hasta = hoy.AddDays(91); break;
            case "MES": desde = new DateTime(hoy.Year, hoy.Month, 1); hasta = desde.Value.AddMonths(1); break;
            case "PASADO": hasta = hoy.AddDays(1); break;
            case "FUTURO": desde = hoy; break;
            // "" = todo el historial, sin acotar.
        }
    }

    private void Pestana(string nombre) { hdnTab.Value = nombre; }

    #endregion

    #region Ciclo de vida

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.Split('=');
                if (array[0] == "Id") Id = Int32.Parse(array[1]);
            }
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;

        if (ctrl.ID == "cboPlanta")
        {
            ClienteInstalacion filtro = new ClienteInstalacion { filtro_cliente = SitioBase.Session.ClienteId().ToString(), filtro_habilitado = "1" };
            ctrl.Items.Add(new RadComboBoxItem("Cualquier planta", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = new ClienteInstalacionController().GetClienteInstalaciones(filtro);
            ctrl.DataValueField = "cin_id";
            ctrl.DataTextField = "cin_nombre";
            ctrl.DataBind();
        }
    }

    protected void cboPlanta_SelectedIndexChanged(object sender, EventArgs e) { Pestana("configuracion"); }

    protected void Filtro_Changed(object sender, EventArgs e)
    {
        Pestana(sender == cboOcurrenciaComentario ? "comentarios" : "ocurrencias");
        _ocurrencias = null;

        // Al cambiar de ocurrencia en la conversacion se responde a esa.
        if (sender == cboOcurrenciaComentario)
        {
            int oc;
            if (int.TryParse(cboOcurrenciaComentario.SelectedValue, out oc)) hidOcurrencia.Value = oc.ToString();
            hidPadre.Value = "";
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        ConfigurarCombos();
        CargarDatos();
        CargarDependientes();
        Pintar();
        Bloqueo();

        /* Lo unico que recarga es Exportar: devuelve un archivo y un binario no
           sobrevive a un postback parcial. Los demas se registran como
           asincronos, incluidos los LinkButton de los repeaters. */
        ScriptManager sm = ScriptManager.GetCurrent(Page);

        sm.RegisterPostBackControl(btnExportar);

        sm.RegisterAsyncPostBackControl(btnGuardar);
        sm.RegisterAsyncPostBackControl(rptProgramaciones);
        sm.RegisterAsyncPostBackControl(rptOcurrencias);
        sm.RegisterAsyncPostBackControl(lnkGenerarOcurrencias);
        sm.RegisterAsyncPostBackControl(btnComentar);
        sm.RegisterAsyncPostBackControl(lnkRefrescar);

        udPanel.Update();
    }

    private void ConfigurarCombos()
    {
        if (cboPrioridad.Items.Count == 0)
        {
            // Tarea_Prioridad: catalogo fijo del bloque 159.
            cboPrioridad.Items.Add(new RadComboBoxItem("Baja", "1"));
            cboPrioridad.Items.Add(new RadComboBoxItem("Media", "2") { Selected = true });
            cboPrioridad.Items.Add(new RadComboBoxItem("Alta", "3"));
            cboPrioridad.Items.Add(new RadComboBoxItem("Crítica", "4"));
        }

        if (cboPeriodo.Items.Count == 0)
        {
            cboPeriodo.Items.Add(new RadComboBoxItem("Últimos y próximos 90 días", "90") { Selected = true });
            cboPeriodo.Items.Add(new RadComboBoxItem("Este mes", "MES"));
            cboPeriodo.Items.Add(new RadComboBoxItem("Lo ya ocurrido", "PASADO"));
            cboPeriodo.Items.Add(new RadComboBoxItem("Lo que viene", "FUTURO"));
            cboPeriodo.Items.Add(new RadComboBoxItem("Todo el historial", ""));
        }

        if (cboEstado.Items.Count == 0)
        {
            // Tarea_Ocurrencia_Estado, bloque 159.
            cboEstado.Items.Add(new RadComboBoxItem("Todos", ""));
            cboEstado.Items.Add(new RadComboBoxItem("Pendiente", "1"));
            cboEstado.Items.Add(new RadComboBoxItem("Aceptada", "2"));
            cboEstado.Items.Add(new RadComboBoxItem("En ejecución", "3"));
            cboEstado.Items.Add(new RadComboBoxItem("Completada", "4"));
            cboEstado.Items.Add(new RadComboBoxItem("No realizada", "5"));
            cboEstado.Items.Add(new RadComboBoxItem("Cancelada", "6"));
            cboEstado.Items.Add(new RadComboBoxItem("Reprogramada", "7"));
        }
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Tarea");

        if (Id == 0)
        {
            litCabTitulo.Text = "Nueva tarea recurrente";
            litCabSub.Text = "Complete la configuración para crearla.";
            litSubtitulo.Text = "Guarde la tarea y aparecerán sus ocurrencias y su conversación.";
            return;
        }

        Tarea t = LaTarea();

        txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Tarea", t.tar_codigo);
        txtTitulo.Text = t.tar_titulo;
        txtDescripcion.Text = t.tar_descripcion;
        txtDuracion.Text = t.tar_duracion_estimada_minuto == null ? "" : t.tar_duracion_estimada_minuto.ToString();
        Seleccionar(cboPrioridad, t.tar_tarea_prioridad.ToString());
        if (t.tar_cliente_instalacion != null) Seleccionar(cboPlanta, t.tar_cliente_instalacion.Value.ToString());
        if (t.tar_instalacion_area != null) _areaEditar = t.tar_instalacion_area.Value.ToString();
        if (t.tar_activo != null) _activoEditar = t.tar_activo.Value.ToString();
        chkEvidencia.Checked = t.tar_requiere_evidencia;
        chkHabilitada.Checked = t.tar_habilitado;

        wucAuditoria.Mostrar(t.usuario_creacion_nombre, t.tar_fecha_creacion, t.usuario_actualizacion_nombre, t.tar_fecha_actualizacion);
    }

    private void CargarDependientes()
    {
        string selA = string.IsNullOrEmpty(_areaEditar) ? cboArea.SelectedValue : _areaEditar;
        string selE = string.IsNullOrEmpty(_activoEditar) ? cboActivo.SelectedValue : _activoEditar;
        int cliente = SitioBase.Session.ClienteId(), planta;
        int.TryParse(cboPlanta.SelectedValue, out planta);

        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Sin área", ""));
        if (planta > 0)
        {
            List<InstalacionArea> areas = new InstalacionAreaController().GetInstalacionAreas(
                new InstalacionArea { iar_cliente = cliente, iar_cliente_instalacion = planta, filtro_habilitado = true });
            if (areas != null)
                foreach (InstalacionArea a in areas)
                    cboArea.Items.Add(new RadComboBoxItem(string.IsNullOrEmpty(a.ruta) ? a.iar_nombre : a.ruta, a.iar_id.ToString()));
        }

        cboActivo.Items.Clear();
        cboActivo.Items.Add(new RadComboBoxItem("Sin equipo", ""));
        Activo fa = new Activo { act_cliente = cliente, filtro_habilitado = true };
        if (planta > 0) fa.filtro_cliente_instalacion = planta;
        List<Activo> activos = new ActivoController().GetActivos(fa);
        if (activos != null)
            foreach (Activo a in activos)
                cboActivo.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));

        RadComboBoxItem ia = cboArea.FindItemByValue(selA ?? ""); if (ia != null) ia.Selected = true;
        RadComboBoxItem ie = cboActivo.FindItemByValue(selE ?? ""); if (ie != null) ie.Selected = true;
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR TAREAS");

        txtCodigo.ReadOnly = Id > 0;
        txtTitulo.ReadOnly = txtDescripcion.ReadOnly = txtDuracion.ReadOnly = !puedeEditar;
        cboPrioridad.ReadOnly = cboPlanta.ReadOnly = cboArea.ReadOnly = cboActivo.ReadOnly = !puedeEditar;
        chkEvidencia.Enabled = chkHabilitada.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;

        lnkNuevaProgramacion.Visible = puedeEditar && Id > 0;
        lnkGenerarOcurrencias.Visible = puedeEditar && Id > 0;

        pnlResponder.Visible = Id > 0 && Token.Puede("COMENTAR TAREA");

        hdnNueva.Value = Id == 0 ? "1" : "0";
    }

    #endregion

    #region Pintado

    private void Pintar()
    {
        litEvidencia.Text = chkEvidencia.Checked ? "Sí" : "No";
        litHabilitada.Text = chkHabilitada.Checked ? "Activa" : "Apagada";

        if (Id == 0)
        {
            litCodigo.Text = "Nueva";
            litChips.Text = "";
            return;
        }

        Tarea t = LaTarea();

        litTitulo.Text = "Tareas recurrentes";
        litSubtitulo.Text = "";

        litCodigo.Text = Server.HtmlEncode(t.tar_codigo);
        litCabTitulo.Text = Server.HtmlEncode(t.tar_titulo);

        List<string> donde = new List<string>();
        if (!string.IsNullOrEmpty(t.planta_nombre)) donde.Add(t.planta_nombre);
        if (!string.IsNullOrEmpty(t.area_nombre)) donde.Add(t.area_nombre);
        if (!string.IsNullOrEmpty(t.activo_codigo)) donde.Add(t.activo_codigo + " " + t.activo_nombre);
        litCabSub.Text = Server.HtmlEncode(string.Join(" · ", donde.ToArray()));

        litChips.Text = chkHabilitada.Checked
            ? "<span class=\"sg-ot-chip es-ejecucion\"><i class=\"mdi mdi-circle-medium\"></i>Activa</span>"
            : "<span class=\"sg-ot-chip es-anulada\"><i class=\"mdi mdi-circle-medium\"></i>Apagada</span>";

        PintarProgramaciones();
        PintarOcurrencias();
        PintarEvidencias();
        PintarResumen(t);
        PintarComentarios();
    }

    private void PintarProgramaciones()
    {
        List<TareaProgramacion> lista = new TareaController().GetTareaProgramaciones(
            new TareaProgramacion { filtro_cliente = SitioBase.Session.ClienteId(), filtro_tarea = Id }) ?? new List<TareaProgramacion>();

        rptProgramaciones.DataSource = lista.Select(p => new
        {
            id = p.tpr_id,
            nombre = p.programacion_nombre,
            tipo = p.programacion_tipo_nombre,
            responsable = string.IsNullOrEmpty(p.responsable_nombre)
                ? "<span class=\"sg-ot-vacio-txt\">Sin responsable</span>"
                : "<i class=\"mdi mdi-account-outline\"></i>" + Server.HtmlEncode(p.responsable_nombre),
            grupo = string.IsNullOrEmpty(p.grupo_nombre)
                ? "<span class=\"sg-ot-vacio-txt\">Sin grupo</span>"
                : Server.HtmlEncode(p.grupo_nombre),
            inicio = p.programacion_fecha_inicio == null ? "—" : "Desde " + p.programacion_fecha_inicio.Value.ToString("dd MMM yyyy"),
            estado = p.tpr_habilitado && p.programacion_habilitado
                ? "<span class=\"sg-ot-chip es-ejecucion\"><i class=\"mdi mdi-circle-medium\"></i>Activa</span>"
                : "<span class=\"sg-ot-chip es-anulada\"><i class=\"mdi mdi-circle-medium\"></i>Apagada</span>"
        }).ToList();
        rptProgramaciones.DataBind();

        pnlSinProgramaciones.Visible = lista.Count == 0;
    }

    /// <summary>
    /// La lista de ocurrencias, sus contadores y el detalle de la elegida.
    ///
    /// "Futura" no es un estado de la base: es una pendiente cuya fecha
    /// todavia no llega. Se distingue porque lo que se hace con una y con otra
    /// es distinto -a la de ayer hay que ir a buscarla, a la del mes que viene
    /// no- y en la lista se veian iguales.
    /// </summary>
    private void PintarOcurrencias()
    {
        List<TareaOcurrencia> lista = Ocurrencias();
        DateTime hoy = global::SitioBase.Hora.Hoy;

        if (Ocurrencia == 0 && lista.Count > 0)
        {
            TareaOcurrencia ultima = lista.LastOrDefault(o => o.ejecutada);
            Ocurrencia = (ultima ?? lista[0]).toc_id;
        }

        CargarResponsables(lista);

        rptOcurrencias.DataSource = lista.Select(o => new
        {
            id = o.toc_id,
            grupo = Grupo(o, hoy),
            fecha = o.prevista == null ? "—" : o.prevista.Value.ToString("dd MMM yyyy HH:mm"),
            responsable = string.IsNullOrEmpty(o.responsable) ? "Sin responsable" : o.responsable,
            estado = ChipEstado(o, hoy),
            ejecucion = o.ejecutada
                ? Server.HtmlEncode(o.ejecutor) + " <span class=\"sg-ot-vacio-txt\">· " + o.fin.Value.ToString("dd MMM HH:mm") + "</span>"
                : "<span class=\"sg-ot-vacio-txt\">Sin ejecución</span>",
            elegida = o.toc_id == Ocurrencia
        }).ToList();
        rptOcurrencias.DataBind();

        pnlSinOcurrencias.Visible = lista.Count == 0;

        litConteoTodas.Text = lista.Count.ToString();
        litConteoCompletadas.Text = lista.Count(o => Grupo(o, hoy) == "completada").ToString();
        litConteoPendientes.Text = lista.Count(o => Grupo(o, hoy) == "pendiente").ToString();
        litConteoFuturas.Text = lista.Count(o => Grupo(o, hoy) == "futura").ToString();

        litOcurrencia.Text = Detalle(lista.FirstOrDefault(o => o.toc_id == Ocurrencia), hoy);
    }

    /// <summary>En que cubo cae la ocurrencia para los contadores de arriba.</summary>
    private static string Grupo(TareaOcurrencia o, DateTime hoy)
    {
        if (o.estado_id == 4) return "completada";
        if (o.estado_id == 5 || o.estado_id == 6) return "cerrada";
        if (o.prevista != null && o.prevista.Value.Date > hoy) return "futura";
        return "pendiente";
    }

    private string ChipEstado(TareaOcurrencia o, DateTime hoy)
    {
        string grupo = Grupo(o, hoy);

        switch (grupo)
        {
            case "completada": return "<span class=\"sg-ot-chip es-ejecucion\"><span class=\"sg-ta-punto es-ok\"></span>" + Server.HtmlEncode(o.estado_nombre) + "</span>";
            case "futura": return "<span class=\"sg-ot-chip es-anulada\"><span class=\"sg-ta-punto es-futura\"></span>Futura</span>";
            case "cerrada": return "<span class=\"sg-ot-chip es-critica\"><span class=\"sg-ta-punto es-mala\"></span>" + Server.HtmlEncode(o.estado_nombre) + "</span>";
            default: return "<span class=\"sg-ot-chip es-espera\"><span class=\"sg-ta-punto es-pendiente\"></span>" + Server.HtmlEncode(o.estado_nombre) + "</span>";
        }
    }

    /// <summary>El panel de la derecha: la ocurrencia elegida, completa.</summary>
    private string Detalle(TareaOcurrencia o, DateTime hoy)
    {
        if (o == null)
            return "<div class=\"sg-ot-vacio\"><i class=\"mdi mdi-calendar-search\"></i>" +
                   "<p>Elija una ocurrencia</p><span>Su detalle se muestra acá.</span></div>";

        StringBuilder s = new StringBuilder();

        s.Append("<header class=\"sg-ot-card-cab\"><span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-calendar-check-outline\"></i></span>")
         .Append("<h3>Ocurrencia del ").Append(o.prevista == null ? "—" : o.prevista.Value.ToString("dd MMM")).Append("</h3>")
         .Append("<span class=\"sg-ot-card-acc\">").Append(ChipEstado(o, hoy)).Append("</span></header>");

        s.Append(Dato("mdi-calendar-sync-outline", "Programación", string.IsNullOrEmpty(o.programacion) ? "Suelta" : o.programacion));
        s.Append(Dato("mdi-calendar-outline", "Fecha prevista", o.prevista == null ? "" : o.prevista.Value.ToString("dd MMM yyyy HH:mm")));
        s.Append(Dato("mdi-account-outline", "Responsable", o.responsable));

        if (o.ejecutada)
        {
            s.Append(Dato("mdi-account-check-outline", "Ejecutada por", o.ejecutor));
            s.Append(Dato("mdi-clock-check-outline", "Finalizada", o.fin.Value.ToString("dd MMM yyyy HH:mm")));
            if (o.minutos != null) s.Append(Dato("mdi-timer-outline", "Tomó", o.minutos + " min"));
            s.Append(Dato("mdi-cellphone", "Origen", o.origen));
        }

        // ---- lo que dejo escrito ----
        string texto = !string.IsNullOrEmpty(o.resultado) ? o.resultado : o.observacion;

        s.Append("<div class=\"sg-ot-sub-titulo\">Observación</div>");
        s.Append(string.IsNullOrEmpty(texto)
            ? "<p class=\"sg-ot-vacio-txt\">No se dejó observación.</p>"
            : "<div class=\"sg-ot-respuesta\">“" + Server.HtmlEncode(texto) + "”</div>");

        // ---- las fotos ----
        List<TareaOcurrenciaArchivo> fotos = new TareaOcurrenciaController().GetEvidencias(o.toc_id);

        s.Append("<div class=\"sg-ot-sub-titulo\">Evidencias</div>");

        if (fotos.Count == 0)
        {
            Tarea t = LaTarea();
            s.Append("<div class=\"sg-ta-sin-fotos\"><i class=\"mdi mdi-file-image-outline\"></i>")
             .Append("<div><strong>No se adjuntaron archivos</strong><span>")
             .Append(t.tar_requiere_evidencia ? "La tarea exige evidencia: falta el respaldo." : "Evidencia no obligatoria.")
             .Append("</span></div></div>");
        }
        else
        {
            s.Append("<div class=\"sg-ot-miniaturas\">");
            foreach (TareaOcurrenciaArchivo a in fotos)
                s.Append(a.es_imagen
                    ? "<a class=\"sg-ot-mini\" href=\"" + UrlArchivo(a.arc_id) + "\" target=\"_blank\"><img src=\"" + UrlArchivo(a.arc_id) + "\" alt=\"" + Server.HtmlEncode(a.etiqueta) + "\" /></a>"
                    : "<a class=\"sg-ot-mini es-doc\" href=\"" + UrlArchivo(a.arc_id) + "\" target=\"_blank\"><i class=\"mdi mdi-file-document-outline\"></i></a>");
            s.Append("</div>");
        }

        // ---- la conversacion ----
        s.Append("<a href=\"#\" class=\"sg-ot-btn es-plano sg-ta-ver-conversacion\" data-ir=\"comentarios\">")
         .Append("<i class=\"mdi mdi-comment-text-outline\"></i>Ver conversación")
         .Append(o.comentarios > 0 ? " (" + o.comentarios + ")" : "").Append("</a>");

        return s.ToString();
    }

    private string Dato(string icono, string etiqueta, string valor)
    {
        return "<div class=\"sg-ot-dato\"><span class=\"sg-ot-dato-ico\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-ot-dato-etq\">" + Server.HtmlEncode(etiqueta) + "</span>" +
               "<span class=\"sg-ot-dato-val\">" + Server.HtmlEncode(string.IsNullOrEmpty(valor) ? "—" : valor) + "</span></div></div>";
    }

    private string UrlArchivo(int id)
    {
        return ResolveUrl("~/View/Comun/Archivos/VerArchivo.aspx") + "?query=" + Cifrar("Id=" + id + "&Modo=VER");
    }

    private void PintarResumen(Tarea t)
    {
        List<TareaOcurrencia> lista = Ocurrencias();
        DateTime hoy = global::SitioBase.Hora.Hoy;

        TareaOcurrencia proxima = lista.Where(o => Grupo(o, hoy) == "pendiente" || Grupo(o, hoy) == "futura")
                                       .OrderBy(o => o.prevista).FirstOrDefault();

        StringBuilder s = new StringBuilder();

        s.Append(Kpi("mdi-timer-outline",
                 t.tar_duracion_estimada_minuto == null ? "Sin estimar" : t.tar_duracion_estimada_minuto + " min",
                 "Duración estimada"));
        s.Append(Kpi("mdi-flag-outline", t.prioridad_nombre, "Nivel de prioridad"));
        s.Append(Kpi("mdi-calendar-sync-outline", t.programaciones + (t.programaciones == 1 ? " programación" : " programaciones"), "Generan las ocurrencias"));
        s.Append(Kpi("mdi-clock-outline",
                 proxima == null ? "Sin próximas" : proxima.prevista.Value.ToString("dd MMM yyyy"),
                 proxima == null ? "No hay ocurrencias por venir" : "Próxima ocurrencia"));

        s.Append("<div class=\"sg-ot-nota es-chica\"><i class=\"mdi mdi-information-outline\"></i>")
         .Append("<span>Las ocurrencias se generan automáticamente según las programaciones configuradas.</span></div>");

        litResumen.Text = s.ToString();

        litInformacion.Text =
            Dato("mdi-account-outline", "Creada por", t.usuario_creacion_nombre) +
            Dato("mdi-calendar-outline", "Fecha de creación", t.tar_fecha_creacion == null ? "" : t.tar_fecha_creacion.Value.ToString("dd-MM-yyyy HH:mm")) +
            (string.IsNullOrEmpty(t.usuario_actualizacion_nombre) ? "" :
                Dato("mdi-pencil-outline", "Última edición",
                     t.usuario_actualizacion_nombre + (t.tar_fecha_actualizacion == null ? "" : " · " + t.tar_fecha_actualizacion.Value.ToString("dd-MM-yyyy HH:mm"))));
    }

    private string Kpi(string icono, string valor, string etiqueta)
    {
        return "<div class=\"sg-ta-kpi\"><span class=\"sg-ot-card-ico\"><i class=\"mdi " + icono + "\"></i></span>" +
               "<div><span class=\"sg-ta-kpi-valor\">" + Server.HtmlEncode(valor ?? "—") + "</span>" +
               "<span class=\"sg-ta-kpi-etq\">" + Server.HtmlEncode(etiqueta) + "</span></div></div>";
    }

    private void CargarResponsables(List<TareaOcurrencia> lista)
    {
        if (cboResponsable.Items.Count > 0) return;

        cboResponsable.Items.Add(new RadComboBoxItem("Todos", ""));

        foreach (TareaOcurrencia o in lista.Where(x => x.responsable_id != null)
                                           .GroupBy(x => x.responsable_id.Value).Select(g => g.First()))
            cboResponsable.Items.Add(new RadComboBoxItem(o.responsable, o.responsable_id.Value.ToString()));
    }

    #endregion

    /// <summary>
    /// La galeria de la tarea: todo lo que llego del terreno, con la
    /// ocurrencia de la que vino.
    ///
    /// Cada tarjeta lleva lo suyo en atributos -tipo, ocurrencia, texto
    /// buscable y los datos del detalle-, asi que filtrar y abrir una
    /// evidencia no le cuesta un viaje al servidor.
    /// </summary>
    private void PintarEvidencias()
    {
        List<TareaOcurrenciaArchivo> ev = new TareaOcurrenciaController().GetEvidenciasTarea(Id);

        litEvTodas.Text = ev.Count.ToString();
        litEvFotos.Text = ev.Count(a => a.es_imagen).ToString();
        litEvVideos.Text = ev.Count(a => a.es_video).ToString();
        litEvArchivos.Text = ev.Count(a => a.es_documento || a.es_audio).ToString();

        pnlSinEvidencias.Visible = ev.Count == 0;

        StringBuilder s = new StringBuilder();

        foreach (TareaOcurrenciaArchivo a in ev)
        {
            string tipo = a.es_imagen ? "imagen" : a.es_video ? "video" : "documento";
            string url = UrlArchivo(a.arc_id);
            string cuando = a.ocurrencia_fecha == null ? "Ocurrencia " + a.ocurrencia
                                                       : "Ocurrencia del " + a.ocurrencia_fecha.Value.ToString("dd MMM yyyy");

            s.Append("<article class=\"sg-ot-ev-card\" data-tipo=\"").Append(tipo)
             .Append("\" data-paso=\"").Append(a.ocurrencia)
             .Append("\" data-buscar=\"").Append(Server.HtmlEncode((a.etiqueta + " " + a.descripcion + " " + cuando).ToLower()))
             .Append("\" data-url=\"").Append(url)
             .Append("\" data-titulo=\"").Append(Server.HtmlEncode(a.etiqueta))
             .Append("\" data-paso-txt=\"").Append(Server.HtmlEncode(cuando))
             .Append("\" data-usuario=\"").Append(Server.HtmlEncode(a.usuario))
             .Append("\" data-fecha=\"").Append(a.fecha == null ? "" : a.fecha.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append("\" data-obs=\"").Append(Server.HtmlEncode(a.descripcion))
             .Append("\" data-icono=\"").Append(IconoArchivo(a))
             .Append("\" data-imagen=\"").Append(a.es_imagen ? "1" : "0").Append("\">");

            s.Append("<span class=\"sg-ot-ev-foto\">");
            if (a.es_imagen) s.Append("<img src=\"").Append(url).Append("\" alt=\"").Append(Server.HtmlEncode(a.etiqueta)).Append("\" />");
            else s.Append("<i class=\"mdi ").Append(IconoArchivo(a)).Append(" sg-ot-ev-icono\"></i>");
            s.Append("<span class=\"sg-ot-ev-tipo\"><i class=\"mdi ").Append(IconoArchivo(a)).Append("\"></i></span>");
            s.Append("</span>");

            s.Append("<div class=\"sg-ot-ev-txt\"><span class=\"sg-ot-ev-nom\">").Append(Server.HtmlEncode(a.etiqueta)).Append("</span>")
             .Append("<span class=\"sg-ot-ev-meta\">").Append(Server.HtmlEncode(a.usuario))
             .Append(a.fecha == null ? "" : " · " + a.fecha.Value.ToString("dd MMM yyyy")).Append("</span>")
             .Append("<span class=\"sg-ot-ev-paso\">").Append(Server.HtmlEncode(cuando)).Append("</span>")
             .Append("</div></article>");
        }

        litEvidencias.Text = s.ToString();
    }

    private static string IconoArchivo(TareaOcurrenciaArchivo a)
    {
        if (a.es_imagen) return "mdi-image-outline";
        if (a.es_video) return "mdi-video-outline";
        if (a.es_audio) return "mdi-microphone-outline";
        return "mdi-file-document-outline";
    }

    #region Comentarios (HU-104)

    /// <summary>
    /// La conversacion, agrupada por ocurrencia y con las respuestas colgando
    /// de su comentario. Una grilla plana perderia el hilo, que es lo que se
    /// viene a leer.
    /// </summary>
    private void PintarComentarios()
    {
        List<TareaComentario> lista = new TareaController().GetTareaComentarios(
            new TareaComentario { filtro_cliente = SitioBase.Session.ClienteId(), filtro_tarea = Id }) ?? new List<TareaComentario>();

        // ---- el combo de ocurrencias con conversacion ----
        if (cboOcurrenciaComentario.Items.Count == 0)
        {
            cboOcurrenciaComentario.Items.Add(new RadComboBoxItem("Todas las ocurrencias", ""));

            foreach (TareaComentario c in lista.GroupBy(x => x.tco_tarea_ocurrencia).Select(g => g.First()))
                cboOcurrenciaComentario.Items.Add(new RadComboBoxItem(
                    c.ocurrencia_fecha == null ? "Ocurrencia " + c.tco_tarea_ocurrencia : c.ocurrencia_fecha.Value.ToString("dd MMM yyyy · HH:mm"),
                    c.tco_tarea_ocurrencia.ToString()));
        }

        int filtro;
        if (int.TryParse(cboOcurrenciaComentario.SelectedValue, out filtro) && filtro > 0)
            lista = lista.Where(c => c.tco_tarea_ocurrencia == filtro).ToList();

        pnlSinComentarios.Visible = lista.Count == 0;

        StringBuilder s = new StringBuilder();

        foreach (IGrouping<int, TareaComentario> grupo in lista.GroupBy(c => c.tco_tarea_ocurrencia))
        {
            TareaComentario cab = grupo.First();

            s.Append("<section class=\"sg-ta-hilo\" data-ocurrencia=\"").Append(grupo.Key).Append("\">")
             .Append("<header class=\"sg-ta-hilo-cab\"><span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-calendar-check-outline\"></i></span>")
             .Append("<div><strong>Ocurrencia del ")
             .Append(cab.ocurrencia_fecha == null ? "—" : cab.ocurrencia_fecha.Value.ToString("dd MMM yyyy · HH:mm"))
             .Append("</strong><span>").Append(grupo.Count()).Append(grupo.Count() == 1 ? " comentario" : " comentarios").Append("</span></div>")
             .Append("<span class=\"sg-ot-card-acc\">").Append(ChipOcurrencia(cab)).Append("</span></header>");

            foreach (TareaComentario c in grupo)
            {
                bool esRespuesta = c.tco_comentario_padre != null;

                s.Append("<article class=\"sg-ta-com").Append(esRespuesta ? " es-respuesta" : "").Append("\">")
                 .Append("<span class=\"sg-ot-avatar\">").Append(Iniciales(c.usuario_nombre)).Append("</span>")
                 .Append("<div class=\"sg-ta-com-txt\"><div class=\"sg-ta-com-meta\"><strong>")
                 .Append(Server.HtmlEncode(c.usuario_nombre)).Append("</strong>")
                 .Append("<span class=\"sg-ta-origen\">").Append(c.tco_dictado_voz != null ? "App móvil" : "Web").Append("</span>")
                 .Append("<span>").Append(c.tco_fecha_creacion == null ? "" : c.tco_fecha_creacion.Value.ToString("dd MMM yyyy HH:mm")).Append("</span>")
                 .Append("</div><p>").Append(Server.HtmlEncode(c.tco_texto)).Append("</p>");

                if (pnlResponder.Visible)
                    s.Append("<a href=\"#\" class=\"sg-ot-link sg-ta-responder-a\" data-ocurrencia=\"").Append(c.tco_tarea_ocurrencia)
                     .Append("\" data-padre=\"").Append(c.tco_id)
                     .Append("\" data-nombre=\"").Append(Server.HtmlEncode(c.usuario_nombre))
                     .Append("\"><i class=\"mdi mdi-reply\"></i>Responder</a>");

                s.Append("</div></article>");
            }

            s.Append("</section>");
        }

        litHilos.Text = s.ToString();

        // ---- el contexto de la derecha ----
        TareaOcurrencia oc = Ocurrencias().FirstOrDefault(o => o.toc_id == Ocurrencia);
        DateTime hoy = global::SitioBase.Hora.Hoy;

        StringBuilder ctx = new StringBuilder();

        ctx.Append("<header class=\"sg-ot-card-cab\"><span class=\"sg-ot-card-ico\"><i class=\"mdi mdi-file-document-outline\"></i></span>")
           .Append("<h3>Contexto de la ejecución</h3>")
           .Append(oc == null ? "" : "<span class=\"sg-ot-card-acc\">" + ChipEstado(oc, hoy) + "</span>")
           .Append("</header>");

        Tarea t = LaTarea();

        ctx.Append(Dato("mdi-cog-outline", "Equipo", string.IsNullOrEmpty(t.activo_codigo) ? "" : t.activo_codigo + " " + t.activo_nombre));
        ctx.Append(Dato("mdi-factory", "Planta", t.planta_nombre));

        if (oc != null)
        {
            ctx.Append(Dato("mdi-calendar-sync-outline", "Programación", oc.programacion));
            ctx.Append(Dato("mdi-account-outline", "Responsable", oc.responsable));
            if (oc.ejecutada)
            {
                ctx.Append(Dato("mdi-account-check-outline", "Ejecutada por", oc.ejecutor));
                ctx.Append(Dato("mdi-clock-check-outline", "Finalizada", oc.fin.Value.ToString("dd MMM yyyy HH:mm")));
            }
        }

        litContextoComentario.Text = ctx.ToString();

        litInstruccion.Text = string.IsNullOrEmpty(t.tar_descripcion)
            ? "<p class=\"sg-ot-vacio-txt\">Esta tarea no tiene instrucciones escritas.</p>"
            : "<p class=\"sg-ot-texto\">" + Server.HtmlEncode(t.tar_descripcion) + "</p>";

        // ---- a quien se le responde ----
        int padre;
        if (int.TryParse(hidPadre.Value, out padre) && padre > 0)
        {
            TareaComentario al = lista.FirstOrDefault(c => c.tco_id == padre);
            litRespondiendo.Text = al == null ? "Nueva respuesta" : "Respondiendo a <strong>" + Server.HtmlEncode(al.usuario_nombre) + "</strong>";
        }
        else
        {
            int oco;
            litRespondiendo.Text = int.TryParse(hidOcurrencia.Value, out oco) && oco > 0
                ? "Comentario nuevo en la ocurrencia elegida"
                : "Elija una ocurrencia o responda un comentario";
        }
    }

    private string ChipOcurrencia(TareaComentario c)
    {
        switch ((c.ocurrencia_estado_codigo ?? "").ToUpperInvariant())
        {
            case "COMPLETADA": return "<span class=\"sg-ot-chip es-ejecucion\"><span class=\"sg-ta-punto es-ok\"></span>" + Server.HtmlEncode(c.ocurrencia_estado_nombre) + "</span>";
            case "NO REALIZADA":
            case "CANCELADA": return "<span class=\"sg-ot-chip es-critica\">" + Server.HtmlEncode(c.ocurrencia_estado_nombre) + "</span>";
            default: return "<span class=\"sg-ot-chip es-espera\">" + Server.HtmlEncode(c.ocurrencia_estado_nombre) + "</span>";
        }
    }

    public static string Iniciales(string nombre)
    {
        string[] partes = (nombre ?? "").Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        if (partes.Length == 0) return "?";
        if (partes.Length == 1) return partes[0].Substring(0, 1).ToUpper();
        return (partes[0].Substring(0, 1) + partes[1].Substring(0, 1)).ToUpper();
    }

    protected void btnComentar_Click(object sender, EventArgs e)
    {
        Pestana("comentarios");
        try
        {
            if (!Token.Puede("COMENTAR TAREA")) throw new Exception("No tiene permiso para comentar tareas.");

            int ocurrencia, padre;
            if (!int.TryParse(hidOcurrencia.Value, out ocurrencia) || ocurrencia <= 0)
                throw new Exception("Elija en qué ocurrencia comentar: use «Responder» en un comentario o elija la ocurrencia arriba.");

            if (string.IsNullOrEmpty(txtComentario.Text.Trim()))
                throw new Exception("Escriba la respuesta antes de publicarla.");

            TareaComentario c = new TareaComentario { tco_tarea_ocurrencia = ocurrencia, tco_texto = txtComentario.Text.Trim() };
            if (int.TryParse(hidPadre.Value, out padre) && padre > 0) c.tco_comentario_padre = padre;

            Respuesta r = new TareaController().InsertTareaComentario(c);

            if (!r.error)
            {
                txtComentario.Text = "";
                hidPadre.Value = "";
            }

            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion

    #region Acciones

    protected void lnkRefrescar_Click(object sender, EventArgs e)
    {
        // El modal de programacion guardo: se repinta sin recargar la pagina.
        Pestana("configuracion");
    }

    protected void rptProgramaciones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        Pestana("configuracion");
        try
        {
            int id;
            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;

            if (e.CommandName == "quitar")
            {
                Respuesta r = new TareaController().DeleteTareaProgramacion(new TareaProgramacion { tpr_id = id });
                Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
                return;
            }

            if (e.CommandName == "editar")
                ScriptManager.RegisterStartupScript(udPanel, udPanel.GetType(), "abrirProg",
                    "abrirTareaProgramacion('" + Cifrar("Id=" + id + "&Tarea=" + Id) + "');", true);
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    protected void rptOcurrencias_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        Pestana("ocurrencias");

        int id;
        if (e.CommandName == "sel" && int.TryParse(Convert.ToString(e.CommandArgument), out id))
        {
            Ocurrencia = id;

            /* Elegir una ocurrencia tambien prepara la conversacion: si la
               persona pasa a Comentarios, el comentario nuevo cae donde
               estaba mirando y no en el vacio. */
            hidOcurrencia.Value = id.ToString();
            hidPadre.Value = "";
        }
    }

    protected void lnkGenerarOcurrencias_Click(object sender, EventArgs e)
    {
        Pestana("ocurrencias");
        try
        {
            if (!Token.Puede("CREAR EDITAR TAREAS")) throw new Exception("No tiene permiso para generar ocurrencias.");

            Respuesta r = new TareaController().GenerarOcurrencias(Id, 90);
            _ocurrencias = null;

            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    protected void btnVolver_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/View/Mantenimiento/Tareas/Tareas.aspx");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        Pestana("configuracion");
        try
        {
            Tarea t = new Tarea();
            TareaController controller = new TareaController();

            t.tar_id = Id;
            t.tar_codigo = SitioBase.CodigoModulo.Componer("Tarea", txtCodigo.Text);
            t.tar_titulo = txtTitulo.Text.Trim();
            t.tar_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            if (t.tar_descripcion == null) t.quita_descripcion = true;
            t.tar_tarea_prioridad = int.Parse(cboPrioridad.SelectedValue);
            t.tar_requiere_evidencia = chkEvidencia.Checked;
            t.tar_habilitado = chkHabilitada.Checked;

            if (!string.IsNullOrEmpty(txtDuracion.Text.Trim()))
            {
                int d;
                if (!int.TryParse(txtDuracion.Text.Trim(), out d) || d <= 0)
                    throw new Exception("La duración estimada tiene que ser un número entero de minutos mayor que cero.");
                t.tar_duracion_estimada_minuto = d;
            }
            else t.quita_duracion = true;

            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue)) t.tar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue); else t.quita_instalacion = true;
            if (!string.IsNullOrEmpty(cboArea.SelectedValue)) t.tar_instalacion_area = int.Parse(cboArea.SelectedValue); else t.quita_area = true;
            if (!string.IsNullOrEmpty(cboActivo.SelectedValue)) t.tar_activo = int.Parse(cboActivo.SelectedValue); else t.quita_activo = true;

            bool nueva = Id == 0;
            Respuesta r = nueva ? controller.InsertTarea(t) : controller.UpdateTarea(t);

            if (r.error) { Tools.tools.ClientAlert(r.detalle, "alerta"); return; }

            // Una tarea recien creada cambia de direccion: el id va cifrado.
            if (nueva) Response.Redirect("~/View/Mantenimiento/Tareas/Tarea.aspx?query=" + Cifrar("Id=" + r.codigo));

            _tarea = null;
            Tools.tools.ClientAlert(r.detalle, "ok");
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    /// <summary>
    /// Las ocurrencias del periodo, en una planilla. Lo que se exporta es lo
    /// que se esta mirando -mismos filtros- y no la tabla entera: bajar un
    /// archivo distinto del que muestra la pantalla es la forma mas rapida de
    /// que dos personas discutan con dos numeros.
    /// </summary>
    protected void btnExportar_Click(object sender, EventArgs e)
    {
        try
        {
            List<TareaOcurrencia> lista = Ocurrencias();
            DateTime hoy = global::SitioBase.Hora.Hoy;

            using (ExcelPackage excel = new ExcelPackage())
            {
                ExcelWorksheet h = excel.Workbook.Worksheets.Add("OCURRENCIAS");

                string[] cols = { "FECHA PREVISTA", "RESPONSABLE", "ESTADO", "EJECUTADA POR", "FINALIZADA", "MINUTOS", "OBSERVACION", "EVIDENCIAS", "COMENTARIOS" };
                for (int i = 0; i < cols.Length; i++)
                {
                    h.Cells[1, i + 1].Value = cols[i];
                    h.Cells[1, i + 1].Style.Font.Bold = true;
                }

                int f = 2;
                foreach (TareaOcurrencia o in lista)
                {
                    h.Cells[f, 1].Value = o.prevista == null ? "" : o.prevista.Value.ToString("dd-MM-yyyy HH:mm");
                    h.Cells[f, 2].Value = o.responsable;
                    h.Cells[f, 3].Value = Grupo(o, hoy) == "futura" ? "Futura" : o.estado_nombre;
                    h.Cells[f, 4].Value = o.ejecutor;
                    h.Cells[f, 5].Value = o.fin == null ? "" : o.fin.Value.ToString("dd-MM-yyyy HH:mm");
                    h.Cells[f, 6].Value = o.minutos;
                    h.Cells[f, 7].Value = !string.IsNullOrEmpty(o.resultado) ? o.resultado : o.observacion;
                    h.Cells[f, 8].Value = o.evidencias;
                    h.Cells[f, 9].Value = o.comentarios;
                    f++;
                }

                h.Columns.AutoFit();

                Tarea t = LaTarea();
                string archivo = "OCURRENCIAS " + t.tar_codigo + " " + global::SitioBase.Hora.Ahora.ToString("dd-MM-yyyy");

                Response.Clear();
                Response.ContentType = "application/vnd.ms-excel";
                Response.HeaderEncoding = Encoding.Default;
                Response.ContentEncoding = Encoding.Default;
                Response.AddHeader("content-disposition", "attachment; filename=" + archivo + ".xlsx");
                Response.BinaryWrite(excel.GetAsByteArray());
                Response.End();
            }
        }
        catch (System.Threading.ThreadAbortException) { throw; }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }

    #endregion
}
