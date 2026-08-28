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

                        //    cliente.filtro_paises = SitioBase.Session.UsuarioIdPaises();


                        //    cliente.cli_usuario_creacion = int.Parse(SitioBase.Session.UsuarioId());
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