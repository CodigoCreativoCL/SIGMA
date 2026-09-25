using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una programacion de tarea (HU-102): «esta tarea, con esta
/// programacion, la hace este responsable o este grupo». Modal sobre el
/// centro de la tarea, que manda la tarea cifrada en el query y aqui queda
/// fija. Al editar tampoco se cambia la programacion: cambiarla es quitar
/// una y agregar otra, a la vista; lo que se edita es quien la hace.
/// </summary>
public partial class View_Mantenimiento_Tareas_TareaProgramacion : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    public int TareaId
    {
        get { return ViewState["Tarea"] != null ? (int)ViewState["Tarea"] : 0; }
        set { ViewState["Tarea"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');
            foreach (string arr in query)
            {
                string[] array = arr.Split('=');
                switch (array[0])
                {
                    case "Id": Id = Int32.Parse(array[1]); break;
                    case "Tarea": TareaId = Int32.Parse(array[1]); break;
                }
            }
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        if (!(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboTarea":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    List<Tarea> lista = new TareaController().GetTareas(new Tarea { tar_cliente = cliente, filtro_habilitado = true });
                    if (lista != null)
                        foreach (Tarea t in lista)
                            ctrl.Items.Add(new RadComboBoxItem(t.tar_codigo + " — " + t.tar_titulo, t.tar_id.ToString()));
                    break;
                }

            case "cboProgramacion":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    List<Programacion> lista = new ProgramacionController().GetProgramaciones(new Programacion { filtro_habilitado = true });
                    if (lista != null)
                        foreach (Programacion p in lista)
                        {
                            string texto = p.pro_nombre;
                            if (!string.IsNullOrEmpty(p.tipo_nombre)) texto += "  ·  " + p.tipo_nombre;
                            ctrl.Items.Add(new RadComboBoxItem(texto, p.pro_id.ToString()));
                        }
                    break;
                }

            case "cboResponsable":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Sin responsable", ""));
                    List<ClienteUsuario> usuarios = new ClienteUsuarioController().GetClienteUsuarios(
                        new ClienteUsuario { ucl_id_cliente = cliente, usu_habilitado = true, id_perfiles = "", filtro = "" });
                    if (usuarios != null)
                        foreach (ClienteUsuario u in usuarios)
                        {
                            string nombre = !string.IsNullOrEmpty(u.nombre_completo) ? u.nombre_completo.Trim()
                                          : (u.usu_nombres + " " + u.usu_apellido_paterno).Trim();
                            if (!string.IsNullOrEmpty(u.perfiles)) nombre += "  ·  " + u.perfiles;
                            ctrl.Items.Add(new RadComboBoxItem(nombre, u.usu_id.ToString()));
                        }
                    break;
                }

            case "cboGrupo":
                {
                    ctrl.Items.Add(new RadComboBoxItem("Sin grupo", ""));
                    List<GrupoTrabajo> grupos = new GrupoTrabajoController().GetGruposTrabajo(new GrupoTrabajo { gtr_cliente = cliente, filtro_habilitado = true });
                    if (grupos != null)
                        foreach (GrupoTrabajo g in grupos)
                            ctrl.Items.Add(new RadComboBoxItem(g.gtr_codigo + " — " + g.gtr_nombre, g.gtr_id.ToString()));
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
            TareaProgramacion p = new TareaController().GetTareaProgramacion(Id);
            lblId.Text = Id.ToString();
            Seleccionar(cboTarea, p.tpr_tarea.ToString());
            Seleccionar(cboProgramacion, p.tpr_programacion.ToString());
            if (p.tpr_usuario_responsable != null) Seleccionar(cboResponsable, p.tpr_usuario_responsable.Value.ToString());
            if (p.tpr_grupo_trabajo != null) Seleccionar(cboGrupo, p.tpr_grupo_trabajo.Value.ToString());
            rdbSi.Checked = p.tpr_habilitado;
            rdbNo.Checked = !p.tpr_habilitado;
        }
        else
        {
            lblId.Text = "Nueva";
            if (TareaId > 0) Seleccionar(cboTarea, TareaId.ToString());
        }
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR TAREAS");

        // Fijos con Enabled y no con ReadOnly: un RadComboBox ReadOnly no
        // renderiza sus items y validaControl se cae al recorrerlos.
        cboTarea.Enabled = !(Id > 0 || TareaId > 0);
        cboProgramacion.Enabled = Id == 0;
        cboTarea.ReadOnly = !puedeEditar;
        cboProgramacion.ReadOnly = !puedeEditar;
        cboResponsable.ReadOnly = !puedeEditar;
        cboGrupo.ReadOnly = !puedeEditar;
        rdbSi.Enabled = rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            TareaProgramacion p = new TareaProgramacion();
            p.tpr_id = Id;
            p.tpr_tarea = string.IsNullOrEmpty(cboTarea.SelectedValue) ? 0 : int.Parse(cboTarea.SelectedValue);
            p.tpr_programacion = string.IsNullOrEmpty(cboProgramacion.SelectedValue) ? 0 : int.Parse(cboProgramacion.SelectedValue);
            if (!string.IsNullOrEmpty(cboResponsable.SelectedValue)) p.tpr_usuario_responsable = int.Parse(cboResponsable.SelectedValue); else p.quita_responsable = true;
            if (!string.IsNullOrEmpty(cboGrupo.SelectedValue)) p.tpr_grupo_trabajo = int.Parse(cboGrupo.SelectedValue); else p.quita_grupo = true;
            p.tpr_habilitado = rdbSi.Checked;

            TareaController controller = new TareaController();
            Respuesta r = Id > 0 ? controller.UpdateTareaProgramacion(p) : controller.InsertTareaProgramacion(p);

            if (!r.error)
            {
                Id = r.codigo;
                Tools.tools.ClientAlert(r.detalle, "ok", true);
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}
