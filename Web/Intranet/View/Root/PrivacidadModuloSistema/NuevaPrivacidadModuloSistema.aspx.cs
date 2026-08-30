using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web;
using System.Web.UI;
using Telerik.Web.UI;

public partial class View_Root_PrivacidadModuloSistema_NuevaPrivacidadModuloSistema : System.Web.UI.Page
{
    public int IdPrivacidad
    {
        get { return Convert.ToInt32(ViewState["IdPrivacidad"]); }
        set { ViewState.Add("IdPrivacidad", value); }
    }

    private PrivacidadModuloSistemaController controller = new PrivacidadModuloSistemaController();

    // Ciclo de vida

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
                    if (array.Length >= 2 && array[0] == "IdPrivacidad")
                        IdPrivacidad = int.Parse(array[1]);
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
            CargarDatos();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    // Carga combos

    public void LoadControls(object sender, EventArgs e)
    {
        if (!(sender is RadComboBox2)) return;
        RadComboBox2 ctrl = (RadComboBox2)sender;
        if (IsPostBack) return;

        if (ctrl.ID == "cboModulo")
        {
            var modulos = new ModuloSistemaController().GetModulos(new ModuloSistema { filtro_habilitado = "1" });
            ctrl.Items.Clear();
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            if (modulos != null)
                foreach (var m in modulos)
                    ctrl.Items.Add(new RadComboBoxItem(m.mds_nombre, m.mds_id.ToString()));
        }
    }

    // Carga datos 

    protected void CargarDatos()
    {
        if (IdPrivacidad <= 0) return;

        PrivacidadModuloSistema filtro = new PrivacidadModuloSistema { filtro_id = IdPrivacidad };
        PrivacidadModuloSistema item = controller.GetPrivacidad(filtro);

        if (item == null) return;

        divID.Visible              = true;
        lblID.Text                 = item.pms_id.ToString();
        cboModulo.SelectedValue    = item.pms_id_modulo.ToString();
        txtDescripcion.Text        = item.pms_descripcion;

        pnlAuditoria.Visible       = true;
        lblUsuarioCreacion.Text    = item.usuario_creacion_nombre;
        lblFechaCreacion.Text      = item.pms_fecha_creacion != DateTime.MinValue
                                        ? item.pms_fecha_creacion.ToString("dd-MM-yyyy HH:mm")
                                        : "-";
        lblUsuarioAct.Text         = item.usuario_act_nombre;
        lblFechaAct.Text           = item.pms_fecha_act != DateTime.MinValue
                                        ? item.pms_fecha_act.ToString("dd-MM-yyyy HH:mm")
                                        : "-";
    }

    //  Guardar

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            PrivacidadModuloSistema item = new PrivacidadModuloSistema();
            item.pms_id         = IdPrivacidad;
            item.pms_id_modulo  = int.Parse(cboModulo.SelectedValue);
            item.pms_descripcion = txtDescripcion.ReadOnly
                                    ? txtDescripcion.Text
                                    : HttpUtility.UrlDecode(txtDescripcion.Text);

            Respuesta respuesta;

            if (IdPrivacidad > 0)
                respuesta = controller.UpdPrivacidad(item);
            else
                respuesta = controller.InsPrivacidad(item);

            if (!respuesta.error)
            {
                IdPrivacidad = respuesta.codigo;
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
