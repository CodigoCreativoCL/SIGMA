using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// Leer una etiqueta y ver, ahí mismo, todo lo que hay en ese lugar.
///
/// LA CAMARA DEL TELEFONO ES EL CAMINO PRINCIPAL
///   Hay dos formas de llegar acá con la cámara, las dos válidas:
///
///     La cámara nativa del teléfono lee el QR sin ayuda de nadie —iOS 11 y
///     Android 9 en adelante— y, como el QR guarda la URL completa, abre esta
///     pantalla ya resuelta. Funciona siempre, sin permisos ni HTTPS.
///
///     La cámara dentro de la pantalla, para escanear varias seguidas sin
///     salir y volver. Necesita HTTPS y un navegador que sepa decodificar;
///     cuando falta alguno de los dos, sigma-escaneo.js lo dice y remite al
///     primer camino en vez de dejar un botón que no responde.
///
/// EL QUERYSTRING VIENE EN CLARO, Y ES DELIBERADO
///   Una etiqueta pegada dura años; un cifrado depende de una clave que algún
///   día cambia, y ese día habría que reimprimir la bodega entera. Lo que
///   protege el dato es esta página —que exige permiso— y el SP, que filtra
///   por el cliente de la sesión.
/// </summary>
public partial class View_Comun_Impresion_Escanear : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        /* El JS necesita saber a qué controles entregar lo leído, y los ids
           de cliente los pone ASP.NET: escribirlos a mano en el .js los
           rompería en cuanto la página cambie de master. */
        string enlace = "sigmaEscaneo.idCampo = '" + hdnLeido.ClientID + "';" +
                        "sigmaEscaneo.idBoton = '" + btnLeido.ClientID + "';";

        ScriptManager.RegisterStartupScript(this, GetType(), "escaneo-ids", enlace, true);

        if (IsPostBack) return;

        Puente();

        /* Este SÍ es un querystring en claro, a diferencia del resto del
           sitio, y es el único: es lo que trae el QR. */
        string leido = Request.QueryString["c"];

        if (!string.IsNullOrEmpty(leido)) Resolver(leido);
    }

    /// <summary>
    /// El QR que lleva ESTA pantalla al teléfono.
    ///
    /// En un computador la cámara no sirve para leer una etiqueta pegada en un
    /// estante: no se puede acercar el monitor al pasillo. Pero sí se puede
    /// mostrar un código que el teléfono lea, y seguir ahí.
    ///
    /// Es el mismo truco que ya usan las etiquetas —el QR lleva una URL— pero
    /// apuntando a la propia pantalla en vez de a un registro.
    ///
    /// SOLO EN ESCRITORIO
    ///   En un teléfono ofrecer "ábralo en su teléfono" es absurdo, y el JS ya
    ///   distingue el aparato; acá se genera igual y el CSS lo esconde, porque
    ///   el servidor no sabe desde qué pantalla lo están mirando.
    /// </summary>
    protected void Puente()
    {
        try
        {
            string url = Request.Url.GetLeftPart(UriPartial.Authority) +
                         ResolveUrl("~/View/Comun/Impresion/Escanear.aspx");

            string qr = new EtiquetaController().QrDeUrl(url);

            if (string.IsNullOrEmpty(qr)) return;

            litQrPuente.Text = "<img src=\"" + qr + "\" alt=\"Abrir esta pantalla en el teléfono\" />";
            pnlPuente.Visible = true;
        }
        catch (Exception)
        {
            /* Sin el QR la pantalla sigue sirviendo entera: es una comodidad,
               no el camino. */
            pnlPuente.Visible = false;
        }
    }

    protected void btnLeido_Click(object sender, EventArgs e)
    {
        Resolver(hdnLeido.Value);
        hdnLeido.Value = "";
    }

    protected void txtLectura_Changed(object sender, EventArgs e)
    {
        Resolver(txtLectura.Text);
    }

    protected void btnBuscar_Click(object sender, EventArgs e)
    {
        Resolver(txtLectura.Text);
    }

    protected void Resolver(string leido)
    {
        pnlResultado.Visible = false;
        pnlNada.Visible = false;

        try
        {
            if (string.IsNullOrEmpty(leido) || leido.Trim().Length == 0) return;

            if (!Token.Puede("VER EXISTENCIAS"))
                throw new Exception("No tiene permiso para consultar existencias.");

            EtiquetaController lector = new EtiquetaController();

            string tipo;
            int id;

            if (!lector.Interpretar(leido, out tipo, out id))
                throw new Exception("No se reconoce «" + leido.Trim() +
                                    "». Escriba el código impreso en la etiqueta, " +
                                    "por ejemplo UBI-17 o BOD-9.");

            /* Un activo NO es un lugar: no tiene existencia adentro, así que
               no hay desglose que mostrar. Su etiqueta lleva a su ficha, que
               es lo que alguien quiere ver parado frente a la máquina.

               Se cifra el querystring porque esto ya es navegación interna
               del sitio: el único que viaja en claro es el del QR, y por una
               razón concreta —una etiqueta pegada dura más que cualquier
               clave—. */
            if (tipo == "ACT")
            {
                if (!Token.Puede("VER ACTIVOS"))
                    throw new Exception("No tiene permiso para consultar activos.");

                string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
                Response.Redirect("~/View/Activos/Activos/Activo.aspx?query=" + q);
                return;
            }

            DesgloseController controller = new DesgloseController();
            bool hallado;

            /* El repuesto se resuelve ACA y no redirige a su ficha. Redirigir
               funcionaba, pero saca de la pantalla a alguien que está de pie
               frente a un estante y va a escanear otra etiqueta en diez
               segundos: tendría que volver cada vez. */
            if (tipo == "UBI") hallado = controller.CargarUbicacion(id);
            else if (tipo == "BOD") hallado = controller.CargarBodega(id);
            else hallado = controller.CargarRepuesto(id);

            if (!hallado || controller.Cabecera == null)
                throw new Exception("Esa etiqueta no corresponde a " + Articulo(tipo) +
                                    " de su empresa.");

            Mostrar(controller, tipo);

            txtLectura.Text = "";
        }
        catch (Exception ex)
        {
            pnlNada.Visible = true;
            litNada.Text = Server.HtmlEncode(ex.Message);
        }
        finally
        {
            udPanel.Update();

            /* Se olvida el último código para que volver a escanear el mismo
               estante consulte de nuevo: entre un escaneo y otro alguien pudo
               sacar algo, y mostrar lo de antes sería mentir. */
            ScriptManager.RegisterStartupScript(this, GetType(), "escaneo-olvidar",
                                                "if(window.sigmaEscaneo) sigmaEscaneo.olvidar();", true);
        }
    }

    protected string Articulo(string tipo)
    {
        if (tipo == "UBI") return "ninguna ubicación";
        if (tipo == "BOD") return "ninguna bodega";
        return "ningún repuesto";
    }

    protected void Mostrar(DesgloseController controller, string tipo)
    {
        DesgloseCabecera c = controller.Cabecera;

        pnlResultado.Visible = true;

        litTipo.Text = c.Tipo;
        litCodigo.Text = Server.HtmlEncode(c.Codigo);
        litNombre.Text = Server.HtmlEncode(c.Nombre);
        litContexto.Text = Server.HtmlEncode(c.Contexto);

        if (!c.Habilitado)
            litNombre.Text += " <span class=\"grid-estado-chip is-alerta\">DADO DE BAJA</span>";

        /* El total solo aplica al repuesto: en una bodega o un estante la
           suma de cosas distintas —litros más unidades más metros— no
           significa nada. */
        pnlTotal.Visible = (c.Total != null);

        if (pnlTotal.Visible)
            litTotal.Text = c.Total.Value.ToString("N2") + " " + Server.HtmlEncode(c.Unidad);

        litResumen.Text = Resumen(controller.Lineas, tipo);

        ViewState["Tipo"] = tipo;

        rptDetalle.DataSource = controller.Lineas;
        rptDetalle.DataBind();
    }

    protected void rptDetalle_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        DesgloseLinea l = (DesgloseLinea)e.Item.DataItem;
        string tipo = ViewState["Tipo"] != null ? ViewState["Tipo"].ToString() : "";

        /* El rótulo del lugar cambia según lo escaneado, y en un estante NO se
           pone: diría lo mismo en todas las tarjetas y ya está en la
           cabecera. Repetir un dato constante lo convierte en ruido. */
        Literal lugar = (Literal)e.Item.FindControl("litLugar");

        if (tipo == "BOD" && !string.IsNullOrEmpty(l.Ubicacion))
            lugar.Text = "<span class=\"lugar\">" + Server.HtmlEncode(l.Ubicacion) + "</span>";
        else if (tipo == "REP")
            lugar.Text = "<span class=\"lugar\">" + Server.HtmlEncode(l.Bodega) +
                         (string.IsNullOrEmpty(l.Ubicacion) ? "" : " · " + Server.HtmlEncode(l.Ubicacion)) +
                         "</span>";

        Literal cantidad = (Literal)e.Item.FindControl("litCantidad");
        cantidad.Text = "<div class=\"valor\">" + l.Cantidad.ToString("N2") + "</div>" +
                        "<div class=\"unidad\">" + Server.HtmlEncode(l.Unidad) + "</div>";

        Literal lote = (Literal)e.Item.FindControl("litLote");
        lote.Text = Lote(l);

        Literal ultimo = (Literal)e.Item.FindControl("litUltimo");

        if (l.UltimoMovimiento != null)
        {
            string texto = "Últ. mov. " + l.UltimoMovimiento.Value.ToString("dd-MM-yyyy");

            if (!string.IsNullOrEmpty(l.UltimoUsuario) && l.UltimoUsuario.Trim().Length > 0)
                texto += " · " + l.UltimoUsuario.Trim();

            ultimo.Text = "<span class=\"esc-ultimo\">" + Server.HtmlEncode(texto) + "</span>";
        }
    }

    /// <summary>
    /// El lote, y cuánto le queda de vida.
    ///
    /// El chip cambia de color porque un lote vencido en la mano es una
    /// decisión distinta a uno que vence en un año: hay que separarlo, no
    /// usarlo. Sesenta días es el umbral que ya usa la ficha del repuesto, y
    /// se respeta para que el mismo lote no se vea de dos colores según dónde
    /// se mire.
    /// </summary>
    protected string Lote(DesgloseLinea l)
    {
        if (string.IsNullOrEmpty(l.LoteCodigo) || l.LoteCodigo.Trim().Length == 0)
            return "";

        string clase = "esc-lote";
        string texto = "Lote " + l.LoteCodigo.Trim();

        if (l.DiasParaVencer != null)
        {
            int dias = l.DiasParaVencer.Value;

            if (dias < 0)
            {
                clase += " is-alerta";
                texto += " · venció hace " + Math.Abs(dias).ToString() + " días";
            }
            else if (dias <= 60)
            {
                clase += " is-advertencia";
                texto += " · vence en " + dias.ToString() + " días";
            }
            else
            {
                texto += " · vence " + l.LoteVence.Value.ToString("dd-MM-yyyy");
            }
        }

        return "<span class=\"" + clase + "\">" + Server.HtmlEncode(texto) + "</span>";
    }

    protected string Resumen(List<DesgloseLinea> lineas, string tipo)
    {
        if (lineas == null || lineas.Count == 0)
        {
            if (tipo == "UBI") return "Este estante está vacío: no hay existencia registrada acá.";
            if (tipo == "BOD") return "Esta bodega no tiene existencia registrada.";
            return "Este repuesto no tiene existencia en ninguna bodega.";
        }

        if (tipo == "REP")
        {
            List<string> sitios = new List<string>();

            foreach (DesgloseLinea l in lineas)
            {
                string sitio = l.Bodega + "|" + l.Ubicacion;
                if (!sitios.Contains(sitio)) sitios.Add(sitio);
            }

            return sitios.Count == 1
                   ? "En 1 ubicación."
                   : "Repartido en " + sitios.Count.ToString() + " ubicaciones.";
        }

        List<int> repuestos = new List<int>();

        foreach (DesgloseLinea l in lineas)
            if (!repuestos.Contains(l.RepuestoId)) repuestos.Add(l.RepuestoId);

        string texto = repuestos.Count == 1
                       ? "1 repuesto"
                       : repuestos.Count.ToString() + " repuestos";

        /* Las líneas pueden ser más que los repuestos: un mismo repuesto con
           dos lotes son dos líneas. Decirlo evita que se lea como un dato
           duplicado. */
        if (lineas.Count > repuestos.Count)
            texto += ", en " + lineas.Count.ToString() + " líneas por lote";

        if (tipo == "BOD")
        {
            List<string> ubic = new List<string>();

            foreach (DesgloseLinea l in lineas)
                if (!ubic.Contains(l.Ubicacion)) ubic.Add(l.Ubicacion);

            texto += ubic.Count == 1
                     ? ", en 1 ubicación"
                     : ", repartidos en " + ubic.Count.ToString() + " ubicaciones";
        }

        return texto + ".";
    }
}
