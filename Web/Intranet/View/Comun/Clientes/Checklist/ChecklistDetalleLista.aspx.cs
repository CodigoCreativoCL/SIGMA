using System;

public partial class View_Comun_Clientes_Checklist_ChecklistDetalleLista : System.Web.UI.Page
{

    #region  Variables Globales
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

                    case "IdCheckListDetalle":
                        IdCheckListDetalle = Int32.Parse(array[1].ToString());
                        break;

                    case "IdChecklistLista":
                        IdChecklistLista = Int32.Parse(array[1].ToString());
                        break;
                }
            }
        }

        wucChecklistDetalleLista.IdCheckListDetalle = IdCheckListDetalle;
        wucChecklistDetalleLista.IdChecklistLista = IdChecklistLista;
    }


   
}