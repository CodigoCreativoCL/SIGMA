using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Especialidades y certificaciones del personal del cliente (HU-017).
/// </summary>
public partial class View_Organizacion_Especialidades_UsuarioEspecialidades : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("UES_ID", "", Width: "3%");
            Grid.AddColumn("USU_NOMBRE", "PERSONA", Width: "24%");
            Grid.AddColumn("ESP_NOMBRE", "ESPECIALIDAD", Width: "18%");
            Grid.AddColumn("ENL_NOMBRE", "NIVEL", Width: "12%");
            Grid.AddColumn("UES_CERTIFICACION", "CERTIFICACIÓN", Width: "20%");
            Grid.AddColumn("UES_FECHA_VENCIMIENTO", "VENCE EL", Width: "11%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "12%", ItemPosition: HorizontalAlign.Center);
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

                if (ctrl.ID == "cboEspecialidad")
                {
                    Especialidad filtro = new Especialidad();
                    filtro.esp_cliente = SitioBase.Session.ClienteId();
                    filtro.filtro_habilitado = true;

                    UsuarioEspecialidadController controller = new UsuarioEspecialidadController();

                    ctrl.Items.Add(new RadComboBoxItem("Todas", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = controller.GetEspecialidades(filtro);
                    ctrl.DataValueField = "esp_id";
                    ctrl.DataTextField = "esp_nombre";
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

        CargarAlertas();
        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// HU-017 escenario 3: "una certificación que vence en menos de 30 días
    /// aparece en el panel de alertas del administrador".
    ///
    /// Se muestran juntas las vencidas y las por vencer: quien administra
    /// necesita ver ambas para decidir a quién recertificar primero.
    /// </summary>
    protected void CargarAlertas()
    {
        UsuarioEspecialidadController controller = new UsuarioEspecialidadController();

        List<UsuarioEspecialidad> vencidas = controller.GetUsuarioEspecialidades(
            new UsuarioEspecialidad
            {
                ues_cliente = SitioBase.Session.ClienteId(),
                filtro_solo_vencidas = true,
                filtro_habilitado = true
            });

        List<UsuarioEspecialidad> porVencer = controller.GetUsuarioEspecialidades(
            new UsuarioEspecialidad
            {
                ues_cliente = SitioBase.Session.ClienteId(),
                filtro_solo_por_vencer = true,
                filtro_habilitado = true
            });

        int nVencidas = vencidas != null ? vencidas.Count : 0;
        int nPorVencer = porVencer != null ? porVencer.Count : 0;

        if (nVencidas == 0 && nPorVencer == 0)
        {
            pnlAlertas.Visible = false;
            return;
        }

        string texto = "";

        if (nVencidas > 0)
            texto += "<span class=\"grid-estado-chip is-alerta\">" +
                     nVencidas + (nVencidas == 1 ? " certificación vencida" : " certificaciones vencidas") +
                     "</span> ";

        if (nPorVencer > 0)
            texto += "<span class=\"grid-estado-chip is-info\">" +
                     nPorVencer + (nPorVencer == 1 ? " vence" : " vencen") + " en menos de 30 días</span>";

        litAlertas.Text = texto;
        pnlAlertas.Visible = true;
    }

    protected void CargarGrid()
    {
        UsuarioEspecialidad filtro = new UsuarioEspecialidad();
        UsuarioEspecialidadController controller = new UsuarioEspecialidadController();

        filtro.ues_cliente = SitioBase.Session.ClienteId();
        filtro.filtro_habilitado = true;

        RadComboBox2 cboEspecialidad = (RadComboBox2)wucFiltro.FindControl("cboEspecialidad");
        RadComboBox2 cboEstado = (RadComboBox2)wucFiltro.FindControl("cboEstado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        if (cboEspecialidad != null && cboEspecialidad.SelectedValue != "")
            filtro.ues_especialidad = int.Parse(cboEspecialidad.SelectedValue);

        if (cboEstado != null)
        {
            if (cboEstado.SelectedValue == "VENCIDA") filtro.filtro_solo_vencidas = true;
            if (cboEstado.SelectedValue == "POR_VENCER") filtro.filtro_solo_por_vencer = true;
        }

        Grid.DataSource = controller.GetUsuarioEspecialidades(filtro);
    }

    protected void rgrEspecialidades_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("ues_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirEspecialidad('" + query + "')");

                item["ues_id"].Controls.Add(Editar);

                string estado = DataBinder.Eval(item.DataItem, "estado") != null
                    ? DataBinder.Eval(item.DataItem, "estado").ToString()
                    : "";

                Label lblEstado = new Label();
                lblEstado.Text = TextoEstado(estado, DataBinder.Eval(item.DataItem, "dias_para_vencer"));
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(estado);
                item["estadoChip"].Controls.Add(lblEstado);
            }
        }
    }

    private string TextoEstado(string estado, object dias)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VENCIDA": return "Vencida";
            case "POR_VENCER":
                // Los días restantes son la información útil: "vence en 12
                // días" dice qué hacer, "por vencer" no.
                return dias != null ? "Vence en " + dias + " días" : "Por vencer";
            case "SIN_CERTIFICACION": return "Sin certificado";
            default: return "Vigente";
        }
    }

    private string ChipDeEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VENCIDA": return "is-alerta";
            case "POR_VENCER": return "is-info";
            case "SIN_CERTIFICACION": return "is-neutro";
            default: return "is-exito";
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
                UsuarioEspecialidadController controller = new UsuarioEspecialidadController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    UsuarioEspecialidad entidad = new UsuarioEspecialidad();
                    entidad.ues_id = Int32.Parse(value["ues_id"].ToString());

                    respuesta = controller.DeleteUsuarioEspecialidad(entidad);
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
