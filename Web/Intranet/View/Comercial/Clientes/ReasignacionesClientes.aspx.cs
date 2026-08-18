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
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_31.Ver;

        SitioBase.Token.SecurityManagerVer(ver);


        wucClientes.VerTodoPaises = (int)SitioBase.Paginas.menu_31.Ver_Todo_Paises;
        wucClientes.Ver_Todo = (int)SitioBase.Paginas.menu_31.Ver_Todo;
        wucClientes.Crear_Editar = (int)SitioBase.Paginas.menu_31.Crear_Editar;
        wucClientes.ReadOnly = true;
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {

        

    }
   
}