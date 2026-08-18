using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Checklist_ChecklistDetalleItem : System.Web.UI.UserControl
{
    private Checklist checklist = new Checklist();
    private ChecklistController checklistController = new ChecklistController();

    private ChecklistDetalle checklistDetalle = new ChecklistDetalle();
    private ChecklistDetalleController checklistDetalleController = new ChecklistDetalleController();

    private ChecklistTipoObjeto checklistTipoObjeto = new ChecklistTipoObjeto();
    private ChecklistTipoObjetoController checklistTipoObjetoController = new ChecklistTipoObjetoController();

    #region Variables Globales
    public int IdChecklist
    {
        get { return Convert.ToInt32(ViewState["IdChecklist"]); }
        set { ViewState.Add("IdChecklist", value); }
    }


    public int IdChecklistDetalle
    {
        get { return Convert.ToInt32(ViewState["IdChecklistDetalle"]); }
        set { ViewState.Add("IdChecklistDetalle", value); }
    }

    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    #endregion

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            CargarDatos();
        }
    }

    public void LoadControls(object sender, System.EventArgs e)
    {
        if (!IsPostBack)
        {

            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {
                    case "cboObjeto":

                        ChecklistTipoObjeto checklistTipoObjeto = new ChecklistTipoObjeto();
                        ChecklistTipoObjetoController checklistTipoObjetoController = new ChecklistTipoObjetoController();

                        ctrl.AppendDataBoundItems = true;
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione Tipo de Campo", ""));
                        ctrl.DataSource = checklistTipoObjetoController.GetCheckListTipoObjetos(checklistTipoObjeto);
                        ctrl.DataValueField = "cho_id";
                        ctrl.DataTextField = "cho_nombre";

                        ctrl.DataBind();

                        break;
                }
            }
        }

    }

    protected void CargarDatos()
    {

        if (IdChecklistDetalle > 0)
        {
            checklistDetalle = new ChecklistDetalle();
            checklistDetalle.chd_id = IdChecklistDetalle;

            checklistDetalle = checklistDetalleController.GetCheckListDetalle(checklistDetalle);

            txtPregunta.Text = checklistDetalle.chd_pregunta;
            cboObjeto.SelectedValue = checklistDetalle.chd_objeto.ToString();
            cboObjeto.Enabled = true;


            rdbNotSi.Checked = checklistDetalle.chd_notificacion;
            rdbNotNo.Checked = !checklistDetalle.chd_notificacion;

            rdbSi.Checked = checklistDetalle.chd_habilitado;
            rdbNo.Checked = !checklistDetalle.chd_habilitado;

            rdbVSi.Checked = checklistDetalle.chd_valor_predeterminado;

            rdbVNo.Checked = !checklistDetalle.chd_valor_predeterminado;

            txtValor.Text = (checklistDetalle.chd_valor != null) ? checklistDetalle.chd_valor.ToString() : string.Empty;


        }

        Bloqueo();

    }


    protected void btnGuardar_OnClick(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();

            checklistDetalle = new ChecklistDetalle();
            checklistDetalle.chd_id = IdChecklistDetalle;
            checklistDetalle.chd_id_checklist = IdChecklist;
            checklistDetalle.chd_pregunta = txtPregunta.Text;
            checklistDetalle.chd_objeto = int.Parse(cboObjeto.SelectedValue);
            checklistDetalle.chd_habilitado = true;
            checklistDetalle.chd_valor = string.IsNullOrEmpty(txtValor.Text) ? null : txtValor.Text;

            checklistDetalle.chd_notificacion = rdbNotSi.Checked ? true : false;
            checklistDetalle.chd_valor_predeterminado = rdbVSi.Checked ? true : false;
            checklistDetalle.chd_habilitado = rdbSi.Checked;

            if (!(rdbSi.Checked || rdbNo.Checked))
            {
                Tools.tools.ClientAlert("Debe indicar SI/NO en habilitado (*)", "alerta");
                return;
            }

            if (IdChecklistDetalle > 0)
                respuesta = checklistDetalleController.UpdateCheckListDetalle(checklistDetalle);
            else
                respuesta = checklistDetalleController.InsertCheckListDetalle(checklistDetalle);

            if (!respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
            Tools.tools.ClientExecute("closeWindow();");


        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert("No es posible guardar el Detalle (" + ex.Message + ").");
        }
    }

    protected void Bloqueo()
    {
        if (ReadOnly)
        {
            txtPregunta.Enabled = false;
            txtValor.Enabled = false;
            cboObjeto.Enabled = false;
            rdbVSi.Enabled = false;
            rdbVNo.Enabled = false;
            rdbNotSi.Enabled = false;
            rdbNotNo.Enabled = false;
            btnGuardar.Visible = false;

        }
    }

}