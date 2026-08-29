using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;
using SitioBase;

public partial class View_Sistema_Perfiles_Perfiles : System.Web.UI.Page
{
    PerfilController controller = new PerfilController();

    protected void Page_Load(object sender, EventArgs e)
    {

        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("PER_ID", "", Width:"2%");
            Grid.AddColumn("PER_ID", "", Width: "4%");
            Grid.AddColumn("PER_NOMBRE", "NOMBRE", Width: "30%");
            Grid.AddColumn("TIPO", "TIPO", Width: "29%");
            Grid.AddColumn("PER_DESCRIPCION", "DESCRIPCION", Width: "30%");
            Grid.AddCheckboxColumn("PER_HABILITADO", "HABILITADO", Width: "5%");
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();
    }

    protected void CargarGrid()
    {
        Perfil perfil = new Perfil();

        //if (!string.IsNullOrEmpty(wucFiltro.Filtro())) perfil.filtro = wucFiltro.Filtro();
        Grid.DataSource = controller.ListoPerfiles(perfil);
    }

    protected void rgrPrefiles_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("per_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                //Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirPerfil('" + query + "')");

                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell CCO_ID = DataItem["per_id"];

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

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int id = Int32.Parse(value["per_id"].ToString());

                    Perfil registro = new Perfil();
                    registro.per_id = id;

                    respuesta = controller.DeletePerfil(registro);
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }
}