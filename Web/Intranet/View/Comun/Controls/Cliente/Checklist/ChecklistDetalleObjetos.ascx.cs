using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Checklist_ChecklistDetalleObjetos : System.Web.UI.UserControl
{
    private ChecklistDetalleObjeto checklistDetalleObjeto = new ChecklistDetalleObjeto();
    private ChecklistDetalleObjetoController checklistDetalleObjetoController = new ChecklistDetalleObjetoController();

    #region Variables Globales
    public int IdCheckListDetalle
    {
        get { return Convert.ToInt32(ViewState["IdCheckListDetalle"]); }
        set { ViewState.Add("IdCheckListDetalle", value); }
    }

    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    #endregion

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            #region query
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {

                    case "IdCheckListDetalle":
                        IdCheckListDetalle = Int32.Parse(array[1].ToString());
                        break;

                    case "ReadOnly":
                        ReadOnly = bool.Parse(array[1].ToString());
                        break;
                }
            }
            #endregion

            Grid.AddSelectColumn();
            Grid.AddColumn("CDC_ID", "", Width: "5%", Align: HorizontalAlign.Left);
            Grid.AddColumn("CDC_ID", "ID", Width: "5%", Align: HorizontalAlign.Left);
            Grid.AddColumn("CDC_NOMBRE", "NOMBRE", Align: HorizontalAlign.Left);
            Grid.AddColumn("CDC_ORDEN", "ORDEN", Width: "5%", Align: HorizontalAlign.Left);
        }
    }


    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Bloqueo();

    }

    protected void CargarGrid()
    {
        checklistDetalleObjeto = new ChecklistDetalleObjeto();
        checklistDetalleObjeto.cdc_id_checklist_detalle = IdCheckListDetalle;

        Grid.DataSource = checklistDetalleObjetoController.GetCheckListDetalleObjetos(checklistDetalleObjeto);
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
                string cdc_id = item.GetDataKeyValue("cdc_id").ToString();
                string cdc_id_checklist_detalle = item.GetDataKeyValue("cdc_id_checklist_detalle").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdChecklistLista=" + cdc_id + "&IdCheckListDetalle=" + cdc_id_checklist_detalle + "&ReadOnly" + ReadOnly));

                //Creo el link 
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkAnular" + cdc_id;
                Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirDetalleObjeto('" + query + "')");

                //Asigno el Link a la celda            
                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell CDC_ID = DataItem["CDC_ID"];
                CDC_ID.Controls.Add(Editar);
            }
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un Ítem.", "alerta");
            }
            else
            {
                Respuesta respuesta = new Respuesta();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int ID = Int32.Parse(value["cdc_id"].ToString());

                    ChecklistDetalleObjeto checklistDetalleObjeto = new ChecklistDetalleObjeto();
                    checklistDetalleObjeto.cdc_id = ID;

                    respuesta = checklistDetalleObjetoController.DeleteCheckListDetalleObjeto(checklistDetalleObjeto);
                }

                if (!respuesta.error)
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                }
                else
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                }
                CargarGrid();
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void lnkAñadir_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + 0 + "&IdCheckListDetalle=" + IdCheckListDetalle + "&ReadOnly" + ReadOnly));
        Tools.tools.ClientExecute("abrirDetalleObjeto('" + query + "')");
    }

    protected void Bloqueo()
    {
        if (ReadOnly)
        {
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
            Grid.DataBind();
        }
    }
}
