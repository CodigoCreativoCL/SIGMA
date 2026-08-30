using SitioBase.Controller;
using SitioBase.Model;
using System;

public partial class View_Root_ModulosSistema_NuevoModuloSistema : System.Web.UI.Page
{
    public int IdModulo
    {
        get { return Convert.ToInt32(ViewState["IdModulo"]); }
        set { ViewState.Add("IdModulo", value); }
    }

    private ModuloSistemaController controller = new ModuloSistemaController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            string queryStr = Request.QueryString["query"];
            if (!string.IsNullOrEmpty(queryStr))
            {
                string[] query = SitioBase.Querystring.Descifrar(queryStr).Split('&');
                foreach (string arr in query)
                {
                    string[] array = arr.Split('=');
                    if (array[0] == "IdModulo")
                        IdModulo = int.Parse(array[1]);
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
            CargarDatos();
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IdModulo > 0)
        {
            ModuloSistema item = controller.GetModulo(IdModulo);
            if (item != null)
            {
                divID.Visible     = true;
                lblID.Text        = item.mds_id.ToString();
                txtNombre.Text    = item.mds_nombre;
                chkHabilitado.Checked = item.mds_habilitado;
            }
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            ModuloSistema item = new ModuloSistema();
            item.mds_id         = IdModulo;
            item.mds_nombre     = txtNombre.Text.Trim();
            item.mds_habilitado = chkHabilitado.Checked;

            Respuesta respuesta;

            if (IdModulo > 0)
                respuesta = controller.UpdModulo(item);
            else
                respuesta = controller.InsModulo(item);

            if (!respuesta.error)
            {
                IdModulo = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }
}
