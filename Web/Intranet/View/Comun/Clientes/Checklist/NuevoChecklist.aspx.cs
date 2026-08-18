using System;

public partial class View_Comun_Clientes_Checklist_NuevoChecklist : System.Web.UI.Page
{
    #region Variables Globales
    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public int IdChecklist
    {
        get { return Convert.ToInt32(ViewState["IdChecklist"]); }
        set { ViewState.Add("IdChecklist", value); }
    }


    #endregion

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            #region query
            //Recupero el query string
            string[] query = Tools.Crypto.Decrypt(Server.UrlDecode(Request.QueryString["query"].ToString())).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "IdChecklist":
                        IdChecklist = Int32.Parse(array[1].ToString());
                        break;
                    case "IdCliente":
                        IdCliente = Int32.Parse(array[1].ToString());
                        break;

                }

            }
            #endregion

        }

        if (IdChecklist != 0)
        {
           IdChecklist = IdChecklist;
        }
        else
        {
            IdChecklist = wucChecklistDetalle.IdChecklist;

        }

        wucChecklistDetalle.IdChecklist = IdChecklist;
        wucChecklistDetalle.IdCliente = IdCliente;
        wucChecklistDetalle.ReadOnly = false;
        wucChecklistDetalle.PanelVisible = true;
    }

}

