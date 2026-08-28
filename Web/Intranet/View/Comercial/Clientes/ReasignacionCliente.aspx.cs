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
        wucUsuario.TipoPerfil = (int)SitioBase.SitioBase.TipoPefil.Sistema;
        string Perfiles = SitioBase.SitioBase.Parametros("Asignar_Perfiles");
        wucUsuario.Perfiles = string.Join(",", Perfiles);
        wucUsuario.ReadOnly = ReadOnly;
        wucUsuario.Asociar = true;

        URLVolverCliente = "~/View/Comercial/Clientes/ReasignacionesClientes.aspx";
    }

}