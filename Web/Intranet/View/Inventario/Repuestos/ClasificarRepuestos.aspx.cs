using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web;
using System.Web.UI.WebControls;

/// <summary>
/// Clasificar repuestos: asigna un tipo a varios repuestos de una vez.
/// Un modal simple (Simple.master): marcar, elegir el tipo y asignar.
/// </summary>
public partial class View_Inventario_Repuestos_ClasificarRepuestos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!Token.Puede("CREAR EDITAR REPUESTOS"))
        {
            litLista.Text = "<div class=\"cl-vacio\">No tienes permiso para clasificar repuestos.</div>";
            btnAsignar.Visible = false;
            return;
        }
        if (!IsPostBack) CargarTipos();
        Pintar();
    }

    private void CargarTipos()
    {
        selTipo.Items.Clear();
        selTipo.Items.Add(new ListItem("Sin clasificar (quitar el tipo)", "0"));
        List<RepuestoTipo> tipos = new RepuestoTipoController().GetRepuestoTipos(new RepuestoTipo { filtro_habilitado = true });
        if (tipos != null)
            foreach (RepuestoTipo t in tipos)
                selTipo.Items.Add(new ListItem(t.rti_nombre, t.rti_id.ToString()));
        selTipo.SelectedIndex = tipos != null && tipos.Count > 0 ? 1 : 0;
    }

    private void Pintar()
    {
        List<Repuesto> lista = new RepuestoController().GetRepuestos(new Repuesto { filtro_habilitado = true }) ?? new List<Repuesto>();
        StringBuilder s = new StringBuilder();
        foreach (Repuesto r in lista)
        {
            bool sin = string.IsNullOrEmpty(r.repuesto_tipo_nombre);
            string texto = (r.rep_codigo + " " + r.rep_nombre + " " + r.rep_fabricante + " " + r.rep_modelo + " " + r.repuesto_tipo_nombre);
            s.Append("<label class=\"cl-fila\" data-id=\"").Append(r.rep_id)
             .Append("\" data-sin=\"").Append(sin ? "1" : "0")
             .Append("\" data-t=\"").Append(HttpUtility.HtmlAttributeEncode(texto)).Append("\">")
             .Append("<input type=\"checkbox\" />")
             .Append("<span><b>").Append(HttpUtility.HtmlEncode(r.rep_nombre)).Append("</b><small>")
             .Append(HttpUtility.HtmlEncode(r.rep_codigo))
             .Append(string.IsNullOrEmpty(r.rep_fabricante) ? "" : " · " + HttpUtility.HtmlEncode(r.rep_fabricante))
             .Append("</small></span>")
             .Append("<span class=\"cl-tipo").Append(sin ? " es-vacio" : "").Append("\">")
             .Append(sin ? "Sin clasificar" : HttpUtility.HtmlEncode(r.repuesto_tipo_nombre)).Append("</span></label>");
        }
        s.Append("<div class=\"cl-vacio\" id=\"clVacio\" style=\"display:none\">Ningún repuesto coincide con la búsqueda.</div>");
        litLista.Text = s.ToString();
    }

    protected void btnAsignar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR REPUESTOS")) return;
            string ids = (hdnIds.Value ?? "").Trim();
            if (ids == "")
            {
                litOk.Text = "<div class=\"cl-ok\" style=\"background:#FDECEA;color:#B02C23\">Marca al menos un repuesto.</div>";
                return;
            }
            int tipo; if (!int.TryParse(selTipo.Value, out tipo)) tipo = 0;
            Respuesta r = new RepuestoController().AsignarTipo(tipo, ids);
            litOk.Text = "<div class=\"cl-ok\"" + (r.error ? " style=\"background:#FDECEA;color:#B02C23\"" : "") + ">"
                       + HttpUtility.HtmlEncode(r.detalle) + "</div>";
            Pintar();   // la lista muestra el tipo nuevo
        }
        catch (Exception ex)
        {
            litOk.Text = "<div class=\"cl-ok\" style=\"background:#FDECEA;color:#B02C23\">" + HttpUtility.HtmlEncode(ex.Message) + "</div>";
        }
    }
}
