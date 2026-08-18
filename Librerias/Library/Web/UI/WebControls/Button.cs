using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Text;

namespace WebControls
{

    public class PushButton : System.Web.UI.WebControls.Button
    {
        
        public PushButton()
            : base()
        {

            this.WaitText = "";
            CssClass = "Button";
            this.UseSubmitBehavior = false;

        }

        public string WaitText
        {
            get
            {
                this.EnsureChildControls();
                return Convert.ToString(ViewState["WaitText"]);
            }
            set { ViewState["WaitText"] = value; }
        }

        protected override void CreateChildControls()
        {
            //base.CreateChildControls();

            //if (string.IsNullOrEmpty(this.WaitText))
            //{
            //    this.WaitText = this.Text;
            //}


            //if (!this.Page.ClientScript.IsClientScriptBlockRegistered("PushButton"))
            //{
            //    StringBuilder sb = new StringBuilder();

            //    sb.AppendLine("function clickOnce(btn, msg)");
            //    sb.AppendLine("{");
            //    sb.AppendLine("    // Comprobamos si se está haciendo una validación");
            //    sb.AppendLine("    if (typeof(Page_ClientValidate) == 'function') ");
            //    sb.AppendLine("    {");
            //    sb.AppendLine("       // Si se está haciendo una validación, volver si ésta da resultado false");
            //    sb.AppendLine("       if (!Page_ClientValidate()) { return false; }");
            //    sb.AppendLine("    }");

            //    sb.AppendLine("    // Asegurarse de que el botón sea del tipo button, nunca del tipo submit");
            //    sb.AppendLine("    if (btn.getAttribute('type') == 'button')");
            //    sb.AppendLine("    {");
            //    sb.AppendLine("        // El atributo msg es totalmente opcional. ");
            //    sb.AppendLine("        // Será el texto que muestre el botón mientras esté deshabilitado");
            //    sb.AppendLine("        if (!msg || (msg='undefined')) { msg = 'Procesando...'; }");

            //    sb.AppendLine("        btn.value = msg;");

            //    sb.AppendLine("        // La magia verdadera :D");
            //    sb.AppendLine("        btn.disabled = true;");
            //    sb.AppendLine("    }");

            //    sb.AppendLine("return true;");
            //    sb.AppendLine("}");

            //    this.Page.ClientScript.RegisterClientScriptBlock(this.GetType(), "PushButton", sb.ToString(), true);

            //}

            //if(this.CausesValidation)
            //    this.Attributes.Add("onclick", "clickOnce(this, '" + this.WaitText + "');");

        }

    }

}