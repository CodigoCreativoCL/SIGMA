using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;

/// <summary>
/// Previsualización de solo lectura de una pauta de inspección (HU-090): se
/// abre al hacer clic en el checklist del listado, sin entrar a editar. Muestra
/// la cabecera y la estructura (secciones + campos) tal como quedó definida.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistPlantillaVista : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (IsPostBack) return;

        int id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
        if (id <= 0) return;

        ChecklistPlantillaController c = new ChecklistPlantillaController();
        ChecklistPlantilla x = c.GetChecklistPlantilla(id);
        if (x == null || x.cpl_id <= 0) { litNombre.Text = "Pauta no encontrada."; return; }

        litCodigo.Text = Server.HtmlEncode(x.cpl_codigo);
        litNombre.Text = Server.HtmlEncode(x.cpl_nombre);
        litDescripcion.Text = Server.HtmlEncode(x.cpl_descripcion ?? "");

        // Chips de contexto.
        StringBuilder meta = new StringBuilder();
        Chip(meta, "Planta", x.planta_nombre);
        Chip(meta, "Asignación", x.asignacion_tipo_nombre);
        Chip(meta, "Tipo de activo", x.activo_tipo_nombre);
        meta.Append("<span class=\"clv-chip\"><b>")
            .Append(x.cpl_habilitado ? "Habilitada" : "Deshabilitada").Append("</b></span>");
        litMeta.Text = meta.ToString();

        // Botón editar: reusa la función del listado (ventana que abrió esta vista).
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
        lnkEditar.Attributes["onclick"] = "getRadWindow().BrowserWindow.abrirChecklistPlantilla('" + query + "'); cerrarVista(); return false;";
        if (!Token.Puede("CREAR EDITAR PAUTAS")) lnkEditar.Visible = false;

        // Estructura.
        ChecklistEstructuraController ec = new ChecklistEstructuraController();
        int version = ec.GetBorradorVersion(id, SitioBase.Session.UsuarioId(), false);
        if (version <= 0)
        {
            litEstructura.Text = "<div class=\"clv-vacio\">Esta pauta todavía no tiene campos definidos. Ábrela con “Editar” para agregarlos.</div>";
            return;
        }

        List<ChecklistSeccion> secciones = ec.GetSecciones(version);
        List<ChecklistItem> items = ec.GetItems(version);
        if (secciones.Count == 0)
        {
            litEstructura.Text = "<div class=\"clv-vacio\">Esta pauta todavía no tiene campos definidos. Ábrela con “Editar” para agregarlos.</div>";
            return;
        }

        StringBuilder sb = new StringBuilder();
        foreach (ChecklistSeccion s in secciones)
        {
            int n = 0;
            StringBuilder its = new StringBuilder();
            foreach (ChecklistItem it in items)
            {
                if (it.seccion_sid != s.sid) continue;
                n++;
                string tipo = it.tipo_nombre;
                if (!string.IsNullOrEmpty(it.unidad_simbolo)) tipo += " (" + it.unidad_simbolo + ")";
                its.Append("<div class=\"clv-item\">")
                   .Append("<span class=\"tx\">").Append(Server.HtmlEncode(it.cpi_texto)).Append("</span>")
                   .Append("<span class=\"clv-tipo\">").Append(Server.HtmlEncode(tipo)).Append("</span>")
                   .Append(it.cpi_obligatorio ? "<span class=\"clv-req\">*</span>" : "")
                   .Append("</div>");
            }

            sb.Append("<div class=\"clv-sec\"><div class=\"clv-sec-cab\">")
              .Append("<i class=\"mdi mdi-folder-outline\"></i>")
              .Append(Server.HtmlEncode(s.cps_nombre))
              .Append("<span class=\"n\">").Append(n).Append(n == 1 ? " campo" : " campos").Append("</span></div>")
              .Append(its).Append("</div>");
        }
        litEstructura.Text = sb.ToString();
    }

    private void Chip(StringBuilder sb, string label, string valor)
    {
        if (string.IsNullOrEmpty(valor)) return;
        sb.Append("<span class=\"clv-chip\">").Append(Server.HtmlEncode(label))
          .Append(": <b>").Append(Server.HtmlEncode(valor)).Append("</b></span>");
    }
}
