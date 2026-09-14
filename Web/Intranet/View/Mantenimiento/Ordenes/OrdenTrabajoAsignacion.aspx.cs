using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Asignar una orden (HU-112). Un tecnico o una empresa externa, uno de los
/// dos; el SP decide el unico responsable, la advertencia de especialidad
/// y la notificacion. La orden viene cifrada en el query desde el centro.
/// </summary>
public partial class View_Mantenimiento_Ordenes_OrdenTrabajoAsignacion : System.Web.UI.Page
{
    public int Orden
    {
        get { return ViewState["Orden"] != null ? (int)ViewState["Orden"] : 0; }
        set { ViewState["Orden"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Orden = SitioBase.Querystring.Entero(Request.QueryString["query"], "Orden");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;
        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboUsuario":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Sin técnico", ""));
                    List<ClienteUsuario> usuarios = new ClienteUsuarioController().GetClienteUsuarios(
                        new ClienteUsuario { ucl_id_cliente = cliente, usu_habilitado = true, id_perfiles = "", filtro = "" });
                    if (usuarios != null)
                        foreach (ClienteUsuario u in usuarios)
                        {
                            string nombre = !string.IsNullOrEmpty(u.nombre_completo) ? u.nombre_completo.Trim() : (u.usu_nombres + " " + u.usu_apellido_paterno).Trim();
                            if (!string.IsNullOrEmpty(u.perfiles)) nombre += "  ·  " + u.perfiles;
                            ctrl.Items.Add(new RadComboBoxItem(nombre, u.usu_id.ToString()));
                        }
                    break;
                }
            case "cboProveedor":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Sin empresa externa", ""));
                    List<Proveedor> lista = new ProveedorController().GetProveedores(new Proveedor { filtro_habilitado = true, filtro_es_contratista = true });
                    if (lista != null) foreach (Proveedor p in lista) ctrl.Items.Add(new RadComboBoxItem(p.prv_razon_social, p.prv_id.ToString()));
                    break;
                }
            case "cboGrupo":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Sin grupo", ""));
                    List<GrupoTrabajo> grupos = new GrupoTrabajoController().GetGruposTrabajo(new GrupoTrabajo { gtr_cliente = cliente, filtro_habilitado = true });
                    if (grupos != null) foreach (GrupoTrabajo g in grupos) ctrl.Items.Add(new RadComboBoxItem(g.gtr_codigo + " — " + g.gtr_nombre, g.gtr_id.ToString()));
                    break;
                }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool puede = Token.Puede("CREAR ORDEN TRABAJO");
        btnGuardar.Visible = puede;
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            OrdenTrabajoAsignacion a = new OrdenTrabajoAsignacion { ota_orden_trabajo = Orden };
            if (!string.IsNullOrEmpty(cboUsuario.SelectedValue)) a.ota_usuario = int.Parse(cboUsuario.SelectedValue);
            if (!string.IsNullOrEmpty(cboProveedor.SelectedValue)) a.ota_proveedor = int.Parse(cboProveedor.SelectedValue);
            if (!string.IsNullOrEmpty(cboGrupo.SelectedValue)) a.ota_grupo_trabajo = int.Parse(cboGrupo.SelectedValue);
            a.ota_es_responsable = rdbRespSi.Checked;
            a.ota_observacion = string.IsNullOrEmpty(txtObservacion.Text.Trim()) ? null : txtObservacion.Text.Trim();

            Respuesta r = new OrdenTrabajoController().Asignar(a);
            if (!r.error) Tools.tools.ClientAlert(r.detalle, r.detalle.Contains("advertencia") ? "alerta" : "ok", true);
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex) { Tools.tools.ClientAlert(ex.Message, "alerta"); }
    }
}
