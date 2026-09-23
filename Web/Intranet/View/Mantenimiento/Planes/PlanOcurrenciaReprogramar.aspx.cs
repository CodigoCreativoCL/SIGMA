using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Globalization;
using System.Web.UI;

/// <summary>
/// Reprogramar una ocurrencia indicando el motivo (HU-086). Carga la ocurrencia,
/// permite moverla a una nueva fecha con un motivo obligatorio, y muestra el
/// resultado. El proceso y las reglas viven en el SP PLAN_OCURRENCIA_REPROGRAMAR;
/// aquí solo se dispara. La acción la habilita Token.Puede("CREAR EDITAR PLANES
/// MANTENIMIENTO") en el servidor (no se esconde el botón por CSS) y todo se
/// acota al cliente en sesión.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanOcurrenciaReprogramar : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Cargar();
        udPanel.Update();
    }

    protected void Cargar()
    {
        if (Id <= 0) return;
        int cliente = SitioBase.Session.ClienteId();

        PlanOcurrencia o = new PlanOcurrenciaController().GetOcurrencia(Id, cliente);
        if (o == null)
        {
            litPlan.Text = "Ocurrencia no encontrada";
            pnlForm.Visible = false; pnlResultado.Visible = false; pnlBloqueada.Visible = false;
            return;
        }

        litActivo.Text = Server.HtmlEncode((o.activo_codigo + " · " + o.activo_nombre).Trim(' ', '·'));
        litPlan.Text = Server.HtmlEncode(o.plan_nombre);
        litHito.Text = Server.HtmlEncode((o.hito_codigo + " · " + o.hito_nombre).Trim(' ', '·'));
        litEstado.Text = Server.HtmlEncode(o.estado_nombre);
        litFecha.Text = o.pmo_fecha_programada != null ? o.pmo_fecha_programada.Value.ToString("dd-MM-yyyy") : "—";
        litOriginal.Text = o.pmo_fecha_original != null ? o.pmo_fecha_original.Value.ToString("dd-MM-yyyy") : "—";

        bool puede = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO");

        // Caso 1: ya fue reprogramada -> se muestra el resultado.
        if (o.YaReprogramada)
        {
            pnlResultado.Visible = true;
            string txt = "Movida";
            if (o.pmo_fecha_nueva != null) txt += " al <b>" + o.pmo_fecha_nueva.Value.ToString("dd-MM-yyyy") + "</b>";
            if (!string.IsNullOrEmpty(o.usuario_actualizacion_nombre)) txt += " por " + Server.HtmlEncode(o.usuario_actualizacion_nombre);
            if (o.pmo_fecha_actualizacion != null) txt += " el " + o.pmo_fecha_actualizacion.Value.ToString("dd-MM-yyyy");
            if (!string.IsNullOrEmpty(o.pmo_observacion)) txt += ".<br/><span style='color:#166534;'>Motivo:</span> " + Server.HtmlEncode(o.pmo_observacion);
            litResultado.Text = txt;
            return;
        }

        // Caso 2: se puede reprogramar (pendiente/disponible) y hay permiso.
        if (o.EsReprogramable && puede)
        {
            pnlForm.Visible = true;
            return;
        }

        // Caso 3: no se puede.
        pnlBloqueada.Visible = true;
        litBloqueada.Text = !puede
            ? "No tiene el permiso para reprogramar ocurrencias de plan."
            : "Solo se reprograma una ocurrencia pendiente o disponible; esta está en estado " + Server.HtmlEncode(o.estado_nombre) + ".";
    }

    protected void btnReprogramar_Click(object sender, EventArgs e)
    {
        try
        {
            // El servidor decide, no el botón.
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para reprogramar ocurrencias de plan.", "alerta");
                return;
            }

            DateTime fecha;
            if (!DateTime.TryParseExact(txtFecha.Text.Trim(), "yyyy-MM-dd",
                    CultureInfo.InvariantCulture, DateTimeStyles.None, out fecha))
            {
                Tools.tools.ClientAlert("Indique la nueva fecha.", "alerta");
                return;
            }
            if (string.IsNullOrEmpty(txtMotivo.Text.Trim()))
            {
                Tools.tools.ClientAlert("Indique el motivo de la reprogramación.", "alerta");
                return;
            }

            Respuesta r = new PlanOcurrenciaController().Reprogramar(Id, fecha, txtMotivo.Text.Trim());
            if (!r.error)
            {
                txtMotivo.Text = "";
                Tools.tools.ClientAlert(r.detalle, "ok");
                Cargar();   // la ocurrencia queda REPROGRAMADA y se muestra el resultado
            }
            else
            {
                Tools.tools.ClientAlert(r.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
