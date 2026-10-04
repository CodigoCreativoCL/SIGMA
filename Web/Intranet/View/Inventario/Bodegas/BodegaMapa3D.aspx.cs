using System;

/// <summary>
/// Mapa 3D de bodegas.
///
/// El code-behind solo exige el permiso de la pantalla: no hay controles de
/// servidor ni postback. Los datos los pide el visor a WsBodegaMapa, que vuelve
/// a validar sesion y permiso en cada llamada.
/// </summary>
public partial class View_Inventario_Bodegas_BodegaMapa3D : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        SitioBase.Token.ExigirPagina();
    }
}
