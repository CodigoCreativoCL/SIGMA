using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// La suscripción del cliente seleccionado (ANEXO F §5).
///
/// Es una grilla de una fila. Podría haber sido una ficha suelta, pero la
/// grilla es la forma en que el sitio muestra listados y así el día que un
/// cliente pueda tener más de una suscripción -o que se quiera mirar la
/// cartera completa- no hay que rehacer la pantalla.
///
/// No hay botón Eliminar. Una suscripción con períodos emitidos es
/// historia de cobranza: se suspende o se cancela desde su ficha, no se
/// borra.
///
/// EL PANEL DE ARRIBA MUESTRA EL ESTADO CALCULADO
///   VENCIDA y EN GRACIA no están guardadas en ninguna columna (§6.1): las
///   calcula FNC_SUSCRIPCION_VIGENTE cada vez que se consulta. Se muestran
///   arriba y no solo en una celda porque es la única información de esta
///   pantalla que decide si el cliente puede o no trabajar hoy.
/// </summary>
public partial class View_Comercial_Suscripciones_Suscripciones : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("SUS_ID", "", Width: "3%");
            Grid.AddColumn("PLC_NOMBRE", "PLAN", Width: "18%");
            Grid.AddColumn("SUE_NOMBRE", "ESTADO REGISTRADO", Width: "16%");
            Grid.AddColumn("SUS_FECHA_INICIO", "DESDE", Width: "11%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("SUS_FECHA_FIN", "HASTA", Width: "11%", DataFormat: "{0:dd-MM-yyyy}");
            Grid.AddColumn("SUS_KEY_PREFIJO", "CLAVE", Width: "12%");
            Grid.AddColumn("SUS_CONTACTO_EMAIL", "CONTACTO", Width: "17%");
            Grid.AddTemplateColumn("estadoChip", "", "VIGENCIA", Width: "12%", ItemPosition: HorizontalAlign.Center);
        }

        Tools.tools.RegisterPostBackScript(Grid);
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;

        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;

        if (!hayCliente) return;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();
    }

    protected void CargarGrid()
    {
        SuscripcionController controller = new SuscripcionController();

        Suscripcion filtro = new Suscripcion();
        filtro.filtro_cliente = SitioBase.Session.ClienteId();

        List<Suscripcion> lista = controller.GetSuscripciones(filtro);

        Grid.DataSource = lista;

        CargarPanel(lista);

        /* Crear se ofrece solo si el cliente NO tiene suscripción. Es una
           por cliente y para siempre (§5.1): el SP rechaza la segunda, pero
           ofrecer un botón que siempre falla es peor que no ofrecerlo. */
        bool tiene = (lista != null && lista.Count > 0);

        Grid.MasterTableView.CommandItemDisplay =
            (!tiene && Token.PuedeFuncion("Crear y editar"))
                ? GridCommandItemDisplay.Top
                : GridCommandItemDisplay.None;
    }

    protected void CargarPanel(List<Suscripcion> lista)
    {
        if (lista == null || lista.Count == 0)
        {
            litEstado.Text = "<span class=\"grid-estado-chip is-neutro\">Sin suscripción</span> " +
                             "Este cliente todavía no tiene suscripción. Puede existir mientras se " +
                             "negocia: crearla es un paso aparte del alta del cliente.";
            pnlEstado.Visible = true;
            return;
        }

        Suscripcion s = lista[0];

        /* SIN FECHA DE TERMINO NO ESTA "VENCIDA": NO HA EMPEZADO.

           `FNC_SUSCRIPCION_VIGENTE` devuelve VENCIDA cuando `sus_fecha_fin`
           es NULL, y para el acceso eso es correcto: sin pago no hay
           vigencia. Pero la palabra manda a buscar un pago que caduco cuando
           lo que hay es un cobro que nadie pago todavia.

           Se corrige la ETIQUETA, no la regla: el permiso de operar sigue
           saliendo del mismo bit y la funcion compartida con la API no se
           toca. */
        bool sinActivar = s.sus_fecha_fin == null;

        string chip = sinActivar
            ? "<span class=\"grid-estado-chip is-advertencia\">Sin activar</span> "
            : "<span class=\"grid-estado-chip " + ChipDeEstado(s.estado) + "\">" +
              TextoEstado(s.estado) + "</span> ";

        string detalle;

        if (sinActivar)
        {
            /* No se afirma que NO haya periodo emitido: puede haberlo, emitido
               y sin pagar, que es el caso normal apenas se cobra. Lo que es
               cierto en los dos casos es que no hay ninguno PAGADO. */
            detalle = "No hay ningún período pagado, así que la suscripción existe pero todavía " +
                      "no habilita nada. La pone en marcha el primer pago verificado, que es " +
                      "el que le fija la fecha de término.";
        }
        else if (s.dias_restantes != null && s.dias_restantes >= 0)
        {
            detalle = "Vigente hasta el " + s.sus_fecha_fin.Value.ToString("dd-MM-yyyy") +
                      " &middot; quedan " + s.dias_restantes + " día(s).";
        }
        else
        {
            detalle = "Venció el " + s.sus_fecha_fin.Value.ToString("dd-MM-yyyy") +
                      ". Los días de gracia del plan son " + s.sus_dias_gracia + ".";
        }

        if (!s.puede_operar)
            detalle += " <strong>El cliente no puede operar.</strong>";

        litEstado.Text = chip + detalle;
        pnlEstado.Visible = true;
    }

    protected void rgrSuscripciones_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("sus_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirSuscripcion('" + query + "')");

                item["sus_id"].Controls.Add(Editar);

                string estado = DataBinder.Eval(item.DataItem, "estado") != null
                    ? DataBinder.Eval(item.DataItem, "estado").ToString()
                    : "";

                Label lblEstado = new Label();
                /* Misma correccion que arriba: sin fecha de termino la
                   suscripcion no vencio, no empezo. */
                lblEstado.Text = TextoEstado(estado);
                lblEstado.CssClass = "grid-estado-chip " + ChipDeEstado(estado);
                item["estadoChip"].Controls.Add(lblEstado);
            }
        }
    }

    private string TextoEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VIGENTE": return "Vigente";
            case "EN GRACIA": return "En gracia";
            case "VENCIDA": return "Vencida";
            case "SUSPENDIDA": return "Suspendida";
            case "CANCELADA": return "Cancelada";
            case "": return "Sin períodos";
            default: return estado;
        }
    }

    private string ChipDeEstado(string estado)
    {
        switch ((estado ?? "").Trim().ToUpper())
        {
            case "VIGENTE": return "is-exito";
            // En gracia todavía opera, pero es un aviso: se le acabó el
            // período y está usando el colchón del plan.
            case "EN GRACIA": return "is-info";
            case "VENCIDA": return "is-alerta";
            case "SUSPENDIDA": return "is-alerta";
            case "CANCELADA": return "is-alerta";
            default: return "is-neutro";
        }
    }
}
