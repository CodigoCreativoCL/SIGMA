using SitioBase.Controller;
using SitioBase.Model;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Clientes_Cliente_Instalaciones : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        //#region SeguridadPagina
        //MenuPerfil ver = new MenuPerfil();
        //ver.mpe_menu = (int)SitioBase.Paginas.menu_42.Ver;

        //SitioBase.Token.SecurityManagerVer(ver);
        //MenuFuncion funCrearEditar = new MenuFuncion();

        //funCrearEditar.mfu_id = (int)SitioBase.Paginas.menu_42.Crear_Editar;
        //wucInstalaciones.ReadOnly = !SitioBase.Token.SecurityManager(funCrearEditar);
        //#endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Cargar();
    }

    public void LoadControls(object sender, System.EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {
                    case "cboCliente":
                        ClienteController clienteController = new ClienteController();
                        Cliente cliente = new Cliente();

                        cliente.filtro_habilitado = true;
                        //#region SeguridadPagina
                        //MenuFuncion funVerTodoPaises = new MenuFuncion();
                        //funVerTodoPaises.mfu_id = (int)SitioBase.Paginas.menu_42.Ver_Todo_Paises;

                        //if (!SitioBase.Token.SecurityManager(funVerTodoPaises))
                        //    cliente.filtro_paises = SitioBase.Session.UsuarioIdPaises();

                        //MenuFuncion funVerTodo = new MenuFuncion();
                        //funVerTodo.mfu_id = (int)SitioBase.Paginas.menu_42.Ver_Todo;

                        //if (!SitioBase.Token.SecurityManager(funVerTodo))
                        //    cliente.cli_usuario_creacion = int.Parse(SitioBase.Session.UsuarioId());
                        //#endregion
                        if(int.Parse(SitioBase.Session.UsuarioTipoPerfil()) == 2)
                            cliente.tipo_perfil = int.Parse(SitioBase.Session.UsuarioTipoPerfil());
                        var clientes = clienteController.GetClientes(cliente);
                        if (clientes.Count > 1)
                        {
                            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                            ctrl.AppendDataBoundItems = true;
                        }
                        ctrl.DataSource = clientes;
                        ctrl.DataValueField = "cli_id";
                        ctrl.DataTextField = "cli_nombre";
                        ctrl.DataBind();
                        break;

                }
            }
        }
    }

    protected void Cargar()
    {
        if (cboCliente.SelectedValue != "")
        {
            wucInstalaciones.IdCliente = int.Parse(cboCliente.SelectedValue);
            //if (int.Parse(SitioBase.Session.UsuarioTipoPerfil()) == 2)
                //wucInstalaciones.Administrativo = int.Parse(SitioBase.Session.UsuarioId());
        }            
        else
            wucInstalaciones.IdCliente = 0;            
    }

}