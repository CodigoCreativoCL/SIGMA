using SitioBase.Model;
using SitioBase;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comercial_Cliente : System.Web.UI.Page
{
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    protected void Page_Load(object sender, EventArgs e)
    {

        wucCliente.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Sistema;
    }
    protected void Page_PreRender(object sender, EventArgs e)
    {
        
    }
    
}