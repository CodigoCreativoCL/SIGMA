using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Un periodo de indisponibilidad (HU-124). Se abre desde la orden o desde
/// la falla, que vienen cifradas en el query junto con el equipo; tambien
/// vale sin ninguna de las dos (una parada por corte de energia). Los
/// minutos los calcula el SP.
/// </summary>
public partial class View_Mantenimiento_Fallas_ActivoIndisponibilidad : System.Web.UI.Page
{
    public int Id { get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; } set { ViewState["Id"] = value; } }
    public int Orden { get { return ViewState["Orden"] != null ? (int)ViewState["Orden"] : 0; } set { ViewState["Orden"] = value; } }
    public int Falla { get { return ViewState["Falla"] != null ? (int)ViewState["Falla"] : 0; } set { ViewState["Falla"] = value; } }
    public int Activo { get { return ViewState["Activo"] != null ? (int)ViewState["Activo"] : 0; } set { ViewState["Activo"] = value; } }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            string q = Request.QueryString["query"];
            Id = SitioBase.Querystring.Entero(q, "Id");
            Orden = SitioBase.Querystring.Entero(q, "Orden");
            Falla = SitioBase.Querystring.Entero(q, "Falla");
            Activo = SitioBase.Querystring.Entero(q, "Activo");
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;
        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        if (ctrl.ID == "cboActivo")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            List<Activo> lista = new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
            if (lista != null) foreach (Activo a in lista) ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
        }
        else if (ctrl.ID == "cboMotivo")
        {
            // Indisponibilidad_Motivo: catalogo fijo del bloque 19
            ctrl.Items.Add(new RadComboBoxItem("Otro (describa abajo)", ""));
            ctrl.Items.Add(new RadComboBoxItem("Mantenimiento planificado", "1"));
            ctrl.Items.Add(new RadComboBoxItem("Falla", "2"));
            ctrl.Items.Add(new RadComboBoxItem("Espera de repuesto", "3"));
            ctrl.Items.Add(new RadComboBoxItem("Espera de técnico", "4"));
            ctrl.Items.Add(new RadComboBoxItem("Causa externa", "5"));
            ctrl.Items.Add(new RadComboBoxItem("Parada de producción", "6"));
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        bool puede = Token.Puede("REGISTRAR FALLA");
        cboActivo.Enabled = Id == 0 && Activo == 0;
        cboActivo.ReadOnly = !puede;
        btnGuardar.Visible = puede;
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;
        if (Id > 0)
        {
            ActivoIndisponibilidad i = new IndisponibilidadController().GetUna(Id);
            lblId.Text = Id.ToString();
            Seleccionar(cboActivo, i.ain_activo.ToString());
            txtInicio.Text = i.ain_fecha_inicio_utc.ToString("dd-MM-yyyy HH:mm");
            txtFin.Text = i.ain_fecha_fin_utc == null ? "" : i.ain_fecha_fin_utc.Value.ToString("dd-MM-yyyy HH:mm");
            rdbPlanSi.Checked = i.ain_planificada; rdbPlanNo.Checked = !i.ain_planificada;
            rdbProdSi.Checked = i.ain_detuvo_produccion; rdbProdNo.Checked = !i.ain_detuvo_produccion;
            if (i.ain_indisponibilidad_motivo != null) Seleccionar(cboMotivo, i.ain_indisponibilidad_motivo.Value.ToString());
            txtMotivo.Text = i.ain_motivo;
            txtInicio.ReadOnly = true;
        }
        else
        {
            lblId.Text = "Nueva";
            if (Activo > 0) Seleccionar(cboActivo, Activo.ToString());
            if (Falla > 0) Seleccionar(cboMotivo, "2");
            else if (Orden > 0) Seleccionar(cboMotivo, "1");
            txtInicio.Text = DateTime.Now.ToString("dd-MM-yyyy HH:mm");
        }
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    private static DateTime? Fecha(string texto, string campo)
    {
        string t = (texto ?? "").Trim();
        if (t.Length == 0) return null;
        DateTime d;
        if (DateTime.TryParseExact(t, new[] { "dd-MM-yyyy HH:mm", "dd-MM-yyyy", "dd/MM/yyyy HH:mm", "dd/MM/yyyy" }, CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) return d;
        throw new Exception("\"" + t + "\" no es una fecha válida en " + campo + " (dd-mm-aaaa hh:mm).");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            ActivoIndisponibilidad i = new ActivoIndisponibilidad { ain_id = Id };
            i.ain_activo = string.IsNullOrEmpty(cboActivo.SelectedValue) ? 0 : int.Parse(cboActivo.SelectedValue);
            if (Orden > 0) i.ain_orden_trabajo = Orden;
            if (Falla > 0) i.ain_falla = Falla;
            DateTime? ini = Fecha(txtInicio.Text, "Inicio");
            if (ini == null) throw new Exception("Indique cuándo empezó la indisponibilidad.");
            i.ain_fecha_inicio_utc = ini.Value;
            i.ain_fecha_fin_utc = Fecha(txtFin.Text, "Término");
            i.ain_planificada = rdbPlanSi.Checked;
            i.ain_detuvo_produccion = rdbProdSi.Checked;
            if (!string.IsNullOrEmpty(cboMotivo.SelectedValue)) i.ain_indisponibilidad_motivo = int.Parse(cboMotivo.SelectedValue);
            i.ain_motivo = string.IsNullOrEmpty(txtMotivo.Text.Trim()) ? null : txtMotivo.Text.Trim();
            i.ain_habilitado = true;

            IndisponibilidadController c = new IndisponibilidadController();
            Respuesta r = Id > 0 ? c.Update(i) : c.Insert(i);
            if (!r.error) { Id = r.codigo; Tools.tools.ClientAlert(r.detalle, "ok", true); }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }
}
