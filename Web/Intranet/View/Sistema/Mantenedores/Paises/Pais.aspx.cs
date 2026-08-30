using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using Telerik.Web.UI;

public partial class View_Sistema_Mantenedores_Pais : System.Web.UI.Page
{
    public int Id
    {
        get { return Convert.ToInt32(ViewState["Id"]); }
        set { ViewState.Add("Id", value); }
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
            Paises paises = new Paises();
            PaisesController paisesController = new PaisesController();

            paises.pai_id = Id;
            paises = paisesController.GetPais(paises);

            lblId.Text = Id.ToString();
            txtNombre.Text = paises.pai_nombres;
            if(paises.pai_suma_resta == "0")
            {
                rbtmenos.Checked = true;
                rbtmas.Checked = false;
            }
            if (paises.pai_suma_resta == "1")
            {
                rbtmenos.Checked = false;
                rbtmas.Checked = true;
            }
            txtHora.Text = paises.pai_hora.ToString();
            if (paises.pai_habilitado == false)
            {
                rdbNo.Checked = true;
                rdbSi.Checked = false;
            }
            if (paises.pai_habilitado == true)
            {
                rdbNo.Checked = false;
                rdbSi.Checked = true;
            }
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            Paises paises = new Paises();
            PaisesController paisesController = new PaisesController();

            paises.pai_id = Id;
            paises = paisesController.GetPais(paises);
            paises.pai_nombres = txtNombre.Text;
            if (rbtmas.Checked == true)
            {
                paises.pai_suma_resta = "1";
            }
            else
            {
                paises.pai_suma_resta = "0";
            }
            paises.pai_hora = int.Parse(txtHora.Text);            
            if (rdbSi.Checked == true)
            {
                paises.pai_habilitado = true;
            }
            else
            {
                paises.pai_habilitado = false;
            }


            if (Id > 0)
            {
                respuesta = paisesController.UpdatePais(paises);
            }
            else
            {
                respuesta = paisesController.InsertPais(paises);
                Id = respuesta.codigo;
            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}