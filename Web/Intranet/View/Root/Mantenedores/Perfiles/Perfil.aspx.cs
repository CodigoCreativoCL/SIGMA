using System;
using Telerik.Web.UI;
using SitioBase.Controller;
using SitioBase.Model;
using SitioBase;

public partial class View_Sistema_Perfiles_Perfil : System.Web.UI.Page
{
    private PerfilController controller = new PerfilController();

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

    public void LoadControls(object sender, System.EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {
                    case "cboTipoPerfil":
                        TipoPerfilController tipoPerfilController = new TipoPerfilController();

                        ctrl.EmptyMessage = "Seleccione...";
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = tipoPerfilController.ListoTipoPerfil();
                        ctrl.DataValueField = "tpp_id";
                        ctrl.DataTextField = "tpp_nombre";

                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    protected void CargarDatos()
    {
        if (Id > 0)
        {
            Perfil item = new Perfil();
            item.per_id = Id;
            item = controller.GetPerfiles(item);

            lblId.Text = Id.ToString();
            txtNombre.Text = item.per_nombre;
            txtDescripcion.Text = item.per_descripcion;
            cboTipoPerfil.SelectedValue = item.per_tipo.ToString();

            if (item.per_habilitado)
            {
                rdbSi.Checked = true;
                rdbNo.Checked = false;
            }
            else
            {
                rdbSi.Checked = false;
                rdbNo.Checked = true;
            }

        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();

            Perfil perfil = new Perfil();
            perfil.per_id = Id;
            perfil.per_nombre = txtNombre.Text;
            perfil.per_descripcion = txtDescripcion.Text;
            perfil.per_tipo = int.Parse(cboTipoPerfil.SelectedValue);

            if (rdbSi.Checked)
                perfil.per_habilitado = true;
            else
                perfil.per_habilitado = false;

            if (Id > 0)
                respuesta = controller.UpdateItem(perfil);
            else
                respuesta = controller.InsertItem(perfil);

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