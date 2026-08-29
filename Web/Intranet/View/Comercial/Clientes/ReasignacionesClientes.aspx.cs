using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comercial_Clientes_ReasignacionesClientes : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina


        wucClientes.ReadOnly = true;
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {

        

    }
   
}