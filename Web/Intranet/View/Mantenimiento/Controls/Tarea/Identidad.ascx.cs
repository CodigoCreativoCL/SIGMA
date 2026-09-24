using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using SitioBase.Model;
using SitioBase.Controller;
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL TAB / SUB-FORMULARIO DE TAREA.
///
/// Aqui vive el CRUD real de la pantalla. Siempre los mismos metodos:
///
///   LoadControls()     -> puebla los combos (una sola vez, en !IsPostBack).
///   CargarDatos()      -> si IdTarea > 0 trae el registro y llena los controles.
///   Bloqueo()          -> aplica ReadOnly a cada control.
///   btnGuardar_Click() -> arma el Model desde los controles y llama Insert/Update.
///
/// PATRON (ver PATRON_MVC.md seccion 6):
///  - Nunca se llama a la BD desde aqui: siempre a traves del Controller.
///  - El "alta vs edicion" se decide con un solo if: IdTarea > 0.
///  - Todo va envuelto en try/catch que termina en Tools.tools.ClientAlert.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Mantenimiento_Controls_Tarea_Identidad : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    public int IdTarea
    {
        get { return ViewState["IdTarea"] == null ? 0 : (int)ViewState["IdTarea"]; }
        set { ViewState["IdTarea"] = value; }
    }

    #endregion

    #region CICLO DE VIDA

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();

        // Sin esta linea el boton Guardar NO dispara postback dentro del UpdatePanel.
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);

        udPanel.Update();
    }

    #endregion

    #region CARGA DE COMBOS

    /// <summary>
    /// Un unico metodo atiende a TODOS los combos del control.
    /// Se engancha desde el markup con OnLoad="LoadControls" y se
    /// desambigua con switch (ctrl.ID).
    ///
    /// El !IsPostBack es clave: sin el, el combo se recargaria en cada
    /// postback y perderia la seleccion del usuario.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                int cliente = SitioBase.Session.ClienteId();

                switch (ctrl.ID)
                {
                    case "cboTareaPrioridad":

                        TareaPrioridadController tareaPrioridadController = new TareaPrioridadController();
                        TareaPrioridad filtroTareaPrioridad = new TareaPrioridad { filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = tareaPrioridadController.GetTareaPrioridads(filtroTareaPrioridad);
                        ctrl.DataValueField = "tpa_id";   // debe existir en el Model
                        ctrl.DataTextField = "tpa_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboTareaCategoria":

                        TareaCategoriaController tareaCategoriaController = new TareaCategoriaController();
                        TareaCategoria filtroTareaCategoria = new TareaCategoria { filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = tareaCategoriaController.GetTareaCategorias(filtroTareaCategoria);
                        ctrl.DataValueField = "tca_id";   // debe existir en el Model
                        ctrl.DataTextField = "tca_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboClienteInstalacion":

                        ClienteInstalacionController clienteInstalacionController = new ClienteInstalacionController();
                        ClienteInstalacion filtroClienteInstalacion = new ClienteInstalacion { cin_cliente = cliente };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = clienteInstalacionController.GetClienteInstalaciones(filtroClienteInstalacion);
                        ctrl.DataValueField = "cin_id";   // debe existir en el Model
                        ctrl.DataTextField = "cin_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboInstalacionArea":

                        InstalacionAreaController instalacionAreaController = new InstalacionAreaController();
                        InstalacionArea filtroInstalacionArea = new InstalacionArea { iar_cliente = cliente, filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = instalacionAreaController.GetInstalacionAreas(filtroInstalacionArea);
                        ctrl.DataValueField = "iar_id";   // debe existir en el Model
                        ctrl.DataTextField = "iar_nombre";
                        ctrl.DataBind();
                        break;

                    case "cboActivo":

                        ActivoController activoController = new ActivoController();
                        Activo filtroActivo = new Activo { act_cliente = cliente, filtro_habilitado = true };

                        // El item vacio se agrega ANTES del DataBind
                        // y se conserva gracias a AppendDataBoundItems.
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataSource = activoController.GetActivos(filtroActivo);
                        ctrl.DataValueField = "act_id";   // debe existir en el Model
                        ctrl.DataTextField = "act_nombre";
                        ctrl.DataBind();
                        break;
                }
            }
        }
    }

    #endregion

    #region CARGA Y BLOQUEO

    /// <summary>
    /// Modo edicion -> trae el registro y llena los controles.
    /// Modo alta    -> limpia todo.
    /// </summary>
    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (IdTarea > 0)
        {
            TareaController tareaController = new TareaController();
            Tarea tarea = tareaController.GetTarea(new Tarea { tar_id = IdTarea });

            if (tarea == null) return;

            txtCodigo.Text = tarea.tar_codigo;
            txtTitulo.Text = tarea.tar_titulo;
            txtDescripcion.Text = tarea.tar_descripcion;
            cboTareaPrioridad.SelectedValue = tarea.tar_tarea_prioridad.ToString();
            cboTareaCategoria.SelectedValue = tarea.tar_tarea_categoria.ToString();
            cboClienteInstalacion.SelectedValue = tarea.tar_cliente_instalacion.ToString();
            cboInstalacionArea.SelectedValue = tarea.tar_instalacion_area.ToString();
            cboActivo.SelectedValue = tarea.tar_activo.ToString();
            txtDuracionEstimadaMinuto.Value = tarea.tar_duracion_estimada_minuto;
            chkRequiereEvidencia.Checked = tarea.tar_requiere_evidencia;
            chkHabilitado.Checked = tarea.tar_habilitado;
        }
        else
        {
            txtCodigo.Text = string.Empty;
            txtTitulo.Text = string.Empty;
            txtDescripcion.Text = string.Empty;
            cboTareaPrioridad.SelectedValue = "";
            cboTareaCategoria.SelectedValue = "";
            cboClienteInstalacion.SelectedValue = "";
            cboInstalacionArea.SelectedValue = "";
            cboActivo.SelectedValue = "";
            txtDuracionEstimadaMinuto.Value = null;
            chkRequiereEvidencia.Checked = false;
            chkHabilitado.Checked = true;
        }
    }

    /// <summary>
    /// Un unico lugar donde se aplica el modo consulta.
    /// ReadOnly en los controles del proyecto renderiza un span con el valor
    /// y oculta el input: no se puede editar ni por inspector.
    /// </summary>
    protected void Bloqueo()
    {
        txtCodigo.ReadOnly = ReadOnly;
        txtTitulo.ReadOnly = ReadOnly;
        txtDescripcion.ReadOnly = ReadOnly;
        cboTareaPrioridad.ReadOnly = ReadOnly;
        cboTareaCategoria.ReadOnly = ReadOnly;
        cboClienteInstalacion.ReadOnly = ReadOnly;
        cboInstalacionArea.ReadOnly = ReadOnly;
        cboActivo.ReadOnly = ReadOnly;
        txtDuracionEstimadaMinuto.ReadOnly = ReadOnly;

        chkRequiereEvidencia.Enabled = !ReadOnly;
        chkHabilitado.Enabled = !ReadOnly;

        btnGuardar.Visible = !ReadOnly;
    }

    #endregion

    #region GUARDAR

    /// <summary>
    /// Unico punto de escritura de la pantalla.
    /// Secuencia: armar Model -> validar -> Insert o Update -> avisar.
    /// </summary>
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            // 1. Armar el Model desde los controles.
            Tarea tarea = new Tarea();
            tarea.tar_id = IdTarea;
            tarea.tar_codigo = txtCodigo.Text.Trim();
            tarea.tar_titulo = txtTitulo.Text.Trim();
            tarea.tar_descripcion = txtDescripcion.Text.Trim();
            tarea.tar_tarea_prioridad = int.Parse(cboTareaPrioridad.SelectedValue);
            tarea.tar_tarea_categoria = string.IsNullOrEmpty(cboTareaCategoria.SelectedValue) ? 0 : int.Parse(cboTareaCategoria.SelectedValue);
            tarea.tar_cliente_instalacion = string.IsNullOrEmpty(cboClienteInstalacion.SelectedValue) ? 0 : int.Parse(cboClienteInstalacion.SelectedValue);
            tarea.tar_instalacion_area = string.IsNullOrEmpty(cboInstalacionArea.SelectedValue) ? 0 : int.Parse(cboInstalacionArea.SelectedValue);
            tarea.tar_activo = string.IsNullOrEmpty(cboActivo.SelectedValue) ? 0 : int.Parse(cboActivo.SelectedValue);
            tarea.tar_duracion_estimada_minuto = txtDuracionEstimadaMinuto.Value.HasValue ? (int)txtDuracionEstimadaMinuto.Value.Value : 0;
            tarea.tar_requiere_evidencia = chkRequiereEvidencia.Checked;
            tarea.tar_habilitado = chkHabilitado.Checked;

            // 2. Insert o Update segun el modo.
            TareaController tareaController = new TareaController();
            Respuesta respuesta;

            if (IdTarea > 0)
                respuesta = tareaController.UpdateTarea(tarea);
            else
                respuesta = tareaController.InsertTarea(tarea);

            // 3. Avisar. En el alta guardamos el id devuelto para que
            //    el siguiente Guardar sea un Update y no otro Insert.
            if (!respuesta.error)
            {
                IdTarea = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    #endregion
}
