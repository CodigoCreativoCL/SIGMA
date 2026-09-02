using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un atributo técnico (HU-032). El código es automático (ATR-&lt;id&gt;).
/// La escritura la habilita Token.Puede("CREAR EDITAR ATRIBUTOS TECNICOS"). Un
/// atributo global de la plataforma se muestra en solo lectura.
/// </summary>
public partial class View_Activos_Atributos_AtributoTecnico : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // Un atributo global (ate_cliente NULL) no lo edita el cliente.
    public bool EsGlobal
    {
        get { return ViewState["EsGlobal"] != null && (bool)ViewState["EsGlobal"]; }
        set { ViewState["EsGlobal"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboTipo":
                {
                    ActivoTipoController c = new ActivoTipoController();
                    ctrl.Items.Add(new RadComboBoxItem("Todos los tipos", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
                    ctrl.DataValueField = "ati_id"; ctrl.DataTextField = "ati_nombre"; ctrl.DataBind();
                    break;
                }
            case "cboTipoDato":
                {
                    TipoDatoController c = new TipoDatoController();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetTiposDato(new TipoDato { filtro_habilitado = true });
                    ctrl.DataValueField = "tda_id"; ctrl.DataTextField = "tda_nombre"; ctrl.DataBind();
                    break;
                }
            case "cboUnidad":
                {
                    UnidadMedidaController c = new UnidadMedidaController();
                    ctrl.Items.Add(new RadComboBoxItem("Sin unidad", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetUnidades();
                    ctrl.DataValueField = "ume_id"; ctrl.DataTextField = "ume_nombre"; ctrl.DataBind();
                    break;
                }
        }
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
            AtributoTecnicoController c = new AtributoTecnicoController();
            AtributoTecnico x = c.GetAtributo(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = x.ate_codigo;
            txtNombre.Text = x.ate_nombre;
            txtOrden.Text = x.ate_orden != null ? x.ate_orden.ToString() : "";
            EsGlobal = x.es_global;

            SeleccionarCombo(cboTipoDato, x.ate_tipo_dato);
            if (x.ate_activo_tipo != null) SeleccionarCombo(cboTipo, x.ate_activo_tipo.Value);
            if (x.ate_unidad_medida != null) SeleccionarCombo(cboUnidad, x.ate_unidad_medida.Value);

            rdbSi.Checked = x.ate_habilitado;
            rdbNo.Checked = !x.ate_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.ate_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.ate_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR ATRIBUTOS TECNICOS") && !EsGlobal;

        pnlGlobal.Visible = EsGlobal;

        txtCodigo.ReadOnly = true;   // el código es automático (ATR-<id>)
        txtNombre.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        cboTipoDato.ReadOnly = !puedeEditar;
        cboUnidad.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (EsGlobal) throw new Exception("Este es un atributo global de la plataforma y no se edita desde aquí.");
            if (string.IsNullOrEmpty(cboTipoDato.SelectedValue)) throw new Exception("Debe elegir el tipo de dato.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el nombre del atributo.");

            AtributoTecnico x = new AtributoTecnico();
            AtributoTecnicoController c = new AtributoTecnicoController();

            x.ate_id = Id;
            x.ate_cliente = SitioBase.Session.ClienteId();
            x.ate_tipo_dato = int.Parse(cboTipoDato.SelectedValue);
            x.ate_codigo = (Id > 0) ? txtCodigo.Text.Trim() : "AUTO";   // ATR-<id> lo genera el SP
            x.ate_nombre = txtNombre.Text.Trim();
            x.ate_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboTipo.SelectedValue)) x.ate_activo_tipo = int.Parse(cboTipo.SelectedValue);
            if (!string.IsNullOrEmpty(cboUnidad.SelectedValue)) x.ate_unidad_medida = int.Parse(cboUnidad.SelectedValue);

            int orden;
            if (int.TryParse(txtOrden.Text.Trim(), out orden)) x.ate_orden = orden;

            Respuesta r = (Id > 0) ? c.UpdateAtributo(x) : c.InsertAtributo(x);

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
