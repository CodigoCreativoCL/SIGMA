using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un paso de procedimiento (HU-062). El paso cuelga de un
/// procedimiento DEL CLIENTE; el orden es único dentro del procedimiento. Un
/// paso puede ser punto de control, exigir evidencia y/o exigir medición (con
/// su variable). La escritura la habilita Token.Puede("CREAR EDITAR
/// PROCEDIMIENTOS"); los pasos de procedimientos globales son de solo lectura.
/// </summary>
public partial class View_Mantenimiento_Procedimientos_ProcedimientoPaso : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // Procedimiento preseleccionado al crear (viene del filtro del listado).
    public int PrcHint
    {
        get { return ViewState["PrcHint"] != null ? (int)ViewState["PrcHint"] : 0; }
        set { ViewState["PrcHint"] = value; }
    }

    // Un paso de procedimiento global no lo edita el cliente.
    public bool EsGlobal
    {
        get { return ViewState["EsGlobal"] != null && (bool)ViewState["EsGlobal"]; }
        set { ViewState["EsGlobal"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            int prc;
            if (int.TryParse(Request.QueryString["prc"], out prc)) PrcHint = prc;
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        if (ctrl.ID == "cboProcedimiento")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ProcedimientoController c = new ProcedimientoController();
            var lista = c.GetProcedimientos(new Procedimiento { filtro_cliente = cliente });
            if (lista != null)
                foreach (Procedimiento p in lista)
                {
                    if (p.es_global) continue;   // a un global no se le agregan pasos
                    string txt = p.prc_codigo + " · " + p.prc_nombre + " (v" + p.prc_version + ")";
                    ctrl.Items.Add(new RadComboBoxItem(txt, p.prc_id.ToString()));
                }
        }
        else if (ctrl.ID == "cboVariable")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            VariableMedicionController c = new VariableMedicionController();
            var lista = c.GetVariables(cliente);
            if (lista != null)
                foreach (VariableMedicion v in lista)
                    ctrl.Items.Add(new RadComboBoxItem(v.etiqueta, v.vme_id.ToString()));
        }
    }

    protected void rdbMed_CheckedChanged(object sender, EventArgs e)
    {
        // El postback recarga; PreRender habilita/inhabilita el combo de variable.
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ProcedimientoPasoController c = new ProcedimientoPasoController();
            ProcedimientoPaso x = c.GetPaso(Id);

            lblId.Text = Id.ToString();
            litModo.Text = "Editar paso";
            if (!string.IsNullOrEmpty(x.ppa_nombre)) litTitulo.Text = Server.HtmlEncode(x.ppa_nombre);

            SeleccionarCombo(cboProcedimiento, x.ppa_procedimiento);
            txtOrden.Text = x.ppa_orden.ToString();
            txtNombre.Text = x.ppa_nombre;
            txtInstruccion.Text = x.ppa_instruccion;
            txtDuracion.Text = x.ppa_duracion_estimada_minuto != null ? x.ppa_duracion_estimada_minuto.ToString() : "";
            EsGlobal = x.es_global;

            rdbPcSi.Checked = x.ppa_es_punto_control; rdbPcNo.Checked = !x.ppa_es_punto_control;
            rdbEvSi.Checked = x.ppa_requiere_evidencia; rdbEvNo.Checked = !x.ppa_requiere_evidencia;
            rdbMedSi.Checked = x.ppa_requiere_medicion; rdbMedNo.Checked = !x.ppa_requiere_medicion;
            if (x.ppa_variable_medicion != null) SeleccionarCombo(cboVariable, x.ppa_variable_medicion.Value);

            rdbSi.Checked = x.ppa_habilitado; rdbNo.Checked = !x.ppa_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.ppa_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.ppa_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
            if (PrcHint > 0) SeleccionarCombo(cboProcedimiento, PrcHint);
        }
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PROCEDIMIENTOS") && !EsGlobal;

        pnlGlobal.Visible = EsGlobal;

        if (Id > 0)
        {
            if (EsGlobal)
                litEstado.Text = "<span class=\"sg-proc-badge is-global\">Global</span>";
            else if (rdbSi.Checked)
                litEstado.Text = "<span class=\"sg-proc-badge is-si\">Habilitado</span>";
            else
                litEstado.Text = "<span class=\"sg-proc-badge is-no\">Deshabilitado</span>";
        }

        // El procedimiento no se cambia una vez creado el paso.
        cboProcedimiento.ReadOnly = !puedeEditar || Id > 0;
        txtOrden.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtInstruccion.ReadOnly = !puedeEditar;
        txtDuracion.ReadOnly = !puedeEditar;
        rdbPcSi.Enabled = puedeEditar; rdbPcNo.Enabled = puedeEditar;
        rdbEvSi.Enabled = puedeEditar; rdbEvNo.Enabled = puedeEditar;
        rdbMedSi.Enabled = puedeEditar; rdbMedNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar; rdbNo.Enabled = puedeEditar;
        // La variable solo aplica si el paso requiere medición.
        cboVariable.ReadOnly = !puedeEditar || !rdbMedSi.Checked;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (EsGlobal) throw new Exception("Este paso es de un procedimiento del sistema y no se edita desde aquí.");
            if (string.IsNullOrEmpty(cboProcedimiento.SelectedValue)) throw new Exception("Debe indicar el procedimiento.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el nombre del paso.");

            bool medicion = rdbMedSi.Checked;
            if (medicion && string.IsNullOrEmpty(cboVariable.SelectedValue))
                throw new Exception("Si el paso requiere medición, indique la variable.");

            ProcedimientoPaso x = new ProcedimientoPaso();
            ProcedimientoPasoController c = new ProcedimientoPasoController();

            x.ppa_id = Id;
            x.ppa_procedimiento = int.Parse(cboProcedimiento.SelectedValue);
            x.ppa_nombre = txtNombre.Text.Trim();
            x.ppa_es_punto_control = rdbPcSi.Checked;
            x.ppa_requiere_evidencia = rdbEvSi.Checked;
            x.ppa_requiere_medicion = medicion;

            int orden;
            if (int.TryParse(txtOrden.Text.Trim(), out orden)) x.ppa_orden = orden;

            int duracion;
            if (int.TryParse(txtDuracion.Text.Trim(), out duracion)) x.ppa_duracion_estimada_minuto = duracion;

            if (!string.IsNullOrEmpty(txtInstruccion.Text.Trim())) x.ppa_instruccion = txtInstruccion.Text.Trim();

            if (medicion && !string.IsNullOrEmpty(cboVariable.SelectedValue))
                x.ppa_variable_medicion = int.Parse(cboVariable.SelectedValue);
            else
                x.quita_variable = true;   // al editar, dejarlo sin variable

            Respuesta r = (Id > 0) ? c.UpdatePaso(x) : c.InsertPaso(x);

            if (!r.error)
            {
                Id = r.codigo;
                Tools.tools.ClientAlert(r.detalle, "ok", true);
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
