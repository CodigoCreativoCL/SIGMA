using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using Sigma.Model;
using Sigma.Controller;
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL TAB / SUB-FORMULARIO DE CLIENTE.
///
/// Aqui vive el CRUD real de la pantalla. Siempre los mismos metodos:
///
///   LoadControls()     -> puebla los combos (una sola vez, en !IsPostBack).
///   CargarDatos()      -> si IdCliente > 0 trae el registro y llena los controles.
///   Bloqueo()          -> aplica ReadOnly a cada control.
///   btnGuardar_Click() -> arma el Model desde los controles y llama Insert/Update.
///
/// PATRON (ver PATRON_MVC.md seccion 6):
///  - Nunca se llama a la BD desde aqui: siempre a traves del Controller.
///  - El "alta vs edicion" se decide con un solo if: IdCliente > 0.
///  - Todo va envuelto en try/catch que termina en Tools.tools.ClientAlert.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Comun_Controls_Cliente_Identidad : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    public int IdCliente
    {
        get { return ViewState["IdCliente"] == null ? 0 : (int)ViewState["IdCliente"]; }
        set { ViewState["IdCliente"] = value; }
    }

    #endregion

    #region CICLO DE VIDA

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();

        // Sin esta linea el boton Guardar NO dispara postback dentro del UpdatePanel.
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);

        udPanel.Update();
    }

    #endregion

    #region CARGA Y BLOQUEO

    /// <summary>
    /// Modo edicion -> trae el registro y llena los controles.
    /// Modo alta    -> limpia todo.
    /// </summary>
    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (IdCliente > 0)
        {
            ClienteController clienteController = new ClienteController();
            Cliente cliente = clienteController.GetCliente(new Cliente { cli_id = IdCliente });

            if (cliente == null) return;

            txtNombre.Text = cliente.cli_nombre;
            chkHabilitado.Checked = cliente.cli_habilitado;
        }
        else
        {
            txtNombre.Text = string.Empty;
            chkHabilitado.Checked = true;
        }
    }

    /// <summary>
    /// Un unico lugar donde se aplica el modo consulta.
    /// ReadOnly en los controles del proyecto renderiza un span con el valor
    /// y oculta el input: no se puede editar ni por inspector.
    /// </summary>
    protected void Bloqueo()
    {
        txtNombre.ReadOnly = ReadOnly;

        chkHabilitado.Enabled = !ReadOnly;

        btnGuardar.Visible = !ReadOnly;
    }

    #endregion

    #region GUARDAR

    /// <summary>
    /// Unico punto de escritura de la pantalla.
    /// Secuencia: armar Model -> validar -> Insert o Update -> avisar.
    /// </summary>
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            // 1. Armar el Model desde los controles.
            Cliente cliente = new Cliente();
            cliente.cli_id = IdCliente;
            cliente.cli_nombre = txtNombre.Text.Trim();
            cliente.cli_habilitado = chkHabilitado.Checked;

            // 2. Insert o Update segun el modo.
            ClienteController clienteController = new ClienteController();
            Respuesta respuesta;

            if (IdCliente > 0)
                respuesta = clienteController.UpdateCliente(cliente);
            else
                respuesta = clienteController.InsertCliente(cliente);

            // 3. Avisar. En el alta guardamos el id devuelto para que
            //    el siguiente Guardar sea un Update y no otro Insert.
            if (!respuesta.error)
            {
                IdCliente = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    #endregion
}
