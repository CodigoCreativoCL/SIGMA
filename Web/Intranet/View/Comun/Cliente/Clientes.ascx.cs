using Facilityges.Controller;
using Facilityges.Model;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;

public partial class View_Comun_Controls_Cliente_Clientes : System.Web.UI.UserControl
{
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public string URLNuevoCliente
    {
        get { return Convert.ToString(ViewState["URLNuevoCliente"]); }
        set { ViewState.Add("URLNuevoCliente", value); }
    }

    public int VerTodoPaises
    {
        get { return Convert.ToInt32(ViewState["VerTodoPaises"]); }
        set { ViewState.Add("VerTodoPaises", value); }
    }

    public int Ver_Todo
    {
        get { return Convert.ToInt32(ViewState["Ver_Todo"]); }
        set { ViewState.Add("Ver_Todo", value); }
    }

    public int Crear_Editar
    {
        get { return Convert.ToInt32(ViewState["Crear_Editar"]); }
        set { ViewState.Add("Crear_Editar", value); }
    }

    public int Tipo_Perfil
    {
        get { return Convert.ToInt32(ViewState["Tipo_Perfil"]); }
        set { ViewState.Add("Tipo_Perfil", value); }
    }

    public string FiltroTexto
    {
        get { return Convert.ToString(ViewState["FiltroTexto"]); }
        set { ViewState.Add("FiltroTexto", value); }
    }

    public string FiltroPais
    {
        get { return Convert.ToString(ViewState["FiltroPais"]); }
        set { ViewState.Add("FiltroPais", value); }
    }

    public string FiltroUsuario
    {
        get { return Convert.ToString(ViewState["FiltroUsuario"]); }
        set { ViewState.Add("FiltroUsuario", value); }
    }

    public bool? FiltroHabilitado
    {
        get { return (bool?)ViewState["FiltroHabilitado"]; }
        set { ViewState.Add("FiltroHabilitado", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

    }




    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (!ReadOnly)
                Grid.AddSelectColumn();
            Grid.AddColumn("CLI_ID", "", Width: "2%");
            Grid.AddColumn("CLI_ID", "ID", Width: "6%");
            Grid.AddColumn("CLI_NOMBRE", "NOMBRE", Width: "68%");
            Grid.AddColumn("PAI_NOMBRE", "PAÍS", Width: "28%");
            Grid.AddCheckboxColumn("CLI_HABILITADO", "HABILITADO");
        }
      
        if (ReadOnly)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
         
        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void CargarGrid()
    {
        ClienteController clienteController = new ClienteController();
        Cliente cliente = new Cliente();

        #region SeguridadPagina
        MenuFuncion funVerTodoPaises = new MenuFuncion();
        funVerTodoPaises.mfu_id = VerTodoPaises;

        if (!SitioBase.Token.SecurityManager(funVerTodoPaises))
        {
            string pais_usuario = SitioBase.Session.UsuarioIdPaises();
            if(!string.IsNullOrEmpty(pais_usuario))
                cliente.filtro_paises = pais_usuario;
            else
                cliente.filtro_paises = "0";
        }

        MenuFuncion funVerTodo = new MenuFuncion();
        funVerTodo.mfu_id = Ver_Todo;

        if (!SitioBase.Token.SecurityManager(funVerTodo))
            cliente.cli_usuario_creacion = int.Parse(SitioBase.Session.UsuarioId());

        MenuFuncion funCrearEditar = new MenuFuncion();
        funCrearEditar.mfu_id = Crear_Editar;

        ReadOnly = !SitioBase.Token.SecurityManager(funCrearEditar);
        #endregion

        cliente.filtro = FiltroTexto;
        if (!string.IsNullOrEmpty(FiltroPais)) cliente.filtro_pais = FiltroPais;
        if (FiltroHabilitado.HasValue) cliente.filtro_habilitado = FiltroHabilitado.Value;
        if (!string.IsNullOrEmpty(FiltroUsuario)) cliente.filtro_usuarios = FiltroUsuario;
        if (Tipo_Perfil > 0) cliente.tipo_perfil = Tipo_Perfil;

        Grid.DataSource = clienteController.GetClientes(cliente);
    }

    protected void rgrCliente_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("cli_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdCliente=" + id + "&ReadOnly=" + ReadOnly));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                //Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirClientes('" + query + "')");

                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell CCO_ID = DataItem["cli_id"];

                CCO_ID.Controls.Add(Editar);
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
                Cliente cliente = new Cliente();
                ClienteController clienteController = new ClienteController();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int id = Int32.Parse(value["cli_id"].ToString());

                    cliente.cli_id = id;

                    respuesta = clienteController.DeleteCliente(cliente);
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