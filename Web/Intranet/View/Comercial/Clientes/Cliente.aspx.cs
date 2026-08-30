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

        /* Perfiles de tipo CLIENTE.

           Decia Sistema, que son Root, Soporte y Gerente Comercial: las
           cuentas de nuestro equipo. Esta es la ficha comercial de una
           empresa y su pestana Usuarios lista a SU gente, asi que el filtro
           por perfil ofrecia justo a quienes no corresponde y a ninguno de
           los que si. */
        wucCliente.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Cliente;
    }
    protected void Page_PreRender(object sender, EventArgs e)
    {
        
    }
    
}