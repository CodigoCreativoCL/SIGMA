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
                    /* HU-017 #1: la lista viene ORDENADA por candidatura
                       (SEL_ORDEN_TRABAJO_CANDIDATO, bloque 251): primero quien
                       tiene todas las especialidades que la orden exige, con
                       su certificación vigente; después quien las tiene
                       vencidas; al final el resto. Cada fila dice sus
                       especialidades: la persona que se buscaba aparece
                       arriba y con su nombre completo de lo que sabe hacer. */
                    ctrl.Items.Add(new RadComboBoxItem("Sin técnico", ""));
                    System.Data.SqlClient.SqlCommand cmd = Conexion.GetCommand("SEL_ORDEN_TRABAJO_CANDIDATO");
                    try
                    {
                        cmd.Parameters.AddWithValue("@CLIENTE", cliente);
                        cmd.Parameters.AddWithValue("@ORDEN", Orden);
                        using (System.Data.SqlClient.SqlDataReader dr = cmd.ExecuteReader())
                        {
                            while (dr.Read())
                            {
                                string nombre = Convert.ToString(dr["USU_NOMBRE"]).Trim();
                                string perfiles = Convert.ToString(dr["PERFILES"]);
                                string especialidades = Convert.ToString(dr["ESPECIALIDADES"]);
                                bool candidato = Convert.ToInt32(dr["CANDIDATO"]) == 1;
                                string vencida = dr["CERTIFICACION_VENCIDA"] == DBNull.Value ? "" : Convert.ToString(dr["CERTIFICACION_VENCIDA"]);

                                if (candidato) nombre = (string.IsNullOrEmpty(vencida) ? "★ Candidato · " : "⚠ Candidato (certificación vencida) · ") + nombre;
                                if (!string.IsNullOrEmpty(especialidades)) nombre += "  ·  " + especialidades;
                                else if (!string.IsNullOrEmpty(perfiles)) nombre += "  ·  " + perfiles;
                                ctrl.Items.Add(new RadComboBoxItem(nombre, Convert.ToString(dr["USU_ID"])));
                            }
                        }
                    }
                    finally
                    {
                        cmd.Connection.Close();
                        cmd.Dispose();
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
