using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una plantilla de checklist / pauta de inspección (HU-090). El
/// código es único por cliente y no se cambia al editar. La escritura la
/// habilita Token.Puede("CREAR EDITAR PAUTAS"); el listado ya filtró por el
/// cliente en sesión (barrera multicliente).
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistPlantilla : System.Web.UI.Page
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

        if (ctrl.ID == "cboPlanta")
        {
            ctrl.Items.Add(new RadComboBoxItem("Todas las plantas", ""));
            ctrl.AppendDataBoundItems = true;
            ClienteInstalacionController c = new ClienteInstalacionController();
            ctrl.DataSource = c.GetClienteInstalaciones(new ClienteInstalacion { cin_cliente = cliente, filtro_habilitado = "1" });
            ctrl.DataValueField = "cin_id"; ctrl.DataTextField = "cin_nombre"; ctrl.DataBind();
        }
        else if (ctrl.ID == "cboAsignacion")
        {
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ChecklistAsignacionTipoController c = new ChecklistAsignacionTipoController();
            ctrl.DataSource = c.GetTipos();
            ctrl.DataValueField = "cat_id"; ctrl.DataTextField = "cat_nombre"; ctrl.DataBind();
        }
        else if (ctrl.ID == "cboActivoTipo")
        {
            ctrl.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
            ctrl.AppendDataBoundItems = true;
            ActivoTipoController c = new ActivoTipoController();
            ctrl.DataSource = c.GetActivoTipos(new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });
            ctrl.DataValueField = "ati_id"; ctrl.DataTextField = "ati_nombre"; ctrl.DataBind();
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
            ChecklistPlantillaController c = new ChecklistPlantillaController();
            ChecklistPlantilla x = c.GetChecklistPlantilla(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = x.cpl_codigo;
            txtNombre.Text = x.cpl_nombre;
            txtDescripcion.Text = x.cpl_descripcion;

            if (x.cpl_cliente_instalacion != null) SeleccionarCombo(cboPlanta, x.cpl_cliente_instalacion.Value);
            if (x.cpl_checklist_asignacion_tipo != null) SeleccionarCombo(cboAsignacion, x.cpl_checklist_asignacion_tipo.Value);
            if (x.cpl_activo_tipo != null) SeleccionarCombo(cboActivoTipo, x.cpl_activo_tipo.Value);

            rdbSi.Checked = x.cpl_habilitado;
            rdbNo.Checked = !x.cpl_habilitado;

            wucAuditoria.Mostrar(x.usuario_creacion_nombre, x.cpl_fecha_creacion,
                                 x.usuario_actualizacion_nombre, x.cpl_fecha_actualizacion);

            CargarEstructura();   // secciones + campos del borrador (si hay)
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    // ===== Campos del checklist (secciones + campos) =====

    private List<ChecklistItemTipo> _tipos;
    private List<ChecklistItemTipo> Tipos()
    {
        if (_tipos == null) _tipos = new ChecklistEstructuraController().GetItemTipos() ?? new List<ChecklistItemTipo>();
        return _tipos;
    }

    private List<UnidadMedida> _unidades;
    private List<UnidadMedida> Unidades()
    {
        if (_unidades == null) _unidades = new UnidadMedidaController().GetUnidades() ?? new List<UnidadMedida>();
        return _unidades;
    }

    /// <summary>&lt;option&gt; de los tipos de campo; marca el seleccionado.</summary>
    public string BuildTipoOptions(int selected)
    {
        StringBuilder sb = new StringBuilder();
        foreach (ChecklistItemTipo t in Tipos())
            sb.Append("<option value=\"").Append(t.cit_id).Append("\"")
              .Append(t.cit_id == selected ? " selected" : "").Append(">")
              .Append(Server.HtmlEncode(t.cit_nombre)).Append("</option>");
        return sb.ToString();
    }

    /// <summary>&lt;option&gt; de las unidades; marca la seleccionada.</summary>
    public string BuildUnidadOptions(int selected)
    {
        StringBuilder sb = new StringBuilder();
        foreach (UnidadMedida u in Unidades())
        {
            string txt = u.ume_nombre + (string.IsNullOrEmpty(u.ume_simbolo) ? "" : " (" + u.ume_simbolo + ")");
            sb.Append("<option value=\"").Append(u.ume_id).Append("\"")
              .Append(u.ume_id == selected ? " selected" : "").Append(">")
              .Append(Server.HtmlEncode(txt)).Append("</option>");
        }
        return sb.ToString();
    }

    /// <summary>Renderiza el borrador (secciones + campos) para que la ficha lo muestre y el POST lo devuelva.</summary>
    private void CargarEstructura()
    {
        ChecklistEstructuraController ec = new ChecklistEstructuraController();
        int version = ec.GetBorradorVersion(Id, SitioBase.Session.UsuarioId(), false); // solo lectura: no crea borrador vacío
        if (version <= 0) { litEstructura.Text = ""; return; }

        List<ChecklistSeccion> secciones = ec.GetSecciones(version);
        List<ChecklistItem> items = ec.GetItems(version);

        StringBuilder sb = new StringBuilder();
        foreach (ChecklistSeccion s in secciones)
        {
            sb.Append("<div class=\"cl-sec\" data-sid=\"").Append(s.sid).Append("\">")
              .Append("<div class=\"cl-sec-head\">")
              .Append("<input type=\"hidden\" name=\"sec_id\" value=\"").Append(s.sid).Append("\" />")
              .Append("<input type=\"text\" name=\"sec_nombre\" class=\"cl-sec-nombre\" value=\"")
              .Append(Server.HtmlEncode(s.cps_nombre)).Append("\" />")
              .Append("<a href=\"javascript:void(0)\" class=\"cl-x\" onclick=\"this.closest('.cl-sec').remove()\">✕ sección</a>")
              .Append("</div><div class=\"cl-items\">");

            foreach (ChecklistItem it in items)
            {
                if (it.seccion_sid != s.sid) continue;
                sb.Append("<div class=\"cl-item\">")
                  .Append("<input type=\"hidden\" name=\"itm_sec\" value=\"").Append(s.sid).Append("\" />")
                  .Append("<input type=\"text\" name=\"itm_nombre\" class=\"cl-itm-nombre\" value=\"")
                  .Append(Server.HtmlEncode(it.cpi_texto)).Append("\" />")
                  .Append("<select name=\"itm_tipo\" class=\"cl-itm-tipo\" onchange=\"clTipoChange(this)\">")
                  .Append(BuildTipoOptions(it.cpi_tipo)).Append("</select>")
                  .Append("<select name=\"itm_unidad\" class=\"cl-itm-unidad\"><option value=\"\">— unidad —</option>")
                  .Append(BuildUnidadOptions(it.cpi_unidad ?? 0)).Append("</select>")
                  .Append("<select name=\"itm_oblig\" class=\"cl-itm-oblig\"><option value=\"1\"")
                  .Append(it.cpi_obligatorio ? " selected" : "").Append(">Obligatorio</option><option value=\"0\"")
                  .Append(!it.cpi_obligatorio ? " selected" : "").Append(">Opcional</option></select>")
                  .Append("<a href=\"javascript:void(0)\" class=\"cl-x\" onclick=\"this.closest('.cl-item').remove()\">✕</a>")
                  .Append("</div>");
            }

            sb.Append("</div>")
              .Append("<a href=\"javascript:void(0)\" class=\"cl-add-item\" onclick=\"clAgregarCampo(this.closest('.cl-sec'))\">+ Agregar campo</a>")
              .Append("</div>");
        }
        litEstructura.Text = sb.ToString();
    }

    /// <summary>Lee las secciones/campos del POST y reemplaza la estructura del borrador.</summary>
    private void GuardarEstructuraDesdeForm(int plantilla)
    {
        if (plantilla <= 0) return;

        string[] secIds = Request.Form.GetValues("sec_id");
        string[] secNoms = Request.Form.GetValues("sec_nombre");

        List<ChecklistSeccion> secciones = new List<ChecklistSeccion>();
        Dictionary<string, ChecklistSeccion> map = new Dictionary<string, ChecklistSeccion>();
        if (secIds != null)
            for (int i = 0; i < secIds.Length; i++)
            {
                ChecklistSeccion s = new ChecklistSeccion();
                s.sid = secIds[i];
                s.cps_nombre = (secNoms != null && i < secNoms.Length) ? (secNoms[i] ?? "").Trim() : "";
                secciones.Add(s);
                if (!map.ContainsKey(s.sid)) map[s.sid] = s;
            }

        string[] itSec = Request.Form.GetValues("itm_sec");
        string[] itNom = Request.Form.GetValues("itm_nombre");
        string[] itTipo = Request.Form.GetValues("itm_tipo");
        string[] itUni = Request.Form.GetValues("itm_unidad");
        string[] itObl = Request.Form.GetValues("itm_oblig");

        if (itSec != null)
            for (int k = 0; k < itSec.Length; k++)
            {
                string sid = itSec[k];
                if (!map.ContainsKey(sid)) continue;
                string nombre = (itNom != null && k < itNom.Length) ? (itNom[k] ?? "").Trim() : "";
                if (nombre == "") continue;

                ChecklistItem it = new ChecklistItem();
                it.seccion_sid = sid;
                it.cpi_texto = nombre;
                int tipo; it.cpi_tipo = (itTipo != null && k < itTipo.Length && int.TryParse(itTipo[k], out tipo)) ? tipo : 1;
                int uni; if (itUni != null && k < itUni.Length && int.TryParse(itUni[k], out uni)) it.cpi_unidad = uni;
                it.cpi_obligatorio = !(itObl != null && k < itObl.Length && itObl[k] == "0");
                map[sid].items.Add(it);
            }

        new ChecklistEstructuraController().GuardarEstructura(plantilla, secciones);
    }

    private void SeleccionarCombo(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PAUTAS");

        // El código es la llave: no se edita una vez creado.
        txtCodigo.ReadOnly = !puedeEditar || Id > 0;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        cboAsignacion.ReadOnly = !puedeEditar;
        cboActivoTipo.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(txtCodigo.Text.Trim())) throw new Exception("Debe indicar el código.");
            if (string.IsNullOrEmpty(txtNombre.Text.Trim())) throw new Exception("Debe indicar el nombre.");

            ChecklistPlantilla x = new ChecklistPlantilla();
            ChecklistPlantillaController c = new ChecklistPlantillaController();

            x.cpl_id = Id;
            x.cpl_codigo = txtCodigo.Text.Trim();
            x.cpl_nombre = txtNombre.Text.Trim();
            x.cpl_habilitado = rdbSi.Checked;

            if (!string.IsNullOrEmpty(txtDescripcion.Text.Trim())) x.cpl_descripcion = txtDescripcion.Text.Trim();
            if (!string.IsNullOrEmpty(cboPlanta.SelectedValue)) x.cpl_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            if (!string.IsNullOrEmpty(cboAsignacion.SelectedValue)) x.cpl_checklist_asignacion_tipo = int.Parse(cboAsignacion.SelectedValue);
            if (!string.IsNullOrEmpty(cboActivoTipo.SelectedValue)) x.cpl_activo_tipo = int.Parse(cboActivoTipo.SelectedValue);

            Respuesta r = (Id > 0) ? c.UpdateChecklistPlantilla(x) : c.InsertChecklistPlantilla(x);

            if (!r.error)
            {
                Id = r.codigo;
                // Con la cabecera guardada (y su id) se persisten los campos del checklist.
                GuardarEstructuraDesdeForm(Id);
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
