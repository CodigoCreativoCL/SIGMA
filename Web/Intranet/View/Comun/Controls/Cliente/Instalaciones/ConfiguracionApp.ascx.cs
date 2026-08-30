using SitioBase.Controller;
using SitioBase.Model;
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
        ClienteAppInstalacion filtro = new ClienteAppInstalacion();
        filtro.cai_id_instalacion = IdClienteInstalacion;
        filtro.id_cliente = IdCliente;

        List<ClienteAppInstalacion> lista =
            clienteAppInstalacionController.GetClienteAppIntalaciones(filtro);

        /* Lista vacia no es lo mismo que error, pero desde la pantalla se ven
           igual: un recuadro en blanco con un boton Guardar debajo. Si el
           plan del cliente no incluye ninguna funcionalidad de app, hay que
           decirlo; y no tiene sentido ofrecer Guardar sobre cero filas. */
        bool hay = lista != null && lista.Count > 0;

        pnlSinFuncionalidades.Visible = !hay;
        btnGuardar.Visible = hay && !ReadOnly;

        rtpHtml.DataSource = hay ? lista : new List<ClienteAppInstalacion>();
        rtpHtml.DataBind();
        udPanel.Update();
    }

    /// <summary>
    /// El ultimo grupo dibujado, para no repetir el encabezado en cada fila.
    /// </summary>
    private string _grupoAnterior = "";

    /// <summary>
    /// El codigo de agrupacion, en palabras. Se traduce aqui y no en la base
    /// porque el codigo es lo estable y el rotulo es lo que se redacta.
    /// </summary>
    private string Legible(string tipo)
    {
        switch ((tipo ?? "").Trim().ToUpper())
        {
            case "TERRENO": return "En terreno";
            case "VOZ": return "Voz e inclusión";
            case "CONSULTA": return "Consultas";
            default: return tipo;
        }
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

            /* Siempre viene con valor: el SP ya resolvio el efectivo -lo
               configurado para esta planta, o el valor por defecto de la
               funcionalidad si nunca se configuro-. Antes podia venir en
               NULL y los dos radios quedaban apagados, sin decir cual regia. */
            bool habilitado = DataBinder.Eval(e.Item.DataItem, "cai_habilitado") != null
                && bool.Parse(DataBinder.Eval(e.Item.DataItem, "cai_habilitado").ToString());

            rdbSi.Checked = habilitado;
            rdbNo.Checked = !habilitado;

            /* La etiqueta de grupo -TERRENO, VOZ, CONSULTA- ayuda a leer la
               lista, pero solo la primera vez que aparece: repetirla en cada
               fila la convierte en ruido. */
            Literal litGrupo = (Literal)e.Item.FindControl("litGrupo");
            string tipo = Convert.ToString(DataBinder.Eval(e.Item.DataItem, "app_tipo"));

            if (litGrupo != null)
            {
                litGrupo.Text = (tipo != _grupoAnterior)
                    ? "<div class=\"sigma-modal-seccion\">" + Server.HtmlEncode(Legible(tipo)) + "</div>"
                    : "";

                _grupoAnterior = tipo;
            }

            if (ReadOnly)
            {
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
