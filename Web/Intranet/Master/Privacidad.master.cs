using System;

public partial class Master_Privacidad : System.Web.UI.MasterPage
{
    protected void Page_Load(object sender, EventArgs e)
    {
        SitioBase.Token.ExigirPagina();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
    }
}
 