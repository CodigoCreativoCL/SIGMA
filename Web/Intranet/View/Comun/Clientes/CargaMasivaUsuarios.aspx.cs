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
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

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

        /* Los nombres de los perfiles se leen de la base.

           Antes estaban escritos a mano en un diccionario -"Coordinador",
           "Administrativo", "G. Comercial"- que eran los perfiles de
           FacilityGes con ids 3 a 7. En SIGMA esos ids apuntan a otros
           perfiles, asi que la pantalla mostraba nombres que no existen
           junto a ids que si, y no habia forma de notarlo salvo leyendo.

           Ademas se usaba rawPerfiles.Replace("3", ...) sobre la cadena
           completa: en una lista como "3,13" eso reemplazaba tambien el 3
           de dentro del 13 y dejaba texto corrupto. */
        string rawPerfiles = Perfiles;

        List<string> ids = new List<string>();
        foreach (string idRaw in rawPerfiles.Split(new char[] { ',', ' ' }, StringSplitOptions.RemoveEmptyEntries))
        {
            string id = idRaw.Trim();
            if (id != "" && !ids.Contains(id)) ids.Add(id);
        }

        Dictionary<string, string> perfilNombres = new Dictionary<string, string>();

        if (ids.Count > 0)
        {
            PerfilController perfilController = new PerfilController();
            Perfil filtro = new Perfil();
            filtro.Perfiles = string.Join(",", ids.ToArray());

            List<Perfil> encontrados = perfilController.ListoPerfiles(filtro);

            if (encontrados != null)
                foreach (Perfil p in encontrados)
                    perfilNombres[p.per_id.ToString()] = p.per_nombre;
        }

        StringBuilder sbEtiqueta = new StringBuilder();
        StringBuilder sbPerfiles = new StringBuilder();

        foreach (string id in ids)
        {
            // Un id que ya no existe se muestra como tal en vez de
            // inventarle un nombre: asi se nota que hay que corregirlo.
            string nombre = perfilNombres.ContainsKey(id) ? perfilNombres[id] : "Perfil no encontrado";

            if (sbEtiqueta.Length > 0) sbEtiqueta.Append(", ");
            sbEtiqueta.AppendFormat("ID: {0} - {1}", id, nombre);

            sbPerfiles.AppendFormat(
                "<div class=\"cmu-perfil-item\"><span class=\"cmu-perfil-nombre\">{0}</span><span class=\"cmu-perfil-id\">{1}</span></div>",
                Server.HtmlEncode(nombre), id);
        }

        lblPerfil.Text = sbEtiqueta.ToString();
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
