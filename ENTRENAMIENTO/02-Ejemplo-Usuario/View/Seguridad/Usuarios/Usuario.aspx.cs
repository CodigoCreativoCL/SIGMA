using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE FORMULARIO.
///
/// Hace exactamente dos cosas:
///   1. Valida el permiso de entrada (igual que la pagina de listado).
///   2. DESCIFRA el querystring que armo el grid y pasa los valores al UserControl.
///
/// Por que se cifra el querystring?
///   Si la URL fuera Usuario.aspx?IdUsuario=5, cualquiera podria escribir
///   IdUsuario=1 y abrir la ficha de otro usuario. Con Tools.Crypto el
///   parametro es opaco y no se puede manipular a mano.
/// </summary>
public partial class View_Seguridad_Usuarios_Usuario : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina

        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_5.Ver;
        SitioBase.Token.SecurityManagerVer(ver);

        #endregion

        if (!IsPostBack)
        {
            // El grid navega a: Usuario.aspx?query=<cadena cifrada>
            if (!string.IsNullOrEmpty(Request.QueryString["query"]))
            {
                // 1. Descifrar -> "IdUsuario=5&ReadOnly=False"
                string parametros = Tools.Crypto.Decrypt(Request.QueryString["query"]);

                // 2. Parsear el string en pares clave=valor.
                foreach (string par in parametros.Split('&'))
                {
                    string[] kv = par.Split('=');
                    if (kv.Length != 2) continue;

                    switch (kv[0])
                    {
                        case "IdUsuario":
                            int id;
                            if (int.TryParse(kv[1], out id))
                                wucUsuario.IdUsuario = id;
                            break;

                        case "ReadOnly":
                            bool ro;
                            if (bool.TryParse(kv[1], out ro))
                                wucUsuario.ReadOnly = ro;
                            break;
                    }
                }
            }

            // Sin query -> alta de un usuario nuevo (IdUsuario queda en 0).

            // Refuerzo de seguridad: si el perfil no tiene Crear/Editar,
            // el formulario se abre siempre en modo consulta.
            MenuFuncion crearEditar = new MenuFuncion();
            crearEditar.mfu_funcion = (int)SitioBase.Paginas.menu_5.Crear_Editar;

            if (!SitioBase.Token.SecurityManager(crearEditar))
                wucUsuario.ReadOnly = true;
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
    }
}
