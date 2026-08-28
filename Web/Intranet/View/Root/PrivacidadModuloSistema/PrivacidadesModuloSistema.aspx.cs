using SitioBase.Controller;
using SitioBase.Model;
using SitioBase;
using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Root_PrivacidadModuloSistema_PrivacidadesModuloSistema : System.Web.UI.Page
{
    private PrivacidadModuloSistemaController controller = new PrivacidadModuloSistemaController();

    protected void Page_Load(object sender, EventArgs e)
    {
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("pms_id",          "",                    "5");
            Grid.AddColumn("pms_id",          "ID",                  "6");
            Grid.AddColumn("mds_nombre",      "MÓDULO",              Wrap: true, HederWrap: true);
            Grid.AddColumn("pms_fecha_creacion", "FECHA CREACIÓN",   "15");
            Grid.AddColumn("pms_fecha_act",    "ÚLTIMA ACTUALIZACIÓN","15");
        }

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void CargarGrid()
    {
        PrivacidadModuloSistema filtro = new PrivacidadModuloSistema();

        if (!string.IsNullOrEmpty(wucFiltro.Filtro()))
            filtro.filtro = wucFiltro.Filtro();

        Grid.DataSource = controller.GetPrivacidades(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem || e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem dataItem = e.Item as GridDataItem;
                string id = dataItem.GetDataKeyValue("pms_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdPrivacidad=" + id));

                HyperLink lnkEditar = new HyperLink();
                lnkEditar.ID          = "lnkEditar" + id;
                lnkEditar.Text        = "&nbsp;";
                lnkEditar.CssClass    = "icono_Editar";
                lnkEditar.NavigateUrl = "javascript:void(0)";
                lnkEditar.Attributes.Add("onclick", "abrirPrivacidad('" + query + "')");
                dataItem["pms_id"].Controls.Add(lnkEditar);
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
                return;
            }

            Respuesta respuesta = new Respuesta { error = false, detalle = "Registro(s) eliminado(s) con éxito." };

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey key = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(key["pms_id"].ToString());
                respuesta = controller.DelPrivacidad(id);
                if (respuesta.error) break;
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
