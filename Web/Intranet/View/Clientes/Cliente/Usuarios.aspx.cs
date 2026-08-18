using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Clientes_Cliente_Usuarios : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.menu_41.Ver;

        SitioBase.Token.SecurityManagerVer(ver);
        MenuFuncion funCrearEditar = new MenuFuncion();

        funCrearEditar.mfu_id = (int)SitioBase.Paginas.menu_41.Crear_Editar;
        //wucUsuarios.ReadOnly = !SitioBase.Token.SecurityManager(funCrearEditar);

        wucUsuarios.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Cliente;
        string perfiles = SitioBase.SitioBase.Parametros("Asignar_Perfiles");

        wucUsuarios.Perfiles = string.Join(",",
            perfiles
                .Split(',')
                .Where(p => p == "6" || p == "7")
        );
        wucUsuarios.VerComboCliente = true;

        #endregion

        #region SeguridadCliente
        wucCliente.VerTodo = (int)SitioBase.Paginas.menu_41.Ver_Todo;
        wucCliente.VerTodoPaises = (int)SitioBase.Paginas.menu_41.Ver_Todo_Paises;
        #endregion
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (wucUsuarios.IdCliente != wucCliente.GetCliente())
        {
            wucUsuarios.IdCliente = wucCliente.GetCliente();
        }
    }
}