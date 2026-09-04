using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Las categorías con que el cliente agrupa sus repuestos.
///
/// POR QUÉ EXISTE ESTA PANTALLA
///   El listado de repuestos era una lista plana. Con diez repuestos se
///   recorre; con trescientos —lo normal en una planta— encontrar un
///   rodamiento entre correas, filtros y fusibles obliga a saberse el código
///   de memoria. Con tipos, el listado se recorre por pestañas.
///
/// LOS DEFINE EL CLIENTE
///   No vienen sembrados. Ninguna lista de categorías sirve para dos plantas
///   distintas, y una "estándar" termina siendo la de quien la escribió más
///   un "Otros" donde cae todo.
/// </summary>
public partial class View_Inventario_Repuestos_RepuestoTipos : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        pnlSinCliente.Visible = SitioBase.Session.ClienteId() <= 0;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        lnkNuevo.Visible = Token.Puede("CREAR EDITAR REPUESTOS");

        Cargar();
        udPanel.Update();
    }

    protected void Cargar()
    {
        if (SitioBase.Session.ClienteId() <= 0)
        {
            rptTipos.Visible = false;
            pnlVacio.Visible = false;
            litCuenta.Text = "";
            return;
        }

        RepuestoTipoController controller = new RepuestoTipoController();
        RepuestoTipo filtro = new RepuestoTipo();

        RadComboBox2 cbo = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");

        if (cbo != null && !string.IsNullOrEmpty(cbo.SelectedValue))
            filtro.filtro_habilitado = cbo.SelectedValue == "1";

        string texto = wucFiltro.Filtro();

        if (!string.IsNullOrEmpty(texto)) filtro.filtro = texto;

        List<RepuestoTipo> lista = controller.GetRepuestoTipos(filtro);

        rptTipos.DataSource = lista;
        rptTipos.DataBind();
        rptTipos.Visible = lista.Count > 0;

        litCuenta.Text = lista.Count == 0 ? ""
                       : (lista.Count == 1 ? "1 tipo" : lista.Count + " tipos");

        /* El vacío de "todavía no hay ninguno" y el de "la búsqueda no
           encontró" son situaciones distintas y se responden distinto: una
           invita a crear, la otra a cambiar lo que se escribió. */
        bool buscando = !string.IsNullOrEmpty(texto) || filtro.filtro_habilitado != null;

        pnlVacio.Visible = lista.Count == 0;

        if (lista.Count == 0)
        {
            litVacioTitulo.Text = buscando
                ? "Ningún tipo coincide"
                : "Todavía no hay tipos de repuesto";

            litVacioTexto.Text = buscando
                ? "Pruebe con otro texto o quite el filtro."
                : "Cree el primero para poder agrupar los repuestos por categoría.";
        }
    }

    protected void rptTipos_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item &&
            e.Item.ItemType != ListItemType.AlternatingItem) return;

        RepuestoTipo t = e.Item.DataItem as RepuestoTipo;

        if (t == null) return;

        bool puedeEditar = Token.Puede("CREAR EDITAR REPUESTOS");

        LinkButton editar = (LinkButton)e.Item.FindControl("lnkEditar");
        LinkButton eliminar = (LinkButton)e.Item.FindControl("lnkEliminar");

        if (editar != null)
        {
            editar.CommandArgument = t.rti_id.ToString();
            editar.Visible = puedeEditar;
            /* El id viaja CIFRADO, como en el resto del sitio: la ficha lo
               lee con `Querystring.Entero`, que descifra. Mandandolo en claro
               el descifrado no encuentra nada, `Id` queda en 0 y la ficha se
               abre en blanco aunque el titulo diga "Editar". */
            editar.OnClientClick = "return abrirTipo('" +
                                   Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + t.rti_id)) + "');";
        }

        if (eliminar != null)
        {
            eliminar.CommandArgument = t.rti_id.ToString();

            /* Un tipo con repuestos no se puede eliminar —el SP lo rechaza—,
               así que el botón no se ofrece. Mostrarlo para que después
               aparezca un error es hacer perder un clic. */
            eliminar.Visible = puedeEditar && t.repuestos == 0;
            eliminar.OnClientClick = "return ConfirSweetAlert(this, '', '¿Eliminar el tipo \"" +
                                     EscapaJs(t.rti_nombre) + "\"?');";

            ScriptManager.GetCurrent(Page).RegisterPostBackControl(eliminar);
        }

        Literal lit = (Literal)e.Item.FindControl("litTipo");

        if (lit == null) return;

        StringBuilder b = new StringBuilder();

        /* El orden va en un cuadrito al frente: es lo que decide la posición
           de la pestaña en el listado de repuestos, y sin verlo no hay forma
           de saber por qué una categoría salió antes que otra. */
        b.Append("<span class=\"sg-tipo-orden\" title=\"Orden de la pestaña\">" + t.rti_orden + "</span>");

        b.Append("<div class=\"sg-tipo-datos\">");
        b.Append("<div class=\"sg-tipo-nombre\"><strong>" + Server.HtmlEncode(t.rti_nombre) + "</strong>");
        b.Append("<span class=\"sg-tipo-codigo\">" + Server.HtmlEncode(t.rti_codigo) + "</span>");

        if (!t.rti_habilitado)
            b.Append("<span class=\"grid-estado-chip is-neutro\">Deshabilitado</span>");

        b.Append("</div>");

        if (!string.IsNullOrEmpty(t.rti_descripcion))
            b.Append("<div class=\"sg-tipo-desc\">" + Server.HtmlEncode(t.rti_descripcion) + "</div>");

        b.Append("<div class=\"sg-tipo-pie\"><i class=\"mdi mdi-package-variant-closed\"></i>" +
                 (t.repuestos == 1 ? "1 repuesto" : t.repuestos + " repuestos") + "</div>");

        b.Append("</div>");

        lit.Text = b.ToString();
    }

    /// <summary>
    /// El nombre, listo para viajar dentro de una cadena de JavaScript. Un
    /// nombre con apóstrofe cerraría la cadena y rompería el botón para esa
    /// fila y solo para esa.
    /// </summary>
    private static string EscapaJs(string valor)
    {
        return (valor ?? "").Replace("\\", "\\\\").Replace("'", "\\'");
    }

    protected void rptTipos_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        if (e.CommandName != "eliminar") return;

        try
        {
            if (!Token.Puede("CREAR EDITAR REPUESTOS"))
            {
                Tools.tools.ClientAlert("No tiene permisos para eliminar tipos de repuesto.", "alerta");
                return;
            }

            int id;

            if (!int.TryParse(Convert.ToString(e.CommandArgument), out id)) return;

            RepuestoTipoController controller = new RepuestoTipoController();
            Respuesta respuesta = controller.DeleteRepuestoTipo(id);

            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }
}
