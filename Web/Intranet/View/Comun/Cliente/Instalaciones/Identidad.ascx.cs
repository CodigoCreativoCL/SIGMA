using SitioBase.Model;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comun_Controls_Instalaciones_Identidad : System.Web.UI.UserControl
{
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public int IdClienteInstalacion
    {
        get { return Convert.ToInt32(ViewState["IdClienteInstalacion"]); }
        set { ViewState.Add("IdClienteInstalacion", value); }
    }

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();
    }

    protected void CargarDatos()
    {
        if (IdClienteInstalacion > 0)
        {
            ClienteInstalacionController clienteInstalacionController = new ClienteInstalacionController();
            ClienteInstalacion clienteInstalacion = new ClienteInstalacion();

            clienteInstalacion.cin_id = IdClienteInstalacion;
            clienteInstalacion = clienteInstalacionController.GetClienteInstalacion(clienteInstalacion);

            lblId.Text = IdClienteInstalacion.ToString();
            txtNombre.Text = clienteInstalacion.cin_nombre;
            txtDescripcion.Text = clienteInstalacion.cin_descripcion;
            txtDireccion.Text = clienteInstalacion.cin_direccion;

            if (clienteInstalacion.cin_habilitado == false)
            {
                rdbNo.Checked = true;
                rdbSi.Checked = false;
            }
            if (clienteInstalacion.cin_habilitado == true)
            {
                rdbNo.Checked = false;
                rdbSi.Checked = true;
            }
        }
    }

    protected void Bloqueo()
    {
        txtNombre.ReadOnly = ReadOnly;
        txtDescripcion.ReadOnly = ReadOnly;
        txtDireccion.ReadOnly = ReadOnly;

        rdbSi.Enabled = !ReadOnly;
        rdbNo.Enabled = !ReadOnly;

        btnGuardar.Visible = !ReadOnly;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            ClienteInstalacionController clienteInstalacionController = new ClienteInstalacionController();
            ClienteInstalacion clienteInstalacion = new ClienteInstalacion();

            clienteInstalacion.cin_id = IdClienteInstalacion;
            clienteInstalacion.cin_cliente = IdCliente;
            clienteInstalacion.cin_nombre = txtNombre.Text;
            clienteInstalacion.cin_descripcion = txtDescripcion.Text;
            clienteInstalacion.cin_direccion = txtDireccion.Text;


            if (rdbSi.Checked == true)
                clienteInstalacion.cin_habilitado = true;
            else
                clienteInstalacion.cin_habilitado = false;

            if (IdClienteInstalacion > 0)
                respuesta = clienteInstalacionController.UpdateClienteInstalacion(clienteInstalacion);
            else
            {
                respuesta = clienteInstalacionController.InsertClienteInstalacion(clienteInstalacion);
                IdClienteInstalacion = respuesta.codigo;
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", false);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

}