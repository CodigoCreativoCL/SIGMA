using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Permisos de trabajo — vista única con dos pestañas (10-10-2026).
///
/// Antes eran dos pantallas sueltas bajo la carpeta «Permisos de trabajo»:
///   - Registro de permisos (HU-063, bloque 94): listar, crear y editar; la
///     situación se calcula contra hoy.
///   - Vigentes y por vencer (HU-064, bloque 97): solo lectura, los tres
///     números arriba y el aviso configurable, «para no descubrir en terreno
///     que el permiso caducó».
/// Se unifican en esta pantalla con pestañas, como en Proveedores (y antes en
/// Activos y Mantenimiento), para que Terceros quede con dos ítems:
/// Proveedores y Permisos de trabajo. El detalle sigue en el modal
/// (PermisoTrabajo.aspx).
///
/// LAS DOS PESTAÑAS COMPARTEN EL PERMISO
///   Ambas cuelgan de VER PERMISOS TRABAJO. La situación se calcula en cada
///   consulta (FNC_PERMISO_SITUACION) contra la fecha de hoy: un estado
///   guardado envejecería solo.
/// </summary>
public partial class View_Terceros_PermisosTrabajo_PermisoTrabajos : System.Web.UI.Page
{
    /// <summary>Pestaña activa: "R" Registro (por defecto) o "V" Vigentes.</summary>
    private string Tab
    {
        get { return (ViewState["Tab"] as string) ?? "R"; }
        set { ViewState["Tab"] = value; }
    }

    /// <summary>
    /// En Vigentes, qué situación se está mirando: "" son todas, o
    /// VENCIDO / POR VENCER (lo elige la tarjeta que se tocó).
    /// </summary>
    public string Situacion
    {
        get { return ViewState["Situacion"] != null ? (string)ViewState["Situacion"] : ""; }
        set { ViewState["Situacion"] = value; }
    }

    /// <summary>Lo que se pintó en Vigentes, para que la exportación baje exactamente eso.</summary>
    private List<PermisoVigente> _mostrado;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // ---- Columnas del Registro ----
            GridRegistro.AddColumn("PTR_ID", "", Width: "3%");
            GridRegistro.AddTemplateColumn("PERMISO", "", "PERMISO", Width: "30%");
            GridRegistro.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "24%");
            GridRegistro.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "17%");
            GridRegistro.AddTemplateColumn("DOCUMENTO", "", "DOCUMENTO FIRMADO", Width: "26%");

            // ---- Columnas de Vigentes y por vencer ----
            GridVigentes.AddColumn("PTR_ID", "", Width: "3%");
            GridVigentes.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "22%");
            GridVigentes.AddTemplateColumn("PERMISO", "", "PERMISO Y TRABAJO", Width: "33%");
            GridVigentes.AddTemplateColumn("QUIEN", "", "RESPONSABLE Y UBICACIÓN", Width: "27%");
            GridVigentes.AddTemplateColumn("DOCUMENTO", "", "RESPALDO", Width: "15%");

            // Se puede abrir directo en Vigentes con ?tab=V.
            string tab = (Request.QueryString["tab"] ?? "").Trim().ToUpperInvariant();
            if (tab == "V") Tab = "V";
        }

        Tools.tools.RegisterPostBackScript(GridRegistro);
        Tools.tools.RegisterPostBackScript(GridVigentes);
    }

    /// <summary>Poblado de los combos de Tipo (ambas pestañas).</summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboTipo" || ctrl.ID == "cboTipoVig")
            {
                PermisoTrabajoController controller = new PermisoTrabajoController();

                ctrl.Items.Add(new RadComboBoxItem("Todos", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = controller.GetTipos();
                ctrl.DataValueField = "ptt_id";
                ctrl.DataTextField = "ptt_nombre";
                ctrl.DataBind();
            }
        }
    }

    protected void Tab_Click(object sender, EventArgs e)
    {
        LinkButton lb = sender as LinkButton;
        if (lb != null && (lb.CommandArgument == "R" || lb.CommandArgument == "V"))
            Tab = lb.CommandArgument;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool esVigentes = (Tab == "V");

        // ---- Pestañas, paneles y subtítulo ----
        tabRegistro.CssClass = "sg-ter-tab" + (esVigentes ? "" : " is-activa");
        tabVigentes.CssClass = "sg-ter-tab" + (esVigentes ? " is-activa" : "");
        if (esVigentes) tabVigentes.Attributes["aria-selected"] = "true"; else tabRegistro.Attributes["aria-selected"] = "true";

        /* Los dos grupos de filtros viven dentro del template de wucFiltro, así
           que no son campos de la página: se alcanzan con FindControl, igual
           que los combos. */
        Control pfr = wucFiltro.FindControl("pnlFiltroRegistro");
        Control pfv = wucFiltro.FindControl("pnlFiltroVigentes");
        if (pfr != null) pfr.Visible = !esVigentes;
        if (pfv != null) pfv.Visible = esVigentes;

        pnlRegistro.Visible = !esVigentes;
        pnlVigentes.Visible = esVigentes;

        litSubtitulo.Text = esVigentes
            ? "Para no descubrir en terreno que el permiso caducó."
            : "La constancia de que la faena de riesgo se ejecutó con la autorización correspondiente.";

        if (esVigentes) BindVigentes();
        else BindRegistro();

        udPanel.Update();
    }

    // ============================================================ REGISTRO

    private void BindRegistro()
    {
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");

        AvisoAdjunto();
        CargarGridRegistro();
        GridRegistro.DataBind();
    }

    /// <summary>
    /// Se pregunta por el almacenamiento y se dice la verdad. Sin esto la
    /// pantalla se vería normal y el usuario descubriría el problema recién al
    /// intentar autorizar un permiso, con un mensaje que hablaría de un adjunto
    /// que nunca se le ofreció.
    /// </summary>
    protected void AvisoAdjunto()
    {
        IAlmacenamiento almacenamiento = Almacenamiento.Actual();

        if (almacenamiento.Disponible) { pnlSinAdjunto.Visible = false; return; }

        pnlSinAdjunto.Visible = true;

        litSinAdjunto.Text =
            "<strong>Todavía no se puede adjuntar el documento firmado.</strong> " +
            Server.HtmlEncode(almacenamiento.Motivo) +
            "<br />Los permisos se pueden registrar igual y quedan como " +
            "<strong>Solicitado</strong>; para pasarlos a <strong>Autorizado</strong> hace falta " +
            "el papel adjunto, que es la constancia que exige la norma.";
    }

    protected void CargarGridRegistro()
    {
        PermisoTrabajo filtro = new PermisoTrabajo();
        PermisoTrabajoController controller = new PermisoTrabajoController();

        RadComboBox2 cboSituacion = (RadComboBox2)wucFiltro.FindControl("cboSituacion");
        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboSituacion != null && !string.IsNullOrEmpty(cboSituacion.SelectedValue))
            filtro.filtro_situacion = cboSituacion.SelectedValue;

        int aux;
        if (cboTipo != null && int.TryParse(cboTipo.SelectedValue, out aux))
            filtro.filtro_tipo = aux;

        List<PermisoTrabajo> lista = controller.GetPermisos(filtro);

        if (lista == null) lista = new List<PermisoTrabajo>();

        litCuentaReg.Text = lista.Count == 0 ? ""
                          : (lista.Count == 1 ? "1 permiso" : lista.Count + " permisos");

        GridRegistro.DataSource = lista;
    }

    protected void GridRegistro_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        PermisoTrabajo p = item.DataItem as PermisoTrabajo;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.ptr_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.ToolTip = "Abrir detalle del permiso";
        editar.Attributes["aria-label"] = "Abrir detalle del permiso " + Server.HtmlEncode(p.tipo_nombre);
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirPermiso('" + query + "')");

        item["PTR_ID"].Controls.Add(editar);

        // ---- Qué permiso es ----
        string permiso = "<div class=\"sg-permit-identity\"><strong>" + Server.HtmlEncode(p.tipo_nombre) + "</strong>";

        if (!string.IsNullOrEmpty(p.ptr_numero))
            permiso += "<span class=\"sg-permit-folio\"><i class=\"mdi mdi-identifier\"></i>Folio " +
                       Server.HtmlEncode(p.ptr_numero) + "</span>";

        if (!string.IsNullOrEmpty(p.orden_correlativo))
            permiso += "<span class=\"sg-permit-work\"><i class=\"mdi mdi-clipboard-text-outline\"></i>OT " +
                       Server.HtmlEncode(p.orden_correlativo) +
                       (string.IsNullOrEmpty(p.orden_titulo) ? "" : " · " + Server.HtmlEncode(p.orden_titulo)) + "</span>";

        permiso += "</div>";

        item["PERMISO"].Text = permiso;

        /* ---- Hasta cuándo ----
           El chip dice la situación y debajo va en palabras cuánto falta:
           "-5" obliga a interpretar el signo, "Venció hace 5 días" no. */
        string iconoSituacion = p.situacion == "VENCIDO" ? "mdi-close-circle-outline" :
                                 (p.situacion == "POR VENCER" ? "mdi-clock-alert-outline" : "mdi-check-circle-outline");
        string vigencia = "<div class=\"sg-permit-vigencia\"><span class=\"grid-estado-chip " + p.situacion_clase + "\">" +
                          "<i class=\"mdi " + iconoSituacion + "\"></i>" + Server.HtmlEncode(p.situacion) + "</span>" +
                          "<strong>" + Server.HtmlEncode(p.vigencia_texto) + "</strong>";

        if (p.ptr_fecha_vigencia_fin_utc != null)
            vigencia += "<small><i class=\"mdi mdi-calendar-end\"></i>Hasta " +
                        p.ptr_fecha_vigencia_fin_utc.Value.ToString("dd MMM yyyy") + "</small>";

        vigencia += "</div>";

        item["VIGENCIA"].Text = vigencia;

        // ---- En qué estado está y quién lo pidió ----
        string estadoClase = p.estado_codigo == "SOLICITADO" ? " is-pending" :
                             (p.estado_codigo == "AUTORIZADO" ? " is-approved" : "");
        string estado = "<div class=\"sg-permit-context\"><span class=\"sg-permit-workflow" + estadoClase + "\">" +
                        "<i class=\"mdi mdi-progress-check\"></i>" + Server.HtmlEncode(p.estado_nombre) + "</span>";

        /* La cara del solicitante y no un icono generico: en una lista de
           treinta la pregunta frecuente es "¿este quien lo pidio?". */
        if (!string.IsNullOrEmpty(p.solicitante_nombre))
            estado += SitioBase.Avatar.CeldaUno(p.solicitante_id, p.solicitante_nombre,
                                                p.solicitante_foto, "Solicitante");

        estado += "</div>";

        item["ESTADO"].Text = estado;

        /* ---- El documento ----
           Es la columna que importa: un permiso sin su papel no acredita nada,
           y por eso se dice en la lista y no dentro de la ficha. */
        if (p.tiene_archivo)
        {
            item["DOCUMENTO"].Text =
                "<span class=\"grid-estado-chip is-exito\">" +
                "<i class=\"mdi mdi-paperclip\"></i>Adjunto</span>" +
                "<br /><span style=\"font-size:11px;\">" +
                Server.HtmlEncode(p.archivo_nombre) + " · " + p.archivo_peso + "</span>";
        }
        else
        {
            item["DOCUMENTO"].Text =
                "<span class=\"grid-estado-chip is-advertencia\">" +
                "<i class=\"mdi mdi-file-alert-outline\"></i>Sin documento</span>";
        }

        /* `is-current` NO puede usarse aca: es la clase con la que el panel de
           detalle marca la fila abierta. Se llama `is-vigente`. */
        item.CssClass += " sg-permit-row " +
                         (p.situacion == "VENCIDO" ? "is-overdue" :
                          (p.situacion == "POR VENCER" ? "is-expiring" : "is-vigente"));
    }

    // ==================================================== VIGENTES Y POR VENCER

    private void BindVigentes()
    {
        /* La descarga escribe el archivo directo en la respuesta, y eso no
           sobrevive a un postback asíncrono: el UpdatePanel espera un fragmento
           y recibe un binario. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);

        CargarGridVigentes();
        GridVigentes.DataBind();
    }

    protected void CargarGridVigentes()
    {
        PermisoTrabajoController controller = new PermisoTrabajoController();

        RadComboBox2 cboTipoVig = (RadComboBox2)wucFiltro.FindControl("cboTipoVig");
        RadComboBox2 cboAviso = (RadComboBox2)wucFiltro.FindControl("cboAviso");

        int tipo = 0;
        if (cboTipoVig != null) int.TryParse(cboTipoVig.SelectedValue, out tipo);

        int aviso = 7;
        if (cboAviso != null && !int.TryParse(cboAviso.SelectedValue, out aviso)) aviso = 7;

        string texto = wucFiltro.Filtro();

        /* Se trae TODO —vigentes, por vencer y vencidos— y se filtra acá para
           pintar los tres contadores. Pedirle al SP cada situación por separado
           serían tres viajes para mostrar una lista. */
        List<PermisoVigente> todo = controller.GetVigentes(aviso, tipo, true, false, texto);

        if (todo == null) todo = new List<PermisoVigente>();

        int vencidos = 0, porVencer = 0, vigentes = 0;

        foreach (PermisoVigente p in todo)
        {
            if (p.situacion == "VENCIDO") vencidos++;
            else if (p.situacion == "POR VENCER") porVencer++;
            else vigentes++;
        }

        /* El contenido va en `Text` y no en controles hijos: una cadena armada
           acá una sola vez. Las tres tarjetas quedan iguales por construcción. */
        lnkVencidos.Text = Tarjeta(vencidos, "mdi-close-circle-outline", "Vencidos");
        lnkPorVencer.Text = Tarjeta(porVencer, "mdi-clock-alert-outline", "Por vencer");
        lnkVigentes.Text = Tarjeta(vigentes, "mdi-check-circle-outline", "Vigentes");

        // La tarjeta que está filtrando se marca.
        lnkVencidos.CssClass = "sg-resumen-tarjeta is-alerta" + (Situacion == "VENCIDO" ? " is-activa" : "");
        lnkPorVencer.CssClass = "sg-resumen-tarjeta is-advertencia" + (Situacion == "POR VENCER" ? " is-activa" : "");
        lnkVigentes.CssClass = "sg-resumen-tarjeta is-exito" + (string.IsNullOrEmpty(Situacion) ? " is-activa" : "");

        // Lo que se muestra, según la tarjeta que se haya tocado.
        List<PermisoVigente> lista;

        if (string.IsNullOrEmpty(Situacion))
        {
            lista = todo;
            litFiltroActivo.Text = "";
            lnkTodos.Visible = false;
        }
        else
        {
            lista = new List<PermisoVigente>();

            foreach (PermisoVigente p in todo)
                if (p.situacion == Situacion) lista.Add(p);

            litFiltroActivo.Text = "<span class=\"grid-estado-chip is-info\">" +
                                   "<i class=\"mdi mdi-filter-outline\"></i>Mostrando solo: " +
                                   Server.HtmlEncode(Situacion) + "</span>";

            lnkTodos.Visible = true;
        }

        _mostrado = lista;

        pnlVacio.Visible = (lista.Count == 0);

        litVacio.Text = string.IsNullOrEmpty(Situacion) && string.IsNullOrEmpty(texto) && tipo == 0
            ? "No hay permisos con vigencia declarada. Los cerrados y los que no tienen fechas " +
              "están en el Registro de permisos."
            : "Con estos filtros no queda ninguno.";

        litCuentaVig.Text = lista.Count == 0 ? ""
                          : (lista.Count == 1 ? "1 permiso" : lista.Count + " permisos");

        GridVigentes.DataSource = lista;
    }

    protected void GridVigentes_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        PermisoVigente p = item.DataItem as PermisoVigente;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.ptr_id));

        HyperLink abrir = new HyperLink();
        abrir.ID = "lnkAbrir" + item.ItemIndex;
        abrir.CssClass = "icono_Editar";
        abrir.ToolTip = "Abrir detalle del permiso";
        abrir.Attributes["aria-label"] = "Abrir detalle del permiso " + Server.HtmlEncode(p.tipo_nombre);
        abrir.NavigateUrl = "javascript:void(0)";
        abrir.Attributes.Add("onclick", "abrirPermiso('" + query + "')");

        item["PTR_ID"].Controls.Add(abrir);

        /* ---- Cuánto falta ----
           Va primera y no el tipo: la pregunta de esta vista es cuándo caduca,
           no de qué es el permiso. */
        string iconoSituacion = p.situacion == "VENCIDO" ? "mdi-close-circle-outline" :
                                 (p.situacion == "POR VENCER" ? "mdi-clock-alert-outline" : "mdi-check-circle-outline");
        string vigencia = "<div class=\"sg-permit-vigencia\"><span class=\"grid-estado-chip " + p.situacion_clase + "\">" +
                          "<i class=\"mdi " + iconoSituacion + "\"></i>" + Server.HtmlEncode(p.situacion) + "</span>" +
                          "<strong>" + Server.HtmlEncode(p.vigencia_texto) + "</strong>";

        if (p.ptr_fecha_vigencia_inicio_utc != null || p.ptr_fecha_vigencia_fin_utc != null)
            vigencia += "<small><i class=\"mdi mdi-calendar-range\"></i>" +
                        (p.ptr_fecha_vigencia_inicio_utc == null ? "—" : p.ptr_fecha_vigencia_inicio_utc.Value.ToString("dd MMM yyyy")) +
                        " → " + (p.ptr_fecha_vigencia_fin_utc == null ? "sin término" : p.ptr_fecha_vigencia_fin_utc.Value.ToString("dd MMM yyyy")) + "</small>";

        vigencia += "</div>";

        item["VIGENCIA"].Text = vigencia;

        // ---- Qué permiso es ----
        string permiso = "<div class=\"sg-permit-identity\"><strong>" + Server.HtmlEncode(p.tipo_nombre) + "</strong>";

        if (!string.IsNullOrEmpty(p.ptr_numero))
            permiso += "<span class=\"sg-permit-folio\"><i class=\"mdi mdi-identifier\"></i>Folio " +
                       Server.HtmlEncode(p.ptr_numero) + "</span>";

        if (!string.IsNullOrEmpty(p.orden_correlativo))
            permiso += "<span class=\"sg-permit-work\"><i class=\"mdi mdi-clipboard-text-outline\"></i>OT " +
                       Server.HtmlEncode(p.orden_correlativo) +
                       (string.IsNullOrEmpty(p.orden_titulo) ? "" : " · " + Server.HtmlEncode(p.orden_titulo)) + "</span>";

        if (!string.IsNullOrEmpty(p.activo_nombre) || !string.IsNullOrEmpty(p.activo_codigo))
            permiso += "<span class=\"sg-permit-work\"><i class=\"mdi mdi-cog-outline\"></i>" +
                       Server.HtmlEncode((p.activo_codigo + " " + p.activo_nombre).Trim()) + "</span>";

        permiso += "</div>";

        item["PERMISO"].Text = permiso;

        // ---- Quién lo pidió y en qué estado está ----
        string quien = "<div class=\"sg-permit-context\">" +
                       (string.IsNullOrEmpty(p.solicitante_nombre)
                            ? SitioBase.Avatar.SinAsignar("Sin solicitante")
                            : SitioBase.Avatar.CeldaUno(p.solicitante_id, p.solicitante_nombre,
                                                        p.solicitante_foto, "Solicitante")) +
                       "<span class=\"sg-permit-workflow\"><i class=\"mdi mdi-progress-check\"></i>" + Server.HtmlEncode(p.estado_nombre) + "</span>";

        if (!string.IsNullOrEmpty(p.instalacion_nombre))
            quien += "<span><i class=\"mdi mdi-map-marker-outline\"></i>" + Server.HtmlEncode(p.instalacion_nombre) + "</span>";

        quien += "</div>";

        item["QUIEN"].Text = quien;

        /* ---- El documento ----
           Un permiso vigente SIN el papel firmado no acredita nada, y en
           terreno eso importa tanto como la fecha. */
        item["DOCUMENTO"].Text = p.tiene_documento
            ? "<span class=\"grid-estado-chip is-exito\">" +
              "<i class=\"mdi mdi-paperclip\"></i>Adjunto</span>"
            : "<span class=\"grid-estado-chip is-advertencia\">" +
              "<i class=\"mdi mdi-file-alert-outline\"></i>Sin documento</span>";

        item.CssClass += " sg-permit-row " +
                         (p.situacion == "VENCIDO" ? "is-overdue" :
                          (p.situacion == "POR VENCER" ? "is-expiring" : "is-vigente"));

        /* ---- El respaldo, para el panel de detalle ----
           La fila declara su adjunto en atributos y sigma-listas.js decide cómo
           mostrarlo. Solo si el archivo pasó el antivirus: sin nombre no se
           ofrece nada. */
        if (!string.IsNullOrEmpty(p.archivo_nombre_vig) && p.ptr_archivo != null)
        {
            bool esImagen = (p.archivo_mime ?? "").StartsWith("image/", StringComparison.OrdinalIgnoreCase);

            item.Attributes["data-sgx-adjunto"] = SitioBase.UrlArchivo.Ver(p.ptr_archivo.Value);
            item.Attributes["data-sgx-adjunto-bajar"] = SitioBase.UrlArchivo.Descargar(p.ptr_archivo.Value);
            item.Attributes["data-sgx-adjunto-nombre"] = p.archivo_nombre_vig;
            item.Attributes["data-sgx-adjunto-imagen"] = esImagen ? "1" : "0";
            item.Attributes["data-sgx-adjunto-peso"] = Peso(p.archivo_byte_vig);
        }
    }

    /// <summary>
    /// El peso en la unidad que se entiende. "1548576 bytes" no le dice nada a
    /// nadie; "1,5 MB" sí.
    /// </summary>
    private static string Peso(long bytes)
    {
        if (bytes <= 0) return "";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024d).ToString("0.#") + " KB";

        return (bytes / (1024d * 1024d)).ToString("0.#") + " MB";
    }

    /// <summary>
    /// El interior de una tarjeta: el número arriba y el rótulo con su icono
    /// debajo. El número NO se escapa porque es un entero contado acá mismo; el
    /// rótulo y el icono son constantes de esta pantalla.
    /// </summary>
    private static string Tarjeta(int numero, string icono, string rotulo)
    {
        return "<span class=\"numero\">" + numero + "</span>" +
               "<span class=\"rotulo\"><i class=\"mdi " + icono + "\"></i>" + rotulo + "</span>";
    }

    protected void lnkVencidos_Click(object sender, EventArgs e) { Situacion = "VENCIDO"; }
    protected void lnkPorVencer_Click(object sender, EventArgs e) { Situacion = "POR VENCER"; }
    protected void lnkVigentes_Click(object sender, EventArgs e) { Situacion = ""; }

    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR y no confiando en que el botón estaba
               visible: quien manda el postback a mano se lo salta. El permiso es
               el mismo de ver, porque el archivo no contiene nada que la pantalla
               no muestre. */
            if (!Token.Puede("VER PERMISOS TRABAJO"))
                throw new Exception("No tiene permiso para ver los permisos de trabajo.");

            /* Se arma la lista otra vez porque PreRender todavía no corrió en
               este postback: _mostrado está en null. */
            CargarGridVigentes();

            PermisoTrabajoController controller = new PermisoTrabajoController();
            controller.ExportarVigentes(_mostrado);
        }
        catch (System.Threading.ThreadAbortException)
        {
            // Response.End() la lanza siempre: es cómo termina una descarga.
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
