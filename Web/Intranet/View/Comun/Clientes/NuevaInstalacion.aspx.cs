using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comun_Clientes_NuevoInstalacion : System.Web.UI.Page
{
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public int IdClienteInstalacion
    {
        get { return Convert.ToInt32(ViewState["IdClienteInstalacion"]); }
        set { ViewState.Add("IdClienteInstalacion", value); }
    }

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
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

                    case "IdClienteInstalacion":
                        IdClienteInstalacion = Int32.Parse(array[1].ToString());
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
        cargar();
        bloqueo();
    }
    
    protected void cargar()
    {
        if (IdClienteInstalacion == 0)
        {
            IdClienteInstalacion = wucIdentidad.IdClienteInstalacion;
        }
        
        wucIdentidad.IdCliente = IdCliente;
        wucIdentidad.IdClienteInstalacion = IdClienteInstalacion;
        wucIdentidad.ReadOnly = ReadOnly;


        wucResponsable.IdCliente = IdCliente;
        wucResponsable.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Sistema;

        string Perfiles = SitioBase.SitioBase.Parametros("Asignar_Perfiles");
        wucResponsable.Perfiles = string.Join(",", Perfiles);
        wucResponsable.IdClienteInstalacion = IdClienteInstalacion;
        wucResponsable.ReadOnly = ReadOnly;
        wucResponsable.Asociar = true;


        wucConfiguracionApp.IdCliente = IdCliente;
        wucConfiguracionApp.IdClienteInstalacion = IdClienteInstalacion;
        wucConfiguracionApp.ReadOnly = ReadOnly;

    }
    
    protected void bloqueo()
    {
        if (IdClienteInstalacion == 0)
        {
            ragTab.Tabs[1].Visible = false;
            ragTab.Tabs[2].Visible = false;
            ragTab.Tabs[3].Visible = false;

        }
        else
        {
            ragTab.Tabs[1].Visible = true;
            ragTab.Tabs[2].Visible = true;
            ragTab.Tabs[3].Visible = true;

        }
    }

}