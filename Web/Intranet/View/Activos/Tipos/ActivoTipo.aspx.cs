using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un tipo de activo, en árbol (HU-030).
///
/// SEGURIDAD EN EL SERVIDOR
///   La escritura la habilita Token.Puede("CREAR EDITAR TIPOS ACTIVO"), no el
///   esconder el botón. Además, un tipo GLOBAL de SIGMA se abre en solo
///   lectura: el SP lo rechaza igual, pero avisar antes es más claro.
/// </summary>
public partial class View_Activos_Tipos_ActivoTipo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>Un tipo global de SIGMA no se puede editar desde el cliente.</summary>
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

    /// <summary>
    /// Llena el combo de tipo superior con los tipos del cliente y los
    /// globales. Al editar se excluye el propio registro. Los descendientes
    /// los rechaza igual UPD_ACTIVO_TIPO.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        if (ctrl.ID != "cboPadre") return;

        ActivoTipo filtro = new ActivoTipo();
        filtro.filtro_cliente = SitioBase.Session.ClienteId();
        filtro.filtro_habilitado = true;

        ActivoTipoController controller = new ActivoTipoController();
        List<ActivoTipo> lista = controller.GetActivoTipos(filtro);

        ctrl.Items.Add(new RadComboBoxItem("Sin tipo superior", ""));
        ctrl.AppendDataBoundItems = true;

        if (lista != null)
        {
            if (Id > 0) lista.RemoveAll(x => x.ati_id == Id);

            ctrl.DataSource = lista;
            ctrl.DataValueField = "ati_id";
            ctrl.DataTextField = "ruta";
            ctrl.DataBind();
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
            ActivoTipoController controller = new ActivoTipoController();
            ActivoTipo entidad = controller.GetActivoTipo(Id);

            EsGlobal = entidad.es_global;

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Activo_Tipo", entidad.ati_codigo);
            txtNombre.Text = entidad.ati_nombre;
            txtDescripcion.Text = entidad.ati_descripcion;
            if (entidad.ati_orden != null) txtOrden.Text = entidad.ati_orden.ToString();

            if (entidad.ati_activo_tipo_padre != null)
            {
                RadComboBoxItem item = cboPadre.FindItemByValue(entidad.ati_activo_tipo_padre.ToString());
                if (item != null) item.Selected = true;
            }

            rdbSi.Checked = entidad.ati_habilitado;
            rdbNo.Checked = !entidad.ati_habilitado;

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.ati_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.ati_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void Bloqueo()
    {
        // Global -> solo lectura, con el aviso. Si no, según el permiso.
        pnlGlobal.Visible = EsGlobal;
        bool puedeEditar = Token.Puede("CREAR EDITAR TIPOS ACTIVO") && !EsGlobal;

        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Activo_Tipo");
        txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        txtOrden.ReadOnly = !puedeEditar;
        cboPadre.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (EsGlobal)
                throw new Exception("Un tipo global de SIGMA no se puede editar.");

            ActivoTipo entidad = new ActivoTipo();
            ActivoTipoController controller = new ActivoTipoController();

            entidad.ati_id = Id;
            entidad.ati_cliente = SitioBase.Session.ClienteId();
            entidad.ati_codigo = SitioBase.CodigoModulo.Componer("Activo_Tipo", txtCodigo.Text);   // TIP-<id> lo genera el SP
            entidad.ati_nombre = txtNombre.Text.Trim();
            entidad.ati_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim()))
                entidad.ati_descripcion = txtDescripcion.Text.Trim();

            if (!string.IsNullOrEmpty(txtOrden.Text.Trim()))
            {
                int orden;
                if (!int.TryParse(txtOrden.Text.Trim(), out orden))
                    throw new Exception("El orden debe ser un número.");
                entidad.ati_orden = orden;
            }

            if (!string.IsNullOrEmpty(cboPadre.SelectedValue))
                entidad.ati_activo_tipo_padre = int.Parse(cboPadre.SelectedValue);
            else
                // Combo vacío al editar significa "súbelo al primer nivel",
                // no "no toques el padre". Sin esta bandera el SP conserva el
                // que ya tenía y el cambio se pierde en silencio.
                entidad.quita_padre = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateActivoTipo(entidad)
                : controller.InsertActivoTipo(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
