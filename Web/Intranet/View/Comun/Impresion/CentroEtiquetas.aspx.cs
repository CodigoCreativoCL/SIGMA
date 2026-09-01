using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// El centro de etiquetas: todo lo imprimible, en un solo sitio.
///
/// LA PANTALLA NO SABE QUE MODULOS EXISTEN
///   Lee Etiqueta_Origen y dibuja lo que haya. Agregar un módulo imprimible
///   es un INSERT en esa tabla más una rama en SEL_ETIQUETA: este archivo no
///   se toca. Es la misma idea que ya gobierna el menú y los permisos —SIGMA
///   decide por datos, no por código repartido por las vistas—.
///
/// CADA ORIGEN LLEVA SU PERMISO
///   No basta con poder IMPRIMIR ETIQUETAS. Una etiqueta de repuesto lleva su
///   nombre y su fabricante; una de bodega, dónde está. Se muestran solo los
///   orígenes cuyo permiso tiene quien mira, y no una reja que aparece recién
///   al apretar.
///
/// LOS ORIGENES APAGADOS SE MUESTRAN, NO SE ESCONDEN
///   Con su motivo escrito. Esconderlos haría pensar que el sistema no
///   contempla ese módulo; mostrarlos gris y mudos haría pensar que algo se
///   rompió. Se dice por qué.
/// </summary>
public partial class View_Comun_Impresion_CentroEtiquetas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            CargarBodegas();
            Cargar();
        }
    }

    protected void cboBodega_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        Cargar();
        udPanel.Update();
    }

    protected void CargarBodegas()
    {
        if (!Token.Puede("VER BODEGAS")) return;

        BodegaController controller = new BodegaController();

        List<Bodega> bodegas = controller.GetBodegas(
            new Bodega { filtro_habilitado = true });

        cboBodega.Items.Add(new RadComboBoxItem("Todas las bodegas", ""));
        cboBodega.AppendDataBoundItems = true;
        cboBodega.DataSource = bodegas;
        cboBodega.DataValueField = "bod_id";
        cboBodega.DataTextField = "bod_nombre";
        cboBodega.DataBind();
    }

    protected void Cargar()
    {
        EtiquetaController controller = new EtiquetaController();

        List<EtiquetaOrigenItem> todos = controller.GetOrigenes();
        List<EtiquetaOrigenItem> visibles = new List<EtiquetaOrigenItem>();

        foreach (EtiquetaOrigenItem o in todos)
        {
            /* El permiso lo declara la propia fila: la pantalla no tiene una
               lista de qué permiso corresponde a qué módulo, que sería una
               segunda copia de la verdad. */
            if (Token.Puede(o.Permiso)) visibles.Add(o);
        }

        /* Se parten por ALCANCE y no por orden: el combo de bodega solo
           afecta a los que se acotan a una, y ponerlos juntos es lo que hace
           obvio a qué se aplica. */
        List<EtiquetaOrigenItem> deBodega = new List<EtiquetaOrigenItem>();
        List<EtiquetaOrigenItem> deCatalogo = new List<EtiquetaOrigenItem>();

        foreach (EtiquetaOrigenItem o in visibles)
        {
            /* La bodega misma va con las de bodega aunque no se acote por el
               combo: se imprime UNA, la elegida, y su sitio natural es ahí. */
            if (o.eto_por_bodega || o.eto_codigo == EtiquetaOrigen.Bodega)
                deBodega.Add(o);
            else
                deCatalogo.Add(o);
        }

        pnlSinOrigenes.Visible = (visibles.Count == 0);

        pnlGrupoBodega.Visible = (deBodega.Count > 0);
        pnlGrupoCatalogo.Visible = (deCatalogo.Count > 0);

        rptBodega.DataSource = deBodega;
        rptBodega.DataBind();

        rptCatalogo.DataSource = deCatalogo;
        rptCatalogo.DataBind();
    }

    protected void rptOrigenes_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        EtiquetaOrigenItem o = (EtiquetaOrigenItem)e.Item.DataItem;
        Literal lit = (Literal)e.Item.FindControl("litTarjeta");

        string icono = string.IsNullOrEmpty(o.eto_icono) ? "mdi mdi-tag-outline" : o.eto_icono;

        string nota = o.eto_habilitado
                      ? o.eto_descripcion
                      : o.eto_motivo_baja;

        string atributos = o.eto_habilitado
                           ? " onclick=\"return abrirEtiquetas('" + Query(o) + "');\""
                           : " disabled=\"disabled\"";

        lit.Text =
            "<button type=\"button\" class=\"sigma-opcion\"" + atributos + ">" +
                "<span class=\"icono\"><i class=\"" + Server.HtmlEncode(icono) + "\"></i></span>" +
                "<span class=\"cuerpo\">" +
                    "<span class=\"titulo\">" + Server.HtmlEncode(o.eto_nombre) + "</span>" +
                    "<span class=\"nota\">" + Server.HtmlEncode(nota) + "</span>" +
                "</span>" +
            "</button>";
    }

    /// <summary>
    /// Lo que se le manda a la pantalla de impresión, cifrado como cualquier
    /// otra navegación interna del sitio. El único querystring en claro del
    /// módulo es el del QR, y por una razón concreta: una etiqueta pegada
    /// dura más que cualquier clave.
    /// </summary>
    protected string Query(EtiquetaOrigenItem o)
    {
        string datos = "Origen=" + o.eto_codigo;

        if (o.eto_por_bodega && !string.IsNullOrEmpty(cboBodega.SelectedValue))
            datos += "&Bodega=" + cboBodega.SelectedValue;

        return Server.UrlEncode(Tools.Crypto.Encrypt(datos));
    }
}
