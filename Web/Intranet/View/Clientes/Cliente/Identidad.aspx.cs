using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Clientes_Cliente_Identidad : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        wucIdentidad.ReadOnly = true;
        wucIdentidad.RequiereSeleccion = true;
        #endregion

        #region SeguridadCliente
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (wucIdentidad.IdCliente != wucCliente.GetCliente())
        {
            wucIdentidad.IdCliente = wucCliente.GetCliente();
        }
    }
}