using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace WebControls
{
    public class FileUpload2 : FileUpload
    {
        public string AllowExtensions
        {
            get { return ViewState["AllowExtensions"] as string ?? ""; }
            set { ViewState["AllowExtensions"] = value; }
        }

        public virtual bool ReadOnly
        {
            get { return ViewState["ReadOnly"] as bool? ?? false; }
            set { ViewState["ReadOnly"] = value; }
        }

        public FileUpload2()
        {
            CssClass = "file-input";
        }

        protected override void CreateChildControls()
        {
            if (!Page.ClientScript.IsClientScriptBlockRegistered("FgFileUpload2Style"))
            {
                StringBuilder style = new StringBuilder();
                style.AppendLine("<style>");
                style.AppendLine(".fg-drop-zone { border: 2px dashed var(--fg-m3-outline, #c0c4cc); border-radius: 8px; background: var(--fg-m3-surface, #f9fafb); padding: 10px 14px; cursor: pointer; transition: border-color 180ms, background 180ms; display: flex; flex-direction: row; align-items: center; gap: 10px; }");
                style.AppendLine(".fg-drop-zone:hover:not(.disabled), .fg-drop-zone.dragover { border-color: var(--fg-m3-primary, #2563eb); background: var(--fg-m3-primary-container, #eff6ff); }");
                style.AppendLine(".fg-drop-zone.disabled { cursor: not-allowed; opacity: 0.55; pointer-events: none; }");
                style.AppendLine(".fg-drop-zone .fg-dz-icon { font-size: 18px; color: var(--fg-m3-primary, #2563eb); flex-shrink: 0; pointer-events: none; }");
                style.AppendLine(".fg-drop-zone .fg-dz-msg { flex: 1; font-size: 13px; color: #4b5563; pointer-events: none; }");
                style.AppendLine(".fg-dz-btn { flex-shrink: 0; background: var(--fg-m3-primary, #2563eb); color: #fff; padding: 6px 16px; border-radius: 6px; font-size: 12px; font-weight: 600; transition: opacity 150ms; cursor: pointer; white-space: nowrap; }");
                style.AppendLine(".fg-drop-zone:hover:not(.disabled) .fg-dz-btn { opacity: .88; }");
                style.AppendLine(".fg-drop-zone.disabled .fg-dz-btn { background: #9ca3af; cursor: not-allowed; }");
                style.AppendLine(".fg-file-list2 { margin-top: 8px; padding: 0; list-style: none; display: flex; flex-wrap: wrap; gap: 6px; }");
                style.AppendLine(".fg-file-list2-label { font-size: 10px; color: #9ca3af; font-weight: 700; margin: 6px 0 4px 0; text-transform: uppercase; letter-spacing: .8px; }");
                style.AppendLine(".fg-file-list2 li { display: inline-flex; align-items: center; gap: 5px; background: var(--fg-m3-primary-container, #eff6ff); padding: 4px 10px 4px 8px; border-radius: 20px; border: 1px solid var(--fg-m3-outline-variant, #dbeafe); }");
                style.AppendLine(".fg-file-list2 .fg-fi-icon { color: var(--fg-m3-primary, #2563eb); font-size: 12px; flex-shrink: 0; }");
                style.AppendLine(".fg-file-list2 .fg-fi-name { font-size: 12px; color: #1d4ed8; max-width: 180px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }");
                style.AppendLine(".fg-file-list2 .fg-fi-remove { cursor: pointer; color: var(--fg-m3-primary, #2563eb); font-size: 14px; margin-left: 2px; transition: color 150ms; flex-shrink: 0; line-height: 1; opacity: .7; }");
                style.AppendLine(".fg-file-list2 .fg-fi-remove:hover { color: var(--fg-m3-error, #dc2626); opacity: 1; }");
                style.AppendLine("</style>");
                Page.ClientScript.RegisterClientScriptBlock(this.GetType(), "FgFileUpload2Style", style.ToString());
            }

            string cid = this.ClientID;
            string initFn = "fgInitUpload_" + cid;

            string extListRaw = (this.AllowExtensions ?? "").Trim();
            string extList = string.IsNullOrEmpty(extListRaw) ? "" : string.Join(",", extListRaw.Split(',')).ToLower().Replace(" ", "");
            string allowMultiple = this.AllowMultiple ? "true" : "false";

            StringBuilder js = new StringBuilder();

            js.AppendLine("var fgFiles_" + cid + " = [];");
            js.AppendLine("var fgExts_" + cid + " = '" + extList + "'.split(',');");
            js.AppendLine("var fgMulti_" + cid + " = " + allowMultiple + ";");

            js.AppendLine("function fgGetExt_" + cid + "(n) { var p = n.split('.'); return p.length > 1 ? p.pop().toLowerCase() : ''; }");

            js.AppendLine("function fgValidExt_" + cid + "(f) {");
            js.AppendLine("  var ext = fgGetExt_" + cid + "(f.name);");
            js.AppendLine("  if (!fgExts_" + cid + " || (fgExts_" + cid + ".length === 1 && fgExts_" + cid + "[0] === '')) return true;");
            js.AppendLine("  if (fgExts_" + cid + ".indexOf(ext) === -1) { AlertSweet('Extensión inválida', 'Solo se permiten: ' + fgExts_" + cid + ".join(', '), 'error'); return false; }");
            js.AppendLine("  return true;");
            js.AppendLine("}");

            js.AppendLine("function fgExists_" + cid + "(f) { return fgFiles_" + cid + ".some(function(x){ return x.name===f.name && x.size===f.size; }); }");

            js.AppendLine("function " + initFn + "() {");
            js.AppendLine("  var $zone = $('#fgDropZone_" + cid + "');");
            js.AppendLine("  var $inp  = $('#" + cid + "');");
            js.AppendLine("  var $list = $('#fgFileList_" + cid + "');");

            js.AppendLine("  function render() {");
            js.AppendLine("    $list.empty();");
            js.AppendLine("    var dt = new DataTransfer();");
            js.AppendLine("    if (fgFiles_" + cid + ".length > 0) { $('#fgFileListLabel_" + cid + "').show(); } else { $('#fgFileListLabel_" + cid + "').hide(); }");
            js.AppendLine("    for (var i = 0; i < fgFiles_" + cid + ".length; i++) {");
            js.AppendLine("      var f = fgFiles_" + cid + "[i];");
            js.AppendLine("      dt.items.add(f);");
            js.AppendLine("      var ext = fgGetExt_" + cid + "(f.name);");
            js.AppendLine("      var ico = ext==='pdf' ? 'fa-file-pdf' : (ext==='doc'||ext==='docx') ? 'fa-file-word' : (ext==='xls'||ext==='xlsx') ? 'fa-file-excel' : (ext==='png'||ext==='jpg'||ext==='jpeg') ? 'fa-file-image' : 'fa-file-alt';");
            js.AppendLine("      $list.append('<li><i class=\"fas '+ico+' fg-fi-icon\"></i><span class=\"fg-fi-name\" title=\"'+f.name+'\">'+f.name+'</span><span class=\"fg-fi-remove\" data-idx=\"'+i+'\">&#x00D7;</span></li>');");
            js.AppendLine("    }");
            js.AppendLine("    $inp[0].files = dt.files;");
            js.AppendLine("  }");

            js.AppendLine("  $zone.off('dragover').on('dragover', function(e){ e.preventDefault(); $zone.addClass('dragover'); });");
            js.AppendLine("  $zone.off('dragleave drop').on('dragleave drop', function(e){ e.preventDefault(); $zone.removeClass('dragover'); });");

            js.AppendLine("  $zone.off('drop').on('drop', function(e) {");
            js.AppendLine("    e.preventDefault(); e.stopPropagation();");
            js.AppendLine("    var fs = e.originalEvent.dataTransfer.files;");
            js.AppendLine("    for (var i=0; i<fs.length; i++) {");
            js.AppendLine("      if (!fgValidExt_" + cid + "(fs[i])) continue;");
            js.AppendLine("      if (!fgExists_" + cid + "(fs[i])) {");
            js.AppendLine("        if (!fgMulti_" + cid + " && fgFiles_" + cid + ".length > 0) { AlertSweet('Límite', 'Solo se permite un archivo', 'warning'); break; }");
            js.AppendLine("        fgFiles_" + cid + ".push(fs[i]);");
            js.AppendLine("      }");
            js.AppendLine("    }");
            js.AppendLine("    render();");
            js.AppendLine("  });");

            js.AppendLine("  $zone.off('click').on('click', function() {");
            js.AppendLine("    if (!$(this).hasClass('disabled')) { $inp.val(null); setTimeout(function(){ $inp.trigger('click'); }, 50); }");
            js.AppendLine("  });");

            js.AppendLine("  $inp.off('change').on('change', function() {");
            js.AppendLine("    var ns = $inp[0].files;");
            js.AppendLine("    for (var i=0; i<ns.length; i++) {");
            js.AppendLine("      if (!fgValidExt_" + cid + "(ns[i])) continue;");
            js.AppendLine("      if (!fgExists_" + cid + "(ns[i])) {");
            js.AppendLine("        if (!fgMulti_" + cid + " && fgFiles_" + cid + ".length > 0) { AlertSweet('Límite', 'Solo se permite un archivo', 'warning'); break; }");
            js.AppendLine("        fgFiles_" + cid + ".push(ns[i]);");
            js.AppendLine("      }");
            js.AppendLine("    }");
            js.AppendLine("    render();");
            js.AppendLine("  });");

            js.AppendLine("  $(document).off('click','#fgFileList_" + cid + " .fg-fi-remove').on('click','#fgFileList_" + cid + " .fg-fi-remove', function(e) {");
            js.AppendLine("    e.stopPropagation();");
            js.AppendLine("    fgFiles_" + cid + ".splice($(this).data('idx'), 1);");
            js.AppendLine("    render();");
            js.AppendLine("  });");

            js.AppendLine("}");

            js.AppendLine("$(document).on('dragover drop', function(e){ e.preventDefault(); e.stopPropagation(); });");
            js.AppendLine("$(document).ready(" + initFn + ");");
            js.AppendLine("if (typeof(Sys) !== 'undefined') { Sys.Application.add_load(" + initFn + "); }");

            ScriptManager.RegisterStartupScript(this, this.GetType(), "FgFileUpload2Script_" + cid, js.ToString(), true);

            base.CreateChildControls();
        }

        protected override void Render(HtmlTextWriter writer)
        {
            string cid = this.ClientID;
            string zoneCss = "fg-drop-zone" + (!this.Enabled || this.ReadOnly ? " disabled" : "");

            // drop zone (barra horizontal, ancho completo)
            writer.AddAttribute(HtmlTextWriterAttribute.Id, "fgDropZone_" + cid);
            writer.AddAttribute(HtmlTextWriterAttribute.Class, zoneCss);
            writer.RenderBeginTag(HtmlTextWriterTag.Div);

            // icono izquierdo
            writer.AddAttribute(HtmlTextWriterAttribute.Class, ReadOnly ? "fas fa-lock fg-dz-icon" : "fas fa-cloud-upload-alt fg-dz-icon");
            writer.RenderBeginTag(HtmlTextWriterTag.I);
            writer.RenderEndTag();

            // mensaje central
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "fg-dz-msg");
            writer.RenderBeginTag(HtmlTextWriterTag.Span);
            writer.Write(ReadOnly ? "Modo solo lectura" : "Arrastra archivos aquí o selecciona");
            writer.RenderEndTag();

            // botón derecho
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "fg-dz-btn");
            writer.RenderBeginTag(HtmlTextWriterTag.Span);
            writer.Write(ReadOnly ? "Deshabilitado" : "Seleccionar");
            writer.RenderEndTag();

            writer.RenderEndTag(); // fg-drop-zone

            // etiqueta de lista (oculta hasta que haya archivos)
            writer.AddAttribute(HtmlTextWriterAttribute.Id, "fgFileListLabel_" + cid);
            writer.AddStyleAttribute(HtmlTextWriterStyle.Display, "none");
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "fg-file-list2-label");
            writer.RenderBeginTag(HtmlTextWriterTag.Div);
            writer.Write("Archivos seleccionados");
            writer.RenderEndTag();

            // lista de chips
            writer.AddAttribute(HtmlTextWriterAttribute.Id, "fgFileList_" + cid);
            writer.AddAttribute(HtmlTextWriterAttribute.Class, "fg-file-list2");
            writer.RenderBeginTag(HtmlTextWriterTag.Ul);
            writer.RenderEndTag();

            // input oculto (target real del upload)
            writer.AddAttribute(HtmlTextWriterAttribute.Type, "file");
            writer.AddAttribute(HtmlTextWriterAttribute.Id, cid);
            writer.AddAttribute(HtmlTextWriterAttribute.Name, this.UniqueID);
            writer.AddStyleAttribute(HtmlTextWriterStyle.Display, "none");
            if (this.AllowMultiple)
                writer.AddAttribute("multiple", "multiple");
            if (!this.Enabled || this.ReadOnly)
                writer.AddAttribute("disabled", "disabled");
            writer.RenderBeginTag(HtmlTextWriterTag.Input);
            writer.RenderEndTag();
        }

        public virtual List<FileUpload2File> Archivos
        {
            get
            {
                var result = new List<FileUpload2File>();
                foreach (HttpPostedFile item in base.PostedFiles)
                {
                    if (item == null || item.ContentLength == 0) continue;
                    using (var br = new BinaryReader(item.InputStream))
                    {
                        result.Add(new FileUpload2File
                        {
                            Binario    = br.ReadBytes(item.ContentLength),
                            Nombre     = Path.GetFileName(item.FileName),
                            Extension  = Path.GetExtension(item.FileName).TrimStart('.'),
                            ContentType = item.ContentType,
                            Tamano     = item.ContentLength
                        });
                    }
                }
                return result;
            }
        }
    }

    public class FileUpload2File
    {
        public byte[] Binario     { get; set; }
        public string Nombre      { get; set; }
        public string Extension   { get; set; }
        public string ContentType { get; set; }
        public int    Tamano      { get; set; }
    }
}
