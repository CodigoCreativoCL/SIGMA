using SitioBase.Controller;
using SitioBase.Model;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;

public partial class View_Comun_Controls_Cliente_Checklist_Checklist : System.Web.UI.UserControl
{
    #region Variables Globales
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public int IdChecklist
    {
        get { return Convert.ToInt32(ViewState["IdChecklist"]); }
        set { ViewState.Add("IdChecklist", value); }
    }


    public string URLNuevoCheckList
    {
        get { return Convert.ToString(ViewState["URLNuevoCliente"]); }
        set { ViewState.Add("URLNuevoCliente", value); }
    }

    #endregion


    private Checklist checkList = new Checklist();
    private ChecklistController checkListController = new ChecklistController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
          
            Grid.AddSelectColumn();
            Grid.AddColumn("chk_id", "", Align: HorizontalAlign.Center);
            Grid.AddColumn("chk_id", "ID", Align: HorizontalAlign.Center);
            Grid.AddColumn("chk_nombre", "NOMBRE", Width: "40%");
            Grid.AddColumn("chk_descripcion", "DESCRIPCION", Width: "60%");
            Grid.AddCheckboxColumn("chk_habilitado", "HABILITADO");

        }

    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargaGrid();
        udPanel.Update();
    }

    protected void CargaGrid()
    {
        checkList = new Checklist();
        checkList.chk_cliente = IdCliente;

        if (wucFiltro.Filtro() != null) checkList.filtro = wucFiltro.Filtro();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (cboHabilitado.SelectedValue == "1") checkList.filtro_habilitado = true;
        if (cboHabilitado.SelectedValue == "0") checkList.filtro_habilitado = false;

        Grid.DataSource = checkListController.GetChecklists(checkList);
        Grid.DataBind();
    }

    protected void Grid_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            //Obtengo los valores del grid
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string IdChecklist = item.GetDataKeyValue("chk_id").ToString();
  
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdChecklist=" + IdChecklist + "&IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly));

                //Creo el link 
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkAnular" + IdChecklist;
                Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrir('" + query + "')");

                //Asigno el Link a la celda            
                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell dca_id = DataItem["chk_id"];
                dca_id.Controls.Add(Editar);
            }
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un CheckList.");
                CargaGrid();
            }
            else
            {
                Respuesta respuesta = new Respuesta();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int Id = Int32.Parse(value["chk_id"].ToString());

                    Checklist checkList = new Checklist();
                    checkList.chk_id = Id;

                    respuesta = checkListController.DeleteChecklist(checkList);
                }

                if (!respuesta.error)
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                }
                else
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                }
                CargaGrid();
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert("No es posible eliminar la(s) Caja(s) (" + ex.Message + ").");
        }
    }

    protected void lnkNuevo_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly));
        Tools.tools.ClientExecute("abrir('" + query + "')");
    }
}