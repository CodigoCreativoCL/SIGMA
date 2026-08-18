using Facilityges.Controller;
using Facilityges.Model;
using SitioBase;
using System;
using System.Collections.Generic;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Root_AplicacionesMoviles_AplicacionMovilVersiones : System.Web.UI.Page
{
    public int IdApp
    {
        get { return Convert.ToInt32(ViewState["IdApp"]); }
        set { ViewState.Add("IdApp", value); }
    }

    private readonly AplicacionMovilController controller = new AplicacionMovilController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!Token.TokenSeguridad()) Response.Redirect("~/Login.aspx");

        if (!IsPostBack)
        {
            string raw = Request.QueryString["query"];
            if (!string.IsNullOrEmpty(raw))
            {
                string[] parts = Tools.Crypto.Decrypt(Server.UrlDecode(raw)).Split('&');
                foreach (string p in parts)
                {
                    string[] kv = p.Split('=');
                    if (kv.Length == 2 && kv[0] == "IdApp")
                        IdApp = int.Parse(kv[1]);
                }
            }

            Grid.AddSelectColumn();
            Grid.AddColumn("apv_id", "");
            Grid.AddColumn("apv_id", "ID");
            Grid.AddColumn("apv_version_nombre", "VERSIÓN");
            Grid.AddColumn("plat_col", "PLATAFORMA");
            Grid.AddColumn("codigo_col", "CÓDIGO");
            Grid.AddColumn("archivos_col", "ARCHIVOS");
            Grid.AddColumn("estado_col", "ESTADO");
            Grid.AddColumn("latest_col", "LATEST");
            Grid.AddColumn("obl_col", "OBLIGATORIA");
            Grid.AddTemplateColumn("publicar_btn", "", "PUBLICAR");

            List<AplicacionMovil> apps = controller.GetAplicacionesMoviles(IdApp);
            if (apps != null && apps.Count > 0)
                lblAppNombre.Text = apps[0].app_nombre;
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        CargarQuery();
        udPanel.Update();
    }

    private void CargarGrid()
    {
        Grid.DataSource = controller.GetVersions(IdApp);
        Grid.DataBind();
    }

    protected void CargarQuery()
    {
        if (Request.QueryString["query"] == null)
        {
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdApp=" + IdApp));
            hdfQuery.Value = query;
        }
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem || e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem dataItem = e.Item as GridDataItem;

                string id = dataItem.GetDataKeyValue("apv_id").ToString();
                AppVersion rowData = dataItem.DataItem as AppVersion;
                if (rowData == null) return;

                // Botón editar
                string q = Server.UrlEncode(Tools.Crypto.Encrypt("IdApp=" + IdApp + "&IdVersion=" + id));
                HyperLink lnkE = new HyperLink();
                lnkE.ID = "lnkE" + id;
                lnkE.Text = "&nbsp;";
                lnkE.CssClass = "icono_Editar";
                lnkE.NavigateUrl = "javascript:void(0)";
                lnkE.Attributes.Add("onclick", "abrirVersion('" + q + "')");
                dataItem["apv_id"].Controls.Add(lnkE);

                // Plataforma badge
                Literal litPlat = new Literal();
                switch ((rowData.apv_plataforma ?? "").ToUpper())
                {
                    case "ANDROID":
                        litPlat.Text = "<span class='chip-md chip-android'><i class='fab fa-android'></i> Android</span>";
                        break;

                    case "IOS":
                        litPlat.Text = "<span class='chip-md chip-ios'><i class='fab fa-apple'></i> iOS</span>";
                        break;

                    default:
                        litPlat.Text = "<span class='chip-md chip-both'><i class='fab fa-android'></i><i class='fab fa-apple'></i> Ambas</span>";
                        break;
                }

                dataItem["plat_col"].Controls.Add(litPlat);

                // Código / Build
                Literal litCod = new Literal();
                litCod.Text = "<div class='version-info'>";

                if (rowData.apv_version_codigo.HasValue)
                    litCod.Text += "<div class='version-item'><b>Android:</b> " + rowData.apv_version_codigo.Value + "</div>";

                if (!string.IsNullOrEmpty(rowData.apv_build_ios))
                    litCod.Text += "<div class='version-item'><b>iOS Build:</b> " + rowData.apv_build_ios + "</div>";

                litCod.Text += "</div>";

                dataItem["codigo_col"].Controls.Add(litCod);

                // Archivos disponibles (descarga directa desde ~/Apps/)
                Literal litArch = new Literal();
                litArch.Text = "";

                if (!string.IsNullOrEmpty(rowData.apv_ruta_apk))
                {
                    string urlApk = ResolveUrl("~/" + rowData.apv_ruta_apk);
                    litArch.Text += "<a href='" + System.Web.HttpUtility.HtmlAttributeEncode(urlApk) + "' target='_blank' class='chip-md chip-android' title='Descargar APK' style='text-decoration:none;'>" +
                                    "<i class='fab fa-android'></i> APK <i class='fas fa-download' style='font-size:10px;opacity:.7;'></i></a> ";
                }

                if (!string.IsNullOrEmpty(rowData.apv_ruta_ipa))
                {
                    string urlIpa = ResolveUrl("~/" + rowData.apv_ruta_ipa);
                    litArch.Text += "<a href='" + System.Web.HttpUtility.HtmlAttributeEncode(urlIpa) + "' target='_blank' class='chip-md chip-ios' title='Descargar IPA' style='text-decoration:none;'>" +
                                    "<i class='fab fa-apple'></i> IPA <i class='fas fa-download' style='font-size:10px;opacity:.7;'></i></a> ";
                }

                if (string.IsNullOrEmpty(litArch.Text))
                    litArch.Text = "<span class='chip-md chip-muted'><i class='fas fa-ban'></i> Sin archivos</span>";

                dataItem["archivos_col"].Controls.Add(litArch);

                // Estado publicación
                Label lblEst = new Label();
                lblEst.Text = rowData.apv_publicada
                    ? "<i class='fas fa-check-circle'></i> Publicada"
                    : "<i class='fas fa-edit'></i> Borrador";

                lblEst.CssClass = "chip-md " + (rowData.apv_publicada ? "chip-success" : "chip-warning");

                dataItem["estado_col"].Controls.Add(lblEst);

                // Latest badge
                Literal litLat = new Literal();
                litLat.Text = rowData.apv_es_latest
                  ? "<span class='chip-md chip-info'><i class='fas fa-star'></i> Latest</span>"
                  : "";
                dataItem["latest_col"].Controls.Add(litLat);

                // Obligatoria badge
                Literal litObl = new Literal();
                litObl.Text = rowData.apv_obligatoria
                ? "<span class='chip-md chip-danger'><i class='fas fa-exclamation-circle'></i> Obligatoria</span>"
                : "<span class='chip-md chip-muted'><i class='fas fa-minus'></i> No</span>";
                dataItem["obl_col"].Controls.Add(litObl);

                LinkButton btnPub = (LinkButton)dataItem["publicar_btn"].FindControl("btnPub");

                if (!rowData.apv_es_latest)
                {
                    btnPub.Visible = true;
                    btnPub.CommandName = id;
                    btnPub.CommandArgument = id;

                    btnPub.OnClientClick =
                        "return ConfirSweetAlert(this, '', '¿Publicar esta versión como latest?');";
                }
                else
                {
                    btnPub.Visible = false;

                    Literal litPub = new Literal();
                    litPub.Text = "<span style='color:#94a3b8;font-size:.75rem;'>—</span>";

                    dataItem["publicar_btn"].Controls.Add(litPub);
                }
            }
        }
    }

    protected void Grid_OnItemCreated(object sender, GridItemEventArgs e)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = (GridDataItem)e.Item;

            LinkButton btnPub = new LinkButton();
            btnPub.ID = "btnPub";
            btnPub.Text = "<i class='fas fa-rocket'></i> Publicar";
            btnPub.CssClass = "btn btn-xs btn-success";
            btnPub.Style.Add("color", "white !important");
            btnPub.Command += BtnPublicar_Command;

            item["publicar_btn"].Controls.Add(btnPub);
        }
    }

    protected void BtnPublicar_Command(object sender, CommandEventArgs e)
    {
        try
        {
            int apvId = Convert.ToInt32(e.CommandArgument);

            Respuesta r = controller.PublicarVersion(apvId, null, null);

            Tools.tools.ClientAlert(
                r.detalle,
                r.error ? "alerta" : "ok");

            CargarGrid();
            Grid.Rebind();
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
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

            Respuesta respuesta = new Respuesta { error = false, detalle = "Versión(es) eliminada(s)." };

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey key = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(key["apv_id"].ToString());
                respuesta = controller.DelVersion(id);
                if (respuesta.error) break;
            }

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "error"); }
    }

    protected void lnkNueva_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdApp=" + IdApp));
        Tools.tools.ClientExecute("abrirVersion('" + query + "')");
    }
}
