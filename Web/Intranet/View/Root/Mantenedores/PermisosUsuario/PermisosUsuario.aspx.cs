using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Excepciones de permiso por persona (HU-007).
///
/// No hay botón Eliminar: revocar es una baja lógica, porque el escenario 2
/// pide que la revocación quede registrada. Un DELETE no registra nada.
/// </summary>
public partial class View_Root_Mantenedores_PermisosUsuario_PermisosUsuario : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("CPM_ID", "", Width: "3%");
            Grid.AddColumn("USU_NOMBRE", "PERSONA", Width: "19%");
            Grid.AddColumn("PRM_NOMBRE", "PERMISO", Width: "22%");
            Grid.AddTemplateColumn("efectoChip", "", "EFECTO", Width: "9%", ItemPosition: HorizontalAlign.Center);
            Grid.AddColumn("AMBITO", "ÁMBITO", Width: "8%");
            Grid.AddColumn("CIN_NOMBRE", "PLANTA", Width: "13%");
            Grid.AddColumn("CPM_FECHA_FIN", "VIGENTE HASTA", Width: "10%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "10%", ItemPosition: HorizontalAlign.Center);
            Grid.AddTemplateColumn("revocar", "", "", Width: "6%", ItemPosition: HorizontalAlign.Center);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        if (!Token.PuedeFuncion("Otorgar y revocar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        ClienteUsuarioPermiso filtro = new ClienteUsuarioPermiso();
        ClienteUsuarioPermisoController controller = new ClienteUsuarioPermisoController();

        filtro.cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboVigencia = (RadComboBox2)wucFiltro.FindControl("cboVigencia");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboVigencia != null && cboVigencia.SelectedValue == "1") filtro.filtro_solo_vigentes = true;

        Grid.DataSource = controller.GetPermisos(filtro);
    }

    protected void Grid_ItemCreated(object sender, GridItemEventArgs e)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = (GridDataItem)e.Item;

            LinkButton lnkRevocar = new LinkButton();
            lnkRevocar.ID = "lnkRevocar";
            lnkRevocar.Text = "&nbsp";
            lnkRevocar.CssClass = "icono_eliminar";
            lnkRevocar.ToolTip = "Revocar";
            lnkRevocar.OnClientClick = "return ConfirSweetAlert(this, '', '¿Revocar este permiso? La persona vuelve a lo que define su perfil.');";
            lnkRevocar.Command += new CommandEventHandler(lnkRevocar_Command);

            item["revocar"].Controls.Add(lnkRevocar);

            ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkRevocar);
        }
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cpm_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirPermiso('" + query + "')");

                item["cpm_id"].Controls.Add(Editar);

                /* Conceder y denegar se distinguen a simple vista: una
                   denegación quita un permiso que el perfil sí da, y
                   confundirla con una concesión al revisar la lista sería
                   leer exactamente lo contrario de lo que dice. */
                bool otorgado = Convert.ToBoolean(DataBinder.Eval(item.DataItem, "cpm_otorgado"));

                Label lblEfecto = new Label();
                lblEfecto.Text = otorgado ? "Concede" : "Deniega";
                lblEfecto.CssClass = "grid-estado-chip " + (otorgado ? "is-exito" : "is-alerta");
                item["efectoChip"].Controls.Add(lblEfecto);

                string estado = DataBinder.Eval(item.DataItem, "estado") != null
                    ? DataBinder.Eval(item.DataItem, "estado").ToString()
                    : "";

                Label lblEstado = new Label();
                lblEstado.Text = Capitalizar(estado);
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(estado);
                item["estadoChip"].Controls.Add(lblEstado);

                // Solo se revoca lo que sigue vigente. Lo ya revocado o
                // vencido no tiene nada que revocar.
                LinkButton lnkRevocar = (LinkButton)item["revocar"].FindControl("lnkRevocar");
                if (lnkRevocar != null)
                {
                    lnkRevocar.CommandName = id;
                    lnkRevocar.Visible = estado == "VIGENTE" && Token.PuedeFuncion("Otorgar y revocar");
                }
            }
        }
    }

    private string Capitalizar(string texto)
    {
        if (string.IsNullOrEmpty(texto)) return "";
        return texto.Substring(0, 1).ToUpper() + texto.Substring(1).ToLower();
    }

    private string ChipDeEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VIGENTE": return "is-exito";
            case "PENDIENTE": return "is-info";
            case "VENCIDO": return "is-neutro";
            case "REVOCADO": return "is-alerta";
            default: return "is-neutro";
        }
    }

    protected void lnkRevocar_Command(object sender, CommandEventArgs e)
    {
        try
        {
            ClienteUsuarioPermiso entidad = new ClienteUsuarioPermiso();
            ClienteUsuarioPermisoController controller = new ClienteUsuarioPermisoController();

            // Se recupera el registro completo: UPD_ escribe todos los
            // campos, así que mandarlo con los demás en blanco borraría la
            // vigencia y el motivo.
            entidad = controller.GetPermiso(new ClienteUsuarioPermiso { cpm_id = int.Parse(e.CommandName.ToString()) });

            Respuesta respuesta = controller.RevocarPermiso(entidad);

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }
}
