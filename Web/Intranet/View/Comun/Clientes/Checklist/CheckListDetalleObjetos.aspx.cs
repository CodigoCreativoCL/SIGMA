using System;

public partial class View_Comun_Clientes_Checklist_CheckListDetalleObjetos : System.Web.UI.Page
{
 

    #region Variables Globales
    public int IdCheckListDetalle
    {
        get { return Convert.ToInt32(ViewState["IdCheckListDetalle"]); }
        set { ViewState.Add("IdCheckListDetalle", value); }
    }

    public int IdCheckList
    {
        get { return Convert.ToInt32(ViewState["IdCheckList"]); }
        set { ViewState.Add("IdCheckList", value); }
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

                    case "IdCheckList":
                        IdCheckList = Int32.Parse(array[1].ToString());
                        break;

                    case "IdCheckListDetalle":
                        IdCheckListDetalle = Int32.Parse(array[1].ToString());
                        break;
                }
            }
        }
    }

 
}
