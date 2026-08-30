using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE LISTADO.
///
/// PATRON (ver PATRON_MVC.md seccion 7):
///  - La pagina es el UNICO lugar donde se valida el permiso de entrada.
///    Si el perfil no tiene la funcion "Ver" del menu, SecurityManagerVer
///    redirige y la pagina ni siquiera se renderiza.
///  - Ademas traduce los permisos del menu a propiedades del UserControl:
///    el UserControl no sabe de menus, solo recibe numeros de funcion.
///  - Regla del equipo: la seguridad SIEMPRE se declara en el .aspx.cs,
///    nunca dentro del UserControl.
/// </summary>
public partial class View_Seguridad_Usuarios_Usuarios : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina

        // menu_5 es el identificador del menu "Usuarios" en SitioBase.Paginas.
        // Cada menu declara sus funciones como enum: Ver, Crear_Editar, Ver_Todo, etc.
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_5.Ver;

        // Si el perfil no tiene el permiso, este metodo corta la ejecucion.
        SitioBase.Token.SecurityManagerVer(ver);

        #endregion

        // Se le pasan al UserControl los ids de funcion que necesita para
        // decidir que puede mostrar (el control resuelve el permiso con
        // Token.SecurityManager dentro de CargarGrid).
        wucUsuarios.Ver_Todo = (int)SitioBase.Paginas.menu_5.Ver_Todo;
        wucUsuarios.VerTodoPaises = (int)SitioBase.Paginas.menu_5.Ver_Todo_Paises;
        wucUsuarios.Crear_Editar = (int)SitioBase.Paginas.menu_5.Crear_Editar;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Se deja declarado aunque este vacio: es parte del esqueleto estandar.
    }
}
