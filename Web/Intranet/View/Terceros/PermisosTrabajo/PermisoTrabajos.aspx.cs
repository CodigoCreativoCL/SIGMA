using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de permisos de trabajo (HU-063, bloque 94).
///
/// LA SITUACION ES LA PREGUNTA QUE TRAE A ALGUIEN ACA
///   Nadie entra a "ver los permisos": entra a saber qué está por vencer, que
///   es lo que HU-064 pide y lo que evita descubrir en terreno que el permiso
///   caducó. Por eso el filtro de situación va primero y el orden por defecto
///   es el que vence antes, primero.
/// </summary>
public partial class View_Terceros_PermisosTrabajo_PermisoTrabajos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("PTR_ID", "", Width: "3%");
            Grid.AddTemplateColumn("PERMISO", "", "PERMISO", Width: "30%");
            Grid.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "24%");
            Grid.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "17%");
            Grid.AddTemplateColumn("DOCUMENTO", "", "DOCUMENTO FIRMADO", Width: "26%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboTipo")
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

    protected void Page_PreRender(object sender, EventArgs e)
    {
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");

        AvisoAdjunto();
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// Se pregunta por el almacenamiento y se dice la verdad.
    ///
    /// Sin esto la pantalla se vería normal y el usuario descubriría el
    /// problema recién al intentar autorizar un permiso, con un mensaje que
    /// hablaría de un adjunto que nunca se le ofreció.
    /// </summary>
    protected void AvisoAdjunto()
    {
        IAlmacenamiento almacenamiento = Almacenamiento.Actual();

        if (almacenamiento.Disponible) return;

        pnlSinAdjunto.Visible = true;

        litSinAdjunto.Text =
            "<strong>Todavía no se puede adjuntar el documento firmado.</strong> " +
            Server.HtmlEncode(almacenamiento.Motivo) +
            "<br />Los permisos se pueden registrar igual y quedan como " +
            "<strong>Solicitado</strong>; para pasarlos a <strong>Autorizado</strong> hace falta " +
            "el papel adjunto, que es la constancia que exige la norma.";
    }

    protected void CargarGrid()
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

        litCuenta.Text = lista.Count == 0 ? ""
                       : (lista.Count == 1 ? "1 permiso" : lista.Count + " permisos");

        Grid.DataSource = lista;
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
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

        /* La cara del solicitante y no un icono generico. Un permiso lo pide
           alguien, y en una lista de treinta la pregunta frecuente es "¿este
           quien lo pidio?". El avatar responde sin leer. */
        if (!string.IsNullOrEmpty(p.solicitante_nombre))
            estado += SitioBase.Avatar.CeldaUno(p.solicitante_id, p.solicitante_nombre,
                                                p.solicitante_foto, "Solicitante");

        estado += "</div>";

        item["ESTADO"].Text = estado;

        /* ---- El documento ----
           Es la columna que importa: un permiso sin su papel no acredita
           nada, y por eso se dice en la lista y no dentro de la ficha. */
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
           detalle marca la fila que esta abierta. Al ponersela a todas las
           filas vigentes, el panel no tenia como distinguir cual estaba
           mirando. Se llama `is-vigente`, que ademas dice lo que es. */
        item.CssClass += " sg-permit-row " +
                         (p.situacion == "VENCIDO" ? "is-overdue" :
                          (p.situacion == "POR VENCER" ? "is-expiring" : "is-vigente"));
    }
}
