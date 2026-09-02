using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Permisos vigentes y por vencer (HU-064, bloque 97).
///
/// "Para no descubrir en terreno que el permiso caducó."
///
/// LOS TRES NUMEROS ANTES DE LA LISTA
///   Alguien entra con una pregunta —"¿tengo algo vencido?"— y la respuesta
///   cabe en un número. Que tenga que contar filas para saberlo es hacerle el
///   trabajo al revés. Y los tres son botones: el que ve un 3 en rojo quiere
///   ver esos tres, no leer la lista completa buscándolos.
///
/// SOLO LECTURA
///   Para corregir un permiso se abre su ficha. Esta pantalla no edita nada:
///   es la que se mira antes de empezar a trabajar.
///
/// LA SITUACION SE CALCULA EN CADA CONSULTA
///   El SP la resuelve contra la fecha de hoy con FNC_PERMISO_SITUACION. Un
///   estado guardado envejecería solo: un permiso que venció anoche seguiría
///   diciendo AUTORIZADO hasta que alguien corriera un proceso.
/// </summary>
public partial class View_Terceros_PermisosTrabajo_PermisoTrabajoVigentes : System.Web.UI.Page
{
    /// <summary>
    /// Qué situación se está mirando: "" son todas, o VENCIDO / POR VENCER.
    /// </summary>
    public string Situacion
    {
        get { return ViewState["Situacion"] != null ? (string)ViewState["Situacion"] : ""; }
        set { ViewState["Situacion"] = value; }
    }

    /// <summary>Lo que se pintó, para que la exportación baje exactamente eso.</summary>
    private List<PermisoVigente> _mostrado;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("PTR_ID", "", Width: "3%");
            Grid.AddTemplateColumn("VIGENCIA", "", "VIGENCIA", Width: "24%");
            Grid.AddTemplateColumn("PERMISO", "", "PERMISO", Width: "30%");
            Grid.AddTemplateColumn("QUIEN", "", "SOLICITANTE", Width: "22%");
            Grid.AddTemplateColumn("DOCUMENTO", "", "DOCUMENTO", Width: "21%");
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
        /* La descarga escribe el archivo directo en la respuesta, y eso no
           sobrevive a un postback asíncrono: el UpdatePanel espera un
           fragmento y recibe un binario. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkExportar);

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        PermisoTrabajoController controller = new PermisoTrabajoController();

        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboAviso = (RadComboBox2)wucFiltro.FindControl("cboAviso");

        int tipo = 0;
        if (cboTipo != null) int.TryParse(cboTipo.SelectedValue, out tipo);

        int aviso = 7;
        if (cboAviso != null && !int.TryParse(cboAviso.SelectedValue, out aviso)) aviso = 7;

        string texto = wucFiltro.Filtro();

        /* Se trae TODO —vigentes, por vencer y vencidos— y se filtra acá para
           pintar los tres contadores. Pedirle al SP cada situación por
           separado serían tres viajes para mostrar una lista. */
        List<PermisoVigente> todo = controller.GetVigentes(aviso, tipo, true, false, texto);

        if (todo == null) todo = new List<PermisoVigente>();

        int vencidos = 0, porVencer = 0, vigentes = 0;

        foreach (PermisoVigente p in todo)
        {
            if (p.situacion == "VENCIDO") vencidos++;
            else if (p.situacion == "POR VENCER") porVencer++;
            else vigentes++;
        }

        litVencidos.Text = vencidos.ToString();
        litPorVencer.Text = porVencer.ToString();
        litVigentes.Text = vigentes.ToString();

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
              "están en el listado completo."
            : "Con estos filtros no queda ninguno.";

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

        PermisoVigente p = item.DataItem as PermisoVigente;

        if (p == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.ptr_id));

        HyperLink abrir = new HyperLink();
        abrir.ID = "lnkAbrir" + item.ItemIndex;
        abrir.CssClass = "icono_Editar";
        abrir.NavigateUrl = "javascript:void(0)";
        abrir.Attributes.Add("onclick", "abrirPermiso('" + query + "')");

        item["PTR_ID"].Controls.Add(abrir);

        /* ---- Cuánto falta ----
           Va primera y no el tipo: la pregunta de esta pantalla es cuándo
           caduca, no de qué es el permiso. */
        string vigencia = "<span class=\"grid-estado-chip " + p.situacion_clase + "\">" +
                          Server.HtmlEncode(p.situacion) + "</span>" +
                          "<br /><strong style=\"font-size:12px;\">" +
                          Server.HtmlEncode(p.vigencia_texto) + "</strong>";

        if (p.ptr_fecha_vigencia_fin_utc != null)
            vigencia += "<br /><span style=\"color:#999;font-size:11px;\">hasta el " +
                        p.ptr_fecha_vigencia_fin_utc.Value.ToString("dd-MM-yyyy") + "</span>";

        item["VIGENCIA"].Text = vigencia;

        // ---- Qué permiso es ----
        string permiso = "<strong>" + Server.HtmlEncode(p.tipo_nombre) + "</strong>";

        if (!string.IsNullOrEmpty(p.ptr_numero))
            permiso += "<br /><span style=\"color:#777;font-size:11px;\">Folio " +
                       Server.HtmlEncode(p.ptr_numero) + "</span>";

        if (!string.IsNullOrEmpty(p.orden_correlativo))
            permiso += "<br /><span style=\"color:#999;font-size:11px;\">OT " +
                       Server.HtmlEncode(p.orden_correlativo) + "</span>";

        item["PERMISO"].Text = permiso;

        // ---- Quién lo pidió y en qué estado está ----
        string quien = string.IsNullOrEmpty(p.solicitante_nombre)
                     ? "<span style=\"color:#aaa;\">—</span>"
                     : Server.HtmlEncode(p.solicitante_nombre);

        quien += "<br /><span style=\"color:#777;font-size:11px;\">" +
                 Server.HtmlEncode(p.estado_nombre) + "</span>";

        item["QUIEN"].Text = quien;

        /* ---- El documento ----
           Un permiso vigente SIN el papel firmado no acredita nada, y en
           terreno eso importa tanto como la fecha. */
        item["DOCUMENTO"].Text = p.tiene_documento
            ? "<span class=\"grid-estado-chip is-exito\">" +
              "<i class=\"mdi mdi-paperclip\"></i>Adjunto</span>"
            : "<span class=\"grid-estado-chip is-advertencia\">" +
              "<i class=\"mdi mdi-file-alert-outline\"></i>Sin documento</span>";
    }

    protected void lnkVencidos_Click(object sender, EventArgs e) { Situacion = "VENCIDO"; }
    protected void lnkPorVencer_Click(object sender, EventArgs e) { Situacion = "POR VENCER"; }
    protected void lnkVigentes_Click(object sender, EventArgs e) { Situacion = ""; }

    protected void lnkExportar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR y no confiando en que el botón
               estaba visible: quien manda el postback a mano se lo salta.
               El permiso es el mismo de ver, porque el archivo no contiene
               nada que la pantalla no muestre. */
            if (!Token.Puede("VER PERMISOS TRABAJO"))
                throw new Exception("No tiene permiso para ver los permisos de trabajo.");

            /* Se arma la lista otra vez porque PreRender todavía no corrió en
               este postback: _mostrado está en null. */
            CargarGrid();

            PermisoTrabajoController controller = new PermisoTrabajoController();
            controller.ExportarVigentes(_mostrado);
        }
        catch (System.Threading.ThreadAbortException)
        {
            /* Response.End() la lanza siempre: es cómo termina una descarga,
               no un fallo. Se deja pasar para que no llegue al catch de abajo
               y muestre una alerta sobre un archivo que sí se envió. */
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
