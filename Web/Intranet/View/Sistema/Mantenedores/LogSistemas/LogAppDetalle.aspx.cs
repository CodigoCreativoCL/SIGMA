using Agendamiento.Controller;
using Agendamiento.Model;
using System;

public partial class View_Root_LogSistema_LogAppDetalle : System.Web.UI.Page
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
            string raw = Request.QueryString["query"];
            if (string.IsNullOrEmpty(raw)) return;

            string decrypted = Tools.Crypto.Decrypt(Server.UrlDecode(raw)); 
            foreach (string par in decrypted.Split('&'))
            {
                string[] kv = par.Split('=');
                if (kv.Length == 2 && kv[0] == "Id")
                    Id = Convert.ToInt32(kv[1]);
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (Id > 0) CargarDatos();
    }

    private void CargarDatos()
    {
        LogAppController ctrl = new LogAppController();
        LogApp item = ctrl.GetLog(Id);

        if (item == null) return;

        // Datos básicos
        lblId.Text            = item.lot_id.ToString();
        lblEndpoint.Text      = item.lot_endpoint;
        lblIp.Text            = item.lot_ip ?? "—";
        lblNombreUsuario.Text = item.lot_nombre_usuario ?? "—";
        lblUsuario.Text       = item.lot_usuario ?? "—";
        lblDuracion.Text      = item.lot_duracion_ms.HasValue
            ? item.lot_duracion_ms.Value.ToString("N0") + " ms"
            : "—";
        lblFecha.Text         = item.lot_fecha_creacion ?? "—";

        // Badge método
        litMetodo.Text = string.Format(
            "<span class=\"badge-met\">{0}</span>", item.lot_metodo ?? "—");

        // Badge error
        litError.Text = item.lot_error
            ? "<span class=\"badge-err\">S&iacute;</span>"
            : "<span class=\"badge-ok\">No</span>";

        // Panel error
        if (item.lot_error && !string.IsNullOrEmpty(item.lot_mensaje_error))
        {
            pnlError.Visible      = true;
            lblMensajeError.Text  = item.lot_mensaje_error;
        }

        // Panel stack trace
        if (!string.IsNullOrEmpty(item.lot_stack_trace))
        {
            pnlStack.Visible      = true;
            txtStackTrace.Text    = item.lot_stack_trace;
        }

        // JSON request / response
        txtRequest.Text  = item.lot_request  ?? string.Empty;
        txtResponse.Text = item.lot_response ?? string.Empty;
    }
}
