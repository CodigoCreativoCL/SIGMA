using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.UI;

namespace WebControls
{

    public class Modal : System.Web.UI.WebControls.PlaceHolder
    {
        //variable id Paciente
        //public virtual string url { get; set; }
        public virtual string titulo { get; set; }
        public virtual string idModal { get; set; }
              
        public Modal() : base()
        {
           
        }
        
        protected override void OnInit(EventArgs e)
        {
            crateModal(titulo, idModal);
        }

        protected void crateModal(string titulo, string id)
        {
            StringBuilder sb = new StringBuilder();
            
            sb.AppendLine("<div class='modal fade' tabindex='-1' data-backdrop='static' data-keyboard='false' role='dialog' id='" + id + "'>");
            sb.AppendLine("<div class='modal-dialog modal-lg' role='document'>");
            sb.AppendLine("<div class='modal-content'>");
            sb.AppendLine("<div class='modal-header'>");
            sb.AppendLine("<button id='" + id + "Close' type='button' class='close' data-dismiss='modal' aria-label='Close'>");
            sb.AppendLine("<span aria-hidden='true'>×</span>");
            sb.AppendLine("</button>");
            sb.AppendLine("<h3 class='modal-title'>");
            sb.AppendLine(titulo);
            sb.AppendLine("</h3>");
            sb.AppendLine("</div>");
            sb.AppendLine("<div class='modal-body'>");
            sb.AppendLine("<div class='embed-responsive embed-responsive-16by9'>");
            //sb.AppendLine("<iframe class='embed-responsive-item' src='" + url + "'></iframe>");
            sb.AppendLine("<iframe id='" + id + "Url' class='embed-responsive-item'></iframe>");
            sb.AppendLine("</div>");
            sb.AppendLine("</div>");
            sb.AppendLine("</div>");
            sb.AppendLine("</div>");
            sb.AppendLine("</div>");

            LiteralControl lc = new LiteralControl();
            lc.Text = sb.ToString();

            Controls.Add(lc);

        }
    }
}