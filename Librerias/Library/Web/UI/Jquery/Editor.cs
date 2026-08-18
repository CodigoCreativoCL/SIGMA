using System;
using System.Linq;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;


namespace WebControls
{
    public class Editor : TextBox
    {
        public virtual bool ReadOnly
        {
            get
            {
                object objeto = ViewState["ReadOnly"];
                return objeto != null && Convert.ToBoolean(objeto);
            }
            set
            {
                ViewState["ReadOnly"] = value;
            }
        }

        public override string Text
        {
            get
            {
                return base.Text;
            }
            set
            {
                base.Text = value;
            }
        }

        public Editor() : base()
        {

        }

        protected override void OnPreRender(EventArgs e)
        {
            // Asegúrate de que el script se ejecute después de que la página se haya cargado
            if (!this.ReadOnly)
            {
                Script();
            }
        }

        protected void Script()
        {
            // Agregar referencias CSS al <head>
            if (!Page.ClientScript.IsClientScriptBlockRegistered("SunEditorCSS"))
            {
                HtmlLink cssLink = new HtmlLink();
                cssLink.Href = ResolveUrl("~/Js/SumEditor/suneditor.min.css");
                cssLink.Attributes["rel"] = "stylesheet";
                cssLink.Attributes["type"] = "text/css";
                this.Page.Header.Controls.Add(cssLink);
            }

            // Agregar referencias JS al body
            if (!Page.ClientScript.IsClientScriptBlockRegistered("JsEditorReferences"))
            {
                StringBuilder sbScript = new StringBuilder();
                sbScript.AppendLine("<script src=\"" + ResolveClientUrl("~/Js/SumEditor/es.js") + "\"></script>");
                sbScript.AppendLine("<script src=\"" + ResolveClientUrl("~/Js/SumEditor/suneditor.min.js") + "\"></script>");

                this.Page.ClientScript.RegisterStartupScript(this.GetType(), "JsEditorReferences", sbScript.ToString(), false);
            }

            // Script principal del editor
            StringBuilder sb = new StringBuilder();

            sb.AppendLine("var sunEditor;");
            sb.AppendLine("function initializeEditors() {");
            sb.AppendLine("    try {");
            sb.AppendLine("        var editorElement = document.getElementById('" + this.ClientID + "');");
            sb.AppendLine("        if (!editorElement) {");
            sb.AppendLine("            console.warn('Editor element no encontrado: " + this.ClientID + "');");
            sb.AppendLine("            return;");
            sb.AppendLine("        }");
            sb.AppendLine("");
            sb.AppendLine("        if (sunEditor) {");
            sb.AppendLine("            try { sunEditor.destroy(); } catch(e) {}");
            sb.AppendLine("            sunEditor = null;");
            sb.AppendLine("        }");
            sb.AppendLine("");
            sb.AppendLine("        sunEditor = SUNEDITOR.create(editorElement, {");
            sb.AppendLine("            buttonList: [");
            sb.AppendLine("                ['undo', 'redo'],");
            sb.AppendLine("                ['font', 'fontSize', 'formatBlock'],");
            sb.AppendLine("                ['bold', 'underline', 'italic'],");
            sb.AppendLine("                ['fontColor', 'hiliteColor'],");
            sb.AppendLine("                ['align', 'list', 'table'],");
            sb.AppendLine("                ['indent', 'outdent'],");
            sb.AppendLine("                ['link', 'image', 'video'],");
            sb.AppendLine("                ['fullScreen', 'codeView']");
            sb.AppendLine("            ],");
            sb.AppendLine("            strictMode: false,");
            sb.AppendLine("            attributesWhitelist: {");
            sb.AppendLine("                'all': 'style'");
            sb.AppendLine("            },");
            sb.AppendLine("            lang: SUNEDITOR_LANG['es']");
            sb.AppendLine("        });");
            sb.AppendLine("");
            sb.AppendLine("        sunEditor.onChange = function(contents) {");
            sb.AppendLine("            updateValue();");
            sb.AppendLine("        };");
            sb.AppendLine("");
            sb.AppendLine("        try {");
            sb.AppendLine("            var currentContent = editorElement.value || '';");
            sb.AppendLine("            if (currentContent.trim() !== '') {");
            sb.AppendLine("                try { currentContent = decodeURIComponent(currentContent); } catch(e) {}");
            sb.AppendLine("                sunEditor.setContents(currentContent);");
            sb.AppendLine("            }");
            sb.AppendLine("        } catch(e) {}");
            sb.AppendLine("    } catch(error) {");
            sb.AppendLine("        console.error('Error al inicializar el editor:', error);");
            sb.AppendLine("    }");
            sb.AppendLine("}");

            sb.AppendLine("function updateValue() {");
            sb.AppendLine("    if (sunEditor) {");
            sb.AppendLine("        var contenido = encodeURIComponent(sunEditor.getContents());");
            sb.AppendLine("        var plainText = decodeURIComponent(contenido).replace(/<[^>]*>/g, '').trim();");
            sb.AppendLine("        var hasContent = plainText.length > 0 || contenido.includes('<img') || contenido.includes('<video') || contenido.includes('iframe');");
            sb.AppendLine("        document.getElementById('" + this.ClientID + "').value = hasContent ? contenido : '';");
            sb.AppendLine("    }");
            sb.AppendLine("}");

            sb.AppendLine("function contieneTexto(html) {");
            sb.AppendLine("     return {");
            sb.AppendLine("         tieneTexto: (html.replace(/<[^>]*>/g, '').trim().length > 0),");
            sb.AppendLine("         tieneImagenes: (html.includes('<img') || /data:image\\/[^;]+;/.test(html)),");
            sb.AppendLine("         tieneImagenesBase64: /data:image\\/[^;]+;base64,/.test(html),");
            sb.AppendLine("         tieneVideo: /<(video|iframe)[^>]*>/.test(html),");
            sb.AppendLine("         tieneContenido: function() {");
            sb.AppendLine("             return this.tieneTexto || this.tieneImagenes || this.tieneVideo;");
            sb.AppendLine("         }");
            sb.AppendLine("     };");
            sb.AppendLine("}");

            sb.AppendLine("(function() {");
            sb.AppendLine("    function tryInit() {");
            sb.AppendLine("        var el = document.getElementById('" + this.ClientID + "');");
            sb.AppendLine("        if (el) initializeEditors();");
            sb.AppendLine("    }");

            sb.AppendLine("    if (document.readyState === 'complete') {");
            sb.AppendLine("        tryInit();");
            sb.AppendLine("    } else {");
            sb.AppendLine("        window.addEventListener('load', tryInit);");
            sb.AppendLine("    }");

            sb.AppendLine("    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {");
            sb.AppendLine("        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {");
            sb.AppendLine("            var el = document.getElementById('" + this.ClientID + "');");
            sb.AppendLine("            if (!el) return;");
            sb.AppendLine("            if (sunEditor) { try { sunEditor.destroy(); } catch(e) {} }");
            sb.AppendLine("            initializeEditors();");
            sb.AppendLine("        });");
            sb.AppendLine("    }");
            sb.AppendLine("})();");

            // Registrar script principal
            this.Page.ClientScript.RegisterStartupScript(this.GetType(), "JsEditor", sb.ToString(), true);
        }

         
        protected override void Render(HtmlTextWriter writer)
        {
            if (ReadOnly)
            {
                RenderReadOnlyContent(writer);
            }
            else
            {
                base.Render(writer);
            }
        }

        private void RenderReadOnlyContent(HtmlTextWriter writer)
        {
            writer.RenderBeginTag("div");

            writer.Write(base.Text);

            writer.RenderEndTag();
        }
    }
}