using SitioBase.Controller;
using SitioBase.Model;
using System;
using Telerik.Web.UI;

public partial class View_Comun_Clientes_NuevoUsuario : System.Web.UI.Page
{
    ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
    ClienteUsuario clienteUsuario = new ClienteUsuario();

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public int Id
    {
        get { return Convert.ToInt32(ViewState["id"]); }
        set { ViewState.Add("id", value); }
    }

    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public bool Asociar
    {
        get { return Convert.ToBoolean(ViewState["Asociar"]); }
        set { ViewState.Add("Asociar", value); }
    }

    public int TipoPerfil
    {
        get { return Convert.ToInt32(ViewState["TipoPerfil"]); }
        set { ViewState.Add("TipoPerfil", value); }
    }

    public string Perfiles
    {
        get { return Convert.ToString(ViewState["Perfiles"]); }
        set { ViewState.Add("Perfiles", value); }
    }


    public bool UsuarioCliente
    {
        get { return Convert.ToBoolean(ViewState["UsuarioCliente"]); }
        set { ViewState.Add("UsuarioCliente", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            //Recupero el query string
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
                        break;
                    case "IdCliente":
                        IdCliente = Int32.Parse(array[1].ToString());
                        break;
                    case "ReadOnly":
                        ReadOnly = bool.Parse(array[1].ToString());
                        break;
                    case "TipoPerfil":
                        TipoPerfil = Int32.Parse(array[1].ToString());
                        break;
                    case "Asociar":
                        Asociar = bool.Parse(array[1].ToString());
                        break;
                    case "UsuarioCliente":
                        UsuarioCliente = bool.Parse(array[1].ToString());
                        break;
                    case "Perfiles":
                        Perfiles = array[1].ToString();
                        break;
                }

            }
        }

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
                    case "cboPerfil":
                        Perfil perfil = new Perfil();
                        PerfilController perfilController = new PerfilController();
                        perfil.filtro_habilitado = "1";

                        /* Este formulario crea usuarios DEL CLIENTE, asi que
                           solo ofrece perfiles de tipo Cliente. El filtro
                           estaba comentado y la lista salia con la whitelist
                           de la propiedad Perfiles, que arrastraba perfiles
                           de sistema. */
                        perfil.tipo = "2";
                        ctrl.EmptyMessage = "Seleccione";
                        ctrl.DataSource = perfilController.ListoPerfiles(perfil);
                        ctrl.DataValueField = "per_id";
                        ctrl.DataTextField = "per_nombre";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            //if (TipoPerfil == 0)
            //    TipoPerfil = 2;
            CargarDatos();
            Bloqueo();
        }
    }

    protected void CargarDatos()
    {
        if (Id > 0 || txtIdentificador.Text != "")
        {
            pnlIdentidad.Visible = true;
            divID.Visible = true;
            if (Id > 0)
            {
                clienteUsuario.usu_id = Id;
                clienteUsuario.ucl_id_cliente = IdCliente;
            }

            if (txtIdentificador.Text != "")
            {
                clienteUsuario.usu_identificador = txtIdentificador.Text;
                clienteUsuario = clienteUsuarioController.GetClienteUsuario(clienteUsuario);
                Id = clienteUsuario.usu_id;
            }

            clienteUsuario.tipo_perfil = TipoPerfil;
            clienteUsuario.devuelve_foto = true;
            clienteUsuario = clienteUsuarioController.GetClienteUsuario(clienteUsuario);

            lblID.Text = Id.ToString();
            textLogin.Text = clienteUsuario.usu_login;
            txtIdentificador.Text = clienteUsuario.usu_identificador;
            /* La contrasena NO se arrastra a la ficha.

               Antes se cargaba usu_password en el campo y volvia tal cual al
               guardar. Con las claves hasheadas eso no puede funcionar: lo
               guardado ya no es la contrasena sino su hash, y devolverlo
               significaria volver a hashear el hash. De hecho asi se rompio
               la cuenta de una persona: le pusieron "1", se guardo en claro,
               y despues no entraba porque el login compara contra el hash.

               Vacio significa "no la cambies"; con algo escrito, "cambiala a
               esto". El validador de obligatorio se apaga al editar, porque
               al editar ya no lo es. */
            textPassword.Text = "";
            litPassword.Text = "Contraseña";
            litPasswordAyuda.Text = "<span class=\"sigma-modal-ayuda\">Déjala vacía para no cambiarla. Lo que escribas aquí reemplaza la actual.</span>";
            CustomValidator4.Enabled = false;
            TextNombre.Text = clienteUsuario.usu_nombres;
            txtPaterno.Text = clienteUsuario.usu_apellido_paterno;
            TextMaterno.Text = clienteUsuario.usu_apellido_materno;
            Textfono.Text = clienteUsuario.usu_telefono;
            TextCorreo.Text = clienteUsuario.usu_correo;

            if (!string.IsNullOrEmpty(clienteUsuario.id_perfiles))
                cboPerfil.SetValues(clienteUsuario.id_perfiles);


        }
        else
        {
            lblID.Text = "";
            textLogin.Text = "";
            textPassword.Text = "";
            litPassword.Text = "Contraseña(*)";
            litPasswordAyuda.Text = "";
            CustomValidator4.Enabled = true;
            TextNombre.Text = "";
            txtPaterno.Text = "";
            TextMaterno.Text = "";
            Textfono.Text = "";
            TextCorreo.Text = "";
            cboPerfil.SelectedValue = "";
        }
    }

    protected void Bloqueo()
    {
        textLogin.ReadOnly = ReadOnly;
        textPassword.ReadOnly = ReadOnly;
        txtIdentificador.ReadOnly = ReadOnly;
        cboPerfil.ReadOnly = ReadOnly;
        TextNombre.ReadOnly = ReadOnly;
        txtPaterno.ReadOnly = ReadOnly;
        TextMaterno.ReadOnly = ReadOnly;

        Textfono.ReadOnly = ReadOnly;
        TextCorreo.ReadOnly = ReadOnly;
        btnGuardar.Visible = !ReadOnly;

        if (Asociar)
        {
            txtIdentificador.ReadOnly = Asociar;
            textLogin.ReadOnly = Asociar;
            textPassword.ReadOnly = Asociar;
            cboPerfil.ReadOnly = Asociar;
            TextNombre.ReadOnly = Asociar;
            txtPaterno.ReadOnly = Asociar;
            TextMaterno.ReadOnly = Asociar;
            Textfono.ReadOnly = Asociar;
            TextCorreo.ReadOnly = Asociar;
            btnGuardar.Visible = !Asociar;
            pnlIdentidad.Visible = true;
        }

    }

    protected void txtIdentificador_TextChanged(object sender, EventArgs e)
    {
        if (txtIdentificador.Text != "")
        {
            CargarDatos();
        }
        else
        {
            Id = 0;
            pnlIdentidad.Visible = false;
        }
    }

    protected void btnGuardar_OnClick(object sender, EventArgs e)
    {
        try
        {
            if (!string.IsNullOrEmpty(cboPerfil.dbValues()))
            {
                Respuesta respuesta = new Respuesta();

                ClienteUsuario clienteUsuario = new ClienteUsuario();
                ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();

                clienteUsuario.usu_id = Id;
                clienteUsuario.usu_login = textLogin.Text;
                // Vacio = no cambiarla. El SP lo interpreta asi.
                clienteUsuario.usu_password = textPassword.Text.Trim();

                clienteUsuario.usu_identificador = txtIdentificador.Text;
                clienteUsuario.usu_login = textLogin.Text;
                clienteUsuario.usu_nombres = TextNombre.Text;
                clienteUsuario.perfiles = cboPerfil.dbValues();
                clienteUsuario.usu_apellido_paterno = txtPaterno.Text;
                clienteUsuario.usu_apellido_materno = TextMaterno.Text;
                clienteUsuario.usu_telefono = Textfono.Text;
                clienteUsuario.usu_correo = TextCorreo.Text;
                clienteUsuario.ucl_id_cliente = IdCliente;

                if (Id > 0)
                {
                    clienteUsuario.cliente_nuevo = false;
                    respuesta = clienteUsuarioController.UpdateClienteUsuario(clienteUsuario);
                }
                else
                {
                    clienteUsuario.cliente_nuevo = true;
                    respuesta = clienteUsuarioController.InsertClienteUsuario(clienteUsuario);
                    Id = respuesta.codigo;
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
            else
                Tools.tools.ClientAlert("Seleccionar perfil para usuario.", "alerta");

        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}