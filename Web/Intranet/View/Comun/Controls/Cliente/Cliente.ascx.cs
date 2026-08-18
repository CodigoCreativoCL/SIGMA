using Facilityges.Controller;
using Facilityges.Model;
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
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

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
            ragTab.Tabs[3].Visible = false;
           
            IdCliente = wucIdentidad.IdCliente;
        }

        wucIdentidad.IdCliente = IdCliente;
        wucIdentidad.ReadOnly = ReadOnly;

        wucUsuarios.IdCliente = IdCliente;
        wucUsuarios.ReadOnly = ReadOnly;

        int[] perfilesSesion = Array.ConvertAll(
            SitioBase.Session.UsuarioPerfil().Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries),
            p => { int v; return int.TryParse(p.Trim(), out v) ? v : 0; });

        if (Array.Exists(perfilesSesion, p =>
               p == (int)SitioBase.SitioBase.Perfil.root
            || p == (int)SitioBase.SitioBase.Perfil.Soporte
            || p == (int)SitioBase.SitioBase.Perfil.Gerente_Comercial))
            wucUsuarios.Perfiles = "3,4,5,6,7";
        else if (Array.Exists(perfilesSesion, p => p == (int)SitioBase.SitioBase.Perfil.Coordinador))
            wucUsuarios.Perfiles = "4,5,6,7";

        wucChecklist.IdCliente = IdCliente;
        wucChecklist.ReadOnly = ReadOnly;


        wucInstalaciones.IdCliente = IdCliente;
        wucInstalaciones.ReadOnly = ReadOnly;

    }


}