using SitioBase.Controller;
using SitioBase.Model;
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

                    /* HU-010. Zona horaria, idioma y moneda son catalogos del
                       sistema: se leen por el registro de catalogos, que
                       devuelve siempre la misma forma sin importar que tabla
                       haya detras. Asi no hace falta un Model y un Controller
                       por cada uno.

                       Se pasa cliente 0 a proposito: son catalogos del
                       sistema, no admiten valores propios de nadie. */
                    case "cboZonaHoraria":
                        CargarCatalogo(ctrl, "ZONA_HORARIA", "Seleccione...");
                        break;

                    case "cboIdioma":
                        CargarCatalogo(ctrl, "IDIOMA", "Seleccione...");
                        break;

                    case "cboMoneda":
                        CargarCatalogo(ctrl, "MONEDA", "Seleccione...");
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

        // La etiqueta del identificador depende del país, así que se
        // resuelve también al abrir y no solo al cambiar el combo.
        EtiquetaIdentificador();

        udPanel.Update();
    }

    /// <summary>
    /// Pone la etiqueta del identificador según el país elegido.
    ///
    /// SIGMA opera en cinco países y el documento tributario no se llama
    /// igual en ninguno: RUT en Chile, RUC en Perú y Ecuador, CUIT en
    /// Argentina. El nombre sale de la tabla Paises, no del código, así que
    /// sumar un país es un INSERT.
    /// </summary>
    protected void EtiquetaIdentificador()
    {
        string etiqueta = "Identificación";

        if (!string.IsNullOrEmpty(cboPais.SelectedValue))
        {
            System.Data.SqlClient.SqlCommand cmd = new System.Data.SqlClient.SqlCommand();

            try
            {
                cmd.CommandText = "SEL_PAIS_IDENTIFICADOR";
                cmd.Parameters.AddWithValue("@PAIS", int.Parse(cboPais.SelectedValue));

                using (System.Data.SqlClient.SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    if (dr.Read()) etiqueta = dr["ETIQUETA"].ToString();
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception ex)
            {
                // Si no se puede resolver, queda la etiqueta neutra: es
                // preferible a dejar el formulario sin poder usarse.
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
        }

        lblIdentificador.Text = etiqueta + "(*):";
    }

    protected void cboPais_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        EtiquetaIdentificador();
        udPanel.Update();
    }

    /// <summary>
    /// Llena un combo desde el registro de catálogos.
    /// El catálogo se identifica por su código, no por su id: el id puede
    /// cambiar entre ambientes, el código no.
    /// </summary>
    private void CargarCatalogo(RadComboBox2 ctrl, string codigoCatalogo, string textoVacio)
    {
        CatalogoController controller = new CatalogoController();

        ctrl.Items.Add(new RadComboBoxItem(textoVacio, ""));
        ctrl.AppendDataBoundItems = true;
        ctrl.DataSource = controller.GetValoresPorCodigo(codigoCatalogo, 0);
        ctrl.DataValueField = "valor_id";
        ctrl.DataTextField = "valor_nombre";
        ctrl.DataBind();
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

            txtNombreFantasia.Text = cliente.cli_nombre_fantasia;

            if (cliente.cli_zona_horaria != null)
                cboZonaHoraria.SelectedValue = cliente.cli_zona_horaria.ToString();
            if (cliente.cli_idioma != null)
                cboIdioma.SelectedValue = cliente.cli_idioma.ToString();
            if (cliente.cli_moneda != null)
                cboMoneda.SelectedValue = cliente.cli_moneda.ToString();

            /* El logo, por URL desde Blob (bloque 100). Se conserva la rama
               de la base64 por si quedara algun logo viejo en la columna. */
            if (cliente.cli_archivo_logo != null && cliente.cli_archivo_logo.Value > 0)
                imgLogo.ImageUrl = SitioBase.UrlArchivo.Ver(cliente.cli_archivo_logo.Value);
            else if (cliente.cli_logo != null)
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
            txtNombreFantasia.Text = string.Empty;
            cboZonaHoraria.SelectedValue = string.Empty;
            cboIdioma.SelectedValue = string.Empty;
            cboMoneda.SelectedValue = string.Empty;
            imgLogo.ImageUrl = string.Empty;
        }
    }

    protected void Bloqueo()
    {
        txtNombre.ReadOnly = ReadOnly;
        cboPais.ReadOnly = ReadOnly;
        txtIdentificacion.ReadOnly = ReadOnly;
        txtRazonSocial.ReadOnly = ReadOnly;

        txtNombreFantasia.ReadOnly = ReadOnly;
        cboZonaHoraria.ReadOnly = ReadOnly;
        cboIdioma.ReadOnly = ReadOnly;
        cboMoneda.ReadOnly = ReadOnly;

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
                /* Sin país elegido, int.Parse("") lanza una excepción que
                   el catch muestra como un volcado de pila entero. Se pide el
                   dato, que es lo que hace falta. */
                if (string.IsNullOrEmpty(cboPais.SelectedValue))
                    throw new Exception("Indique el país del cliente.");

                cliente.cli_pais = int.Parse(cboPais.SelectedValue);

                // HU-010
                cliente.cli_nombre_fantasia = txtNombreFantasia.Text.Trim();

                if (!string.IsNullOrEmpty(cboZonaHoraria.SelectedValue))
                    cliente.cli_zona_horaria = int.Parse(cboZonaHoraria.SelectedValue);
                if (!string.IsNullOrEmpty(cboIdioma.SelectedValue))
                    cliente.cli_idioma = int.Parse(cboIdioma.SelectedValue);
                if (!string.IsNullOrEmpty(cboMoneda.SelectedValue))
                    cliente.cli_moneda = int.Parse(cboMoneda.SelectedValue);

                // El logotipo solo se toca cuando el formulario adjunto uno.
                if (fldLogo.HasFile)
                {
                    /* Va a Blob, no a la base. El id queda apuntado por
                       UPD_CLIENTE_LOGO; cli_logo ya no se escribe. */
                    new ClienteController().GuardarLogo(cliente.cli_id, fldLogo.FileName,
                                                        fldLogo.FileBytes,
                                                        fldLogo.PostedFile.ContentType);
                    cliente.cambia_logo = true;
                }

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

                /* EL ERROR DEL GUARDADO TAMBIÉN SE MUESTRA.

                   Antes solo estaba la rama del éxito. El `else` de más abajo
                   es de la validación de la IMAGEN, no del resultado de
                   guardar: si el alta fallaba, no entraba a ninguna rama y la
                   pantalla se quedaba muda. El botón parecía no hacer nada. */
                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            /* ex.Message y no ex.ToString(): lo segundo vuelca la traza
               completa encima de la pantalla, que no le dice nada a quien la
               está usando y de paso publica la estructura interna. */
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

}