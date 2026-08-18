using Facilityges.Controller;
using Facilityges.Model;
using SitioBase;
using SitioBase.Model;
using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Root_AplicacionesMoviles_AplicacionesMoviles : System.Web.UI.Page
{
    private readonly AplicacionMovilController controller = new AplicacionMovilController();

    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)Paginas.menu_1064.Ver;
        Token.SecurityManagerVer(ver);
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("app_id", "", "5");
            Grid.AddColumn("app_id", "ID", "8");
            Grid.AddColumn("logo_col", "LOGO", "8");
            Grid.AddColumn("app_nombre", "NOMBRE", Wrap: true, HederWrap: true);
            Grid.AddColumn("plat_col", "PLATAFORMA");
            Grid.AddColumn("ver_col", "VERSIÓN");
            Grid.AddColumn("estado_col", "ESTADO");
            Grid.AddTemplateColumn("ver_btn", "", "VERSIONES");
        }

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
        Tools.tools.RegisterPostBackScript(Grid);
    }

    private void CargarGrid()
    {
        Grid.DataSource = controller.GetAplicacionesMoviles();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem || e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem dataItem = e.Item as GridDataItem;
                string id = dataItem.GetDataKeyValue("app_id").ToString();
                AplicacionMovil rowData = dataItem.DataItem as AplicacionMovil;
                if (rowData == null) return;

                // Botón editar
                string queryApp = Server.UrlEncode(Tools.Crypto.Encrypt("IdApp=" + id));
                HyperLink lnkEditar = new HyperLink();
                lnkEditar.ID = "lnkEditar" + id;
                lnkEditar.Text = "&nbsp;";
                lnkEditar.CssClass = "icono_Editar";
                lnkEditar.NavigateUrl = "javascript:void(0)";
                lnkEditar.Attributes.Add("onclick", "abrirApp('" + queryApp + "')");
                dataItem["app_id"].Controls.Add(lnkEditar);

                // Logo
                if (!string.IsNullOrEmpty(rowData.app_ruta_logo))
                {
                    Image imgLogo = new Image();
                    imgLogo.ImageUrl = ResolveUrl("~/" + rowData.app_ruta_logo);
                    imgLogo.Width = 36;
                    imgLogo.Height = 36;
                    imgLogo.Style.Add("border-radius", "8px");
                    dataItem["logo_col"].Controls.Add(imgLogo);
                }

                // Plataforma
                Literal litPlat = new Literal();
                switch ((rowData.apv_plataforma ?? "").ToUpper())
                {
                    case "ANDROID":
                        litPlat.Text = "<i class='fab fa-android'></i> Android";
                        break;
                    case "IOS":
                        litPlat.Text = "<i class='fab fa-apple'></i> iOS";
                        break;
                    case "AMBAS":
                        litPlat.Text = "<i class='fab fa-android'></i> <i class='fab fa-apple'></i> Ambas";
                        break;
                    default:
                        litPlat.Text = "-";
                        break;
                }
                dataItem["plat_col"].Controls.Add(litPlat);

                // Versión
                Label lblVer = new Label();
                if (rowData.tiene_version)
                {
                    lblVer.Text = "v" + rowData.apv_version_nombre;
                    lblVer.CssClass = "distintivo-plantilla distintivo-activo";
                }
                else
                {
                    lblVer.Text = "Sin publicar";
                    lblVer.CssClass = "distintivo-plantilla distintivo-inactivo";
                }
                dataItem["ver_col"].Controls.Add(lblVer);

                // Estado
                Label lblEst = new Label();
                lblEst.Text = rowData.app_activa ? "Activa" : "Inactiva";
                lblEst.CssClass = "distintivo-plantilla " + (rowData.app_activa ? "distintivo-activo" : "distintivo-inactivo");
                dataItem["estado_col"].Controls.Add(lblEst);

                // Botón Versiones
                string queryVer = Server.UrlEncode(Tools.Crypto.Encrypt("IdApp=" + id));
                LinkButton btnVer = new LinkButton();
                btnVer.ID = "btnVer" + id;
                btnVer.Text = "<i class='fas fa-code-branch'></i> Versiones";
                btnVer.CssClass = "btn btn-xs btn-outline-primary";
                btnVer.Attributes.Add("onclick", "abrirVersiones('" + queryVer + "'); return false;");
                dataItem["ver_btn"].Controls.Add(btnVer);
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

            Respuesta respuesta = new Respuesta { error = false, detalle = "Aplicación(es) actualizada(s) con éxito." };
            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey key = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(key["app_id"].ToString());
                respuesta = controller.DelAplicacionMovil(id);
                if (respuesta.error) break;
            }

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
