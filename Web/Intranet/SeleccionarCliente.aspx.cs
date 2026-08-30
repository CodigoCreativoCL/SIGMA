using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Selector de cliente (HU-002).
///
/// Se llega aqui de dos formas: al entrar, cuando la persona pertenece a
/// mas de un cliente, o desde el encabezado, cuando quiere cambiarse.
/// </summary>
public partial class SeleccionarCliente : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            CargarClientes();
        }
    }

    protected void CargarClientes()
    {
        ClienteSesionController controller = new ClienteSesionController();
        List<Cliente> clientes = controller.GetClientesElegibles(int.Parse(SitioBase.Session.UsuarioId()));

        cboCliente.Items.Clear();
        cboCliente.Items.Add(new RadComboBoxItem("Seleccione...", ""));
        cboCliente.AppendDataBoundItems = true;

        if (clientes != null)
        {
            cboCliente.DataSource = clientes;
            cboCliente.DataValueField = "cli_id";
            cboCliente.DataTextField = "cli_nombre";
            cboCliente.DataBind();
        }

        // Si ya venia trabajando en uno, queda preseleccionado: cambiar de
        // cliente no deberia obligar a buscar de nuevo el actual.
        if (SitioBase.Session.ClienteId() > 0)
            cboCliente.SelectedValue = SitioBase.Session.ClienteId().ToString();
    }

    protected void btnContinuar_Click(object sender, EventArgs e)
    {
        pnlError.Visible = false;

        if (string.IsNullOrEmpty(cboCliente.SelectedValue))
        {
            MostrarError("Debe elegir un cliente para continuar.");
            return;
        }

        try
        {
            ClienteSesionController controller = new ClienteSesionController();

            Respuesta respuesta = controller.CambiarCliente(
                int.Parse(SitioBase.Session.UsuarioId()),
                int.Parse(cboCliente.SelectedValue));

            if (respuesta.error)
            {
                MostrarError(respuesta.detalle);
                return;
            }

            // Se vuelve a la pantalla de inicio y no a la anterior: el
            // escenario 3 pide que no quede ningun dato del cliente previo
            // en pantalla, y volver atras es justamente arrastrarlos.
            Response.Redirect("~/Default.aspx");
        }
        catch (Exception ex)
        {
            MostrarError(ex.Message);
        }
    }

    private void MostrarError(string mensaje)
    {
        litError.Text = Server.HtmlEncode(mensaje);
        pnlError.Visible = true;
        udPanel.Update();
    }
}
