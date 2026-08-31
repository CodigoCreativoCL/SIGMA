using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Genera la hoja de etiquetas y la manda a la impresora del navegador.
///
/// POR QUE EL NAVEGADOR Y NO UN PDF
///   Las etiquetas se imprimen en cosas muy distintas: una impresora térmica
///   de rollo en la bodega, la multifuncional de oficina con planchas
///   adhesivas A4. El diálogo del navegador ya sabe elegir la bandeja, la
///   escala y el papel; un PDF nuestro tendría que aprender todo eso de
///   nuevo y quedaría peor.
///
/// LA PANTALLA NO SABE QUE ESTA IMPRIMIENDO
///   Recibe filas ya normalizadas por SEL_ETIQUETA —token, código, título,
///   subtítulo, detalle, pie— y las maqueta igual sean bodegas, estantes,
///   repuestos o activos. Agregar un origen nuevo no toca este archivo.
/// </summary>
public partial class View_Comun_Impresion_Etiquetas : System.Web.UI.Page
{
    public string Origen
    {
        get { return ViewState["Origen"] != null ? ViewState["Origen"].ToString() : ""; }
        set { ViewState["Origen"] = value; }
    }

    public string Ids
    {
        get { return ViewState["Ids"] != null ? ViewState["Ids"].ToString() : ""; }
        set { ViewState["Ids"] = value; }
    }

    public int Bodega
    {
        get { return ViewState["Bodega"] != null ? (int)ViewState["Bodega"] : 0; }
        set { ViewState["Bodega"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            /* Querystring.Entero y Querystring.Texto reciben el valor TAL
               COMO VIENE: descifran por dentro. Pasarles el resultado de
               Descifrar lo haría descifrar dos veces, la segunda falla, y
               como el helper no lanza, devuelve vacío en silencio. */
            Origen = Querystring.Texto(Request.QueryString["query"], "Origen");
            Ids = Querystring.Texto(Request.QueryString["query"], "Ids");
            Bodega = Querystring.Entero(Request.QueryString["query"], "Bodega");

            Cargar();
        }
    }

    protected void cboFormato_Changed(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        Cargar();
    }

    protected void Cargar()
    {
        /* La página tiene su fila en Menus, así que el framework ya frenó a
           quien no puede entrar. Esto es la segunda reja: quien puede
           IMPRIMIR ETIQUETAS no necesariamente puede ver los repuestos, y
           una etiqueta de repuesto lleva su nombre y su fabricante. */
        if (!PuedeVerOrigen())
        {
            Mostrar(new List<Etiqueta>());
            litVacio.Text = "No tiene permiso para ver estos datos.";
            return;
        }

        EtiquetaController controller = new EtiquetaController();

        List<Etiqueta> lista = controller.GetEtiquetas(Origen, Ids, Bodega, UrlBaseEscaneo());

        Mostrar(lista);
    }

    /// <summary>
    /// El QR guarda la URL COMPLETA y no solo el token, porque el teléfono de
    /// cualquiera tiene que poder abrirla sin instalar nada: la cámara nativa
    /// lee el QR y abre esa dirección.
    /// </summary>
    protected string UrlBaseEscaneo()
    {
        string autoridad = Request.Url.GetLeftPart(UriPartial.Authority);
        string ruta = ResolveUrl("~/View/Comun/Impresion/Escanear.aspx");

        return autoridad + ruta + "?c=";
    }

    protected bool PuedeVerOrigen()
    {
        switch (Origen)
        {
            case EtiquetaOrigen.Bodega:
            case EtiquetaOrigen.Ubicacion:
                return Token.Puede("VER BODEGAS");

            case EtiquetaOrigen.Repuesto:
                return Token.Puede("VER REPUESTOS");

            case EtiquetaOrigen.Activo:
                return Token.Puede("VER ACTIVOS");

            case EtiquetaOrigen.UbicacionRepuesto:
                /* Lleva el nombre del repuesto Y dónde está guardado: hacen
                   falta los dos permisos, no cualquiera de los dos. */
                return Token.Puede("VER BODEGAS") && Token.Puede("VER REPUESTOS");
        }

        return false;
    }

    protected void Mostrar(List<Etiqueta> lista)
    {
        litTitulo.Text = TituloOrigen();
        litPagina.Text = ReglaDePagina();

        bool hay = (lista != null && lista.Count > 0);

        divHoja.Visible = hay;
        pnlVacio.Visible = !hay;
        btnImprimir.Visible = hay;

        if (!hay)
        {
            if (string.IsNullOrEmpty(litVacio.Text))
                litVacio.Text = "No hay nada que etiquetar todavía.";

            litCuenta.Text = "";
            return;
        }

        divHoja.Attributes["class"] = "etq-hoja etq-" + Formato();

        litCuenta.Text = lista.Count == 1
                         ? "1 etiqueta"
                         : lista.Count.ToString() + " etiquetas";

        rptEtiquetas.DataSource = lista;
        rptEtiquetas.DataBind();
    }

    protected void rptEtiquetas_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        Etiqueta item = (Etiqueta)e.Item.DataItem;

        /* El código se dimensiona según su largo: en una etiqueta de ancho
           fijo, uno de 4 caracteres y uno de 20 no pueden ir al mismo tamaño.
           CSS no sabe cuántos caracteres vienen; acá sí. */
        Literal cod = (Literal)e.Item.FindControl("litCodigo");
        cod.Text = "<div class=\"codigo " + Escala(item.Codigo) + "\">" +
                   Server.HtmlEncode(item.Codigo) + "</div>";

        Literal lit = (Literal)e.Item.FindControl("litQr");

        /* Sin QR se deja el hueco y la etiqueta igual sirve: el código va
           impreso en grande justamente para poder teclearlo. */
        if (string.IsNullOrEmpty(item.QrDataUri)) return;

        lit.Text = "<img src=\"" + item.QrDataUri + "\" alt=\"" +
                   Server.HtmlEncode(item.Codigo) + "\" />";
    }

    /// <summary>
    /// Qué tan grande puede ir el código sin que se corte.
    ///
    /// Los cortes salen de lo que cabe en una línea del formato más angosto.
    /// Por encima de 18 caracteres el código ocupa dos líneas: partirlo es
    /// preferible a no poder leerlo, que es lo que pasaba cuando llevaba
    /// text-overflow y DEMO-BOD-CENTRAL se imprimía como "DEMO-B...".
    /// </summary>
    protected string Escala(string codigo)
    {
        int largo = string.IsNullOrEmpty(codigo) ? 0 : codigo.Trim().Length;

        if (largo <= 8) return "cod-l";
        if (largo <= 12) return "cod-m";
        if (largo <= 18) return "cod-s";

        return "cod-xs";
    }

    protected string Formato()
    {
        return string.IsNullOrEmpty(cboFormato.SelectedValue) ? "a4-24" : cboFormato.SelectedValue;
    }

    /// <summary>
    /// El tamaño del papel. El rollo térmico NO es A4: mandarlo como A4 deja
    /// una etiqueta de 5 cm arriba de una hoja en blanco y gasta el rollo.
    /// </summary>
    protected string ReglaDePagina()
    {
        string regla = Formato() == "termica"
                       ? "@page { size: 50mm 25mm; margin: 0; }"
                       : "@page { size: A4; margin: 8mm; }";

        return "<style type=\"text/css\">" + regla + "</style>";
    }

    protected string TituloOrigen()
    {
        switch (Origen)
        {
            case EtiquetaOrigen.Bodega: return "Etiquetas de bodega";
            case EtiquetaOrigen.Ubicacion: return "Etiquetas de ubicación";
            case EtiquetaOrigen.UbicacionRepuesto: return "Etiquetas de ubicación con su repuesto";
            case EtiquetaOrigen.Repuesto: return "Etiquetas de repuesto";
            case EtiquetaOrigen.Activo: return "Etiquetas de activo";
        }

        return "Etiquetas";
    }
}
