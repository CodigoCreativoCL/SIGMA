using System;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class Comun_Controls_FiltroAvanzado : System.Web.UI.UserControl
{
    [PersistenceMode(PersistenceMode.InnerProperty)]
    public ITemplate FiltroPersonalizado { get; set; }

    public string Filtro()
    {
        string filtro = "";
        if (txtFiltro.Text != "") filtro = txtFiltro.Text;
        return filtro;
    }

    protected void Page_Init()
    {
        if (FiltroPersonalizado != null)
        {
            Control container = new Control();
            FiltroPersonalizado.InstantiateIn(container);
            phPersonalizado.Controls.Add(container);
        }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* EL MANEJADOR SE REGISTRA UNA SOLA VEZ.

           Antes se hacia `add_endRequest(...)` en cada PreRender, y PreRender
           corre en CADA refresco parcial: despues de diez postbacks habia diez
           manejadores encima, los diez llamando a lo mismo. Es una fuga que
           ademas multiplica el trabajo en cada refresco.

           La bandera en `window` sobrevive a los refrescos parciales —la
           pagina no se recarga— asi que basta con preguntar si ya se hizo. */
        string idPanel = divPersonalizado.ClientID;
        string idFlag = hdfExpanded.ClientID;

        string script =
            "if (!window.__sgFiltro_" + this.ClientID + ") {" +
            "  window.__sgFiltro_" + this.ClientID + " = true;" +
            "  Sys.WebForms.PageRequestManager.getInstance().add_endRequest(" +
            "    function(s,a){ expandeFiltro(true,'" + idPanel + "','" + idFlag + "'); });" +
            "}" +
            "expandeFiltro(true,'" + idPanel + "','" + idFlag + "');";

        ScriptManager.RegisterStartupScript(this, this.GetType(),
            "FiltroAvanzado_" + this.ClientID, script, true);
    }

}