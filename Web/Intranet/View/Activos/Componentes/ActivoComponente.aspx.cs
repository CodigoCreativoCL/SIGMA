using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un componente de activo (HU-036). La escritura la habilita
/// Token.Puede("CREAR EDITAR COMPONENTES"); el activo no se cambia al editar.
/// </summary>
public partial class View_Activos_Componentes_ActivoComponente : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    // El componente superior a preseleccionar al ABRIR la ficha en edición.
    // Solo aplica en el primer render; después manda lo que elige el usuario.
    private string _padreEditar = null;

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
            case "cboActivo":
                {
                    ActivoController c = new ActivoController();
                    List<Activo> l = c.GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    if (l != null) foreach (Activo a in l)
                        ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
                    break;
                }
            case "cboTipo":
                {
                    ComponenteTipoController c = new ComponenteTipoController();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetTipos(new ComponenteTipo { filtro_cliente = cliente, filtro_habilitado = true });
                    ctrl.DataValueField = "cto_id"; ctrl.DataTextField = "cto_nombre"; ctrl.DataBind();
                    break;
                }
            case "cboEstado":
                {
                    ActivoComponenteEstadoController c = new ActivoComponenteEstadoController();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetEstados(new ActivoComponenteEstado { filtro_habilitado = true });
                    ctrl.DataValueField = "ace_id"; ctrl.DataTextField = "ace_nombre"; ctrl.DataBind();
                    break;
                }
            case "cboCriticidad":
                {
                    CriticidadNivelController c = new CriticidadNivelController();
                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetCriticidadNiveles(new CriticidadNivel { filtro_habilitado = true });
                    ctrl.DataValueField = "crn_id"; ctrl.DataTextField = "crn_nombre"; ctrl.DataBind();
                    break;
                }
            case "cboPosicion":
                {
                    ComponentePosicionController c = new ComponentePosicionController();
                    ctrl.Items.Add(new RadComboBoxItem("Sin posición", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = c.GetPosiciones(new ComponentePosicion { filtro_cliente = cliente, filtro_habilitado = true });
                    ctrl.DataValueField = "cpn_id"; ctrl.DataTextField = "cpn_nombre"; ctrl.DataBind();
                    break;
                }
        }
    }

    /// <summary>
    /// Recarga la ficha al cambiar el activo: el combo de componente superior
    /// solo debe ofrecer los del activo elegido (el SP rechaza uno de otro).
    /// </summary>
    protected void cboActivo_SelectedIndexChanged(object sender, EventArgs e)
    {
        // El trabajo lo hace Page_PreRender (CargarPadre lee el activo actual);
        // este handler existe para que el cambio dispare el postback.
    }

    /// <summary>
    /// Llena el combo de componente superior con los componentes DEL ACTIVO
    /// seleccionado, excluyendo el propio registro. Preserva la selección del
    /// usuario entre postbacks; al cambiar de activo, la opción vieja ya no
    /// está en la lista y queda deseleccionada sola.
    /// </summary>
    protected void CargarPadre()
    {
        string padreSel = string.IsNullOrEmpty(_padreEditar) ? cboPadre.SelectedValue : _padreEditar;

        cboPadre.Items.Clear();
        cboPadre.Items.Add(new RadComboBoxItem("Sin componente superior", ""));

        int activo;
        if (int.TryParse(cboActivo.SelectedValue, out activo) && activo > 0)
        {
            ActivoComponenteController c = new ActivoComponenteController();
            List<ActivoComponente> l = c.GetComponentes(new ActivoComponente
            {
                aco_cliente = SitioBase.Session.ClienteId(),
                filtro_activo = activo,
                filtro_habilitado = true
            });

            if (l != null)
            {
                if (Id > 0) l.RemoveAll(x => x.aco_id == Id);
                foreach (ActivoComponente a in l)
                    cboPadre.Items.Add(new RadComboBoxItem(a.aco_codigo + " — " + a.aco_nombre, a.aco_id.ToString()));
            }
        }

        RadComboBoxItem it = cboPadre.FindItemByValue(padreSel);
        if (it != null) it.Selected = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarPadre();   // depende del activo ya seleccionado por CargarDatos
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ActivoComponenteController c = new ActivoComponenteController();
            ActivoComponente x = c.GetComponente(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Activo_Componente", x.aco_codigo);
            txtNombre.Text = x.aco_nombre;
            txtDescripcion.Text = x.aco_descripcion;
            calInstalacion.Value = x.aco_fecha_instalacion;

            SeleccionarCombo(cboActivo, x.aco_activo);
            SeleccionarCombo(cboTipo, x.aco_componente_tipo);
            SeleccionarCombo(cboEstado, x.aco_activo_componente_estado);
            SeleccionarCombo(cboCriticidad, x.aco_criticidad_nivel);
            if (x.aco_componente_posicion != null) SeleccionarCombo(cboPosicion, x.aco_componente_posicion.Value);
            // El padre lo selecciona CargarPadre (que se llama después y ya
            // conoce el activo); aquí solo se guarda cuál preseleccionar.
            if (x.aco_componente_padre != null) _padreEditar = x.aco_componente_padre.Value.ToString();

            rdbSi.Checked = x.aco_habilitado;
            rdbNo.Checked = !x.aco_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.aco_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.aco_fecha_actualizacion);
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
        bool puedeEditar = Token.Puede("CREAR EDITAR COMPONENTES");

        cboActivo.ReadOnly = !puedeEditar || Id > 0;   // el activo no se cambia al editar
        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Activo_Componente");
        txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        calInstalacion.Enabled = puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        cboEstado.ReadOnly = !puedeEditar;
        cboCriticidad.ReadOnly = !puedeEditar;
        cboPosicion.ReadOnly = !puedeEditar;
        cboPadre.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboActivo.SelectedValue)) throw new Exception("Debe elegir el activo.");
            if (string.IsNullOrEmpty(cboTipo.SelectedValue)) throw new Exception("Debe elegir el tipo de componente.");
            if (string.IsNullOrEmpty(cboEstado.SelectedValue)) throw new Exception("Debe elegir el estado.");
            if (string.IsNullOrEmpty(cboCriticidad.SelectedValue)) throw new Exception("Debe elegir la criticidad.");

            ActivoComponente x = new ActivoComponente();
            ActivoComponenteController c = new ActivoComponenteController();

            x.aco_id = Id;
            x.aco_cliente = SitioBase.Session.ClienteId();
            x.aco_activo = int.Parse(cboActivo.SelectedValue);
            x.aco_componente_tipo = int.Parse(cboTipo.SelectedValue);
            x.aco_activo_componente_estado = int.Parse(cboEstado.SelectedValue);
            x.aco_criticidad_nivel = int.Parse(cboCriticidad.SelectedValue);
            x.aco_codigo = SitioBase.CodigoModulo.Componer("Activo_Componente", txtCodigo.Text);   // COM-<id> lo genera el SP
            x.aco_nombre = txtNombre.Text.Trim();
            x.aco_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboPosicion.SelectedValue)) x.aco_componente_posicion = int.Parse(cboPosicion.SelectedValue);
            if (!string.IsNullOrEmpty(cboPadre.SelectedValue)) x.aco_componente_padre = int.Parse(cboPadre.SelectedValue);
            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.aco_descripcion = txtDescripcion.Text.Trim();

            if (calInstalacion.Value != null && calInstalacion.Value.Value.Date > DateTime.Today)
                throw new Exception("La fecha de instalación no puede ser futura.");
            x.aco_fecha_instalacion = calInstalacion.Value;

            Respuesta r = (Id > 0) ? c.UpdateComponente(x) : c.InsertComponente(x);

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
