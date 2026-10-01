using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de umbrales y acciones de un ítem (HU-091). Define, por ítem, qué
/// valores son normales (mínimo/advertencia/crítico/máximo, largo y expresión) y
/// qué ocurre fuera de rango (exigir comentario, exigir fotografía, generar
/// alerta, generar hallazgo). Hay una validación por ítem: al crear se elige el
/// ítem; al editar el ítem queda fijo. La escritura la habilita
/// Token.Puede("CREAR EDITAR VALIDACIONES"); el cliente va desde la sesión.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistItemValidacion : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>Al crear (desde el centro), acota el selector de ítem al borrador de la pauta.</summary>
    public int Version
    {
        get { return ViewState["Version"] != null ? (int)ViewState["Version"] : 0; }
        set { ViewState["Version"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
            Version = SitioBase.Querystring.Entero(Request.QueryString["query"], "Version");
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        if (ctrl.ID != "cboItem") return;

        ctrl.Items.Add(new RadComboBoxItem("Seleccione un ítem…", ""));
        var items = new ChecklistItemValidacionController().GetItems(Version);
        if (items != null)
            foreach (ChecklistItemValidacion i in items)
            {
                // Solo se ofrecen los ítems que aún no tienen validación.
                if (i.tiene_validacion) continue;
                string etiqueta = i.plantilla_nombre
                    + (string.IsNullOrEmpty(i.seccion_nombre) ? "" : " · " + i.seccion_nombre)
                    + " · " + i.item_texto + " (" + i.tipo_nombre + ")";
                ctrl.Items.Add(new RadComboBoxItem(etiqueta, i.item_id.ToString()));
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
            ChecklistItemValidacion x = new ChecklistItemValidacionController().GetValidacion(Id);
            if (x == null) { lblId.Text = "—"; return; }

            lblId.Text = Id.ToString();

            // El ítem queda fijo al editar.
            pnlItemNuevo.Visible = false;
            pnlItemEdita.Visible = true;
            litItem.Text = "<strong>" + Server.HtmlEncode(x.plantilla_nombre) + "</strong>"
                + (string.IsNullOrEmpty(x.seccion_nombre) ? "" : " · " + Server.HtmlEncode(x.seccion_nombre))
                + " · " + Server.HtmlEncode(x.item_texto) + " <span class=\"sigma-inv-vacio\">(" + Server.HtmlEncode(x.tipo_nombre) + ")</span>";

            txtMinimo.Text = Dec(x.valor_minimo);
            txtAdvertencia.Text = Dec(x.valor_advertencia);
            txtCritico.Text = Dec(x.valor_critico);
            txtMaximo.Text = Dec(x.valor_maximo);
            txtLargoMin.Text = x.largo_minimo == null ? "" : x.largo_minimo.ToString();
            txtLargoMax.Text = x.largo_maximo == null ? "" : x.largo_maximo.ToString();
            txtExpresion.Text = x.expresion_regular;
            chkComentario.Checked = x.requiere_comentario;
            chkEvidencia.Checked = x.requiere_evidencia;
            chkAlerta.Checked = x.genera_alerta;
            chkHallazgo.Checked = x.genera_hallazgo;
            txtMensaje.Text = x.mensaje;
            rdbSi.Checked = x.habilitado; rdbNo.Checked = !x.habilitado;
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR VALIDACIONES");

        cboItem.ReadOnly = !puedeEditar;
        txtMinimo.ReadOnly = txtAdvertencia.ReadOnly = txtCritico.ReadOnly = txtMaximo.ReadOnly = !puedeEditar;
        txtLargoMin.ReadOnly = txtLargoMax.ReadOnly = txtExpresion.ReadOnly = txtMensaje.ReadOnly = !puedeEditar;
        chkComentario.Enabled = chkEvidencia.Enabled = chkAlerta.Enabled = chkHallazgo.Enabled = puedeEditar;
        rdbSi.Enabled = rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            ChecklistItemValidacion x = new ChecklistItemValidacion();
            ChecklistItemValidacionController c = new ChecklistItemValidacionController();

            x.civ_id = Id;
            if (Id == 0)
            {
                if (string.IsNullOrEmpty(cboItem.SelectedValue)) throw new Exception("Debe indicar el ítem.");
                x.item_id = int.Parse(cboItem.SelectedValue);
            }

            x.valor_minimo = Parse(txtMinimo.Text);
            x.valor_advertencia = Parse(txtAdvertencia.Text);
            x.valor_critico = Parse(txtCritico.Text);
            x.valor_maximo = Parse(txtMaximo.Text);
            x.largo_minimo = ParseInt(txtLargoMin.Text);
            x.largo_maximo = ParseInt(txtLargoMax.Text);
            x.expresion_regular = string.IsNullOrEmpty(txtExpresion.Text.Trim()) ? null : txtExpresion.Text.Trim();
            x.requiere_comentario = chkComentario.Checked;
            x.requiere_evidencia = chkEvidencia.Checked;
            x.genera_alerta = chkAlerta.Checked;
            x.genera_hallazgo = chkHallazgo.Checked;
            x.mensaje = string.IsNullOrEmpty(txtMensaje.Text.Trim()) ? null : txtMensaje.Text.Trim();
            x.habilitado = rdbSi.Checked;

            Respuesta r = (Id > 0) ? c.UpdateValidacion(x) : c.InsertValidacion(x);

            if (!r.error) { Id = r.codigo; Tools.tools.ClientAlert(r.detalle, "ok", true); }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    private static string Dec(decimal? v)
    {
        return v == null ? "" : v.Value.ToString("0.######", CultureInfo.InvariantCulture);
    }

    /// <summary>Acepta coma o punto como separador decimal.</summary>
    private static decimal? Parse(string s)
    {
        s = (s ?? "").Trim().Replace(",", ".");
        if (s.Length == 0) return null;
        decimal d;
        if (!decimal.TryParse(s, NumberStyles.Number, CultureInfo.InvariantCulture, out d))
            throw new Exception("Los umbrales deben ser numéricos.");
        return d;
    }

    private static int? ParseInt(string s)
    {
        s = (s ?? "").Trim();
        if (s.Length == 0) return null;
        int n;
        if (!int.TryParse(s, out n)) throw new Exception("El largo debe ser un número entero.");
        return n;
    }
}
