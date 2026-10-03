using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Listado de bodegas (HU-052).
/// </summary>
public partial class View_Inventario_Bodegas_Bodegas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("BOD_ID", "", Width: "6%");
            Grid.AddColumn("BOD_CODIGO", "CÓDIGO", Width: "13%");
            Grid.AddColumn("BOD_NOMBRE", "NOMBRE", Width: "24%");
            Grid.AddColumn("PLANTA_NOMBRE", "PLANTA", Width: "18%");
            // lo mismo que muestra el mapa 3D de cada bodega (bloque 332)
            Grid.AddColumn("METODO", "SALIDA", Width: "9%");
            Grid.AddColumn("UBICACIONES", "RACKS", Width: "9%");
            Grid.AddColumn("CONTADOS_30", "CONTADOS 30 D", Width: "10%");
            Grid.AddColumn("REPUESTOS_CON_SALDO", "CON EXISTENCIA", Width: "11%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// Llena el combo de plantas del filtro (patrón: OnLoad="LoadControls").
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboPlanta")
            {
                ClienteInstalacion filtroPlanta = new ClienteInstalacion();
                filtroPlanta.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                filtroPlanta.filtro_habilitado = "1";

                ClienteInstalacionController ctrlPlanta = new ClienteInstalacionController();

                ctrl.Items.Add(new RadComboBoxItem("Todas", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = ctrlPlanta.GetClienteInstalaciones(filtroPlanta);
                ctrl.DataValueField = "cin_id";
                ctrl.DataTextField = "cin_nombre";
                ctrl.DataBind();
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!Token.PuedeFuncion("Crear y editar"))
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("bod_id").ToString();
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + item.ItemIndex;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirBodega('" + query + "')");

                item["bod_id"].Controls.Add(Editar);

                /* La misma bodega en el mapa 3D, en otra pestaña: el listado
                   no se pierde. */
                if (Token.Puede("VER BODEGAS"))
                {
                    HyperLink mapa = new HyperLink();
                    mapa.ID = "lnkMapa" + item.ItemIndex;
                    mapa.Text = "<i class=\"mdi mdi-cube-scan\" style=\"font-size:18px;color:#087BEA;vertical-align:middle;margin-left:8px\"></i>";
                    mapa.ToolTip = "Ver en el mapa 3D";
                    mapa.Target = "_blank";
                    mapa.NavigateUrl = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx") + "?ir=BOD-" + id;
                    item["bod_id"].Controls.Add(mapa);
                }
            }
        }
    }

    protected void CargarGrid()
    {
        BodegaController controller = new BodegaController();

        Bodega filtro = new Bodega();

        /* El texto busca por código y por nombre: es lo que hace @FILTRO en
           SEL_BODEGA, parametrizado. */
        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        RadComboBox2 cboPlanta = (RadComboBox2)wucFiltro.FindControl("cboPlanta");
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (cboPlanta != null && !string.IsNullOrEmpty(cboPlanta.SelectedValue))
            filtro.filtro_instalacion = int.Parse(cboPlanta.SelectedValue);

        /* Por defecto solo las habilitadas. Sin esto el listado abriría
           mostrando también las dadas de baja, que es información de
           auditoría y no lo que se viene a hacer. */
        filtro.filtro_habilitado = (cboHabilitado != null && !string.IsNullOrEmpty(cboHabilitado.SelectedValue))
            ? (bool?)(cboHabilitado.SelectedValue == "1")
            : true;

        /* La grilla se arma con lo de SEL_BODEGA y lo que sabe el mapa
           (metodo de salida y racks contados en 30 dias): una tabla y no la
           lista, porque esas dos columnas no son del modelo Bodega. */
        Dictionary<int, DataRow> mapa = new Dictionary<int, DataRow>();
        foreach (DataRow r in new BodegaAlmacenamientoController().Resumen().Rows) mapa[Convert.ToInt32(r["BOD_ID"])] = r;

        DataTable t = new DataTable();
        foreach (string c in new[] { "bod_id", "bod_codigo", "bod_nombre", "planta_nombre", "metodo", "ubicaciones", "contados_30", "repuestos_con_saldo" })
            t.Columns.Add(c, c == "bod_id" || c == "ubicaciones" || c == "contados_30" || c == "repuestos_con_saldo" ? typeof(int) : typeof(string));
        foreach (Bodega b in controller.GetBodegas(filtro) ?? new List<Bodega>())
        {
            DataRow m;
            mapa.TryGetValue(b.bod_id, out m);
            t.Rows.Add(b.bod_id, b.bod_codigo, b.bod_nombre, b.planta_nombre,
                       m != null ? Convert.ToString(m["METODO"]) : "FEFO", b.ubicaciones,
                       m != null ? Convert.ToInt32(m["CONTADOS_30"]) : 0, b.repuestos_con_saldo);
        }
        Grid.DataSource = t;
    }
}
