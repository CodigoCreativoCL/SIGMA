using System;
using System.Text;
using System.Web;
using System.Web.UI;

namespace Tools
{

    public static class tools
    {
        #region Alerts
        public static void ClientAlert(string Message)
        {
            Page page = (Page)HttpContext.Current.Handler;
            Message = Message.Replace("\"", "");
            Message = Message.Replace("''", "'");
            Message = Message.Replace("''''", "'");
            Message = Message.Replace("\n", "");
            Message = Message.Replace("\r", "");
            RegisterScriptBlock(page, "alert" + DateTime.Now.ToString(), "alert(\"" + Message + "\");");
        }

        public static void ClientAlert(string mensaje, string tipo, bool cerrar = false, string nombreFuncion = "")
        {
            mensaje = mensaje.Replace("\"", "");
            mensaje = mensaje.Replace("''", "'");
            mensaje = mensaje.Replace("''''", "'");
            mensaje = mensaje.Replace("'", "");
            mensaje = mensaje.Replace("\n", "");
            mensaje = mensaje.Replace("\r", "");

            StringBuilder sb = new StringBuilder();

            sb.AppendLine("function ClientAlert(mensaje, tipo) {");

            sb.AppendLine("$(\"#myModal\").remove();");

            sb.AppendLine("var icono = '';");
            sb.AppendLine("var boton = '';");

            sb.AppendLine("switch (tipo) {");
            sb.AppendLine(" case \"error\":");
            sb.AppendLine("     icono = '<div class=\"sa\"><div class=\"sa-error\"><div class=\"sa-error-x\"><div class=\"sa-error-left\"></div><div class=\"sa-error-right\"></div></div><div class=\"sa-error-placeholder\"></div><div class=\"sa-error-fix\"></div></div></div>'");
            sb.AppendLine("     boton = '<button type=\"button\" class=\"ButtonSweetError\" onclick=\"CloseWindows()\">Aceptar</button>'");
            sb.AppendLine("     break;");
            sb.AppendLine(" case \"ok\":");
            sb.AppendLine("     icono = '<div class=\"sa\"><div class=\"sa-success\"><div class=\"sa-success-tip\"></div><div class=\"sa-success-long\"></div><div class=\"sa-success-placeholder\"></div><div class=\"sa-success-fix\"></div></div></div>'");
            sb.AppendLine("     boton = '<button type=\"button\" class=\"ButtonSweetOk\" onclick=\"CloseWindows()\">Aceptar</button>'");
            sb.AppendLine("     break;");
            sb.AppendLine("case \"alerta\":");
            sb.AppendLine("     icono = '<div class=\"sa\"><div class=\"sa-warning\"><div class=\"sa-warning-body\"></div><div class=\"sa-warning-dot\"></div></div></div>'");
            sb.AppendLine("     boton = '<button type=\"button\" class=\"ButtonSweetAlerta\" onclick=\"CloseWindows()\">Aceptar</button>'");
            sb.AppendLine("     break;");
            sb.AppendLine("}");

            sb.AppendLine("var modal = '';");

            sb.AppendLine("modal += '<div class=\"modal fade\" id=\"myModal\" role =\"dialog\" data-backdrop=\"static\" data-keyboard=\"false\" >';");
            sb.AppendLine("modal += '   <div class=\"modal-dialog\">';");
            sb.AppendLine("modal += '       <div class=\"modal-content\">';");
            sb.AppendLine("modal += '           <div class=\"modal-header\">';");
            sb.AppendLine("modal += '               ' + icono + ' ';");
            sb.AppendLine("modal += '               <h4 class=\"modal-title\"></h4>';");
            sb.AppendLine("modal += '           </div>';");
            sb.AppendLine("modal += '           <div class=\"modal-body\">';");
            sb.AppendLine("modal += '               <div>';");
            sb.AppendLine("modal += '                   <p>' + mensaje + '</p>';");
            sb.AppendLine("modal += '               </div>';");
            sb.AppendLine("modal += '           </div>';");
            sb.AppendLine("modal += '           <div class=\"modal-footer\">';");
            sb.AppendLine("modal += '               ' + boton + ' ';");
            sb.AppendLine("modal += '           </div>';");
            sb.AppendLine("modal += '       </div>'");
            sb.AppendLine("modal += '   </div>';");
            sb.AppendLine("modal += '</div>';");

            sb.AppendLine("$(\"body\").append(modal);");
            sb.AppendLine("$(\"#myModal\").modal();");

            sb.AppendLine("}");

            sb.AppendLine("function CloseWindows() {");
            if (cerrar) sb.AppendLine("if (window.closeWindow) window.closeWindow();");
            if (nombreFuncion != "") sb.AppendLine(nombreFuncion);
            sb.AppendLine("$('#myModal').modal('hide');");
            sb.AppendLine("}");

            Page page = (Page)HttpContext.Current.Handler;

            RegisterScriptBlock(page, "ClientAlert" + DateTime.Now.ToString(), sb.ToString());

            ClientExecute("ClientAlert('" + mensaje + "','" + tipo + "');");

        }

        #endregion

        public static void ClientClose()
        {
            Page page = (Page)HttpContext.Current.Handler;
            RegisterStartupScript(page, "close", "close();");
        }

        public static void ClientExecute(string Script)
        {
            Page page = (Page)HttpContext.Current.Handler;
            RegisterStartupScript(page, "execute" + DateTime.Now.ToString(), Script);
        }

        public static bool IsStartupScriptRegistered(string key)
        {
            Page page = (Page)HttpContext.Current.Handler;
            return page.ClientScript.IsStartupScriptRegistered(typeof(Page), key);
        }

        public static bool IsStartupScriptRegistered(System.Web.UI.Page Page, string key)
        {
            return Page.ClientScript.IsStartupScriptRegistered(typeof(Page), key);
        }

        public static bool IsClientScriptBlockRegistered(string key)
        {
            Page page = (Page)HttpContext.Current.Handler;
            return page.ClientScript.IsClientScriptBlockRegistered(typeof(Page), key);
        }

        public static bool IsClientScriptBlockRegistered(System.Web.UI.Page Page, string key)
        {
            return Page.ClientScript.IsClientScriptBlockRegistered(typeof(Page), key);
        }

        public static void RegisterStartupScript(string key, string Script)
        {
            Page page = (Page)HttpContext.Current.Handler;
            RegisterStartupScript(page, key, Script);
        }

        public static void RegisterStartupScript(System.Web.UI.Page Page, string key, string Script)
        {
            if (ScriptManager.GetCurrent(Page) != null)
            {
                ScriptManager.RegisterStartupScript(Page, typeof(Page), key, Script, true);
            }
            else
            {
                if (!Page.ClientScript.IsStartupScriptRegistered(typeof(Page), key))
                {
                    Page.ClientScript.RegisterStartupScript(typeof(Page), key, Script, true);
                }
            }

        }

        public static void RegisterScriptBlock(string key, string Script)
        {
            Page page = (Page)HttpContext.Current.Handler;
            RegisterScriptBlock(page, key, Script);
        }

        public static void RegisterScriptBlock(System.Web.UI.Page Page, string key, string Script)
        {
            if (ScriptManager.GetCurrent(Page) != null)
            {
                ScriptManager.RegisterClientScriptBlock(Page, typeof(Page), key, Script, true);
            }
            else
            {
                if (!Page.ClientScript.IsClientScriptBlockRegistered(typeof(Page), key))
                {
                    Page.ClientScript.RegisterClientScriptBlock(typeof(Page), key, Script, true);
                }
            }

        }

        public static void RegisterWebResource(Control Ctrl, string ResourceName)
        {
            string url = Ctrl.Page.ClientScript.GetWebResourceUrl(Ctrl.GetType(), ResourceName);
            string key = ResourceName.Replace(".", "_");

            if (ScriptManager.GetCurrent(Ctrl.Page) != null)
            {
                ScriptManager.RegisterClientScriptInclude(Ctrl.Page, Ctrl.Page.GetType(), key, url);
            }
            else
            {
                if (!Ctrl.Page.ClientScript.IsClientScriptIncludeRegistered(key))
                {
                    Ctrl.Page.ClientScript.RegisterClientScriptInclude(key, url);
                }
            }

        }

        public static void RegisterPostBackScript(Control ctrl)
        {
            RegisterPostBackScript(ctrl, "", "refresh");
        }

        public static void RegisterPostBackScript(Control ctrl, string argument, string scriptName)
        {
            if (scriptName.Length == 0)
            {
                throw new ArgumentException("Debe especificar un nombre para la función.");
            }

            StringBuilder sb = new StringBuilder();

            sb.AppendLine("function " + scriptName + "()");
            sb.AppendLine("{");
            sb.AppendLine(ctrl.Page.ClientScript.GetPostBackEventReference(ctrl, argument));
            sb.AppendLine("}");

            RegisterScriptBlock(ctrl.Page, DateTime.Now.ToString(), sb.ToString());

        }


    }

}

