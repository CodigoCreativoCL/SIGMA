using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE FORMULARIO DE PRODUCTO.
///
/// Hace exactamente dos cosas:
///   1. Valida el permiso de entrada (igual que la pagina de listado).
///   2. DESCIFRA el querystring que armo el grid y pasa los valores al UserControl.
///
/// Por que se cifra el querystring?
///   Si la URL fuera Producto.aspx?IdProducto=5, cualquiera podria escribir
///   otro numero y abrir la ficha ajena. Con Tools.Crypto el parametro es opaco.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Inventario_Productos_Producto : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina

        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_12.Ver;
        SitioBase.Token.SecurityManagerVer(ver);

        #endregion

        if (!IsPostBack)
        {
            // El grid navega a: Producto.aspx?query=<cadena cifrada>
            if (!string.IsNullOrEmpty(Request.QueryString["query"]))
            {
                // 1. Descifrar -> "IdProducto=5&ReadOnly=False"
                string parametros = Tools.Crypto.Decrypt(Request.QueryString["query"]);

                // 2. Parsear el string en pares clave=valor.
                foreach (string par in parametros.Split('&'))
                {
                    string[] kv = par.Split('=');
                    if (kv.Length != 2) continue;

                    switch (kv[0])
                    {
                        case "IdProducto":
                            int id;
                            if (int.TryParse(kv[1], out id))
                                wucProducto.IdProducto = id;
                            break;

                        case "ReadOnly":
                            bool ro;
                            if (bool.TryParse(kv[1], out ro))
                                wucProducto.ReadOnly = ro;
                            break;
                    }
                }
            }

            // Sin query -> alta de un registro nuevo (IdProducto queda en 0).

            // Refuerzo de seguridad: si el perfil no tiene Crear/Editar,
            // el formulario se abre siempre en modo consulta.
            MenuFuncion crearEditar = new MenuFuncion();
            crearEditar.mfu_funcion = (int)SitioBase.Paginas.menu_12.Crear_Editar;

            if (!SitioBase.Token.SecurityManager(crearEditar))
                wucProducto.ReadOnly = true;
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
    }
}
