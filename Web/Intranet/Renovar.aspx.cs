using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Mi suscripción y su renovación (ANEXO F §6.6 · HU-193).
///
/// Es la única pantalla que sigue abierta cuando la suscripción venció. Por
/// eso está en `SuscripcionAcceso.EXENTAS` y en `Token.EXENTAS`: bloquear
/// sin dejar a dónde ir sería encerrar al cliente, que no podría ni ver
/// cuánto debe ni a quién escribirle.
///
/// También se llega estando al día, desde el aviso del encabezado: sirve de
/// consulta del estado y del consumo del plan.
/// </summary>
public partial class Renovar : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            GridPeriodos.AddColumn("SPE_FECHA_INICIO", "DESDE", Width: "14%", DataFormat: "{0:dd-MM-yyyy}");
            GridPeriodos.AddColumn("SPE_FECHA_FIN", "HASTA", Width: "14%", DataFormat: "{0:dd-MM-yyyy}");
            GridPeriodos.AddColumn("PLC_NOMBRE", "PLAN", Width: "18%");
            GridPeriodos.AddColumn("PCB_NOMBRE", "PERIODICIDAD", Width: "16%");
            GridPeriodos.AddColumn("SPE_MONTO_CLP", "MONTO", Width: "13%", DataFormat: "{0:C0}", Align: HorizontalAlign.Right);
            GridPeriodos.AddColumn("SPE_MONTO_PAGADO_CLP", "PAGADO", Width: "13%", DataFormat: "{0:C0}", Align: HorizontalAlign.Right);
            GridPeriodos.AddColumn("SALDO_CLP", "SALDO", Width: "12%", DataFormat: "{0:C0}", Align: HorizontalAlign.Right);

            GridLimites.AddColumn("FUN_NOMBRE", "LÍMITE", Width: "34%");
            GridLimites.AddColumn("CONSUMO", "EN USO", Width: "16%", Align: HorizontalAlign.Right);
            GridLimites.AddColumn("TOPE", "TOPE DEL PLAN", Width: "18%", Align: HorizontalAlign.Right);
            GridLimites.AddColumn("DISPONIBLE", "DISPONIBLE", Width: "16%", Align: HorizontalAlign.Right);
            GridLimites.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "16%", ItemPosition: HorizontalAlign.Center);

            GridPagos.AddColumn("SPA_ID", "", Width: "4%");
            GridPagos.AddColumn("SPA_FECHA_TRANSFERENCIA", "TRANSFERIDO EL", Width: "15%", DataFormat: "{0:dd-MM-yyyy}");
            GridPagos.AddColumn("SPA_BANCO", "BANCO", Width: "18%");
            GridPagos.AddColumn("SPA_NUMERO_OPERACION", "N° OPERACIÓN", Width: "17%");
            GridPagos.AddColumn("SPA_MONTO_DECLARADO_CLP", "DECLARADO", Width: "15%", DataFormat: "{0:C0}", Align: HorizontalAlign.Right);
            GridPagos.AddColumn("SPA_MONTO_VERIFICADO_CLP", "VERIFICADO", Width: "15%", DataFormat: "{0:C0}", Align: HorizontalAlign.Right);
            GridPagos.AddTemplateColumn("estadoChip", "", "ESTADO", Width: "16%", ItemPosition: HorizontalAlign.Center);
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        int cliente = SitioBase.Session.ClienteId();

        if (cliente == 0)
        {
            // Cuenta de plataforma: no tiene suscripción propia que mirar.
            litChipEstado.Text = "Sin cliente";
            litTitulo.Text = "Selecciona un cliente";
            litMensaje.Text = "Esta pantalla muestra la suscripción del cliente con el que estás trabajando.";
            return;
        }

        PintarEstado();
        PintarPeriodos(cliente);
        PintarLimites(cliente);
        PintarPagos(cliente);
    }

    /// <summary>
    /// Los pagos que este cliente declaró, y el botón para declarar uno más.
    ///
    /// La función vivía en Comercial &gt; Pagos, que es la vista de TODAS las
    /// suscripciones y dejó de ser del cliente cuando se le quitaron los
    /// permisos de plataforma. Aquí es donde corresponde.
    ///
    /// El permiso se pregunta con <c>Token.Puede</c> y NO con
    /// <c>PuedeFuncion</c>: las funciones se resuelven contra la página
    /// actual, y "Declarar pago" cuelga de Pagos.aspx. Preguntando desde
    /// aquí la respuesta sería siempre no, y el botón no aparecería nunca.
    /// </summary>
    protected void PintarPagos(int cliente)
    {
        SuscripcionPagoController controller = new SuscripcionPagoController();

        List<SuscripcionPago> pagos = controller.GetPagos(
            new SuscripcionPago { filtro_cliente = cliente });

        bool puedeDeclarar = Token.Puede("DECLARAR PAGO SUSCRIPCION");

        // Sin pagos y sin permiso para declarar, la sección no aporta nada.
        pnlPagos.Visible = puedeDeclarar || (pagos != null && pagos.Count > 0);

        if (!pnlPagos.Visible) return;

        GridPagos.MasterTableView.CommandItemDisplay = puedeDeclarar
            ? GridCommandItemDisplay.Top
            : GridCommandItemDisplay.None;

        GridPagos.DataSource = pagos;
        GridPagos.DataBind();
    }

    protected void lnkDeclarar_Click(object sender, EventArgs e)
    {
        // Id=0 es "nuevo". Va cifrado como en el resto del sitio, y
        // Querystring.Entero lo lee sin lanzar si llega ilegible.
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=0"));
        Tools.tools.ClientExecute("abrirPago('" + query + "')");
    }

    protected void GridPagos_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("spa_id").ToString();

                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));

                HyperLink ver = new HyperLink();
                ver.ID = "lnkVer" + id;
                ver.CssClass = "icono_Editar";
                ver.NavigateUrl = "javascript:void(0)";
                ver.Attributes.Add("onclick", "abrirPago('" + query + "')");
                item["SPA_ID"].Controls.Add(ver);

                // El color sale del CÓDIGO y el texto del NOMBRE: el código
                // es estable, el nombre es redactable.
                string nombre = DataBinder.Eval(item.DataItem, "spo_nombre") != null
                    ? DataBinder.Eval(item.DataItem, "spo_nombre").ToString() : "";
                string codigo = DataBinder.Eval(item.DataItem, "spo_codigo") != null
                    ? DataBinder.Eval(item.DataItem, "spo_codigo").ToString() : "";

                Label lbl = new Label();
                lbl.Text = nombre;
                lbl.CssClass = "grid-estado-chip " + ChipDePago(codigo);
                item["estadoChip"].Controls.Add(lbl);
            }
        }
    }

    private string ChipDePago(string codigo)
    {
        switch ((codigo ?? "").Trim().ToUpper())
        {
            case "VERIFICADO": return "is-exito";
            case "RECHAZADO": return "is-alerta";
            case "EN REVISION": return "is-info";
            // DECLARADO: todavía no lo miró nadie. Neutro, no alerta: que
            // exista es lo esperado, no un problema.
            default: return "is-neutro";
        }
    }

    protected void PintarEstado()
    {
        SuscripcionEstadoCliente estado = SitioBase.SuscripcionAcceso.Estado();

        if (estado == null || estado.SinSuscripcion)
        {
            litChipEstado.Text = "Sin suscripción";
            litTitulo.Text = "Todavía no hay un plan contratado";
            litMensaje.Text = "Este cliente está configurado pero aún no tiene una suscripción activa. " +
                              "Mientras tanto no se aplica ningún límite de plan.";
            lblPlan.Text = "—";
            lblVigencia.Text = "—";
            return;
        }

        lblVigencia.Text = estado.fecha_fin != null
            ? estado.fecha_fin.Value.ToString("dd-MM-yyyy")
            : "—";

        // El texto cambia según el estado porque lo que la persona tiene
        // que hacer es distinto en cada uno.
        switch (estado.estado)
        {
            case "VIGENTE":
                litChipEstado.Text = "Vigente";
                litTitulo.Text = "Tu suscripción está al día";
                litMensaje.Text = estado.dias_restantes != null
                    ? "Quedan " + estado.dias_restantes + " días de vigencia."
                    : "";
                break;

            case "EN GRACIA":
                litChipEstado.Text = "En período de gracia";
                litTitulo.Text = "Tu suscripción venció, pero sigues trabajando";
                litMensaje.Text = "Estás dentro del período de gracia. Regulariza el pago para no perder el acceso.";
                break;

            case "VENCIDA":
                litChipEstado.Text = "Vencida";
                litTitulo.Text = "Tu suscripción venció";
                litMensaje.Text = "El acceso al sistema está suspendido hasta regularizar el pago. " +
                                  "Toda tu información sigue completa y se recupera al renovar.";
                break;

            case "SUSPENDIDA":
                litChipEstado.Text = "Suspendida";
                litTitulo.Text = "Tu suscripción está suspendida";
                litMensaje.Text = "Contáctanos para revisar la situación y reactivarla.";
                break;

            case "CANCELADA":
                litChipEstado.Text = "Cancelada";
                litTitulo.Text = "Tu suscripción está cancelada";
                litMensaje.Text = "Contáctanos si quieres volver a activarla. Tus datos siguen guardados.";
                break;

            default:
                litChipEstado.Text = estado.estado;
                litTitulo.Text = "Estado de tu suscripción";
                litMensaje.Text = "";
                break;
        }
    }

    protected void PintarPeriodos(int cliente)
    {
        SuscripcionPeriodoController controller = new SuscripcionPeriodoController();

        List<SuscripcionPeriodo> periodos = controller.GetPeriodos(
            new SuscripcionPeriodo { filtro_cliente = cliente, filtro_solo_impagos = true });

        decimal saldo = 0;

        if (periodos != null)
            foreach (SuscripcionPeriodo p in periodos)
                saldo += p.saldo_clp;

        lblSaldo.Text = saldo > 0 ? saldo.ToString("C0") : "Sin saldo pendiente";

        if (periodos != null && periodos.Count > 0)
        {
            GridPeriodos.DataSource = periodos;
            GridPeriodos.DataBind();
            pnlPeriodos.Visible = true;

            // El plan se toma del período más reciente, que es el que
            // refleja lo contratado hoy.
            lblPlan.Text = periodos[0].plc_nombre;
        }
        else
        {
            pnlPeriodos.Visible = false;
            if (string.IsNullOrEmpty(lblPlan.Text)) lblPlan.Text = "—";
        }
    }

    protected void PintarLimites(int cliente)
    {
        SuscripcionController controller = new SuscripcionController();
        List<ClienteLimite> limites = controller.GetLimites(cliente);

        if (limites == null || limites.Count == 0)
        {
            pnlLimites.Visible = false;
            return;
        }

        GridLimites.DataSource = limites;
        GridLimites.DataBind();
        pnlLimites.Visible = true;

        /* HU-192 #2: aviso cuando algun limite pasa del 80 %. Se calcula
           contra tope y consumo, que ya vienen del SP. */
        List<string> cerca = new List<string>();
        foreach (ClienteLimite l in limites)
            if (l.tope != null && l.tope > 0 && l.consumo / l.tope.Value >= 0.8m)
                cerca.Add(l.fun_nombre.ToLower() + " (" + l.consumo.ToString("0.##") + " de " + l.tope.Value.ToString("0.##") + ")");

        litAvisoLimites.Text = cerca.Count == 0 ? "" :
            "<div class=\"sg-renovar-aviso\"><i class=\"mdi mdi-alert-outline\"></i><div>" +
            "<strong>Estás cerca del límite</strong> en " + string.Join(", ", cerca.ToArray()) +
            ". Cuando lo alcances no podrás crear más; si necesitas ampliarlo, cambia de plan o contáctanos.</div></div>";

        PintarIncluye();
    }

    /// <summary>
    /// HU-192 #1: las funcionalidades del plan contratado, incluidas y no
    /// incluidas. Los limites numericos ya estan en la grilla de arriba, asi
    /// que aqui van solo las de inclusion.
    /// </summary>
    protected void PintarIncluye()
    {
        SuscripcionEstadoCliente estado = SitioBase.SuscripcionAcceso.Estado();
        if (estado == null || estado.SinSuscripcion || estado.plan_comercial == null) return;

        PlanComercialController controller = new PlanComercialController();
        List<PlanFuncionalidad> lista = controller.GetFuncionalidades(estado.plan_comercial.Value, estado.cliente);
        if (lista == null || lista.Count == 0) return;

        System.Text.StringBuilder si = new System.Text.StringBuilder();
        System.Text.StringBuilder no = new System.Text.StringBuilder();

        foreach (PlanFuncionalidad f in lista)
        {
            if (f.pcf_tipo == 2 || (f.fun_codigo ?? "").StartsWith("LIMITE ")) continue;   // los topes ya estan en "Uso de tu plan"
            string item = "<div class=\"sg-renovar-incluye-item\">" + Server.HtmlEncode(f.fun_nombre) + "</div>";
            if (f.pcf_incluida) si.Append(item); else no.Append(item);
        }

        litIncluidas.Text = si.Length > 0 ? si.ToString() : "<div class=\"sg-renovar-incluye-item is-vacio\">—</div>";
        litNoIncluidas.Text = no.Length > 0 ? no.ToString() : "<div class=\"sg-renovar-incluye-item is-vacio\">Tu plan incluye todo.</div>";
        pnlIncluye.Visible = true;
    }

    protected void GridLimites_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;

                string estado = DataBinder.Eval(item.DataItem, "estado") != null
                    ? DataBinder.Eval(item.DataItem, "estado").ToString()
                    : "";

                /* HU-192 #2: al 80 % del tope el chip avisa antes de llegar
                   al limite. */
                decimal? tope = DataBinder.Eval(item.DataItem, "tope") as decimal?;
                decimal consumo = DataBinder.Eval(item.DataItem, "consumo") is decimal ? (decimal)DataBinder.Eval(item.DataItem, "consumo") : 0;
                if (estado == "DISPONIBLE" && tope != null && tope > 0 && consumo / tope.Value >= 0.8m)
                    estado = "CERCA DEL LIMITE";

                Label lbl = new Label();
                lbl.Text = Legible(estado);
                lbl.CssClass = "grid-estado-chip " + Chip(estado);
                item["estadoChip"].Controls.Add(lbl);

                // Sin tope no hay número que mostrar: un guion se lee mejor
                // que una celda vacía, que parece un dato que falta.
                if (item["TOPE"].Text == "&nbsp;" || item["TOPE"].Text == "")
                    item["TOPE"].Text = "Sin tope";
                if (item["DISPONIBLE"].Text == "&nbsp;" || item["DISPONIBLE"].Text == "")
                    item["DISPONIBLE"].Text = "—";
            }
        }
    }

    private string Legible(string estado)
    {
        switch (estado)
        {
            case "SIN SUSCRIPCION": return "Sin plan";
            case "NO INCLUIDA": return "No incluida";
            case "SIN TOPE": return "Sin tope";
            case "AL LIMITE": return "Al límite";
            case "CERCA DEL LIMITE": return "Cerca del límite";
            default: return "Disponible";
        }
    }

    private string Chip(string estado)
    {
        switch (estado)
        {
            case "AL LIMITE": return "is-alerta";
            case "CERCA DEL LIMITE": return "is-advertencia";
            case "NO INCLUIDA": return "is-neutro";
            case "SIN TOPE": return "is-acento";
            case "SIN SUSCRIPCION": return "is-neutro";
            default: return "is-exito";
        }
    }
}
