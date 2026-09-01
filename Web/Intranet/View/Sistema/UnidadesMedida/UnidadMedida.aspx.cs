using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una unidad de medida (HU-040).
///
/// La escritura la habilita Token.Puede("CREAR EDITAR UNIDADES MEDIDA"), no
/// el esconder el botón. Es catálogo de plataforma: no hay cliente.
/// </summary>
public partial class View_Sistema_UnidadesMedida_UnidadMedida : System.Web.UI.Page
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

        switch (ctrl.ID)
        {
            case "cboMagnitud":
                {
                    MagnitudController controller = new MagnitudController();
                    List<Magnitud> lista = controller.GetMagnitudes();

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                    ctrl.AppendDataBoundItems = true;
                    ctrl.DataSource = lista;
                    ctrl.DataValueField = "mag_id";
                    ctrl.DataTextField = "mag_nombre";
                    ctrl.DataBind();
                    break;
                }

            case "cboBase":
                {
                    // Todas las unidades habilitadas; el SP valida que la base
                    // sea de la misma magnitud. Al editar se excluye la propia.
                    UnidadMedidaController controller = new UnidadMedidaController();
                    List<UnidadMedida> lista = controller.GetUnidades(
                        new UnidadMedida { filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Esta es la base", ""));
                    ctrl.AppendDataBoundItems = true;

                    if (lista != null)
                    {
                        if (Id > 0) lista.RemoveAll(x => x.ume_id == Id);
                        foreach (UnidadMedida u in lista)
                            ctrl.Items.Add(new RadComboBoxItem(
                                u.ume_codigo + " — " + u.ume_nombre + " (" + u.magnitud_nombre + ")",
                                u.ume_id.ToString()));
                    }
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
            UnidadMedidaController controller = new UnidadMedidaController();
            UnidadMedida u = controller.GetUnidad(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = u.ume_codigo;
            txtNombre.Text = u.ume_nombre;
            txtSimbolo.Text = u.ume_simbolo;
            txtFactor.Text = u.ume_factor.ToString("0.######", CultureInfo.InvariantCulture);
            txtOffset.Text = u.ume_offset.ToString("0.######", CultureInfo.InvariantCulture);

            SeleccionarCombo(cboMagnitud, u.ume_magnitud);
            if (u.ume_unidad_base != null) SeleccionarCombo(cboBase, u.ume_unidad_base.Value);

            rdbSi.Checked = u.ume_habilitado;
            rdbNo.Checked = !u.ume_habilitado;

            wucAuditoria.Mostrar(u.usuario_creacion_nombre, u.ume_fecha_creacion,
                                 u.usuario_actualizacion_nombre, u.ume_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
            txtFactor.Text = "1";
            txtOffset.Text = "0";
        }
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR UNIDADES MEDIDA");

        txtCodigo.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtSimbolo.ReadOnly = !puedeEditar;
        txtFactor.ReadOnly = !puedeEditar;
        txtOffset.ReadOnly = !puedeEditar;
        cboMagnitud.ReadOnly = !puedeEditar;
        cboBase.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboMagnitud.SelectedValue))
                throw new Exception("Debe elegir la magnitud.");

            UnidadMedida entidad = new UnidadMedida();
            UnidadMedidaController controller = new UnidadMedidaController();

            entidad.ume_id = Id;
            entidad.ume_magnitud = int.Parse(cboMagnitud.SelectedValue);
            entidad.ume_codigo = txtCodigo.Text.Trim();
            entidad.ume_nombre = txtNombre.Text.Trim();
            entidad.ume_simbolo = txtSimbolo.Text.Trim();
            entidad.ume_factor = LeerDecimal(txtFactor.Text, "factor") ?? 1m;
            entidad.ume_offset = LeerDecimal(txtOffset.Text, "offset") ?? 0m;
            entidad.ume_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(cboBase.SelectedValue))
                entidad.ume_unidad_base = int.Parse(cboBase.SelectedValue);
            else
                // Vacío al editar significa "esta es la base"; sin la bandera
                // el SP conservaría la base anterior.
                entidad.quita_base = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateUnidad(entidad)
                : controller.InsertUnidad(entidad);

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

    /// <summary>Lee un decimal; acepta coma o punto. Vacío devuelve null.</summary>
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

        return valor;
    }
}
