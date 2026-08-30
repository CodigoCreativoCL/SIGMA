using SitioBase;
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
        wucUsuarios.ReadOnly = !Token.Puede("CREAR EDITAR CLIENTE USUARIOS");

        /* Basta con el tipo. Antes ademas se filtraba por una lista de
           ids que venia del parametro "Asignar_Perfiles" -que en la base se
           llama ASIGNAR_PERFIL, asi que volvia vacia- y encima se quedaba
           solo con los ids 6 y 7, que eran perfiles de FacilityGes y hoy no
           existen: entre las dos cosas, el filtro no ofrecia ninguno.

           Con el tipo, el perfil que un cliente cree manana aparece solo,
           sin que nadie tenga que editar un parametro. */
        wucUsuarios.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Cliente;
        wucUsuarios.VerComboCliente = true;

        #endregion

        #region SeguridadCliente
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