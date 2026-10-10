using System;

/// <summary>
/// SIGMA AI · Centro de monitoreo. La vista se dibuja en el navegador (Js/sigma-ai-centro.js) con lo que
/// devuelve WsAiCentro; esta pagina solo entrega el marco. El permiso es el de VER PREDICCIONES, que
/// ya exige el menu «SIGMA AI».
/// </summary>
public partial class View_SigmaAI_Centro : System.Web.UI.Page
{
    /// <summary>423 · El chat de SIGMA AI se vende por plan comercial (Funcionalidad SIGMA AI CHAT).</summary>
    protected bool ChatIncluido;

    protected void Page_Load(object sender, EventArgs e)
    {
        ChatIncluido = SitioBase.Controller.PlanFuncion.Incluye(SitioBase.Controller.PlanFuncion.AI_CHAT);
    }
}
