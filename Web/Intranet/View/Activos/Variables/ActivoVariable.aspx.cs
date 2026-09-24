using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una variable de condicion de un equipo (HU-041).
///
/// Equipo, componente y variable identifican el registro (UX por la terna)
/// y no se cambian al editar: lo que se edita son la unidad, los umbrales y
/// la frecuencia. Los umbrales se validan en el SP (orden minimo <=
/// advertencia <= critico <= maximo); aqui solo se traduce el tipeo.
/// </summary>
public partial class View_Activos_Variables_ActivoVariable : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    private string _componenteEditar = null;

    /// <summary>
    /// El activo ya viene decidido: la ficha se abrió desde el centro de ESE
    /// equipo. Misma regla que en componentes y medidores.
    /// </summary>
    public int ActivoFijo
    {
        get { return ViewState["ActivoFijo"] != null ? (int)ViewState["ActivoFijo"] : 0; }
        set { ViewState["ActivoFijo"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            ActivoFijo = SitioBase.Querystring.Entero(Request.QueryString["query"], "Activo");
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboActivo":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    List<Activo> lista = new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
                    if (lista != null)
                        foreach (Activo a in lista)
                            ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
                    break;
                }
            case "cboVariable":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    List<VariableMedicion> lista = new VariableMedicionController().GetVariables(cliente, true);
                    if (lista != null)
                        foreach (VariableMedicion v in lista)
                            ctrl.Items.Add(new RadComboBoxItem(string.IsNullOrEmpty(v.etiqueta) ? v.vme_nombre : v.etiqueta, v.vme_id.ToString()));
                    break;
                }
            case "cboUnidad":
                {
                    ctrl.Items.Add(new RadComboBoxItem("La de la variable", ""));
                    List<UnidadMedida> lista = new UnidadMedidaController().GetUnidades(new UnidadMedida { filtro_habilitado = true });
                    if (lista != null)
                        foreach (UnidadMedida u in lista)
                            ctrl.Items.Add(new RadComboBoxItem(u.ume_nombre + " (" + u.ume_simbolo + ")", u.ume_id.ToString()));
                    break;
                }
        }
    }

    protected void cboActivo_SelectedIndexChanged(object sender, EventArgs e) { }

    /// <summary>Los componentes dependen del equipo; se rearman en cada postback conservando lo elegido.</summary>
    private void CargarComponentes()
    {
        string sel = string.IsNullOrEmpty(_componenteEditar) ? cboComponente.SelectedValue : _componenteEditar;
        cboComponente.Items.Clear();
        cboComponente.Items.Add(new RadComboBoxItem("Equipo completo", ""));

        int activo;
        if (int.TryParse(cboActivo.SelectedValue, out activo) && activo > 0)
        {
            List<ActivoComponente> comps = new ActivoComponenteController().GetComponentes(
                new ActivoComponente { aco_cliente = SitioBase.Session.ClienteId(), filtro_activo = activo, filtro_habilitado = true });
            if (comps != null)
                foreach (ActivoComponente c in comps)
                    cboComponente.Items.Add(new RadComboBoxItem(c.aco_codigo + " — " + c.aco_nombre, c.aco_id.ToString()));
        }

        RadComboBoxItem it = cboComponente.FindItemByValue(sel ?? ""); if (it != null) it.Selected = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarComponentes();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ActivoVariable v = new ActivoVariableController().GetVariable(Id);
            lblId.Text = Id.ToString();
            Seleccionar(cboActivo, v.ava_activo.ToString());
            if (v.ava_activo_componente != null) _componenteEditar = v.ava_activo_componente.Value.ToString();
            Seleccionar(cboVariable, v.ava_variable_medicion.ToString());
            if (v.ava_unidad_medida != null) Seleccionar(cboUnidad, v.ava_unidad_medida.Value.ToString());
            txtMinimo.Text = Num(v.ava_valor_minimo);
            txtMaximo.Text = Num(v.ava_valor_maximo);
            txtAdvertencia.Text = Num(v.ava_valor_advertencia);
            txtCritico.Text = Num(v.ava_valor_critico);
            txtFrecuencia.Text = v.ava_frecuencia_esperada_hora == null ? "" : v.ava_frecuencia_esperada_hora.ToString();
            rdbSi.Checked = v.ava_habilitado;
            rdbNo.Checked = !v.ava_habilitado;
            wucAuditoria.Mostrar(v.usuario_creacion_nombre, v.ava_fecha_creacion, v.usuario_actualizacion_nombre, v.ava_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
            if (ActivoFijo > 0) Seleccionar(cboActivo, ActivoFijo.ToString());
        }
    }

    private static string Num(decimal? d) { return d == null ? "" : d.Value.ToString("0.######", CultureInfo.InvariantCulture); }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR VARIABLES ACTIVO");

        // Fijos con Enabled: un RadComboBox ReadOnly no renderiza sus items y validaControl se cae.
        cboActivo.Enabled = Id == 0 && ActivoFijo == 0;
        cboComponente.Enabled = Id == 0;
        cboVariable.Enabled = Id == 0;
        cboActivo.ReadOnly = cboVariable.ReadOnly = cboComponente.ReadOnly = !puedeEditar;
        cboUnidad.ReadOnly = !puedeEditar;
        txtMinimo.ReadOnly = txtMaximo.ReadOnly = txtAdvertencia.ReadOnly = txtCritico.ReadOnly = txtFrecuencia.ReadOnly = !puedeEditar;
        rdbSi.Enabled = rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    private static decimal? Decimal(string texto, string campo)
    {
        string t = (texto ?? "").Trim();
        if (t.Length == 0) return null;
        decimal d;
        if (decimal.TryParse(t, out d)) return d;
        if (decimal.TryParse(t, NumberStyles.Any, CultureInfo.InvariantCulture, out d)) return d;
        throw new Exception("\"" + t + "\" no es un número válido en " + campo + ".");
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            ActivoVariable v = new ActivoVariable();
            v.ava_id = Id;
            v.ava_activo = string.IsNullOrEmpty(cboActivo.SelectedValue) ? 0 : int.Parse(cboActivo.SelectedValue);
            if (!string.IsNullOrEmpty(cboComponente.SelectedValue)) v.ava_activo_componente = int.Parse(cboComponente.SelectedValue);
            v.ava_variable_medicion = string.IsNullOrEmpty(cboVariable.SelectedValue) ? 0 : int.Parse(cboVariable.SelectedValue);
            if (!string.IsNullOrEmpty(cboUnidad.SelectedValue)) v.ava_unidad_medida = int.Parse(cboUnidad.SelectedValue);

            v.ava_valor_minimo = Decimal(txtMinimo.Text, "Mínimo");         v.quita_minimo = v.ava_valor_minimo == null;
            v.ava_valor_maximo = Decimal(txtMaximo.Text, "Máximo");         v.quita_maximo = v.ava_valor_maximo == null;
            v.ava_valor_advertencia = Decimal(txtAdvertencia.Text, "Advertencia"); v.quita_advertencia = v.ava_valor_advertencia == null;
            v.ava_valor_critico = Decimal(txtCritico.Text, "Crítico");      v.quita_critico = v.ava_valor_critico == null;

            if (!string.IsNullOrEmpty(txtFrecuencia.Text.Trim()))
            {
                int f;
                if (!int.TryParse(txtFrecuencia.Text.Trim(), out f) || f <= 0)
                    throw new Exception("La frecuencia esperada tiene que ser un número entero de horas mayor que cero.");
                v.ava_frecuencia_esperada_hora = f;
            }
            else v.quita_frecuencia = true;
            v.ava_habilitado = rdbSi.Checked;

            ActivoVariableController c = new ActivoVariableController();
            Respuesta r = Id > 0 ? c.Update(v) : c.Insert(v);
            if (!r.error) { Id = r.codigo; Tools.tools.ClientAlert(r.detalle, "ok", true); }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
