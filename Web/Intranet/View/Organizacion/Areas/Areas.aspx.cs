using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de areas de planta (HU-012).
/// </summary>
public partial class View_Organizacion_Areas_Areas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("IAR_ID", "", Width: "3%");
            Grid.AddColumn("IAR_CODIGO", "CÓDIGO", Width: "13%");
            Grid.AddColumn("IAR_NOMBRE", "NOMBRE", Width: "27%");
            Grid.AddColumn("CIN_NOMBRE", "PLANTA", Width: "18%");
            Grid.AddColumn("PADRE_NOMBRE", "ÁREA SUPERIOR", Width: "17%");
            Grid.AddColumn("IAT_NOMBRE", "TIPO", Width: "12%");
            Grid.AddCheckboxColumn("IAR_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// El combo de plantas del filtro. Solo las del cliente en sesion: es
    /// la primera barrera del aislamiento multicliente y evita que alguien
    /// pueda siquiera pedir las areas de otra empresa.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                if (ctrl.ID == "cboPlanta")
                {
                    ClienteInstalacion filtro = new ClienteInstalacion();
                    filtro.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                    filtro.filtro_habilitado = "1";

                    ClienteInstalacionController controller = new ClienteInstalacionController();

                    ctrl.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                    ctrl.DataValueField = "cin_id";
                    ctrl.DataTextField = "cin_nombre";
                    ctrl.DataBind();
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        InstalacionArea filtro = new InstalacionArea();
        InstalacionAreaController controller = new InstalacionAreaController();

        filtro.iar_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboPlanta != null && cboPlanta.SelectedValue != "")
            filtro.iar_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetInstalacionAreas(filtro);
    }

    protected void rgrAreas_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("iar_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirArea('" + query + "')");

                item["iar_id"].Controls.Add(Editar);

                // Indentacion por nivel: el arbol se lee en la misma grilla.
                int nivel = 1;
                object valorNivel = DataBinder.Eval(item.DataItem, "nivel");
                if (valorNivel != null) int.TryParse(valorNivel.ToString(), out nivel);

                if (nivel > 1)
                    item["iar_nombre"].Style["padding-left"] = ((nivel - 1) * 22) + "px";
            }
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                Respuesta respuesta = new Respuesta();
                InstalacionAreaController controller = new InstalacionAreaController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    InstalacionArea entidad = new InstalacionArea();
                    entidad.iar_id = Int32.Parse(value["iar_id"].ToString());

                    respuesta = controller.DeleteInstalacionArea(entidad);
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
