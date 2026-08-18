using Facilityges.Controller;
using Facilityges.Model;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Identidad : System.Web.UI.UserControl
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

    // Cuando true, muestra PanelSinSeleccion si IdCliente==0 (hay un selector externo).
    // Cuando false (default), siempre muestra el formulario (modo crear/editar directo).
    public bool RequiereSeleccion
    {
        get { return Convert.ToBoolean(ViewState["RequiereSeleccion"]); }
        set { ViewState.Add("RequiereSeleccion", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

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
                    case "cboPais":
                        Paises paises = new Paises();
                        PaisesController paisesController = new PaisesController();
                        paises.filtro_habilitado = "1";

                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = paisesController.GetPaises(paises);
                        ctrl.DataValueField = "pai_id";
                        ctrl.DataTextField = "pai_nombres";
                        ctrl.DataBind();
                        break;

                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool conCliente = IdCliente > 0;
        pnlContenido.Visible = conCliente || !RequiereSeleccion;
        wucPanelSinSeleccion.MostrarPanel = !conCliente && RequiereSeleccion;

        if (conCliente)
        {
            CargarDatos();
            Bloqueo();
            ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        }

        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IdCliente > 0)
        {
            ClienteController clienteController = new ClienteController();
            Cliente cliente = new Cliente();
            cliente.cli_id = IdCliente;
            cliente = clienteController.GetCliente(cliente);

            lblId.Text = IdCliente.ToString();
            txtNombre.Text = cliente.cli_nombre;
            txtRazonSocial.Text = cliente.cli_razon_social;
            txtIdentificacion.Text = cliente.cli_identificador;
            cboPais.SelectedValue = cliente.cli_pais.ToString();

            if (cliente.cli_logo != null)
                imgLogo.ImageUrl = "data:image/jpeg;base64," + Convert.ToBase64String(cliente.cli_logo, 0, cliente.cli_logo.Length);
            else
                imgLogo.ImageUrl = string.Empty;

            if (cliente.cli_habilitado == false)
            {
                rdbNo.Checked = true;
                rdbSi.Checked = false;
            }
            if (cliente.cli_habilitado == true)
            {
                rdbNo.Checked = false;
                rdbSi.Checked = true;
            }
        }
        else
        {
            lblId.Text = string.Empty;
            txtNombre.Text = string.Empty;
            txtRazonSocial.Text = string.Empty;
            txtIdentificacion.Text = string.Empty;
            cboPais.SelectedValue = string.Empty;
            imgLogo.ImageUrl = string.Empty;
        }
    }

    protected void Bloqueo()
    {
        txtNombre.ReadOnly = ReadOnly;
        cboPais.ReadOnly = ReadOnly;
        txtIdentificacion.ReadOnly = ReadOnly;
        txtRazonSocial.ReadOnly = ReadOnly;

        rdbSi.Enabled = !ReadOnly;
        rdbNo.Enabled = !ReadOnly;

        fldLogo.Enabled = !ReadOnly;
        pnlLogo.Visible = !ReadOnly;
        btnGuardar.Visible = !ReadOnly;
    }


    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            Cliente cliente = new Cliente();
            ClienteController clienteController = new ClienteController();

            if (fldLogo.HasFile)
            {
                string extension = Path.GetExtension(fldLogo.FileName).ToUpper();

                if (!".JPG,.PNG".Contains(extension))
                {
                    respuesta.error = true;
                    respuesta.detalle = "El formato de la imagen debe ser JPG O PNG";
                }
            }
            if (!respuesta.error)
            {
                cliente.cli_id = IdCliente;
                cliente.cli_nombre = txtNombre.Text;
                cliente.cli_identificador = txtIdentificacion.Text;
                cliente.cli_razon_social = txtRazonSocial.Text;
                cliente.cli_pais = int.Parse(cboPais.SelectedValue);
                if (fldLogo.HasFile)
                    cliente.cli_logo = fldLogo.FileBytes;

                if (rdbSi.Checked == true)
                    cliente.cli_habilitado = true;
                else
                    cliente.cli_habilitado = false;

                if (IdCliente > 0)
                    respuesta = clienteController.UpdateCliente(cliente);
                else
                {
                    respuesta = clienteController.InsertCliente(cliente);
                    IdCliente = respuesta.codigo;
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

}