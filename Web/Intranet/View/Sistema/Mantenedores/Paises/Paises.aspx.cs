using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Sistema_Mantenedores_Paises : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PAI_ID", "", Width:"2%");
            Grid.AddColumn("PAI_ID", "ID", Width: "6%");
            Grid.AddColumn("PAI_NOMBRES", "NOMBRE", Width:"88%");
            Grid.AddCheckboxColumn("PAI_HABILITADO", "HABILITADO");
        }
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        Paises paises = new Paises();
        PaisesController paisesController = new PaisesController();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (wucFiltro.Filtro() != null) paises.filtro = wucFiltro.Filtro();
        if (cboHabilitado.SelectedValue != "") paises.filtro_habilitado = cboHabilitado.SelectedValue;

        Grid.DataSource = paisesController.GetPaises(paises);
    }

    protected void rgrPaises_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("pai_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                //Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirPais('" + query + "')");

                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell CCO_ID = DataItem["pai_id"];

                CCO_ID.Controls.Add(Editar);
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
                Paises paises = new Paises();
                PaisesController paisesController = new PaisesController();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int id = Int32.Parse(value["pai_id"].ToString());

                    paises.pai_id = id;

                    respuesta = paisesController.DeletePais(paises);
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