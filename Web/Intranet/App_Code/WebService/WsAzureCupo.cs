using SitioBase;
using System;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// El cupo gratuito que le queda a la base Azure SQL este mes, para el chip de la barra
/// superior. Lo lee SitioBase.AzureCupo (Azure Monitor, cacheado 10 minutos); sin
/// azure.config responde activo = false y el chip no se dibuja.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsAzureCupo : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cupo()
    {
        if (!Token.TokenSeguridad())
            return WsSoporte.Json(new { activo = false, sesion = true });
        try { return WsSoporte.Json(SitioBase.AzureCupo.Leer()); }
        catch (Exception ex) { return WsSoporte.Json(new { activo = true, ok = false, mensaje = ex.Message }); }
    }
}
