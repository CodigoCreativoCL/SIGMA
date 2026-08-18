using SitioBase.Controller;
using SitioBase.Model;
using SitioBase.Model;
using System;
using System.Activities.Expressions;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Controls_Cliente_Checklist_ChecklistDetalle : System.Web.UI.UserControl
{
    #region Variables Globales

    public int IdChecklist
    {
        get { return Convert.ToInt32(ViewState["IdChecklist"]); }
        set { ViewState.Add("IdChecklist", value); }
    }



    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public bool PanelVisible
    {
        get { return Convert.ToBoolean(ViewState["PanelVisible"]); }
        set { ViewState.Add("PanelVisible", value); }
    }

    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }
    #endregion

    private Checklist checkList = new Checklist();
    private ChecklistController checklistController = new ChecklistController();

    private ChecklistDetalle checklistDetalle = new ChecklistDetalle();
    private ChecklistDetalleController checklistDetalleController = new ChecklistDetalleController();

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {

            Grid.AddSelectColumn();
            Grid.AddColumn("CHD_ID", "", Width: "5%", Align: HorizontalAlign.Left);
            Grid.AddColumn("CHD_ID", "ID", Width: "5%", Align: HorizontalAlign.Left);
            Grid.AddColumn("CHD_ORDEN", "ORDEN", Align: HorizontalAlign.Left);
            Grid.AddColumn("CHD_PREGUNTA", "NOMBRE", Align: HorizontalAlign.Left);
            Grid.AddColumn("CHD_VALOR_PREDETERMINADO", "VALOR PREDETERMINADO", Align: HorizontalAlign.Left);
            Grid.AddColumn("CHD_VALOR", "VALOR", Align: HorizontalAlign.Left);
            Grid.AddColumn("NOMBRETIPODATO", "TIPO DATO", Width: "10%");
            Grid.AddTemplateColumn("DATALLEOBJETO", "", "TIPO DE CAMPO", ItemPosition: HorizontalAlign.Left, Width: "10%");
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        //CargarDatos();

        if (pnlCheckListDetalle.Visible == true)
        {
            CargarGrid();
        }
        else pnlCheckListDetalle.Visible = false;
        CargarDatos();

    }


    protected void CargarDatos()
    {
        lblCliente.Text = IdCliente.ToString();
        if (IdChecklist > 0)
        {
            lblCliente.Text = IdCliente.ToString();

            checkList = new Checklist();
            checkList.chk_id = IdChecklist;
            checkList.chk_cliente = IdCliente;

            checkList = checklistController.GetChecklist(checkList);
            txtNombre.Text = checkList.chk_nombre;
            txtDescripcion.Text = checkList.chk_descripcion;

            if (checkList.chk_habilitado)
                rdbSi.Checked = true;
            else
                rdbNo.Checked = true;

            CargarGrid();

            pnlCheckListDetalle.Visible = true;
        }
        else
        {
            CargarGridVacia();
            pnlCheckListDetalle.Visible = false;
        }

        Bloqueo();

    }

    protected void CargarGrid()
    {
        checklistDetalle = new ChecklistDetalle();
        checklistDetalle.chd_id_checklist = IdChecklist;

        Grid.DataSource = checklistDetalleController.GetCheckListDetalles(checklistDetalle);
        Grid.DataBind();
    }

    protected void CargarGridVacia()
    {
        List<ChecklistDetalle> checklistDetalle = new List<ChecklistDetalle>();

        Grid.DataSource = checklistDetalle;
        Grid.DataBind();
    }


    protected void Grid_ItemDataBound(object sender, Telerik.Web.UI.GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            //Obtengo los valores del grid
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string chd_id = item.GetDataKeyValue("chd_id").ToString();
                string chd_id_checklist = item.GetDataKeyValue("chd_id_checklist").ToString();
                string chd_objeto = item.GetDataKeyValue("chd_objeto").ToString();

                int chd_orden = 0;
                if (item.GetDataKeyValue("chd_orden") != null)
                    chd_orden = int.Parse(item.GetDataKeyValue("chd_orden").ToString());

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdChecklistDetalle=" + chd_id + "&IdChecklist=" + chd_id_checklist));

                //Creo el link 
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkAnular" + chd_id;
                Editar.Text = "&nbsp";
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirBusqueda('" + query + "')");

                //Asigno el Link a la celda            
                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell CHD_ID = DataItem["CHD_ID"];
                CHD_ID.Controls.Add(Editar);

                // Creo caja texto para el orden
                RadNumericBox2 txtvalor = new RadNumericBox2();
                txtvalor.ID = "txtvalor" + chd_id;
                txtvalor.Value = chd_orden;
                txtvalor.Enabled = !ReadOnly;
                txtvalor.Attributes.Add("onblur", "registraOrden('" + txtvalor.ClientID + "','" + chd_id + "','" + chd_id_checklist + "')");

                TableCell orden = item["CHD_ORDEN"];
                orden.Controls.Add(txtvalor);

                string queryDetalleObjeto = Server.UrlEncode(Tools.Crypto.Encrypt("IdCheckListDetalle=" + chd_id + "&ReadOnly=" + ReadOnly));

                //creo el link del detalle del objeto
                HyperLink lnkAbrirDetalleObjeto = new HyperLink();
                lnkAbrirDetalleObjeto.ID = "lnkVer";
                lnkAbrirDetalleObjeto.Text = "&nbsp";
                lnkAbrirDetalleObjeto.CssClass = "icono_ver_Lupa";
                lnkAbrirDetalleObjeto.NavigateUrl = "javascript:void(0)";
                lnkAbrirDetalleObjeto.ToolTip = "Agregar ítems";
                lnkAbrirDetalleObjeto.Attributes.Add("onclick", "abrirDetalleObjeto('" + queryDetalleObjeto + "')");

                string NOMBREOBJETO = string.Empty;
                if (item.GetDataKeyValue("NOMBREOBJETO") != null)
                    NOMBREOBJETO = item.GetDataKeyValue("NOMBREOBJETO").ToString();

                Label lblObjeto = new Label();
                lblObjeto.ID = "lblObjeto";
                lblObjeto.Text = NOMBREOBJETO;

                //Asigno el Link a la celda            
                TableCell detalle_objeto = DataItem["DATALLEOBJETO"];
                detalle_objeto.Controls.Add(lblObjeto);
                detalle_objeto.Controls.Add(lnkAbrirDetalleObjeto);

                if (chd_objeto != "5")
                    lnkAbrirDetalleObjeto.Visible = false;


                string ValorPredeterminado = item["CHD_VALOR_PREDETERMINADO"].Text;

                // Verifica si el valor es "True" o "False" y lo convierte en "Sí" o "No"
                if (ValorPredeterminado != null && ValorPredeterminado.Trim().ToLower() == "true")
                {
                    item["CHD_VALOR_PREDETERMINADO"].Text = "Sí";
                }
                else
                {
                    item["CHD_VALOR_PREDETERMINADO"].Text = "No";
                }

            }
        }
    }

    protected void lnkEliminar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un Ítem.", "alerta");
            }
            else
            {
                Respuesta respuesta = new Respuesta();

                checkList = new Checklist();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int ID = Int32.Parse(value["chd_id"].ToString());

                    ChecklistDetalle checkListDetalle = new ChecklistDetalle();
                    checkListDetalle.chd_id = ID;

                    respuesta = checklistDetalleController.DeleteCheckListDetalle(checkListDetalle);
                }

                if (!respuesta.error)
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                }
                else
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                }
                CargarGrid();
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert("No es posible eliminar los ítems seleccionados (" + ex.Message + ")", "error", true);
        }
    }


    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta respuesta = new Respuesta();
            checkList.chk_id = IdChecklist;

            checkList.chk_cliente = IdCliente;

            checkList.chk_nombre = txtNombre.Text;
            checkList.chk_descripcion = txtDescripcion.Text;
            checkList.chk_habilitado = true;

            if (rdbSi.Checked)
            {
                checkList.chk_habilitado = true;
            }
            else
            {
                checkList.chk_habilitado = false;
            }
            if (!rdbSi.Checked && !rdbNo.Checked)
            {
                Tools.tools.ClientAlert("Debe indicar SI/NO en habilitado (*)", "alerta");
                return;
            }


            if (IdChecklist > 0)
            {
                respuesta = checklistController.UpdateChecklist(checkList);
                pnlCheckListDetalle.Visible = true;
                CargarGrid();
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }
            else
            {
                respuesta = checklistController.InsertChecklist(checkList);

                Tools.tools.ClientAlert(respuesta.detalle, "ok");
                IdChecklist = respuesta.codigo;

                pnlCheckListDetalle.Visible = true;
                CargarGridVacia();

            }

        }

        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    protected void lnkAñadir_Click(object sender, EventArgs e)
    {

        string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdChecklist=" + IdChecklist + "&ReadOnly" + ReadOnly));

        Tools.tools.ClientExecute("abrirBusqueda('" + query + "')");


    }

    protected void Bloqueo()
    {
        if (ReadOnly)
        {
            txtNombre.Enabled = false;
            txtDescripcion.Enabled = false;
            rdbSi.Enabled = false;
            rdbNo.Enabled = false;
            btnGuardar.Visible = false;
            btnCerrar.Visible = false;

            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;
            Grid.DataBind();
        }
    }

}