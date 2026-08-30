using SitioBase.Model;
using SitioBase.Controller;
using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Instalaciones : System.Web.UI.UserControl
{
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }
    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }
    
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "IdCliente":
                        IdCliente = Int32.Parse(array[1].ToString());
                        break;

                    case "ReadOnly":
                        ReadOnly = bool.Parse(array[1].ToString());
                        break;

                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (!ReadOnly)
                Grid.AddSelectColumn();

            Grid.AddColumn("CIN_ID", "", Width: "2%");
            Grid.AddColumn("CIN_ID", "ID", Width: "6%");
            Grid.AddColumn("CIN_NOMBRE", "NOMBRE", Width: "38%");
            Grid.AddColumn("CIN_DESCRIPCION", "DESCRIPCIÓN", Width: "30%");
            Grid.AddColumn("CIN_DIRECCION", "DIRECCIÓN", Width: "30%");
            Grid.AddCheckboxColumn("CIN_HABILITADO", "HABILITADO");
        }
        Tools.tools.RegisterPostBackScript(Grid);


        CargarGrid();
        udPanel.Update();

        if (ReadOnly)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        Grid.DataBind();
    }

    protected void CargarGrid()
    {
        ClienteInstalacion clienteInstalacion = new ClienteInstalacion();
        ClienteInstalacionController clienteInstalacionController = new ClienteInstalacionController();
        clienteInstalacion.filtro_cliente = IdCliente.ToString();
       
        Grid.DataSource = clienteInstalacionController.GetClienteInstalaciones(clienteInstalacion);
    }

    protected void rgrClienteInstalacion_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cin_id").ToString();

                /* Planta.aspx lee "Id", no "IdClienteInstalacion": esta
                   pestana dejo de abrir la ficha parcial y abre la completa,
                   que es la unica que existe. */
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id + "&IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                //Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirClienteInstalacion('" + query + "')");

                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell CCO_ID = DataItem["cin_id"];

                CCO_ID.Controls.Add(Editar);

            }
        }
    }

    protected void lnkNuevoClienteInstalacion_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=0&IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly));
        Tools.tools.ClientExecute("abrirClienteInstalacion('" + query + "')");
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
                ClienteInstalacion clienteInstalacion = new ClienteInstalacion();
                ClienteInstalacionController clienteInstalacionController = new ClienteInstalacionController();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int id = Int32.Parse(value["cin_id"].ToString());

                    clienteInstalacion.cin_id = id;

                    respuesta = clienteInstalacionController.DeleteClienteInstalacion(clienteInstalacion);
                }
                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", false);
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