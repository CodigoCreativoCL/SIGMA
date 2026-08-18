using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Facilityges.Model;
using Facilityges.Controller;

public partial class View_Comun_GetArchivo : System.Web.UI.Page
{
    public int idArchivo
    {
        get { return Convert.ToInt32(ViewState["idArchivo"]); }
        set { ViewState.Add("idArchivo", value); }
    }

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
                    case "idArchivo":
                        idArchivo = Int32.Parse(array[1].ToString());
                        break;                  
                }
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            ArchivoController archivoController = new ArchivoController();
            Archivo archivo = new Archivo();
            archivo.arc_id = idArchivo;
            archivo = archivoController.GetListsArchivoBinario(archivo);

            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.Charset = "";
            HttpContext.Current.Response.ContentType = archivo.arc_contenido;
            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + archivo.arc_nombre_archivo);
            HttpContext.Current.Response.BinaryWrite(archivo.archivoBinario.abi_archivo_binario);
            HttpContext.Current.ApplicationInstance.CompleteRequest();
            HttpContext.Current.Response.End();
        }
    }

    protected void Page_PreRenderComplete(object sender, EventArgs e)
    {
        Tools.tools.ClientExecute("window.close();");
    }
}