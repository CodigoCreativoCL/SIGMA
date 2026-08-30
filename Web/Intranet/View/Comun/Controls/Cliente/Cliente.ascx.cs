using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Cliente : System.Web.UI.UserControl
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

    public string URLVolverCliente
    {
        get { return Convert.ToString(ViewState["URLVolverCliente"]); }
        set { ViewState.Add("URLVolverCliente", value); }
    }

    public int TipoPerfil
    {
        get { return Convert.ToInt32(ViewState["TipoPerfil"]); }
        set { ViewState.Add("TipoPerfil", value); }
    }


    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "IdCliente":
                        IdCliente = Int32.Parse(array[1].ToString());
                        break;

                    case "ReadOnly":
                        ReadOnly = bool.Parse(array[1].ToString());
                        break;

                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
       
    }

    protected void CargarDatos()
    {
        if (IdCliente == 0)
        {
            ragTab.Tabs[1].Visible = false;
            ragTab.Tabs[2].Visible = false;
           
            IdCliente = wucIdentidad.IdCliente;
        }

        wucIdentidad.IdCliente = IdCliente;
        wucIdentidad.ReadOnly = ReadOnly;

        wucUsuarios.IdCliente = IdCliente;
        wucUsuarios.ReadOnly = ReadOnly;

        /* Aqui habia un filtro por la lista de ids "3,4,5,6,7", que se
           aplicaba cuando quien miraba era Root, Soporte o Gerente
           Comercial. Esos ids eran perfiles de FacilityGes; en SIGMA el 3 es
           Gerente Comercial, el 4 Bodeguero, el 5 Jefe de Mantenimiento, y
           el 6 y el 7 no existen. O sea que a las cuentas de plataforma
           -justamente las que administran al cliente- la pestana les
           ocultaba a casi toda la gente de la empresa y les mostraba una
           mezcla sin sentido.

           No se reemplaza por otra lista: el filtro por TIPO de perfil, que
           ya viene puesto desde la pagina, hace lo correcto y no envejece
           cuando un cliente crea un perfil propio. */

        wucInstalaciones.IdCliente = IdCliente;
        wucInstalaciones.ReadOnly = ReadOnly;

    }


}