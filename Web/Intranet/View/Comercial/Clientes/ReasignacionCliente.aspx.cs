using SitioBase.Model;
using SitioBase;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comercial_Clientes_ReasignacionCliente : System.Web.UI.Page
{
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

    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
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

                    case "URLVolverCliente":
                        URLVolverCliente = array[1].ToString();
                        break;

                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        wucIdentidad.ReadOnly = true;
        wucIdentidad.IdCliente = IdCliente;

        wucUsuario.IdCliente = IdCliente;

        /* Los perfiles que se ofrecen aqui son de tipo CLIENTE.

           Decia Sistema, que son Root, Soporte y Gerente Comercial: las
           cuentas del equipo de SIGMA. Reasignar un cliente es mover a SU
           gente, no a la nuestra, asi que la lista salia con las personas
           equivocadas y sin ninguna de las correctas.

           Tampoco se filtra ya por el parametro ASIGNAR_PERFIL, que traia
           una lista fija de ids heredada de FacilityGes -y ademas se leia
           con otro nombre, "Asignar_Perfiles", asi que devolvia vacio-. El
           tipo alcanza: si manana el cliente crea un perfil propio, aparece
           solo, sin que nadie tenga que editar un parametro. */
        wucUsuario.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Cliente;
        wucUsuario.ReadOnly = ReadOnly;
        wucUsuario.Asociar = true;

        URLVolverCliente = "~/View/Comercial/Clientes/ReasignacionesClientes.aspx";
    }

}