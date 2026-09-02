using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un medidor de activo (HU-042).
///
/// SEGURIDAD EN EL SERVIDOR
///   La escritura la habilita Token.Puede("CREAR EDITAR MEDIDORES"), no el
///   esconder el botón: Bloqueo() pone en solo lectura los controles y oculta
///   Guardar cuando el usuario no tiene el permiso. El acceso a la ficha lo
///   resolvió ya el master con Token.ExigirPagina().
/// </summary>
public partial class View_Activos_Medidores_ActivoMedidor : System.Web.UI.Page
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

    /// <summary>
    /// Puebla los combos. El de activos y el de unidades se leen de su SEL_,
    /// no se escriben a mano en el markup.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboActivo":
                {
                    ActivoController controller = new ActivoController();
                    List<Activo> lista = controller.GetActivos(
                        new Activo { act_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;

                    if (lista != null)
                        foreach (Activo a in lista)
                            ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));

                    break;
                }

            case "cboUnidad":
                {
                    UnidadMedidaController controller = new UnidadMedidaController();
                    List<UnidadMedida> lista = controller.GetUnidades();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;

                    if (lista != null)
                        foreach (UnidadMedida u in lista)
                            ctrl.Items.Add(new RadComboBoxItem(u.ume_nombre + " (" + u.ume_simbolo + ")", u.ume_id.ToString()));

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
            ActivoMedidorController controller = new ActivoMedidorController();
            ActivoMedidor entidad = controller.GetActivoMedidor(Id);

            lblId.Text = Id.ToString();
            SeleccionarCombo(cboActivo, entidad.ame_activo);
            SeleccionarCombo(cboUnidad, entidad.ame_unidad_medida);
            txtCodigo.Text = entidad.ame_codigo;
            txtNombre.Text = entidad.ame_nombre;
            txtValorActual.Text = entidad.ame_valor_actual.ToString("0.##", CultureInfo.InvariantCulture);
            if (entidad.ame_valor_reinicio != null)
                txtValorReinicio.Text = entidad.ame_valor_reinicio.Value.ToString("0.##", CultureInfo.InvariantCulture);

            rdbReinicioSi.Checked = entidad.ame_permite_reinicio;
            rdbReinicioNo.Checked = !entidad.ame_permite_reinicio;

            rdbSi.Checked = entidad.ame_habilitado;
            rdbNo.Checked = !entidad.ame_habilitado;

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.ame_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.ame_fecha_actualizacion);
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
        bool puedeEditar = Token.Puede("CREAR EDITAR MEDIDORES");

        // El activo no se cambia al editar: el medidor pertenece a su máquina.
        cboActivo.ReadOnly = !puedeEditar || Id > 0;
        cboUnidad.ReadOnly = !puedeEditar;
        txtCodigo.ReadOnly = true;   // el código es automático (MED-<id>)
        txtNombre.ReadOnly = !puedeEditar;
        txtValorActual.ReadOnly = !puedeEditar;
        txtValorReinicio.ReadOnly = !puedeEditar;

        rdbReinicioSi.Enabled = puedeEditar;
        rdbReinicioNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboActivo.SelectedValue))
                throw new Exception("Debe elegir el activo al que pertenece el medidor.");
            if (string.IsNullOrEmpty(cboUnidad.SelectedValue))
                throw new Exception("Debe elegir la unidad de medida.");

            ActivoMedidor entidad = new ActivoMedidor();
            ActivoMedidorController controller = new ActivoMedidorController();

            entidad.ame_id = Id;
            entidad.ame_cliente = SitioBase.Session.ClienteId();
            entidad.ame_activo = int.Parse(cboActivo.SelectedValue);
            entidad.ame_unidad_medida = int.Parse(cboUnidad.SelectedValue);
            // Al crear se manda AUTO y el SP genera MED-<id> tras el INSERT;
            // al editar viaja el que ya tiene (no se regenera).
            entidad.ame_codigo = (Id > 0) ? txtCodigo.Text.Trim() : "AUTO";
            entidad.ame_nombre = txtNombre.Text.Trim();
            entidad.ame_valor_actual = LeerDecimal(txtValorActual.Text, "valor actual") ?? 0m;
            entidad.ame_valor_reinicio = LeerDecimal(txtValorReinicio.Text, "valor de reinicio");
            entidad.ame_permite_reinicio = rdbReinicioSi.Checked;
            entidad.ame_habilitado = rdbSi.Checked;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateActivoMedidor(entidad)
                : controller.InsertActivoMedidor(entidad);

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

    /// <summary>
    /// Lee un decimal opcional. Acepta coma o punto como separador decimal
    /// (es-CL escribe coma) y el punto de miles. Vacío devuelve null.
    /// </summary>
    private decimal? LeerDecimal(string texto, string campo)
    {
        texto = (texto ?? "").Trim();
        if (texto.Length == 0) return null;

        string limpio = texto.Replace(" ", "");
        if (limpio.Contains(",") && limpio.Contains("."))
            limpio = limpio.Replace(".", "").Replace(",", ".");
        else
            limpio = limpio.Replace(",", ".");

        decimal valor;
        if (!decimal.TryParse(limpio, NumberStyles.Number, CultureInfo.InvariantCulture, out valor))
            throw new Exception("El " + campo + " no es un número válido.");

        if (valor < 0)
            throw new Exception("El " + campo + " no puede ser negativo.");

        return valor;
    }
}
