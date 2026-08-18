using System;
using System.IO;
using SitioBase.Model;
using SitioBase.Controller;
using Telerik.Web.UI;
using SitioBase.Model;
using SitioBase.Controller;
using System.Web.DynamicData;


public partial class View_Comun_Clientes_AsociarUsuario : System.Web.UI.Page
{
    public int Id
    {
        get { return Convert.ToInt32(ViewState["id"]); }
        set { ViewState.Add("id", value); }
    }

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public int IdClienteInstalacion
    {
        get { return Convert.ToInt32(ViewState["IdClienteInstalacion"]); }
        set { ViewState.Add("IdClienteInstalacion", value); }
    }

    public int TipoPerfil
    {
        get { return Convert.ToInt32(ViewState["TipoPerfil"]); }
        set { ViewState.Add("TipoPerfil", value); }
    }

    public string Perfiles
    {
        get { return Convert.ToString(ViewState["Perfiles"]); }
        set { ViewState.Add("Perfiles", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddSelectColumn();
            Grid.AddColumn("USU_ID", "", Width: "2%");
            Grid.AddColumn("nombre_completo", "NOMBRE COMPLETO");
            Grid.AddColumn("usu_telefono", "TELEFONO");
            Grid.AddColumn("usu_correo", "CORREO");
            Grid.AddColumn("PERFILES", "PERFIL");

            //Recupero el query string
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
                        break;
                    case "IdCliente":
                        IdCliente = Int32.Parse(array[1].ToString());
                        break;
                    case "IdClienteInstalacion":
                        IdClienteInstalacion = Int32.Parse(array[1].ToString());
                        break;
                    case "TipoPerfil":
                        TipoPerfil = Int32.Parse(array[1].ToString());
                        break;
                    case "Perfiles":
                        Perfiles = array[1].ToString();
                        break;
                   
                }

            }
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
    }

    protected void CargarDatos()
    {
        ClienteUsuario clienteUsuario = new ClienteUsuario();
        ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
        clienteUsuario.cin_id_instalacion = IdClienteInstalacion;
        clienteUsuario.ucl_id_cliente = IdCliente;
        clienteUsuario.tipo_perfil = TipoPerfil;
        clienteUsuario.id_perfiles = Perfiles;

        RadComboBox2 cboPerfiles = wucFiltro.FindControl("cboPerfiles") as RadComboBox2;
        if (!string.IsNullOrEmpty(cboPerfiles.SelectedValue))
            clienteUsuario.id_perfiles = cboPerfiles.SelectedValue;

        if (wucFiltro.Filtro() != null) clienteUsuario.filtro = wucFiltro.Filtro();


        if (IdClienteInstalacion > 0)
        {
            // Vista para asociar a Instalaciones
            Grid.DataSource = clienteUsuarioController.GetClienteUsuariosAsociarInstalacion2(clienteUsuario);
        }
        else
        {
            // Vista para asociar reasignacion de uusuario a cliente
            Grid.DataSource = clienteUsuarioController.GetClienteUsuariosAsociarInstalacion(clienteUsuario);
        }
        Grid.DataBind();

    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {

                    case "cboPerfiles":

                        PerfilController perfilController = new PerfilController();
                        Perfil perfil = new Perfil();
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataValueField = "per_id";
                        ctrl.DataTextField = "per_nombre";
                        perfil.tipo = "1";
                        string Perfiles = SitioBase.SitioBase.Parametros("Asignar_Perfiles");
                        perfil.Perfiles = Perfiles;
                        ctrl.DataSource = perfilController.ListoPerfiles(perfil);
                        ctrl.DataBind();

                        break;

                }
            }
        }
    }

    protected void btnGuardar_OnClick(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                ClienteUsuario clienteUsuario = new ClienteUsuario();
                ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
                Respuesta respuesta = new Respuesta();

                foreach (string item in Grid.SelectedIndexes)
                {
                    if (TipoPerfil == 1)
                    {
                        if (IdClienteInstalacion > 0)
                        {
                            Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                            int id = Int32.Parse(value["usu_id"].ToString());

                            clienteUsuario.usu_id = id;
                            clienteUsuario.ucl_id_cliente = IdCliente;
                            clienteUsuario.cin_id_instalacion = IdClienteInstalacion;

                            respuesta = clienteUsuarioController.AsociarClienteUsuario(clienteUsuario);
                        }
                        // Si IdClienteInstalacion es NULL o 0, pasa por el else
                        else
                        {
                            Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                            int id = Int32.Parse(value["usu_id"].ToString());

                            clienteUsuario.usu_id = id;
                            clienteUsuario.ucl_id_cliente = IdCliente;

                            UsuarioPerfil usuarioPerfil = new UsuarioPerfil();
                            usuarioPerfil.upe_usuario = id;

                            UsuarioController usuarioController = new UsuarioController();
                            usuarioController.GetUsuarioPerfil(usuarioPerfil);
                            

                            respuesta = clienteUsuarioController.ReasignarUsuarioCliente(clienteUsuario);
                        }
                    }
                    else
                    {
                        Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                        int id = Int32.Parse(value["usu_id"].ToString());

                        clienteUsuario.usu_id = id;
                        clienteUsuario.ucl_id_cliente = IdCliente;
                        clienteUsuario.cin_id_instalacion = IdClienteInstalacion;
                
                        respuesta = clienteUsuarioController.AsociarClienteUsuario(clienteUsuario);
                    }

                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}