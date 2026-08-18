using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Clientes_CargaMasivaUsuarios : System.Web.UI.Page
{

    private ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
    private ClienteUsuario clienteUsuario = new ClienteUsuario();
    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public int TipoPerfil
    {
        get { return Convert.ToInt32(ViewState["TipoPerfil"]); }
        set { ViewState.Add("TipoPerfil", value); }
    }
    public string Perfiles
    {
        get { return Convert.ToString(ViewState["Perfiles"]); }
        set { ViewState.Add("Perfiles", value); }
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
                    case "Perfiles":
                        Perfiles = array[1].ToString();
                        break;
                }
            }
        }

        string rawPerfiles = Perfiles;

        lblPerfil.Text = rawPerfiles
            .Replace("3", " ID: 3 - Gerente Comercial")
            .Replace("4", " ID: 4 - Coordinador")
            .Replace("5", " ID: 5 - Supervisor ")
            .Replace("6", " ID: 6 - Administrador")
            .Replace("7", " ID: 7 - Administrativo");

        var perfilNombres = new Dictionary<string, string>
        {
            { "3", "G. Comercial" }, { "4", "Coordinador" }, { "5", "Supervisor" },
            { "6", "Administrador" }, { "7", "Administrativo" }
        };
        var sbPerfiles = new StringBuilder();
        foreach (string idRaw in rawPerfiles.Split(new char[] { ',', ' ' }, StringSplitOptions.RemoveEmptyEntries))
        {
            string id = idRaw.Trim();
            string nombre = perfilNombres.ContainsKey(id) ? perfilNombres[id] : "Perfil " + id;
            sbPerfiles.AppendFormat(
                "<div class=\"cmu-perfil-item\"><span class=\"cmu-perfil-nombre\">{0}</span><span class=\"cmu-perfil-id\">{1}</span></div>",
                nombre, id);
        }
        litPerfiles.Text = sbPerfiles.ToString();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(lnkDescargaPlanilla);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnCargaMasiva);
    }


    protected void btnCargaMasiva_Click(object sender, EventArgs e)
    {

        if (fldDocumento.HasFile)
        {
            DateTime ProcesoInicio = DateTime.Now;
            Respuesta respuesta = new Respuesta();
            System.Threading.Thread.Sleep(1000);

            ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
            ClienteUsuario clienteUsuario = new ClienteUsuario();
            clienteUsuario.ucl_id_cliente = IdCliente;

            clienteUsuario.fileUpload = fldDocumento;
            clienteUsuario.abi_archivo = fldDocumento.FileBytes;

            respuesta = clienteUsuarioController.InsertUsuariosMasivo(clienteUsuario);

            DateTime PorcesoTermino = DateTime.Now;

            TimeSpan TiempoProcesoTotal = PorcesoTermino - ProcesoInicio;

            lblTiempoTotalProceso.Text = TiempoProcesoTotal.Minutes.ToString() + " Minutos Con " + TiempoProcesoTotal.Seconds.ToString() + " Segundos";
            lblDocumentosCargados.Text = respuesta.cantidaCargada.ToString();
            lblDocumentosNoCargados.Text = respuesta.cantidaError.ToString();

            pnlResultado.Visible = true;

            if (respuesta.error)
            {
                Grid3.DataSource = respuesta.table;
                Grid3.DataBind();
                Grid3.Visible = true;
            }
            else
            {
                Grid3.DataSource = null;
                Grid3.Visible = false;
            }
        }
        else
        {
            Tools.tools.ClientAlert("No ha adjuntado Documento", "alerta");
        }

        Tools.tools.ClientExecute("closeWindowProcesamiento();");
    }


    protected void lnkDescargaPlanilla_Click(object sender, EventArgs e)
    {
        clienteUsuario.ucl_id_cliente = IdCliente;
        clienteUsuario.perfiles = Perfiles;
        clienteUsuarioController.PlantillaCargaUsuarios(clienteUsuario);
    }
}
