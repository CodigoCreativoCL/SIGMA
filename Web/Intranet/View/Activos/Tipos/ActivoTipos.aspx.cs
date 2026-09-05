using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de tipos de activo, en árbol (HU-030).
///
/// Muestra los tipos del cliente en sesión MÁS los globales de SIGMA (que
/// se ven pero no se editan). El acceso lo resuelve el master con
/// Token.ExigirPagina(); aquí solo se pregunta la función de escritura.
/// </summary>
public partial class View_Activos_Tipos_ActivoTipos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("ATI_ID", "", Width: "4%");     // lupa (editar)
            Grid.AddColumn("nivel", "", Width: "4%");        // columna propia del chevron (reusa el campo nivel)
            Grid.AddColumn("ATI_CODIGO", "CÓDIGO", Width: "16%");
            Grid.AddColumn("ATI_NOMBRE", "NOMBRE", Width: "30%");
            Grid.AddColumn("PADRE_NOMBRE", "DEPENDE DE", Width: "22%");
            Grid.AddColumn("AMBITO", "ÁMBITO", Width: "12%");
            Grid.AddCheckboxColumn("ATI_HABILITADO", "HABILITADO");
        }

        // Es un ÁRBOL: las filas deben quedar en su orden jerárquico (padre y
        // luego sus hijos, por ruta). Ordenar por columna o paginar rompería
        // ese orden y la indentación/dependencias se desarmarían. Por eso se
        // desactiva el ordenamiento y el paginado (se fuerza aquí para que no
        // lo reponga el wrapper del RadGrid).
        Grid.AllowSorting = false;
        Grid.MasterTableView.AllowSorting = false;
        Grid.AllowPaging = false;
        Grid.MasterTableView.AllowPaging = false;

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
        ActivoTipo filtro = new ActivoTipo();
        ActivoTipoController controller = new ActivoTipoController();

        // El SEL devuelve los del cliente MÁS los globales.
        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();
        if (cboHabilitado != null && cboHabilitado.SelectedValue != "")
            filtro.filtro_habilitado = cboHabilitado.SelectedValue == "1";

        Grid.DataSource = controller.GetActivoTipos(filtro);
    }

    protected void rgrTipos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("ati_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                int nivel = 1;
                object valorNivel = DataBinder.Eval(item.DataItem, "nivel");
                if (valorNivel != null) int.TryParse(valorNivel.ToString(), out nivel);

                item.Attributes["data-nivel"] = nivel.ToString();
                item.Attributes["data-tipoid"] = id;

                // La lupa (editar) en su columna.
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirActivoTipo('" + query + "')");
                item["ati_id"].Controls.Add(Editar);

                // El chevron en SU PROPIA columna (reemplaza el número de nivel).
                // El JS lo enciende solo si el tipo tiene hijos.
                TableCell celdaBtn = item["nivel"];
                celdaBtn.HorizontalAlign = HorizontalAlign.Center;
                celdaBtn.Text = "<span class=\"sigma-tree-btn\"></span>";

                // En la columna Nombre queda el conector └ (para los hijos) + el
                // nombre indentado por nivel. El botón ya no vive aquí.
                TableCell celda = item["ati_nombre"];
                celda.Style["padding-left"] = "0";
                int indent = (nivel - 1) * 28;
                string elbow = nivel > 1 ? "<span class=\"sigma-tree-elbow\"></span>" : "";
                celda.Text =
                    "<span class=\"sigma-tree-item\" style=\"padding-left:" + indent + "px\">" +
                        elbow +
                        "<span class=\"sigma-tree-nom\">" + celda.Text + "</span>" +
                    "</span>";
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
                ActivoTipoController controller = new ActivoTipoController();

                foreach (string indice in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(indice)];

                    ActivoTipo entidad = new ActivoTipo();
                    entidad.ati_id = Int32.Parse(value["ati_id"].ToString());

                    respuesta = controller.DeleteActivoTipo(entidad);
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
