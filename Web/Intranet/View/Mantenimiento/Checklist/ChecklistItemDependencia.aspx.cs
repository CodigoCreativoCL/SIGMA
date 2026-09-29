using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una dependencia entre ítems (HU-092). Un ítem (dependiente) se
/// muestra/oculta/requiere/bloquea según cómo se respondió otro ítem (condición)
/// con un operador y un valor. Ambos de la misma pauta; un ítem no puede depender
/// de sí mismo (lo enforcea el SP). La escritura la habilita
/// Token.Puede("CREAR EDITAR DEPENDENCIAS"); el cliente va desde la sesión.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistItemDependencia : System.Web.UI.Page
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
        if (ctrl.ID != "cboItem" && ctrl.ID != "cboCondicion") return;

        ctrl.Items.Add(new RadComboBoxItem("Seleccione un ítem…", ""));
        var items = new ChecklistItemValidacionController().GetItems();
        if (items != null)
            foreach (ChecklistItemValidacion i in items)
            {
                string etiqueta = i.plantilla_nombre
                    + (string.IsNullOrEmpty(i.seccion_nombre) ? "" : " · " + i.seccion_nombre)
                    + " · " + i.item_texto + " (" + i.tipo_nombre + ")";
                ctrl.Items.Add(new RadComboBoxItem(etiqueta, i.item_id.ToString()));
            }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        ConfigurarCatalogos();
        CargarDatos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    /// <summary>Operador_Comparacion y Dependencia_Accion son catálogos fijos.</summary>
    private void ConfigurarCatalogos()
    {
        if (cboAccion.Items.Count == 0)
        {
            cboAccion.Items.Add(new RadComboBoxItem("Mostrar", "1"));
            cboAccion.Items.Add(new RadComboBoxItem("Ocultar", "2"));
            cboAccion.Items.Add(new RadComboBoxItem("Requerir", "3"));
            cboAccion.Items.Add(new RadComboBoxItem("Bloquear", "4"));
        }
        if (cboOperador.Items.Count == 0)
        {
            cboOperador.Items.Add(new RadComboBoxItem("Igual a", "1"));
            cboOperador.Items.Add(new RadComboBoxItem("Distinto de", "2"));
            cboOperador.Items.Add(new RadComboBoxItem("Mayor que", "3"));
            cboOperador.Items.Add(new RadComboBoxItem("Mayor o igual que", "4"));
            cboOperador.Items.Add(new RadComboBoxItem("Menor que", "5"));
            cboOperador.Items.Add(new RadComboBoxItem("Menor o igual que", "6"));
            cboOperador.Items.Add(new RadComboBoxItem("Entre", "7"));
            cboOperador.Items.Add(new RadComboBoxItem("Contiene", "8"));
        }
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ChecklistItemDependencia x = new ChecklistItemDependenciaController().GetDependencia(Id);
            if (x == null) { lblId.Text = "—"; return; }

            lblId.Text = Id.ToString();

            pnlItemNuevo.Visible = false;
            pnlItemEdita.Visible = true;
            litItem.Text = "<strong>" + Server.HtmlEncode(x.plantilla_nombre) + "</strong> · " + Server.HtmlEncode(x.item_texto);

            Seleccionar(cboAccion, x.accion_id);
            Seleccionar(cboCondicion, x.condicion_id);
            Seleccionar(cboOperador, x.operador_id);
            txtValor.Text = x.valor;
            rdbSi.Checked = x.habilitado; rdbNo.Checked = !x.habilitado;
        }
        else
        {
            lblId.Text = "Nuevo";
        }
    }

    private static void Seleccionar(RadComboBox2 combo, int id)
    {
        RadComboBoxItem item = combo.FindItemByValue(id.ToString());
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR DEPENDENCIAS");

        cboItem.ReadOnly = cboCondicion.ReadOnly = cboAccion.ReadOnly = cboOperador.ReadOnly = !puedeEditar;
        txtValor.ReadOnly = !puedeEditar;
        rdbSi.Enabled = rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0 && string.IsNullOrEmpty(cboItem.SelectedValue)) throw new Exception("Debe indicar el ítem dependiente.");
            if (string.IsNullOrEmpty(cboCondicion.SelectedValue)) throw new Exception("Debe indicar el ítem de condición.");
            if (string.IsNullOrEmpty(cboAccion.SelectedValue)) throw new Exception("Debe indicar la acción.");
            if (string.IsNullOrEmpty(cboOperador.SelectedValue)) throw new Exception("Debe indicar el operador.");

            ChecklistItemDependencia x = new ChecklistItemDependencia();
            ChecklistItemDependenciaController c = new ChecklistItemDependenciaController();

            x.cid_id = Id;
            if (Id == 0) x.item_id = int.Parse(cboItem.SelectedValue);
            x.condicion_id = int.Parse(cboCondicion.SelectedValue);
            x.accion_id = int.Parse(cboAccion.SelectedValue);
            x.operador_id = int.Parse(cboOperador.SelectedValue);
            x.valor = string.IsNullOrEmpty(txtValor.Text.Trim()) ? null : txtValor.Text.Trim();
            x.habilitado = rdbSi.Checked;

            Respuesta r = (Id > 0) ? c.UpdateDependencia(x) : c.InsertDependencia(x);

            if (!r.error) { Id = r.codigo; Tools.tools.ClientAlert(r.detalle, "ok", true); }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
