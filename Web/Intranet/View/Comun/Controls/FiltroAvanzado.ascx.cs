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
        ScriptManager.RegisterStartupScript(this, this.GetType(), "FiltroAvanzado_" + this.ClientID,
            "Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function(s,a){expandeFiltro(true,'" + divPersonalizado.ClientID + "','" + hdfExpanded.ClientID + "');});",
            true);
    }

}