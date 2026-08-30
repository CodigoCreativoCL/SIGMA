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
/// CODE-BEHIND DEL TAB / SUB-FORMULARIO.
///
/// Aqui vive el CRUD real de la pantalla. Tiene 4 metodos y siempre los mismos:
///
///   LoadControls()    -> puebla los combos (una sola vez, en !IsPostBack).
///   CargarDatos()     -> si IdUsuario > 0 trae el registro y llena los controles.
///   Bloqueo()         -> aplica ReadOnly a cada control.
///   btnGuardar_Click() -> arma el Model desde los controles y llama Insert/Update.
///
/// PATRON (ver PATRON_MVC.md seccion 6):
///  - Nunca se llama a la BD desde aqui: siempre a traves del Controller.
///  - El "alta vs edicion" se decide con un solo if: IdUsuario > 0.
///  - Todo va envuelto en try/catch que termina en Tools.tools.ClientAlert.
/// </summary>
public partial class View_Seguridad_Controls_Usuario_Identidad : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    public int IdUsuario
    {
        get { return ViewState["IdUsuario"] == null ? 0 : (int)ViewState["IdUsuario"]; }
        set { ViewState["IdUsuario"] = value; }
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

    #region CARGA DE COMBOS

    /// <summary>
    /// Un unico metodo atiende a TODOS los combos del control.
    /// Se engancha desde el markup con OnLoad="LoadControls" y se
    /// desambigua con switch (ctrl.ID).
    ///
    /// El !IsPostBack es clave: sin el, el combo se recargaria en cada
    /// postback y perderia la seleccion del usuario.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                switch (ctrl.ID)
                {
                    case "cboPerfil":

                        PerfilController perfilController = new PerfilController();
                        Perfil filtroPerfil = new Perfil { filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = perfilController.GetPerfiles(filtroPerfil);
                        ctrl.DataValueField = "per_id";     // debe existir en el Model
                        ctrl.DataTextField = "per_nombre";  // debe existir en el Model
                        ctrl.DataBind();
                        break;

                    case "cboPais":

                        PaisesController paisesController = new PaisesController();
                        Paises filtroPais = new Paises { filtro_habilitado = "1" };

                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = paisesController.GetPaises(filtroPais);
                        ctrl.DataValueField = "pai_id";
                        ctrl.DataTextField = "pai_nombres";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    #endregion

    #region CARGA Y BLOQUEO

    /// <summary>
    /// Modo edicion  -> trae el registro y llena los controles.
    /// Modo alta     -> limpia todo.
    /// </summary>
    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (IdUsuario > 0)
        {
            UsuarioController usuarioController = new UsuarioController();
            Usuario usuario = usuarioController.GetUsuario(new Usuario { usu_id = IdUsuario });

            if (usuario == null) return;

            txtRut.Text = usuario.usu_rut;
            txtNombres.Text = usuario.usu_nombres;
            txtApellidos.Text = usuario.usu_apellidos;
            txtEmail.Text = usuario.usu_email;
            txtTelefono.Text = usuario.usu_telefono;
            chkHabilitado.Checked = usuario.usu_habilitado;

            // Para seleccionar un item del combo se usa el Value, no el Text.
            cboPerfil.SelectedValue = usuario.usu_perfil.ToString();
            cboPais.SelectedValue = usuario.usu_pais.ToString();

            // La password NUNCA se rellena: viaja vacia y solo se
            // actualiza si el usuario escribe una nueva.
            txtPassword.Text = string.Empty;
        }
        else
        {
            txtRut.Text = string.Empty;
            txtNombres.Text = string.Empty;
            txtApellidos.Text = string.Empty;
            txtEmail.Text = string.Empty;
            txtTelefono.Text = string.Empty;
            txtPassword.Text = string.Empty;
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
        txtRut.ReadOnly = ReadOnly;
        txtNombres.ReadOnly = ReadOnly;
        txtApellidos.ReadOnly = ReadOnly;
        txtEmail.ReadOnly = ReadOnly;
        txtTelefono.ReadOnly = ReadOnly;
        cboPerfil.ReadOnly = ReadOnly;
        cboPais.ReadOnly = ReadOnly;

        chkHabilitado.Enabled = !ReadOnly;

        // En Password se usa Enabled, no ReadOnly (ver comentario del .ascx).
        txtPassword.Enabled = !ReadOnly;

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
            Usuario usuario = new Usuario();
            usuario.usu_id = IdUsuario;
            usuario.usu_rut = txtRut.Text.Trim();
            usuario.usu_nombres = txtNombres.Text.Trim();
            usuario.usu_apellidos = txtApellidos.Text.Trim();
            usuario.usu_email = txtEmail.Text.Trim();
            usuario.usu_telefono = txtTelefono.Text.Trim();
            usuario.usu_perfil = int.Parse(cboPerfil.SelectedValue);
            usuario.usu_pais = int.Parse(cboPais.SelectedValue);
            usuario.usu_habilitado = chkHabilitado.Checked;
            usuario.usu_password = txtPassword.Text.Trim();

            // 2. Validaciones de negocio que el CustomValidator no cubre.
            if (IdUsuario == 0 && string.IsNullOrEmpty(usuario.usu_password))
            {
                Tools.tools.ClientAlert("Debe ingresar una contrasena para el usuario nuevo.", "alerta");
                return;
            }

            // 3. Insert o Update segun el modo.
            UsuarioController usuarioController = new UsuarioController();
            Respuesta respuesta;

            if (IdUsuario > 0)
                respuesta = usuarioController.UpdateUsuario(usuario);
            else
                respuesta = usuarioController.InsertUsuario(usuario);

            // 4. Avisar. En el alta guardamos el id devuelto para que
            //    el siguiente Guardar sea un Update y no otro Insert.
            if (!respuesta.error)
            {
                IdUsuario = respuesta.codigo;
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
