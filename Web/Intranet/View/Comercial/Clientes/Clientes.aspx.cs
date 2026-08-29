using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;

public partial class View_Comercial_Clientes : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina


        wucClientes.Tipo_Perfil = 1;
        #endregion
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;
            switch (ctrl.ID)
            {
                case "cboPais":
                    PaisesController paisesController = new PaisesController();
                    Paises paises = new Paises();
                    ctrl.Items.Clear();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataValueField = "pai_id";
                    ctrl.DataTextField = "pai_nombres";
                    ctrl.DataSource = paisesController.GetPaises(paises);
                    ctrl.DataBind();

                    break;

            }
        }
    }
    protected void Page_PreRender(object sender, EventArgs e)
    {
        wucClientes.FiltroTexto = wucFiltro.Filtro();

        RadComboBox2 cboHabilitados = (RadComboBox2)wucFiltro.FindControl("cboHabilitados");
        RadComboBox2 cboPais = (RadComboBox2)wucFiltro.FindControl("cboPais");
        TextBox2 txtUsuario = (TextBox2)wucFiltro.FindControl("txtUsuario");

        if (cboHabilitados.SelectedValue != "") wucClientes.FiltroHabilitado = bool.Parse(cboHabilitados.SelectedValue);
        if (cboPais.SelectedValue != "") wucClientes.FiltroPais = cboPais.SelectedValue;
        if (txtUsuario.Text != "") wucClientes.FiltroUsuario = txtUsuario.Text;
    }

} 