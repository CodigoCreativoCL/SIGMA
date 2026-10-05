using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// Los contactos del cliente: agregar, corregir y quitar.
///
/// EL CLIENTE VIENE DE AFUERA
///   Lo fija la pantalla que usa el control —`IdCliente`—, igual que
///   `Identidad.ascx`. En un alta todavía no hay id, y entonces el control lo
///   dice en vez de ofrecer un formulario que no tendría dónde guardar.
///
/// LAS REGLAS VIVEN EN LA BASE
///   Uno solo principal, al menos un correo o un teléfono, correo con forma
///   válida, sin nombres repetidos. Acá se muestran los mensajes que devuelve
///   el procedimiento: duplicar las reglas en C# es garantizar que algún día
///   digan cosas distintas.
/// </summary>
public partial class View_Comun_Controls_Cliente_Contactos : System.Web.UI.UserControl
{
    #region Propiedades

    public int IdCliente
    {
        get { return ViewState["ctIdCliente"] != null ? (int)ViewState["ctIdCliente"] : 0; }
        set { ViewState["ctIdCliente"] = value; }
    }

    public bool ReadOnly
    {
        get { return ViewState["ctReadOnly"] != null && (bool)ViewState["ctReadOnly"]; }
        set { ViewState["ctReadOnly"] = value; }
    }

    /// <summary>Qué contacto se está editando. 0 = uno nuevo.</summary>
    protected int EditandoId
    {
        get { return ViewState["ctEdit"] != null ? (int)ViewState["ctEdit"] : 0; }
        set { ViewState["ctEdit"] = value; }
    }

    #endregion

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = IdCliente > 0;

        pnlSinCliente.Visible = !hayCliente;
        /* La edición se habilita con ReadOnly, igual que el resto de la ficha
           (Identidad, Usuarios…). El permiso real ("Crear y editar") ya se
           verificó en el listado que abrió esta ficha editable: ahí la función
           está registrada; en la página de detalle no, y PuedeFuncion devolvía
           siempre false, dejando el botón oculto a quien sí puede. */
        btnNuevo.Visible = hayCliente && !ReadOnly;

        if (!hayCliente)
        {
            rptContactos.Visible = false;
            pnlVacio.Visible = false;
            pnlForm.Visible = false;
        }
        else
            Cargar();

        udPanel.Update();
    }

    #region Lista

    /// <summary>Una fila de la lista. Pública: Eval() no ve tipos internos.</summary>
    public class Fila
    {
        public int Id { get; set; }
        public string Numero { get; set; }
        public string Nombre { get; set; }
        public string Cargo { get; set; }
        public string Vias { get; set; }
        public string Meta { get; set; }
        public string Iniciales { get; set; }
        public string Color { get; set; }
        public string Clase { get; set; }
        public string ChipPrincipal { get; set; }
    }

    /// <summary>Los mismos doce colores del resto del sistema.</summary>
    private static readonly string[] PALETA = {
        "#6C5CFF", "#0EA5E9", "#10B981", "#F59E0B",
        "#EF4444", "#8B5CF6", "#EC4899", "#14B8A6",
        "#F97316", "#3B82F6", "#84CC16", "#A855F7"
    };

    private static string ColorDe(int id)
    {
        if (id < 0) return PALETA[0];
        return PALETA[id % PALETA.Length];
    }

    protected void Cargar()
    {
        List<ClienteContacto> lista = new ClienteContactoController().GetContactos();

        List<Fila> filas = new List<Fila>();

        foreach (ClienteContacto c in lista)
        {
            Fila f = new Fila();

            f.Id = c.ccn_id;
            f.Numero = c.NumeroTexto;

            /* La función, y la empresa/rubro si los hay, en una línea. */
            string cargo = c.ccn_cargo ?? "";
            string emp = string.IsNullOrEmpty(c.ccn_empresa) ? "" : c.ccn_empresa
                       + (string.IsNullOrEmpty(c.ccn_rubro) ? "" : " · " + c.ccn_rubro);
            string cargoLinea = cargo;
            if (!string.IsNullOrEmpty(emp))
                cargoLinea = (cargo == "" ? "" : cargo + " — ") + emp;

            f.Nombre = Server.HtmlEncode(c.ccn_nombre ?? "");
            f.Cargo = Server.HtmlEncode(cargoLinea);
            f.Iniciales = Server.HtmlEncode(c.Iniciales);

            /* "Ingresado 04-10-2026", con la dirección si está. */
            string meta = "";
            if (c.ccn_fecha_creacion.HasValue)
                meta = "Ingresado " + c.ccn_fecha_creacion.Value.ToString("dd-MM-yyyy");
            if (!string.IsNullOrEmpty(c.ccn_direccion))
                meta += (meta == "" ? "" : "  ·  ") + Server.HtmlEncode(c.ccn_direccion);
            f.Meta = meta;
            f.Color = ColorDe(c.ccn_id);
            f.Clase = c.ccn_principal ? "is-principal" : "";

            f.ChipPrincipal = c.ccn_principal
                ? "<span class=\"sg-ct-chip\">Principal</span>"
                : "";

            /* El correo y el teléfono como enlaces: copiarlos a mano para
               pegarlos en el cliente de correo es un paso que no hace falta. */
            System.Text.StringBuilder v = new System.Text.StringBuilder();

            if (!string.IsNullOrEmpty(c.ccn_email))
                v.Append("<a href=\"mailto:" + Server.HtmlEncode(c.ccn_email) + "\">" +
                         "<i class=\"mdi mdi-email-outline\"></i>" +
                         Server.HtmlEncode(c.ccn_email) + "</a>");

            if (!string.IsNullOrEmpty(c.ccn_telefono))
                v.Append("<a href=\"tel:" + Server.HtmlEncode(c.ccn_telefono.Replace(" ", "")) + "\">" +
                         "<i class=\"mdi mdi-phone-outline\"></i>" +
                         Server.HtmlEncode(c.ccn_telefono) + "</a>");

            f.Vias = v.ToString();

            filas.Add(f);
        }

        rptContactos.Visible = filas.Count > 0;
        pnlVacio.Visible = filas.Count == 0 && !pnlForm.Visible;

        rptContactos.DataSource = filas;
        rptContactos.DataBind();
    }

    protected void rptContactos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        bool puede = !ReadOnly;

        LinkButton editar = e.Item.FindControl("btnEditar") as LinkButton;
        LinkButton borrar = e.Item.FindControl("btnEliminar") as LinkButton;

        /* Esconder el botón no es seguridad —el servidor vuelve a validar—,
           pero mostrarlo a quien no puede es prometerle algo que se le va a
           negar. */
        if (editar != null) editar.Visible = puede;

        if (borrar != null)
        {
            borrar.Visible = puede;

            Fila f = e.Item.DataItem as Fila;

            borrar.OnClientClick = "return confirm('¿Eliminar el contacto " +
                                   (f != null ? f.Nombre.Replace("'", "\\'") : "") +
                                   "?');";
        }
    }

    protected void rptContactos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        int id;
        if (!int.TryParse(e.CommandArgument.ToString(), out id)) return;

        if (ReadOnly) return;

        if (e.CommandName == "Editar")
        {
            AbrirFormulario(id);
            return;
        }

        if (e.CommandName == "Eliminar")
        {
            Respuesta r = new ClienteContactoController().DeleteContacto(id);
            Tools.tools.ClientAlert(r.detalle, r.error ? "alerta" : "ok");
        }
    }

    #endregion

    #region Formulario

    protected void btnNuevo_Click(object sender, EventArgs e) { AbrirFormulario(0); }

    protected void btnCancelar_Click(object sender, EventArgs e)
    {
        pnlForm.Visible = false;
        EditandoId = 0;
    }

    private void AbrirFormulario(int id)
    {
        EditandoId = id;
        pnlForm.Visible = true;

        litFormTitulo.Text = id > 0 ? "Editar contacto" : "Nuevo contacto";

        txtNombre.Text = "";
        txtCargo.Text = "";
        txtEmpresa.Text = "";
        txtRubro.Text = "";
        txtEmail.Text = "";
        txtTelefono.Text = "";
        txtDireccion.Text = "";
        txtNotas.Text = "";
        chkPrincipal.Checked = false;

        if (id <= 0) return;

        List<ClienteContacto> lista = new ClienteContactoController().GetContactos(id);

        if (lista == null || lista.Count == 0)
        {
            /* Se pidió editar algo que ya no está —lo borró otra pestaña, o
               no es de este cliente—. Se dice, no se abre un formulario en
               blanco que al guardar crearía un contacto nuevo. */
            pnlForm.Visible = false;
            EditandoId = 0;
            Tools.tools.ClientAlert("El contacto ya no existe.", "alerta");
            return;
        }

        ClienteContacto c = lista[0];

        txtNombre.Text = c.ccn_nombre;
        txtCargo.Text = c.ccn_cargo;
        txtEmpresa.Text = c.ccn_empresa;
        txtRubro.Text = c.ccn_rubro;
        txtEmail.Text = c.ccn_email;
        txtTelefono.Text = c.ccn_telefono;
        txtDireccion.Text = c.ccn_direccion;
        txtNotas.Text = c.ccn_notas;
        chkPrincipal.Checked = c.ccn_principal;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            /* Esconder el botón en PreRender no es seguridad: quien manda el
               postback a mano se lo salta. ReadOnly viene del query cifrado que
               arma el listado, y solo es False para quien allí pudo abrir la
               ficha en modo edición (donde sí se validó "Crear y editar"). */
            if (ReadOnly)
                throw new Exception("No tiene permiso para editar los contactos del cliente.");

            if (IdCliente <= 0)
                throw new Exception("Guarde primero el cliente.");

            ClienteContacto c = new ClienteContacto();

            c.ccn_id = EditandoId;
            c.ccn_cliente = IdCliente;
            c.ccn_nombre = txtNombre.Text.Trim();
            c.ccn_cargo = txtCargo.Text.Trim();
            c.ccn_empresa = txtEmpresa.Text.Trim();
            c.ccn_rubro = txtRubro.Text.Trim();
            c.ccn_email = txtEmail.Text.Trim();
            c.ccn_telefono = txtTelefono.Text.Trim();
            c.ccn_direccion = txtDireccion.Text.Trim();
            c.ccn_notas = txtNotas.Text.Trim();
            c.ccn_principal = chkPrincipal.Checked;
            c.ccn_habilitado = true;

            ClienteContactoController controller = new ClienteContactoController();

            Respuesta r = EditandoId > 0 ? controller.UpdateContacto(c)
                                         : controller.InsertContacto(c);

            if (r.error)
            {
                /* El mensaje viene del procedimiento: "indique al menos un
                   correo o un teléfono", "el correo no tiene un formato
                   válido". Se muestra tal cual en vez de traducirlo, porque
                   la regla es una sola y vive allá. */
                Tools.tools.ClientAlert(r.detalle, "alerta");
                return;
            }

            pnlForm.Visible = false;
            EditandoId = 0;

            Tools.tools.ClientAlert(r.detalle, "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    #endregion
}
