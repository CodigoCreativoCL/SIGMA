using Facilityges.Controller;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comun_Clientes_InformeUsuarioMarcacionFoto : System.Web.UI.Page
{
    private InformeUsuarioMarcacionController informeUsuarioMarcacionController = new InformeUsuarioMarcacionController();
    public int Id
    {
        get { return Convert.ToInt32(ViewState["Id"]); }
        set { ViewState.Add("Id", value); }
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
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
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
        if (Id > 0)
        {
            InformeUsuarioMarcacion informeUsuarioMarcacion = new InformeUsuarioMarcacion();
            informeUsuarioMarcacion.mar_id = Id;
            informeUsuarioMarcacion = informeUsuarioMarcacionController.GetInformeUsuarioMarcacion(informeUsuarioMarcacion);

            imgNovedad.ImageUrl = "data:image/jpeg;base64," + Convert.ToBase64String(informeUsuarioMarcacion.abi_archivo_binario, 0, informeUsuarioMarcacion.abi_archivo_binario.Length);
        }
    }
}