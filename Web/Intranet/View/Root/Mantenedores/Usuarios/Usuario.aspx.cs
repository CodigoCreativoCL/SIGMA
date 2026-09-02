using System;
using System.IO;
using SitioBase.Model;
using SitioBase.Controller;
using Telerik.Web.UI;
using SitioBase;

public partial class View_Sistema_Usuarios_Usuario : System.Web.UI.Page
{
    UsuarioController usuariosController = new UsuarioController();

    public int Id
    {
        get { return Convert.ToInt32(ViewState["id"]); }
        set { ViewState.Add("id", value); }
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
                    
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            CargarDatos();
        }

        Validaciones();
    }

    protected void Validaciones()
    {
        if (Id > 0)
        {
            ragTab.Tabs[1].Visible = true;
            ragTab.Tabs[2].Visible = true;
            //pnlNombre.Visible = true;
        }
        else 
        {
            ragTab.Tabs[1].Visible = false;
            ragTab.Tabs[2].Visible = false;
            //pnlNombre.Visible = false;
            lblTituloUsuario.Text = "Nuevo Usuario";
        }
    }

    protected void CargarDatos()
    {
        if (Id > 0)
        {
            Usuario usuario = new Usuario();
            usuario.usu_id = Id;
            usuario.devuelve_foto = true;

            usuario = usuariosController.GetUsuario(usuario);

            lblTituloUsuario.Text = usuario.usu_login;

            lblID.Text = Id.ToString();
            textLogin.Text = usuario.usu_login;
            txtIdentificador.Text = usuario.usu_identificador;
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
            lblPass.Text = "Contraseña";
            litPasswordAyuda.Text = "<span class=\"sigma-modal-ayuda\">Déjala vacía para no cambiarla. Lo que escribas aquí reemplaza la actual.</span>";
            CustomValidator4.Enabled = false;
            TextNombre.Text = usuario.usu_nombres;
            txtPaterno.Text = usuario.usu_apellido_paterno;
            TextMaterno.Text = usuario.usu_apellido_materno;
            Textfono.Text = usuario.usu_telefono;
            TextCorreo.Text = usuario.usu_correo;
            /* La foto, por URL desde Blob (bloque 100). Se conserva la rama
               de la base64 por si quedara alguna foto vieja en la columna. */
            if (usuario.usu_archivo_foto != null && usuario.usu_archivo_foto.Value > 0)
            {
                imgLogo.ImageUrl = SitioBase.UrlArchivo.Ver(usuario.usu_archivo_foto.Value);
            }
            else if (usuario.usu_foto != null)
            {
                imgLogo.ImageUrl = "data:image/jpeg;base64," + Convert.ToBase64String(usuario.usu_foto, 0, usuario.usu_foto.Length);
            }
            if (usuario.usu_habilitado != null)
            {
                if (bool.Parse(usuario.usu_habilitado.ToString()))
                {
                    rdbSi.Checked = true;
                    rdbNo.Checked = false;
                }
                else
                {
                    rdbSi.Checked = false;
                    rdbNo.Checked = true;
                }
            }
                        
            if (usuario.usu_foto != null)
            {
                string base64String = Convert.ToBase64String(usuario.usu_foto, 0, usuario.usu_foto.Length);
                imgLogo.ImageUrl = "data:image/jpeg;base64," + base64String;
            }

            wucUsuarioPerfil.IdUsuario = Id;
            wucUsuarioPaises.IdUsuario = Id;
        }
    }

    protected void btnGuardar_OnClick(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            bool formatoCorrecto = true;

            if (fudLogo.HasFile)
            {
                if (Path.GetExtension(fudLogo.FileName).ToUpper() == ".JPG" | Path.GetExtension(fudLogo.FileName).ToUpper() == ".PNG")
                {
                    if (fudLogo.FileBytes.Length > 2097152) //2MB (1 MB = 1048576 bytes)
                    {
                        Tools.tools.ClientAlert("El tamaño del archivo no debe superar los 2MB", "alerta");
                        formatoCorrecto = false;
                        return;
                    }
                }
                else
                {
                    formatoCorrecto = false;
                    Tools.tools.ClientAlert("El formato de la imagen debe ser JPG O PNG","alerta");
                    return;
                }
            }

            if (formatoCorrecto)
            {
                Usuario usuario = new Usuario();

                usuario.usu_id = Id;
                usuario.usu_login = textLogin.Text;
                // Vacio = no cambiarla.
                usuario.usu_password = textPassword.Text.Trim();
                usuario.usu_nombres = TextNombre.Text;
                usuario.usu_apellido_paterno = txtPaterno.Text;
                usuario.usu_apellido_materno = TextMaterno.Text;
                usuario.usu_telefono = Textfono.Text;
                usuario.usu_correo = TextCorreo.Text;
                usuario.usu_identificador = txtIdentificador.Text;

                if (rdbSi.Checked)
                    usuario.usu_habilitado = true;
                else
                    usuario.usu_habilitado = false;

                /* La foto se guarda DESPUES de crear el usuario: en un alta
                   todavia no hay id al que apuntarla. Ver mas abajo. */
                    
                if (Id > 0)
                    respuesta = usuariosController.UpdateUsuario(usuario);
                else
                {
                    respuesta = usuariosController.InsertUsuario(usuario);
                    Id = respuesta.codigo;

                    wucUsuarioPerfil.IdUsuario = Id;
                    wucUsuarioPaises.IdUsuario = Id;
                }

                /* LA FOTO, DESPUES DE GUARDAR AL USUARIO.

                   En un alta el id no existe hasta que InsertUsuario vuelve,
                   y UPD_USUARIO_FOTO necesita a quien apuntarle. Por eso va
                   aca y no arriba con el resto de los campos.

                   Si la subida falla NO se dice que todo salio bien: el
                   usuario quedo guardado —eso es cierto— pero se avisa que
                   la foto no. Un "guardado con exito" con la foto perdida es
                   lo que hace que alguien no vuelva a intentarlo. */
                if (!respuesta.error && fudLogo.HasFile && Id > 0)
                {
                    try
                    {
                        usuariosController.GuardarFoto(Id, fudLogo.FileName,
                                                       fudLogo.FileBytes,
                                                       fudLogo.PostedFile.ContentType);
                    }
                    catch (Exception exFoto)
                    {
                        Tools.tools.ClientAlert("El usuario se guardó, pero la foto no: " +
                                                exFoto.Message, "alerta");
                        return;
                    }
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");

            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}