using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de compatibilidades de repuesto (HU-051, bloque 92).
///
/// LA PREGUNTA VA EN LAS DOS DIRECCIONES
///   El planificador pregunta "¿para qué equipos sirve esta pieza?"; el
///   técnico —que es quien no debe montar la que no corresponde— pregunta al
///   revés. Los filtros de repuesto y de alcance cubren las dos, y se pueden
///   combinar.
///
/// EL CLIENTE SALE DE LA SESION
///   Repuesto_Compatibilidad no tiene columna de cliente: la pertenencia
///   viene del repuesto. El SP hace ese JOIN y filtra, así que un id escrito
///   a mano no alcanza para ver la de otra empresa.
/// </summary>
public partial class View_Inventario_Compatibilidades_RepuestoCompatibilidades : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("RCO_ID", "", Width: "3%");
            Grid.AddTemplateColumn("REPUESTO", "", "REPUESTO", Width: "34%");
            Grid.AddTemplateColumn("ALCANCE", "", "APLICA A", Width: "33%");
            Grid.AddTemplateColumn("NOTA", "", "OBSERVACIÓN", Width: "30%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// Los tres combos del filtro. Los alcances traen los globales y los del
    /// cliente juntos, que es como se eligen.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            switch (ctrl.ID)
            {
                case "cboRepuesto":

                    RepuestoController ctrlRep = new RepuestoController();

                    ctrl.Items.Add(new RadComboBoxItem("Todos", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlRep.GetRepuestos(new Repuesto { filtro_habilitado = true });
                    ctrl.DataValueField = "rep_id";
                    ctrl.DataTextField = "rep_codigo";
                    ctrl.DataBind();
                    break;

                case "cboTipo":

                    ActivoTipoController ctrlTipo = new ActivoTipoController();

                    ctrl.Items.Add(new RadComboBoxItem("Todos", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlTipo.GetActivoTipos(
                        new ActivoTipo { filtro_cliente = SitioBase.Session.ClienteId(),
                                         filtro_habilitado = true });
                    ctrl.DataValueField = "ati_id";
                    ctrl.DataTextField = "ati_nombre";
                    ctrl.DataBind();
                    break;

                case "cboModelo":

                    ActivoModeloController ctrlModelo = new ActivoModeloController();

                    ctrl.Items.Add(new RadComboBoxItem("Todos", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = ctrlModelo.GetModelos(
                        new ActivoModelo { filtro_habilitado = true });
                    ctrl.DataValueField = "amo_id";
                    ctrl.DataTextField = "etiqueta";
                    ctrl.DataBind();
                    break;
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        lnkNuevo.Visible = Token.PuedeFuncion("Crear y editar");
        lnkEliminar.Visible = Token.PuedeFuncion("Eliminar");

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        RepuestoCompatibilidad filtro = new RepuestoCompatibilidad();
        RepuestoCompatibilidadController controller = new RepuestoCompatibilidadController();

        RadComboBox2 cboRepuesto = (RadComboBox2)wucFiltro.FindControl("cboRepuesto");
        RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
        RadComboBox2 cboModelo = (RadComboBox2)wucFiltro.FindControl("cboModelo");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        int aux;

        if (cboRepuesto != null && int.TryParse(cboRepuesto.SelectedValue, out aux))
            filtro.filtro_repuesto = aux;

        if (cboTipo != null && int.TryParse(cboTipo.SelectedValue, out aux))
            filtro.filtro_tipo = aux;

        if (cboModelo != null && int.TryParse(cboModelo.SelectedValue, out aux))
            filtro.filtro_modelo = aux;

        List<RepuestoCompatibilidad> lista = controller.GetCompatibilidades(filtro);

        if (lista == null) lista = new List<RepuestoCompatibilidad>();

        litCuenta.Text = lista.Count == 0 ? ""
                       : (lista.Count == 1 ? "1 compatibilidad"
                                           : lista.Count + " compatibilidades");

        Grid.DataSource = lista;
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        RepuestoCompatibilidad c = item.DataItem as RepuestoCompatibilidad;

        if (c == null) return;

        // ---- Enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + c.rco_id));

        HyperLink editar = new HyperLink();
        editar.ID = "lnkEditar" + item.ItemIndex;
        editar.CssClass = "icono_Editar";
        editar.NavigateUrl = "javascript:void(0)";
        editar.Attributes.Add("onclick", "abrirCompatibilidad('" + query + "')");

        item["RCO_ID"].Controls.Add(editar);

        // ---- El repuesto ----
        item["REPUESTO"].Text =
            "<strong>" + Server.HtmlEncode(c.repuesto_codigo) + "</strong>" +
            "<br /><span style=\"color:#777;font-size:11px;\">" +
            Server.HtmlEncode(c.repuesto_nombre) + "</span>";

        /* ---- A qué aplica ----
           El chip dice de qué clase es el alcance, y eso importa tanto como
           el nombre: "Bomba centrífuga" puede ser un tipo —todas las bombas—
           o un modelo —solo ese—, y confundirlos es exactamente el error que
           la historia quiere evitar. */
        string chip = (c.alcance == "COMPONENTE") ? "is-acento"
                    : (c.alcance == "MODELO") ? "is-info" : "is-neutro";

        item["ALCANCE"].Text =
            "<span class=\"grid-estado-chip " + chip + "\">" +
            "<i class=\"" + c.alcance_icono + "\"></i>" +
            Server.HtmlEncode(c.alcance_etiqueta) + "</span>" +
            "<br /><strong>" + Server.HtmlEncode(c.alcance_nombre) + "</strong>";

        item["NOTA"].Text = string.IsNullOrEmpty(c.rco_observacion)
            ? "<span style=\"color:#aaa;\">—</span>"
            : "<span style=\"font-size:12px;\">" + Server.HtmlEncode(c.rco_observacion) + "</span>";
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Se comprueba en el SERVIDOR: esconder el botón no es seguridad,
               quien manda el postback a mano se lo salta. */
            if (!Token.PuedeFuncion("Eliminar"))
                throw new Exception("No tiene permiso para eliminar compatibilidades.");

            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            RepuestoCompatibilidadController controller = new RepuestoCompatibilidadController();

            List<string> fallidos = new List<string>();
            int borrados = 0;

            foreach (string indice in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(indice)];

                Respuesta respuesta = controller.DeleteCompatibilidad(
                    int.Parse(value["rco_id"].ToString()));

                if (respuesta.error) fallidos.Add(respuesta.detalle);
                else borrados++;
            }

            /* Se informa lo que pasó con CADA una: mostrar solo el último
               resultado diría "eliminada con éxito" cuando se seleccionaron
               tres y dos fueron rechazadas. */
            if (fallidos.Count == 0)
            {
                Tools.tools.ClientAlert(
                    borrados == 1 ? "Compatibilidad eliminada con éxito."
                                  : borrados + " compatibilidades eliminadas con éxito.", "ok", true);
            }
            else
            {
                string detalle = (borrados > 0 ? borrados + " eliminada(s). " : "") +
                                 string.Join(" ", fallidos.ToArray());

                Tools.tools.ClientAlert(detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
