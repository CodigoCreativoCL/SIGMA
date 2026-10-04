using System;

/// <summary>
/// Centro de carga de datos.
///
/// El code-behind solo exige el permiso de la pantalla (GESTIONAR CARGAS
/// MASIVAS, via Menus): no hay controles de servidor ni postback. WsCargaDatos
/// vuelve a validar sesion y permiso en cada llamada.
/// </summary>
public partial class View_Comun_CargaDatos_CentroCargaDatos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        SitioBase.Token.ExigirPagina();
    }
}
