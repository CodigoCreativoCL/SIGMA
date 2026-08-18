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
                this.imgUsuario.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.png");
                this.imgUsuarioLateral.ImageUrl = ResolveUrl("~/Imagen/usuario-de-perfil.png");
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

