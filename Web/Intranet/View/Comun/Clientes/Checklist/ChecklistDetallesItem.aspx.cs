using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

public partial class View_Comun_Clientes_Checklist_ChecklistDetallesItem : System.Web.UI.Page
{
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

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {

                    case "IdChecklist":
                        IdChecklist = Int32.Parse(array[1].ToString());
                        break;

                    case "IdChecklistDetalle":
                        IdChecklistDetalle = Int32.Parse(array[1].ToString());
                        break;


                    case "ReadOnly":
                        ReadOnly = bool.Parse(array[1].ToString());
                        break;
                }
            }
            wucChecklistDetalleItem.IdChecklist = IdChecklist;
            wucChecklistDetalleItem.IdChecklistDetalle = IdChecklistDetalle;
        }
    }


}
