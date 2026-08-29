using SitioBase.Controller;
using System;

public partial class Master_Default : System.Web.UI.MasterPage
{
    private MenuMaterialApoyoController menuCapsulaController = new MenuMaterialApoyoController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!SitioBase.Token.TokenSeguridad())
        {
            Response.Redirect("~/Login.aspx");
        }

        // El permiso de la pagina sale de su propia URL contra Menus.mnu_link.
        // Por eso ninguna pagina bajo este master declara su permiso.
        SitioBase.Token.ExigirPagina();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (SitioBase.Token.TokenSeguridad())
        {
            if (SitioBase.Session.UsuarioFoto() != null)
            {
                string base64String = SitioBase.Session.UsuarioFoto();

                this.imgUsuario.ImageUrl = "data:image/jpeg;base64," + base64String;

                this.imgUsuarioLateral.ImageUrl = "data:image/jpeg;base64," + base64String;

            }
            else
            {
                // El .png que se referenciaba aqui no existe en Imagen/: la
                // imagen salia rota para todo usuario sin foto. Se reemplaza
                // por un marcador SVG con los grises de la paleta.
                this.imgUsuario.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.svg");
                this.imgUsuarioLateral.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.svg");
            }

        }
    }

    protected void lnkCerrarSession_Click(object sender, EventArgs e)
    {
        Session.Abandon();
        Session.RemoveAll();

        Response.Redirect("~/Login.aspx");
    }

}

