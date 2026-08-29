using SitioBase.Controller;
using SitioBase.Model;
using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_UsuarioClientes : System.Web.UI.UserControl
{
protected InformeController controller = new InformeController();

    protected void Page_Load(object sender, EventArgs e)
    {
        // Los permisos son codigos y se consultan directo con Token.Puede.
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

                        UsuarioCliente filtro = new UsuarioCliente();

                        if (!Token.PuedeFuncion("Ver todo"))
                        {   
                            // si no tiene el permiso debo filtrar por los clientes del usuario
                            filtro.ucl_id = int.Parse(SitioBase.Session.UsuarioId());
                        }

                        List<Cliente> lista = controller.GetClienteCBO(filtro);

                        if (lista == null || lista.Count == 0)
                        {
                            ctrl.Items.Add(new RadComboBoxItem("Sin Clientes", ""));
                        }
                        else
                        {
                            if (lista.Count > 1)
                            {
                                ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                            }

                            ctrl.AppendDataBoundItems = true;
                            ctrl.DataSource = lista;
                            ctrl.DataValueField = "cli_id";
                            ctrl.DataTextField = "cli_nombre";
                            ctrl.DataBind();
                        }
                        break;
                }
            }
        }
    }

    public int GetCliente()
    {
        if (!string.IsNullOrEmpty(cboCliente.SelectedValue))
            return int.Parse(cboCliente.SelectedValue);
        else
            return 0;
    }
}