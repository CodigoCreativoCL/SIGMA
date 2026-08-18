using Facilityges.Controller;
using Facilityges.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

public partial class View_Comun_Controls_Cliente_Instalaciones_ConfiguracionApp : System.Web.UI.UserControl
{
    private ClienteAppInstalacionController clienteAppInstalacionController = new ClienteAppInstalacionController();
    private ClienteAppInstalacion clienteAppInstalacion = new ClienteAppInstalacion();

    #region Variables Globales
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
    public int IdClienteInstalacion
    {
        get { return Convert.ToInt32(ViewState["IdClienteInstalacion"]); }
        set { ViewState.Add("IdClienteInstalacion", value); }
    }

    #endregion
    protected void Page_Load(object sender, EventArgs e)
    {

    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
            CargarDatos();
    }

    protected void CargarDatos()
    {
        ClienteAppInstalacion clienteAppInstalacion = new ClienteAppInstalacion();
        clienteAppInstalacion.cai_id_instalacion = IdClienteInstalacion;
        List<ClienteAppInstalacion> clienteAppInstalacions = new List<ClienteAppInstalacion>();
        clienteAppInstalacions = clienteAppInstalacionController.GetClienteAppIntalaciones(clienteAppInstalacion);
        rtpHtml.DataSource = clienteAppInstalacions;
        rtpHtml.DataBind();
        udPanel.Update();
    }

    protected void rtpHtml_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType == ListItemType.Item || e.Item.ItemType == ListItemType.AlternatingItem)
        {

            Label lblnombreapp = (Label)e.Item.FindControl("lblnombreapp");
            HiddenField hdfId = (HiddenField)e.Item.FindControl("hdfId");
            RadioButton rdbSi = (RadioButton)e.Item.FindControl("rdbSi");
            RadioButton rdbNo = (RadioButton)e.Item.FindControl("rdbNo");

            lblnombreapp.Text = DataBinder.Eval(e.Item.DataItem, "app_nombre").ToString();
            hdfId.Value = DataBinder.Eval(e.Item.DataItem, "app_id").ToString();

            if (DataBinder.Eval(e.Item.DataItem, "cai_habilitado") != null)
            {
                bool habilitado = bool.Parse(DataBinder.Eval(e.Item.DataItem, "cai_habilitado").ToString());

                if (habilitado)
                    rdbSi.Checked = true;
                else
                    rdbNo.Checked = true;

            }

            if (ReadOnly == true)
            {
                rdbSi.Enabled = false;
                rdbNo.Enabled = false;
                btnGuardar.Visible = false;
            }

            //bloquea todas las funcionalidades Base
            int app_tipo = int.Parse(DataBinder.Eval(e.Item.DataItem, "app_tipo").ToString());

            if (app_tipo == 1)
            {
                rdbSi.Checked = true;
                rdbSi.Enabled = false;
                rdbNo.Enabled = false;
            }
        }
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            foreach (RepeaterItem item in rtpHtml.Items)
            {
                HiddenField hdfId = (HiddenField)item.FindControl("hdfId");
                RadioButton rdbSi = (RadioButton)item.FindControl("rdbSi");
                RadioButton rdbNo = (RadioButton)item.FindControl("rdbNo");

                ClienteAppInstalacion clienteAppInstalacion = new ClienteAppInstalacion();
                clienteAppInstalacion.id_cliente = IdCliente;
                clienteAppInstalacion.cai_id_instalacion = IdClienteInstalacion;
                clienteAppInstalacion.cai_id_app = int.Parse(hdfId.Value);
                clienteAppInstalacion.cai_habilitado = rdbSi.Checked;

                respuesta = clienteAppInstalacionController.InsertClienteAppInstalacion(clienteAppInstalacion);

            }

            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");

            CargarDatos();

        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}
