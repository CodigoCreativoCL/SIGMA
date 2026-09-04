using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de procedimientos reutilizables (HU-061). El SEL trae los del
/// cliente MAS los globales del sistema; estos se ven pero no se editan ni se
/// dan de baja desde aquí (se marcan "Global" y sin lápiz). Filtra siempre por
/// el cliente en sesión.
/// </summary>
public partial class View_Mantenimiento_Procedimientos_Procedimientos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("prc_id", "", Width: "4%");
            Grid.AddColumn("prc_codigo", "CÓDIGO", Width: "12%");
            Grid.AddColumn("prc_nombre", "PROCEDIMIENTO", Width: "26%");
            Grid.AddColumn("prc_version", "VER.", Width: "6%");
            Grid.AddColumn("activo_tipo_nombre", "TIPO DE ACTIVO", Width: "18%");
            Grid.AddColumn("pasos", "PASOS", Width: "7%");
            Grid.AddColumn("es_global", "ORIGEN", Width: "10%");
            Grid.AddCheckboxColumn("prc_habilitado", "HABILITADO");
        }

        Tools.tools.RegisterPostBackScript(Grid);
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
        Procedimiento filtro = new Procedimiento();
        ProcedimientoController controller = new ProcedimientoController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetProcedimientos(filtro);
    }

    protected void rgrProcedimientos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                bool esGlobal = bool.Parse(DataBinder.Eval(item.DataItem, "es_global").ToString());
                string id = item.GetDataKeyValue("prc_id").ToString();

                item["es_global"].Text = esGlobal ? "Global" : "Del cliente";

                // Los procedimientos globales del sistema no se editan aquí: se
                // muestran sin lápiz (si igual se marcan para baja, el SP los
                // rechaza con un mensaje claro).
                if (esGlobal) return;

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirProcedimiento('" + query + "')");
                item["prc_id"].Controls.Add(Editar);
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
                ProcedimientoController controller = new ProcedimientoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    Procedimiento entidad = new Procedimiento();
                    entidad.prc_id = Int32.Parse(value["prc_id"].ToString());
                    respuesta = controller.DeleteProcedimiento(entidad);
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
