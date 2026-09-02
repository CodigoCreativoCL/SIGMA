using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;
using SitioBase.Model;
using SitioBase.Controller;

public partial class View_Comun_Controls_MiCuenta_MiCuenta : System.Web.UI.UserControl
{
    Usuario actual = new Usuario();

    // Vista agrupada para rptClientes: un cliente asociado al usuario y sus instalaciones.
    public class ClienteConInstalaciones
    {
        public string cli_id { get; set; }
        public string cli_nombre { get; set; }
        public List<KeyValuePair<string, string>> Instalaciones { get; set; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        UsuarioController usuarioController = new UsuarioController();
        Usuario usuario = new Usuario();
        usuario.usu_id = int.Parse(SitioBase.Session.UsuarioId());
        usuario.devuelve_foto = true;
        actual = usuarioController.GetUsuario(usuario);

        lblUsuario.Text = actual.usu_login;
        txtCorreo.Text = actual.usu_correo;
        lblNombre.Text = actual.usu_nombres;
        lblApellidoPaterno.Text = actual.usu_apellido_paterno;
        lblApellidoMaterno.Text = actual.usu_apellido_materno;

        lblId.Text = actual.usu_id.ToString();
        lblIdentificador.Text = !string.IsNullOrEmpty(actual.usu_identificador) ? actual.usu_identificador : "Sin asignar";
        lblNombreCompleto.Text = actual.nombre_completo;
        txtTelefono.Text = actual.usu_telefono;

        List<KeyValuePair<string, string>> paises = ParsePares(actual.id_paises, actual.paises);
        lblPais.Text = paises.Count > 0 ? string.Join(", ", paises.Select(p => p.Value)) : "Sin asignar";

        List<KeyValuePair<string, string>> perfiles = ParsePares(actual.id_perfiles, actual.perfiles);
        lblPerfil.Text = perfiles.Count > 0 ? string.Join(", ", perfiles.Select(p => p.Value)) : "Sin asignar";

        List<UsuarioClienteInstalacion> clienteInstalaciones = usuarioController.GetClienteInstalaciones(actual.usu_id);
        List<ClienteConInstalaciones> clientes = clienteInstalaciones
            .GroupBy(ci => new { ci.cli_id, ci.cli_nombre })
            .Select(g => new ClienteConInstalaciones
            {
                cli_id = g.Key.cli_id.ToString(),
                cli_nombre = g.Key.cli_nombre,
                Instalaciones = g.Where(ci => ci.cin_id.HasValue)
                                  .Select(ci => new KeyValuePair<string, string>(ci.cin_id.Value.ToString(), ci.cin_nombre))
                                  .ToList()
            })
            .ToList();

        pnlClientes.Visible = clientes.Count > 0;
        rptClientes.DataSource = clientes;
        rptClientes.DataBind();

        /* Antes este campo mostraba la contraseña del usuario, forzando el
           atributo "value" para saltarse la protección de ASP.NET.

           Ya no se puede ni tiene sentido: desde el bloque 26 de base de
           datos las contraseñas se guardan como hash SHA2-256 con sal, así
           que lo único que se podría pintar aquí son 64 caracteres
           hexadecimales. Y aunque se pudiera, dejar la contraseña legible en
           el HTML de la página nunca fue una buena idea: cualquiera que
           mirara el código fuente la veía.

           El campo se deja en pantalla como marcador de "aquí hay una
           contraseña", relleno con puntos. Para cambiarla está el switch de
           al lado. */
        txtPasswordVer.Attributes["value"] = "••••••••";

        /* La foto, por URL desde Blob (bloque 100). Se conserva la rama de
           la base64 por si quedara alguna foto vieja en la columna. */
        int idFoto = SitioBase.Session.UsuarioArchivoFoto();

        if (idFoto > 0)
            imgFoto.ImageUrl = SitioBase.UrlArchivo.Ver(idFoto);
        else if (actual.usu_foto != null)
            imgFoto.ImageUrl = "data:image/jpeg;base64," + Convert.ToBase64String(actual.usu_foto, 0, actual.usu_foto.Length);
    }

    protected void rptClientes_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType == ListItemType.Item || e.Item.ItemType == ListItemType.AlternatingItem)
        {
            ClienteConInstalaciones cliente = (ClienteConInstalaciones)e.Item.DataItem;

            Repeater rptInstalacionesCliente = (Repeater)e.Item.FindControl("rptInstalacionesCliente");
            rptInstalacionesCliente.DataSource = cliente.Instalaciones;
            rptInstalacionesCliente.DataBind();

            Panel pnlSinInstalaciones = (Panel)e.Item.FindControl("pnlSinInstalaciones");
            pnlSinInstalaciones.Visible = cliente.Instalaciones.Count == 0;
        }
    }

    // Separa listas comma-list (PERFILES/ID_PERFILES, PAISES/ID_PAISES) en pares (id, nombre).
    private List<KeyValuePair<string, string>> ParsePares(string ids, string nombres)
    {
        List<KeyValuePair<string, string>> lista = new List<KeyValuePair<string, string>>();

        if (string.IsNullOrEmpty(ids) || string.IsNullOrEmpty(nombres))
            return lista;

        string[] arrIds = ids.Trim(',').Split(',');
        string[] arrNombres = nombres.Trim(',').Split(',');

        for (int i = 0; i < arrIds.Length && i < arrNombres.Length; i++)
        {
            if (!string.IsNullOrEmpty(arrIds[i]))
                lista.Add(new KeyValuePair<string, string>(arrIds[i], arrNombres[i]));
        }

        return lista;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            UsuarioController usuarioController = new UsuarioController();

            Usuario datosActuales = new Usuario();
            datosActuales.usu_id = int.Parse(SitioBase.Session.UsuarioId());
            datosActuales.devuelve_foto = true;
            actual = usuarioController.GetUsuario(datosActuales);

            if (fldFoto.HasFile)
            {
                string extension = Path.GetExtension(fldFoto.FileName).ToUpper();
                if (!".JPG,.PNG".Contains(extension))
                {
                    Tools.tools.ClientAlert("El formato de la imagen debe ser JPG O PNG", "alerta");
                    return;
                }
            }

            /* CAMBIO DE CONTRASEÑA (HU-005 escenario 1).

               Ya no se compara en C# contra actual.usu_password: eso era una
               comparación de texto plano y con el hash SHA2-256 del bloque
               26 fallaría siempre, dejando a todo el mundo sin poder cambiar
               su clave.

               Ahora lo resuelve UPD_USUARIO_PASSWORD, que es quien puede:
               tiene la sal para comparar la actual, aplica las reglas de
               largo y composición, comprueba que no repita ninguna de las
               tres anteriores y escribe el historial. */
            if (chkCambiarPassword.Checked)
            {
                if (string.IsNullOrEmpty(txtPasswordActual.Text))
                {
                    Tools.tools.ClientAlert("Debe ingresar su contraseña actual.", "alerta");
                    return;
                }

                if (string.IsNullOrEmpty(txtPasswordNueva.Text) || string.IsNullOrEmpty(txtPasswordConfirmar.Text))
                {
                    Tools.tools.ClientAlert("Debe ingresar y confirmar la nueva contraseña.", "alerta");
                    return;
                }

                if (txtPasswordNueva.Text != txtPasswordConfirmar.Text)
                {
                    Tools.tools.ClientAlert("Las contraseñas no coinciden.", "alerta");
                    return;
                }

                CuentaController cuentaController = new CuentaController();
                Respuesta cambio = cuentaController.CambiarMiClave(txtPasswordActual.Text, txtPasswordNueva.Text);

                if (cambio.error)
                {
                    // El detalle viene del SP: contraseña actual incorrecta,
                    // muy corta, sin letra o número, o repetida. Son los
                    // mensajes que la persona necesita leer para corregir.
                    Tools.tools.ClientAlert(cambio.detalle, "alerta");
                    return;
                }
            }

            Usuario usuario = new Usuario();
            usuario.usu_id = int.Parse(SitioBase.Session.UsuarioId());
            usuario.usu_login = actual.usu_login;

            /* La contraseña NO viaja en este UPDATE.

               Antes se reenviaba actual.usu_password, que hoy es el hash
               almacenado. UPD_USUARIO lo habría vuelto a hashear y la
               contraseña de la persona habría quedado inservible con solo
               guardar su teléfono. Se manda null, que el SP interpreta como
               "no toques la contraseña". */
            usuario.usu_password = null;

            usuario.usu_nombres = actual.usu_nombres;
            usuario.usu_apellido_paterno = actual.usu_apellido_paterno;
            usuario.usu_apellido_materno = actual.usu_apellido_materno;
            usuario.usu_telefono = txtTelefono.Text;
            usuario.usu_correo = txtCorreo.Text;
            usuario.usu_identificador = actual.usu_identificador;
            usuario.usu_habilitado = actual.usu_habilitado;

            /* La foto va a Blob y NO al UPD_USUARIO: GuardarFoto la sube, la
               apunta con UPD_USUARIO_FOTO y refresca la sesion para que el
               avatar de la cabecera cambie sin volver a entrar. */
            if (fldFoto.HasFile)
                usuarioController.GuardarFoto(int.Parse(SitioBase.Session.UsuarioId()),
                                              fldFoto.FileName, fldFoto.FileBytes,
                                              fldFoto.PostedFile.ContentType);

            Respuesta respuesta = usuarioController.UpdateUsuario(usuario);

            if (!respuesta.error)
            {
                usuarioController.GetUsuarioSession(usuario);

                txtPasswordActual.Text = string.Empty;
                txtPasswordNueva.Text = string.Empty;
                txtPasswordConfirmar.Text = string.Empty;
                chkCambiarPassword.Checked = false;

                Tools.tools.ClientAlert("Datos actualizados con éxito.", "ok");
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
