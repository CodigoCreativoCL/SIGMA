using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una programación recurrente de pauta (HU-094). Enlaza una pauta
/// (con versión publicada) + una recurrencia + un objetivo (activo o área). La
/// regla activo-o-área la enforcea el SP; aquí también se avisa antes. La
/// escritura la habilita Token.Puede("CREAR EDITAR PAUTAS") y el listado ya
/// filtró por el cliente en sesión.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistProgramacion : System.Web.UI.Page
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

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        if (ctrl.ID == "cboPauta")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            var lista = new ChecklistVersionController().GetPublicadas(cliente);
            if (lista != null)
                foreach (ChecklistVersion v in lista)
                    ctrl.Items.Add(new RadComboBoxItem(v.plantilla_codigo + " · " + v.plantilla_nombre + " (v" + v.cpv_numero + ")", v.cpv_checklist_plantilla.ToString()));
        }
        else if (ctrl.ID == "cboRecurrencia")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            var lista = new ProgramacionController().GetProgramaciones(new Programacion { filtro_habilitado = true });
            if (lista != null)
                foreach (Programacion p in lista)
                    ctrl.Items.Add(new RadComboBoxItem(p.pro_nombre, p.pro_id.ToString()));
        }
        else if (ctrl.ID == "cboActivo")
        {
            ctrl.Items.Add(new RadComboBoxItem("— Sin activo —", ""));
            var lista = new ActivoController().GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
            if (lista != null)
                foreach (Activo a in lista)
                    ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " · " + a.act_nombre, a.act_id.ToString()));
        }
        else if (ctrl.ID == "cboArea")
        {
            ctrl.Items.Add(new RadComboBoxItem("— Sin área —", ""));
            var lista = new InstalacionAreaController().GetInstalacionAreas(new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true });
            if (lista != null)
                foreach (InstalacionArea a in lista)
                    ctrl.Items.Add(new RadComboBoxItem(a.iar_nombre, a.iar_id.ToString()));
        }
        else if (ctrl.ID == "cboGrupo")
        {
            ctrl.Items.Add(new RadComboBoxItem("— Sin grupo —", ""));
            var lista = new GrupoTrabajoController().GetGruposTrabajo(new GrupoTrabajo { gtr_cliente = cliente, filtro_habilitado = true });
            if (lista != null)
                foreach (GrupoTrabajo g in lista)
                    ctrl.Items.Add(new RadComboBoxItem(g.gtr_nombre, g.gtr_id.ToString()));
        }
        else if (ctrl.ID == "cboResponsable")
        {
            ctrl.Items.Add(new RadComboBoxItem("— Sin responsable —", ""));
            var lista = new ClienteUsuarioController().GetClienteUsuarios(new ClienteUsuario { ucl_id_cliente = cliente, usu_habilitado = true });
            if (lista != null)
                foreach (ClienteUsuario u in lista)
                    ctrl.Items.Add(new RadComboBoxItem((u.usu_nombres + " " + u.usu_apellido_paterno).Trim(), u.usu_id.ToString()));
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
            ChecklistProgramacion x = new ChecklistProgramacionController().GetProgramacion(Id);
            lblId.Text = Id.ToString();
            txtNombre.Text = x.cpr_nombre;

            SeleccionarCombo(cboPauta, x.cpr_checklist_plantilla);
            SeleccionarCombo(cboRecurrencia, x.cpr_programacion);
            if (x.cpr_activo != null) SeleccionarCombo(cboActivo, x.cpr_activo.Value);
            if (x.cpr_instalacion_area != null) SeleccionarCombo(cboArea, x.cpr_instalacion_area.Value);
            if (x.cpr_grupo_trabajo != null) SeleccionarCombo(cboGrupo, x.cpr_grupo_trabajo.Value);
            if (x.cpr_usuario_responsable != null) SeleccionarCombo(cboResponsable, x.cpr_usuario_responsable.Value);

            rdbSi.Checked = x.cpr_habilitado; rdbNo.Checked = !x.cpr_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.cpr_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.cpr_fecha_actualizacion);
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
        bool puedeEditar = Token.Puede("CREAR EDITAR PAUTAS");

        txtNombre.ReadOnly = !puedeEditar;
        cboPauta.ReadOnly = !puedeEditar;
        cboRecurrencia.ReadOnly = !puedeEditar;
        cboActivo.ReadOnly = !puedeEditar;
        cboArea.ReadOnly = !puedeEditar;
        cboGrupo.ReadOnly = !puedeEditar;
        cboResponsable.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el nombre.");
            if (string.IsNullOrEmpty(cboPauta.SelectedValue)) throw new Exception("Debe indicar la pauta.");
            if (string.IsNullOrEmpty(cboRecurrencia.SelectedValue)) throw new Exception("Debe indicar la recurrencia.");

            bool hayActivo = !string.IsNullOrEmpty(cboActivo.SelectedValue);
            bool hayArea = !string.IsNullOrEmpty(cboArea.SelectedValue);
            if (!hayActivo && !hayArea) throw new Exception("Indique un objetivo: un activo o un área.");

            ChecklistProgramacion x = new ChecklistProgramacion();
            ChecklistProgramacionController c = new ChecklistProgramacionController();

            x.cpr_id = Id;
            x.cpr_nombre = txtNombre.Text.Trim();
            x.cpr_checklist_plantilla = int.Parse(cboPauta.SelectedValue);
            x.cpr_programacion = int.Parse(cboRecurrencia.SelectedValue);
            x.cpr_habilitado = rdbSi.Checked;
            if (hayActivo) x.cpr_activo = int.Parse(cboActivo.SelectedValue);
            if (hayArea) x.cpr_instalacion_area = int.Parse(cboArea.SelectedValue);
            if (!string.IsNullOrEmpty(cboGrupo.SelectedValue)) x.cpr_grupo_trabajo = int.Parse(cboGrupo.SelectedValue);
            if (!string.IsNullOrEmpty(cboResponsable.SelectedValue)) x.cpr_usuario_responsable = int.Parse(cboResponsable.SelectedValue);

            Respuesta r = (Id > 0) ? c.UpdateProgramacion(x) : c.InsertProgramacion(x);

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
