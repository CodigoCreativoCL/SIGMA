using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Root_ModulosSistema_ModulosSistema : System.Web.UI.Page
{
    private ModuloSistemaController controller = new ModuloSistemaController();

    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)Paginas.menu_1062.Ver;
        Token.SecurityManagerVer(ver);
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("mds_id",     "",          "5");
            Grid.AddColumn("mds_id",     "ID",        "8");
            Grid.AddColumn("mds_nombre", "NOMBRE",    Wrap: true, HederWrap: true);
            Grid.AddColumn("hab_badge",  "HABILITADO","12");
        }

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void CargarGrid()
    {
        ModuloSistema filtro = new ModuloSistema();

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro_nombre = wucFiltro.Filtro();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (cboHabilitado != null && !string.IsNullOrEmpty(cboHabilitado.SelectedValue)) filtro.filtro_habilitado = cboHabilitado.SelectedValue;

        Grid.DataSource = controller.GetModulos(filtro);
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem || e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem dataItem = e.Item as GridDataItem;
                string id = dataItem.GetDataKeyValue("mds_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdModulo=" + id));

                // Botón editar
                HyperLink lnkEditar = new HyperLink();
                lnkEditar.ID          = "lnkEditar" + id;
                lnkEditar.Text        = "&nbsp;";
                lnkEditar.CssClass    = "icono_Editar";
                lnkEditar.NavigateUrl = "javascript:void(0)";
                lnkEditar.Attributes.Add("onclick", "abrirModulo('" + query + "')");
                dataItem["mds_id"].Controls.Add(lnkEditar);

                // Badge habilitado
                ModuloSistema rowData = dataItem.DataItem as ModuloSistema;
                if (rowData != null)
                {
                    bool habilitado = rowData.mds_habilitado;
                    System.Web.UI.WebControls.Label badge = new System.Web.UI.WebControls.Label();
                    badge.Text     = habilitado ? "Activo" : "Inactivo";
                    badge.CssClass = "distintivo-plantilla " + (habilitado ? "distintivo-activo" : "distintivo-inactivo");
                    dataItem["hab_badge"].Controls.Add(badge);
                }
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

            Respuesta respuesta = new Respuesta { error = false, detalle = "Módulos eliminados con éxito" };
            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey key = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(key["mds_id"].ToString());
                respuesta = controller.DelModulo(id);
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
