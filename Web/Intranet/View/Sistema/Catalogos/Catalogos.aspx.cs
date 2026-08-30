using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Consulta de catálogos y alta de valores propios (HU-020 y HU-021).
///
/// Una sola pantalla recorre los 81 catálogos registrados. Lo que cambia
/// entre uno y otro no es el código sino la fila de la tabla Catalogo: qué
/// tabla hay detrás y si admite valores del cliente.
/// </summary>
public partial class View_Sistema_Catalogos_Catalogos : System.Web.UI.Page
{
    /// <summary>Catálogo elegido. Sobrevive al postback del grid.</summary>
    public int IdCatalogo
    {
        get { return ViewState["IdCatalogo"] != null ? (int)ViewState["IdCatalogo"] : 0; }
        set { ViewState["IdCatalogo"] = value; }
    }

    public bool EsAmpliable
    {
        get { return ViewState["EsAmpliable"] != null ? (bool)ViewState["EsAmpliable"] : false; }
        set { ViewState["EsAmpliable"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            GridValores.AddColumn("VALOR_ID", "", Width: "3%");
            GridValores.AddColumn("VALOR_CODIGO", "CÓDIGO", Width: "20%");
            GridValores.AddColumn("VALOR_NOMBRE", "NOMBRE VISIBLE", Width: "32%");
            GridValores.AddColumn("VALOR_DESCRIPCION", "DESCRIPCIÓN", Width: "25%");
            GridValores.AddTemplateColumn("origenChip", "", "ORIGEN", Width: "10%");
            GridValores.AddCheckboxColumn("VALOR_HABILITADO", "HABILITADO");

            GridBusqueda.AddColumn("CTL_MODULO", "MÓDULO", Width: "18%");
            GridBusqueda.AddColumn("CTL_NOMBRE", "CATÁLOGO", Width: "27%");
            GridBusqueda.AddColumn("VALOR_CODIGO", "CÓDIGO", Width: "25%");
            GridBusqueda.AddColumn("VALOR_NOMBRE", "NOMBRE", Width: "30%");

            CargarCatalogos();
        }

        Tools.tools.RegisterPostBackScript(GridValores);
    }

    protected void CargarCatalogos()
    {
        CatalogoController controller = new CatalogoController();

        Catalogo filtro = new Catalogo();
        filtro.filtro_habilitado = true;

        List<Catalogo> lista = controller.GetCatalogos(filtro);

        cboCatalogo.Items.Clear();
        cboCatalogo.Items.Add(new RadComboBoxItem("Seleccione un catálogo...", ""));
        cboCatalogo.AppendDataBoundItems = true;

        if (lista != null)
        {
            // El módulo va en el texto para que la lista, que es larga,
            // se pueda filtrar escribiendo "Activos" o "Seguridad".
            foreach (Catalogo item in lista)
                cboCatalogo.Items.Add(new RadComboBoxItem(item.ctl_modulo + " · " + item.ctl_nombre, item.ctl_id.ToString()));
        }
    }

    protected void cboCatalogo_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        IdCatalogo = string.IsNullOrEmpty(cboCatalogo.SelectedValue) ? 0 : int.Parse(cboCatalogo.SelectedValue);

        EsAmpliable = false;

        if (IdCatalogo > 0)
        {
            CatalogoController controller = new CatalogoController();
            Catalogo catalogo = controller.GetCatalogo(IdCatalogo);

            EsAmpliable = catalogo.ctl_ampliable;

            lblTipoCatalogo.Text = catalogo.ctl_ampliable
                ? "Admite valores propios"
                : "Sólo lectura";

            lblTipoCatalogo.CssClass = catalogo.ctl_ampliable
                ? "grid-estado-chip is-exito"
                : "grid-estado-chip is-neutro";
        }
        else
        {
            lblTipoCatalogo.Text = "";
        }

        // Elegir un catálogo cierra la búsqueda transversal: son dos formas
        // distintas de mirar lo mismo y verlas juntas confunde.
        pnlBusqueda.Visible = false;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarValores();
        GridValores.DataBind();

        /* El botón "Nuevo valor" solo aparece cuando el catálogo admite
           valores propios (HU-021 escenario 2: "cuando abro un catálogo que
           no admite valores propios, la acción de agregar no se muestra")
           y además la persona tiene la facultad de escritura.

           Ocultarlo no es la seguridad: INS_CATALOGO_VALOR rechaza igual un
           catálogo no ampliable. Esto es para no ofrecer algo que va a
           fallar. */
        bool puedeCrear = IdCatalogo > 0 && EsAmpliable && Token.PuedeFuncion("Crear y editar");

        GridValores.MasterTableView.CommandItemDisplay = puedeCrear
            ? GridCommandItemDisplay.Top
            : GridCommandItemDisplay.None;

        udPanel.Update();
    }

    protected void CargarValores()
    {
        if (IdCatalogo == 0)
        {
            GridValores.DataSource = new List<CatalogoValor>();
            return;
        }

        CatalogoController controller = new CatalogoController();
        GridValores.DataSource = controller.GetValores(IdCatalogo, SitioBase.Session.ClienteId());
    }

    protected void GridValores_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;

                string origen = DataBinder.Eval(item.DataItem, "origen") != null
                    ? DataBinder.Eval(item.DataItem, "origen").ToString()
                    : "";

                Label lblOrigen = new Label();
                lblOrigen.Text = origen;
                lblOrigen.CssClass = "grid-estado-chip " + (origen == "Propio" ? "is-acento" : "is-neutro");
                item["origenChip"].Controls.Add(lblOrigen);

                /* Solo los valores PROPIOS del cliente se pueden editar. Los
                   del sistema son de sólo lectura (HU-020 escenario 1: "no
                   puedo modificar ni eliminar sus valores"), así que no se
                   les pinta el lápiz. UPD_CATALOGO_VALOR lo vuelve a
                   comprobar de todas formas. */
                object cliente = item.GetDataKeyValue("valor_cliente");
                bool esPropio = cliente != null && cliente != DBNull.Value;

                if (esPropio && Token.PuedeFuncion("Crear y editar"))
                {
                    string id = item.GetDataKeyValue("valor_id").ToString();

                    string query = Server.UrlEncode(Tools.Crypto.Encrypt(
                        "IdCatalogo=" + IdCatalogo + "&IdValor=" + id));

                    HyperLink Editar = new HyperLink();
                    Editar.ID = "lnkEditar" + id;
                    Editar.CssClass = "icono_Editar";
                    Editar.NavigateUrl = "javascript:void(0)";
                    Editar.Attributes.Add("onclick", "abrirValor('" + query + "')");

                    item["valor_id"].Controls.Add(Editar);
                }
            }
        }
    }

    protected void btnBuscar_Click(object sender, EventArgs e)
    {
        try
        {
            string texto = txtBusqueda.Text.Trim();

            if (texto.Length < 2)
            {
                Tools.tools.ClientAlert("Indique al menos dos caracteres para buscar.", "alerta");
                return;
            }

            CatalogoController controller = new CatalogoController();
            List<CatalogoValor> resultados = controller.BuscarEnCatalogos(texto, SitioBase.Session.ClienteId());

            GridBusqueda.DataSource = resultados;
            GridBusqueda.DataBind();

            pnlBusqueda.Visible = true;

            if (resultados == null || resultados.Count == 0)
                Tools.tools.ClientAlert("No se encontraron valores con ese texto.", "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void btnLimpiar_Click(object sender, EventArgs e)
    {
        txtBusqueda.Text = "";
        pnlBusqueda.Visible = false;
        GridBusqueda.DataSource = new List<CatalogoValor>();
        GridBusqueda.DataBind();
    }
}
