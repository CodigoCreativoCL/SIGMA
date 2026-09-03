using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Existencia por repuesto y bodega (HU-056).
///
/// LA PREGUNTA QUE CONTESTA ESTA PANTALLA ES "¿ME ALCANZA?"
///   No "cuántos hay". Por eso la cantidad y su umbral van en la MISMA
///   celda: repartidos en tres columnas, la comparación la hace el ojo
///   saltando de lado a lado. Juntos se lee de una.
///
/// EMPIEZA MOSTRANDO TODO, NO SOLO LAS ALERTAS
///   Es la pantalla que se abre para responder "¿hay?", y filtrar por
///   defecto escondería justo lo que se vino a buscar. El interruptor de
///   alertas está arriba, con la cuenta a la vista.
///
/// EL COLOR SOLO APARECE CUANDO HAY ALGO QUE MIRAR
///   Pintar todas las filas convierte el color en decoración y deja de
///   avisar. Solo se pinta lo que está fuera de su umbral.
/// </summary>
public partial class View_Inventario_Existencias_Existencias : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("REPUESTO_CODIGO", "CÓDIGO", Width: "13%");
            Grid.AddColumn("REPUESTO_NOMBRE", "REPUESTO", Width: "26%");
            Grid.AddColumn("BODEGA_NOMBRE", "BODEGA", Width: "16%");
            Grid.AddColumn("UBICACION_CODIGO", "UBICACIÓN", Width: "12%");

            /* Columnas de plantilla: el contenido lo arma ItemDataBound.
               Una columna enlazada solo puede mostrar un valor, y acá cada
               celda lleva dos —la cantidad y su rango, el estado y su
               icono—. */
            /* Field vacio: una columna de plantilla sin template no
               enlaza nada, el contenido lo arma ItemDataBound. Es como lo
               hacen Pagos, Periodos y Suscripciones. */
            Grid.AddTemplateColumn("EXISTENCIA", "", "EXISTENCIA",
                Width: "13%", ItemPosition: HorizontalAlign.Right,
                HederPosition: HorizontalAlign.Right);

            Grid.AddTemplateColumn("ESTADO", "", "ESTADO", Width: "20%");
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    /// <summary>
    /// Llena el combo de bodegas del filtro. Es el patrón del sitio:
    /// OnLoad="LoadControls" en el markup y un switch por ID.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboBodega")
            {
                BodegaController controller = new BodegaController();

                ctrl.Items.Add(new RadComboBoxItem("Todas", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = controller.GetBodegas(new Bodega { filtro_habilitado = true });
                ctrl.DataValueField = "bod_id";
                ctrl.DataTextField = "bod_nombre";
                ctrl.DataBind();
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarGrid();
        Grid.DataBind();

        udPanel.Update();
    }

    /// <summary>
    /// Pinta cada fila según su umbral.
    ///
    /// La marca la decide el SP —BAJO_MINIMO y SOBRE_MAXIMO llegan
    /// calculados—, no esta pantalla. Si cada consumidor comparara cantidad
    /// contra umbral por su cuenta, el día que la regla cambie habría que
    /// cambiarla en todos.
    /// </summary>
    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType != GridItemType.AlternatingItem &&
            e.Item.ItemType != GridItemType.Item) return;

        GridDataItem item = e.Item as GridDataItem;

        if (item == null) return;

        InventarioSaldo f = item.DataItem as InventarioSaldo;

        if (f == null) return;

        // ---- Código: enlace a la ficha ----
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + f.isa_repuesto));

        HyperLink ver = new HyperLink();
        ver.ID = "lnkVer" + item.ItemIndex;
        ver.Text = Server.HtmlEncode(f.repuesto_codigo);
        ver.NavigateUrl = "javascript:void(0)";
        ver.Attributes.Add("onclick", "abrirExistencia('" + query + "')");

        item["REPUESTO_CODIGO"].Text = "";
        item["REPUESTO_CODIGO"].Controls.Add(ver);

        /* La ficha completa se abre por repuesto; el drawer, en cambio,
           necesita distinguir el saldo de ESTA bodega. Se le entrega su
           propio token cifrado en la fila y el navegador nunca ve el id. */
        item.Attributes["data-sgx-token"] = Server.UrlEncode(
            Tools.Crypto.Encrypt("Id=" + f.isa_id));
        item.Attributes["data-sgx-readonly"] = "1";

        // ---- Ubicación: vacío no se entiende, "sin registrar" sí ----
        if (string.IsNullOrEmpty(f.ubicacion_codigo))
            item["UBICACION_CODIGO"].Text =
                "<span class=\"sigma-inv-vacio\">sin registrar</span>";

        // ---- Existencia: la cifra y, debajo, contra qué se compara ----
        string clase = f.bajo_minimo ? " is-bajo" : (f.sobre_maximo ? " is-sobre" : "");

        string celda = "<div class=\"sigma-inv-cantidad" + clase + "\">"
                     + "<span><span class=\"valor\">" + f.isa_cantidad.ToString("N2") + "</span>"
                     + "<span class=\"unidad\">" + Server.HtmlEncode(f.unidad_simbolo) + "</span></span>"
                     + Rango(f)
                     + "</div>";

        item["EXISTENCIA"].Controls.Add(new Literal { Text = celda });

        // ---- Estado ----
        item["ESTADO"].Controls.Add(new Literal { Text = Estado(f) });

        /* NO se le toca la clase a la fila.

           item.CssClass += " ..." parece que agrega, pero el getter de una
           fila de RadGrid devuelve vacio: Telerik pone rgRow y rgAltRow por
           otro camino. Asi que el += termina REEMPLAZANDO la clase, y la
           fila pierde su borde y el rayado alternado. Se veia justo en las
           filas con alerta, que son las que uno mira.

           El estado lo dice el chip de la columna ESTADO y el color de la
           cifra. Con eso alcanza: una fila entera pintada compite con el
           texto y no agrega nada que el chip no diga ya. */
        if (f.bajo_minimo)
            item.ToolTip = "Bajo el stock mínimo definido para esta bodega.";
        else if (f.sobre_maximo)
            item.ToolTip = "Sobre el stock máximo definido para esta bodega.";
    }

    /// <summary>
    /// "mín 4 · máx 12". Sin umbrales no se escribe nada: una línea que
    /// dice "sin mínimo" en cada fila es ruido, y el estado ya lo dice.
    /// </summary>
    private string Rango(InventarioSaldo f)
    {
        if (f.rbs_stock_minimo == null && f.rbs_stock_maximo == null) return "";

        string texto = "";

        if (f.rbs_stock_minimo != null)
            texto = "mín " + f.rbs_stock_minimo.Value.ToString("N0");

        if (f.rbs_stock_maximo != null)
            texto += (texto.Length > 0 ? " · " : "") + "máx " + f.rbs_stock_maximo.Value.ToString("N0");

        return "<span class=\"rango\">" + texto + "</span>";
    }

    /// <summary>
    /// En qué estado está esta fila. **Una sola función**, y de acá salen el
    /// chip y el filtro.
    ///
    /// Si el combo clasificara por su cuenta, tarde o temprano el filtro
    /// "Hora de pedir" devolvería filas cuyo chip dice otra cosa, y el
    /// usuario tendría razón en no volver a confiar en ninguno de los dos.
    ///
    /// Cinco estados, no dos: "sin umbral" no es lo mismo que "está bien"
    /// —nadie definió cuánto debería haber— y confundirlos esconde el
    /// trabajo de configuración que falta.
    /// </summary>
    private string EstadoCodigo(InventarioSaldo f)
    {
        if (f.bajo_minimo) return "BAJO";
        if (f.sobre_maximo) return "SOBRE";
        if (f.rbs_stock_minimo == null) return "SIN";

        // Cerca del punto de reposición: todavía no es alerta, pero es
        // cuando conviene pedir. Avisar recién en el mínimo llega tarde.
        if (f.rbs_punto_reposicion != null && f.isa_cantidad <= f.rbs_punto_reposicion.Value)
            return "PEDIR";

        return "RANGO";
    }

    /// <summary>El badge, a partir del mismo código que filtra el combo.</summary>
    private string Estado(InventarioSaldo f)
    {
        switch (EstadoCodigo(f))
        {
            case "BAJO":
                decimal falta = (f.rbs_stock_minimo ?? 0) - f.isa_cantidad;

                return "<span class=\"grid-estado-chip is-alerta\">"
                     + "<i class=\"mdi mdi-alert-circle\"></i>Faltan " + falta.ToString("N0")
                     + "</span>";

            case "SOBRE":
                return "<span class=\"grid-estado-chip is-advertencia\">"
                     + "<i class=\"mdi mdi-arrow-up-bold\"></i>Sobre el máximo</span>";

            case "SIN":
                return "<span class=\"grid-estado-chip is-neutro\">"
                     + "<i class=\"mdi mdi-help-circle-outline\"></i>Sin umbral</span>";

            case "PEDIR":
                return "<span class=\"grid-estado-chip is-advertencia\">"
                     + "<i class=\"mdi mdi-cart-outline\"></i>Hora de pedir</span>";

            default:
                return "<span class=\"grid-estado-chip is-exito\">"
                     + "<i class=\"mdi mdi-check-circle\"></i>En rango</span>";
        }
    }

    protected void CargarGrid()
    {
        InventarioController controller = new InventarioController();

        /* El texto y la bodega se filtran EN EL SP: SEL_INVENTARIO_SALDO ya
           recibe @FILTRO y @BODEGA. Traer todo y recortar en memoria sería
           traer de más el día que la planta tenga cinco mil repuestos.

           El estado, en cambio, se filtra acá: se calcula a partir de la
           cantidad y del umbral, y esa regla vive en EstadoCodigo. */
        InventarioSaldo filtro = new InventarioSaldo();

        if (!string.IsNullOrEmpty(wucFiltro.Filtro())) filtro.filtro = wucFiltro.Filtro();

        RadComboBox2 cboBodega = (RadComboBox2)wucFiltro.FindControl("cboBodega");

        if (cboBodega != null && !string.IsNullOrEmpty(cboBodega.SelectedValue))
            filtro.isa_bodega = int.Parse(cboBodega.SelectedValue);

        List<InventarioSaldo> todo = controller.GetSaldos(filtro);

        if (todo == null) todo = new List<InventarioSaldo>();

        /* El resumen cuenta sobre el TOTAL, no sobre lo filtrado. Si contara
           lo filtrado, elegir "En rango" mostraria "0 bajo el minimo" y
           daria a entender que el problema se resolvio. */
        int bajo = 0, sobre = 0, pedir = 0;

        foreach (InventarioSaldo s in todo)
        {
            switch (EstadoCodigo(s))
            {
                case "BAJO": bajo++; break;
                case "SOBRE": sobre++; break;
                case "PEDIR": pedir++; break;
            }
        }

        litAlertas.Text = Resumen(todo.Count, bajo, sobre, pedir);

        // ---- El filtro ----
        RadComboBox2 cboEstado = (RadComboBox2)wucFiltro.FindControl("cboEstado");

        string estado = (cboEstado != null ? cboEstado.SelectedValue : "") ?? "";
        estado = estado.Trim();

        if (estado.Length > 0)
        {
            List<InventarioSaldo> filtrado = new List<InventarioSaldo>();

            foreach (InventarioSaldo s in todo)
            {
                string codigo = EstadoCodigo(s);

                // "Fuera de umbral" agrupa los dos extremos: es la vista con
                // la que el bodeguero empieza el dia y no deberia obligarlo
                // a mirar dos veces.
                bool calza = (estado == "FUERA")
                    ? (codigo == "BAJO" || codigo == "SOBRE")
                    : (codigo == estado);

                if (calza) filtrado.Add(s);
            }

            todo = filtrado;

            if (todo.Count == 0)
                litAlertas.Text += " <span class=\"sigma-inv-vacio\">"
                                 + "Ninguna fila en ese estado.</span>";
        }

        Grid.DataSource = todo;
    }

    /// <summary>
    /// El encabezado del listado.
    ///
    /// Las tres alertas van separadas porque no son el mismo problema ni las
    /// resuelve la misma persona: quedarse corto de una pieza critica es una
    /// compra urgente, tener de mas es plata detenida, y "hora de pedir" es
    /// una compra normal que todavia se puede planificar.
    /// </summary>
    private string Resumen(int total, int bajo, int sobre, int pedir)
    {
        if (bajo == 0 && sobre == 0 && pedir == 0)
            return "<span class=\"grid-estado-chip is-exito\">"
                 + "<i class=\"mdi mdi-check-circle\"></i>Todo en rango</span> "
                 + total + " combinación(es) de repuesto y bodega con existencia.";

        string html = "";

        if (bajo > 0)
            html += "<span class=\"grid-estado-chip is-alerta\">"
                  + "<i class=\"mdi mdi-alert-circle\"></i>" + bajo + " bajo el mínimo</span> ";

        if (sobre > 0)
            html += "<span class=\"grid-estado-chip is-advertencia\">"
                  + "<i class=\"mdi mdi-arrow-up-bold\"></i>" + sobre + " sobre el máximo</span> ";

        if (pedir > 0)
            html += "<span class=\"grid-estado-chip is-advertencia\">"
                  + "<i class=\"mdi mdi-cart-outline\"></i>" + pedir + " por pedir</span> ";

        return html + "de " + total + " con existencia.";
    }

}
