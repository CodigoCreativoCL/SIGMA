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
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirPermiso('" + query + "')");

        item["PTR_ID"].Controls.Add(editar);

        // ---- Qué permiso es ----
        string permiso = "<strong>" + Server.HtmlEncode(p.tipo_nombre) + "</strong>";

        if (!string.IsNullOrEmpty(p.ptr_numero))
            permiso += "<br /><span style=\"color:#777;font-size:11px;\">Folio " +
                       Server.HtmlEncode(p.ptr_numero) + "</span>";

        if (!string.IsNullOrEmpty(p.orden_correlativo))
            permiso += "<br /><span style=\"color:#999;font-size:11px;\">OT " +
                       Server.HtmlEncode(p.orden_correlativo) + "</span>";

        item["PERMISO"].Text = permiso;

        /* ---- Hasta cuándo ----
           El chip dice la situación y debajo va en palabras cuánto falta:
           "-5" obliga a interpretar el signo, "Venció hace 5 días" no. */
        string vigencia = "<span class=\"grid-estado-chip " + p.situacion_clase + "\">" +
                          Server.HtmlEncode(p.situacion) + "</span>" +
                          "<br /><span style=\"font-size:11px;\">" +
                          Server.HtmlEncode(p.vigencia_texto) + "</span>";

        if (p.ptr_fecha_vigencia_fin_utc != null)
            vigencia += "<br /><span style=\"color:#999;font-size:11px;\">hasta el " +
                        p.ptr_fecha_vigencia_fin_utc.Value.ToString("dd-MM-yyyy") + "</span>";

        item["VIGENCIA"].Text = vigencia;

        // ---- En qué estado está y quién lo pidió ----
        string estado = Server.HtmlEncode(p.estado_nombre);

        if (!string.IsNullOrEmpty(p.solicitante_nombre))
            estado += "<br /><span style=\"color:#777;font-size:11px;\">" +
                      Server.HtmlEncode(p.solicitante_nombre) + "</span>";

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
    }
}
