using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un modelo de activo (HU-031). La escritura la habilita
/// Token.Puede("CREAR EDITAR MODELOS ACTIVO"). Un modelo global de la
/// plataforma se muestra en solo lectura: no se edita desde el cliente.
/// </summary>
public partial class View_Activos_Modelos_ActivoModelo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // Un modelo global (amo_cliente NULL) no lo edita el cliente.
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

        if (ctrl.ID == "cboTipo")
        {
            ActivoTipoController c = new ActivoTipoController();
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
            ctrl.DataValueField = "ati_id"; ctrl.DataTextField = "ati_nombre"; ctrl.DataBind();
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
            ActivoModeloController c = new ActivoModeloController();
            ActivoModelo x = c.GetModelo(Id);

            lblId.Text = Id.ToString();
            txtFabricante.Text = x.amo_fabricante;
            txtNombre.Text = x.amo_nombre;
            txtDescripcion.Text = x.amo_descripcion;
            EsGlobal = x.es_global;

            SeleccionarCombo(cboTipo, x.amo_activo_tipo);

            rdbSi.Checked = x.amo_habilitado;
            rdbNo.Checked = !x.amo_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.amo_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.amo_fecha_actualizacion);
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
        bool puedeEditar = Token.Puede("CREAR EDITAR MODELOS ACTIVO") && !EsGlobal;

        pnlGlobal.Visible = EsGlobal;

        cboTipo.ReadOnly = !puedeEditar;
        txtFabricante.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (EsGlobal) throw new Exception("Este es un modelo global de la plataforma y no se edita desde aquí.");
            if (string.IsNullOrEmpty(cboTipo.SelectedValue)) throw new Exception("Debe elegir el tipo de activo.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el modelo.");

            ActivoModelo x = new ActivoModelo();
            ActivoModeloController c = new ActivoModeloController();

            x.amo_id = Id;
            x.amo_cliente = SitioBase.Session.ClienteId();
            x.amo_activo_tipo = int.Parse(cboTipo.SelectedValue);
            x.amo_nombre = txtNombre.Text.Trim();
            x.amo_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(txtFabricante.Text.Trim())) x.amo_fabricante = txtFabricante.Text.Trim();
            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.amo_descripcion = txtDescripcion.Text.Trim();

            Respuesta r = (Id > 0) ? c.UpdateModelo(x) : c.InsertModelo(x);

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
