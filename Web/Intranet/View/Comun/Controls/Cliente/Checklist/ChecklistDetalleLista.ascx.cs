using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Checklist_ChecklistDetalleLista : System.Web.UI.UserControl
{
    private ChecklistDetalleObjeto checkListDetalleObjeto = new ChecklistDetalleObjeto();
    private ChecklistDetalleObjetoController checkListDetalleObjetoController = new ChecklistDetalleObjetoController();

    #region Variables Globales
    public int IdCheckListDetalle
    {
        get { return Convert.ToInt32(ViewState["IdCheckListDetalle"]); }
        set { ViewState.Add("IdCheckListDetalle", value); }
    }

    public int IdChecklistLista
    {
        get { return Convert.ToInt32(ViewState["IdChecklistLista"]); }
        set { ViewState.Add("IdChecklistLista", value); }
    }

    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }
    #endregion

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            #region query
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {

                    case "IdCheckListDetalle":
                        IdCheckListDetalle = Int32.Parse(array[1].ToString());
                        break;

                    case "IdChecklistLista":
                        IdChecklistLista = Int32.Parse(array[1].ToString());
                        break;

                    case "ReadOnly":
                        ReadOnly = bool.Parse(array[1].ToString());
                        break;
                }
            }
            #endregion
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();

    }

    protected void CargarDatos()
    {
        if (IdChecklistLista > 0)
        {
            checkListDetalleObjeto = new ChecklistDetalleObjeto();
            checkListDetalleObjeto.cdc_id = IdChecklistLista;

            checkListDetalleObjeto = checkListDetalleObjetoController.GetCheckListDetalleObjeto(checkListDetalleObjeto);

            txtValor.Text = checkListDetalleObjeto.cdc_orden.ToString();
            txtNombre.Text = checkListDetalleObjeto.cdc_nombre;
            txtValor.Enabled = true;
        }

        Bloqueo();

    }

    protected void btnGuardar_OnClick(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();

            checkListDetalleObjeto = new ChecklistDetalleObjeto();
            checkListDetalleObjeto.cdc_id = IdChecklistLista;
            checkListDetalleObjeto.cdc_id_checklist_detalle = IdCheckListDetalle;
            checkListDetalleObjeto.cdc_orden = int.Parse(txtValor.Text);
            checkListDetalleObjeto.cdc_nombre = txtNombre.Text;

            if (IdChecklistLista > 0)
                respuesta = checkListDetalleObjetoController.UpdateCheckListDetalleObjeto(checkListDetalleObjeto);
            else
                respuesta = checkListDetalleObjetoController.InsertCheckListDetalleObjeto(checkListDetalleObjeto);

            if (!respuesta.error)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
            Tools.tools.ClientExecute("closeWindow(); __doPostBack('', '');");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert("No es posible guardar el CheckList (" + ex.Message + ").", "error");
        }
    }


    protected void Bloqueo()
    {
        if (ReadOnly)
        {
            txtNombre.Enabled = false;
            txtValor.Enabled = false;
            btnGuardar.Visible = false;
        }
    }
}