using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de atributos técnicos (HU-032), tabla plana con el tipo de equipo
/// como columna. El SEL trae los del cliente MÁS los globales de la plataforma
/// (estos se ven pero no se editan aquí). Filtra siempre por el cliente en sesión.
/// </summary>
public partial class View_Activos_Atributos_AtributoTecnicos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ate_id", "", Width: "4%");
            Grid.AddColumn("TIPO_NOMBRE", "TIPO DE ACTIVO", Width: "18%");
            Grid.AddColumn("ATE_CODIGO", "CÓDIGO", Width: "10%");
            Grid.AddColumn("ATE_NOMBRE", "ATRIBUTO", Width: "22%");
            Grid.AddColumn("TIPO_DATO_NOMBRE", "TIPO DE DATO", Width: "13%");
            Grid.AddColumn("UNIDAD_NOMBRE", "UNIDAD", Width: "12%");
            Grid.AddColumn("es_global", "ORIGEN", Width: "10%");
            Grid.AddCheckboxColumn("ATE_HABILITADO", "HABILITADO");
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
        AtributoTecnico filtro = new AtributoTecnico();
        AtributoTecnicoController controller = new AtributoTecnicoController();

        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        List<AtributoTecnico> lista = controller.GetAtributos(filtro) ?? new List<AtributoTecnico>();
        // Agrupados visualmente: se ordenan por tipo y luego por el atributo.
        Grid.DataSource = lista.OrderBy(a => a.tipo_nombre).ThenBy(a => a.ate_id).ToList();
    }

    protected void rgrAtributos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                bool esGlobal = bool.Parse(DataBinder.Eval(item.DataItem, "es_global").ToString());
                string id = item.GetDataKeyValue("ate_id").ToString();

                item["es_global"].Text = esGlobal ? "Global" : "Del cliente";

                // Los atributos globales de la plataforma no se editan aquí.
                if (esGlobal) return;

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirAtributo('" + query + "')");
                item["ate_id"].Controls.Add(Editar);
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
                AtributoTecnicoController controller = new AtributoTecnicoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];
                    AtributoTecnico entidad = new AtributoTecnico();
                    entidad.ate_id = Int32.Parse(value["ate_id"].ToString());
                    respuesta = controller.DeleteAtributo(entidad);
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
