using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un procedimiento reutilizable (HU-061). El código y la versión son
/// la llave: se escriben al crear y no se cambian al editar (para versionar se
/// crea uno nuevo con el mismo código y otra versión). La escritura la habilita
/// Token.Puede("CREAR EDITAR PROCEDIMIENTOS"); un procedimiento global del
/// sistema se muestra en solo lectura.
/// </summary>
public partial class View_Mantenimiento_Procedimientos_Procedimiento : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // Un procedimiento global (prc_cliente NULL) no lo edita el cliente.
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
            ctrl.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
            ctrl.DataValueField = "ati_id"; ctrl.DataTextField = "ati_nombre"; ctrl.DataBind();
        }
        else if (ctrl.ID == "cboPermisoTipo")
        {
            PermisoTrabajoController c = new PermisoTrabajoController();
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetTipos();
            ctrl.DataValueField = "ptt_id"; ctrl.DataTextField = "ptt_nombre"; ctrl.DataBind();
        }
    }

    protected void rdbPermiso_CheckedChanged(object sender, EventArgs e)
    {
        // El postback recarga; PreRender ajusta el combo según el radio.
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
            ProcedimientoController c = new ProcedimientoController();
            Procedimiento x = c.GetProcedimiento(Id);

            lblId.Text = Id.ToString();
            litModo.Text = "Editar procedimiento";
            if (!string.IsNullOrEmpty(x.prc_nombre)) litTitulo.Text = Server.HtmlEncode(x.prc_nombre);
            txtCodigo.Text = x.prc_codigo;
            txtVersion.Text = x.prc_version.ToString();
            txtNombre.Text = x.prc_nombre;
            txtDescripcion.Text = x.prc_descripcion;
            txtDuracion.Text = x.prc_duracion_estimada_minuto != null ? x.prc_duracion_estimada_minuto.ToString() : "";
            EsGlobal = x.es_global;

            if (x.prc_activo_tipo != null) SeleccionarCombo(cboTipo, x.prc_activo_tipo.Value);

            rdbPermisoSi.Checked = x.prc_requiere_permiso;
            rdbPermisoNo.Checked = !x.prc_requiere_permiso;
            if (x.prc_permiso_trabajo_tipo != null) SeleccionarCombo(cboPermisoTipo, x.prc_permiso_trabajo_tipo.Value);

            rdbSi.Checked = x.prc_habilitado;
            rdbNo.Checked = !x.prc_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.prc_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.prc_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
            txtVersion.Text = "1";
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

        // Badge de estado en el encabezado (solo en edición).
        if (Id > 0)
        {
            if (EsGlobal)
                litEstado.Text = "<span class=\"sg-proc-badge is-global\">Global</span>";
            else if (rdbSi.Checked)
                litEstado.Text = "<span class=\"sg-proc-badge is-si\">Habilitado</span>";
            else
                litEstado.Text = "<span class=\"sg-proc-badge is-no\">Deshabilitado</span>";
        }

        // Código y versión son la llave: no se editan una vez creado.
        txtCodigo.ReadOnly = !puedeEditar || Id > 0;
        txtVersion.ReadOnly = !puedeEditar || Id > 0;
        txtNombre.ReadOnly = !puedeEditar;
        txtDuracion.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        rdbPermisoSi.Enabled = puedeEditar;
        rdbPermisoNo.Enabled = puedeEditar;
        // El tipo de permiso solo aplica si se exige permiso.
        cboPermisoTipo.ReadOnly = !puedeEditar || !rdbPermisoSi.Checked;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (EsGlobal) throw new Exception("Este procedimiento es del sistema y no se edita desde aquí.");
            if (string.IsNullOrEmpty(txtCodigo.Text.Trim())) throw new Exception("Debe indicar el código.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el nombre.");

            bool requierePermiso = rdbPermisoSi.Checked;
            if (requierePermiso && string.IsNullOrEmpty(cboPermisoTipo.SelectedValue))
                throw new Exception("Si el procedimiento exige permiso de trabajo, indique de qué tipo.");

            Procedimiento x = new Procedimiento();
            ProcedimientoController c = new ProcedimientoController();

            x.prc_id = Id;
            x.prc_cliente = SitioBase.Session.ClienteId();
            x.prc_codigo = txtCodigo.Text.Trim();
            x.prc_nombre = txtNombre.Text.Trim();
            x.prc_habilitado = rdbSi.Checked;
            x.prc_requiere_permiso = requierePermiso;

            int version;
            x.prc_version = int.TryParse(txtVersion.Text.Trim(), out version) ? version : 1;

            int duracion;
            if (int.TryParse(txtDuracion.Text.Trim(), out duracion)) x.prc_duracion_estimada_minuto = duracion;

            if (!string.IsNullOrEmpty(cboTipo.SelectedValue))
                x.prc_activo_tipo = int.Parse(cboTipo.SelectedValue);
            else
                x.quita_tipo = true;   // al editar, dejarlo sin tipo

            if (requierePermiso && !string.IsNullOrEmpty(cboPermisoTipo.SelectedValue))
                x.prc_permiso_trabajo_tipo = int.Parse(cboPermisoTipo.SelectedValue);

            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.prc_descripcion = txtDescripcion.Text.Trim();

            Respuesta r = (Id > 0) ? c.UpdateProcedimiento(x) : c.InsertProcedimiento(x);

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
