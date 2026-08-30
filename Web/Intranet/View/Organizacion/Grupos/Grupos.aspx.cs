using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de grupos de trabajo (HU-016).
///
/// Sin botón Eliminar: un grupo con historial de órdenes asignadas se
/// deshabilita, no se borra.
/// </summary>
public partial class View_Organizacion_Grupos_Grupos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("GTR_ID", "", Width: "3%");
            Grid.AddColumn("GTR_CODIGO", "CÓDIGO", Width: "12%");
            Grid.AddColumn("GTR_NOMBRE", "NOMBRE", Width: "25%");
            Grid.AddColumn("CIN_NOMBRE", "PLANTA", Width: "18%");
            Grid.AddColumn("ESP_NOMBRE", "ESPECIALIDAD", Width: "15%");
            Grid.AddColumn("LIDER", "LÍDER", Width: "17%");
            Grid.AddColumn("INTEGRANTES", "INTEGRANTES", Width: "10%", Align: HorizontalAlign.Center);
            Grid.AddCheckboxColumn("GTR_HABILITADO", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

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
        GrupoTrabajo filtro = new GrupoTrabajo();
        GrupoTrabajoController controller = new GrupoTrabajoController();

        filtro.gtr_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboPlanta != null && cboPlanta.SelectedValue != "")
            filtro.gtr_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);

        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetGruposTrabajo(filtro);
    }

    protected void rgrGrupos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("gtr_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirGrupo('" + query + "')");

                item["gtr_id"].Controls.Add(Editar);

                // Un grupo sin líder vigente se marca: el escenario 2 dice
                // que las notificaciones del grupo van al líder, así que un
                // grupo sin uno es un grupo al que nadie escucha.
                object lider = DataBinder.Eval(item.DataItem, "lider");
                if (lider == null || string.IsNullOrEmpty(lider.ToString()))
                {
                    Label sinLider = new Label();
                    sinLider.Text = "Sin líder";
                    sinLider.CssClass = "grid-estado-chip is-alerta";
                    item["lider"].Controls.Add(sinLider);
                }
            }
        }
    }
}
