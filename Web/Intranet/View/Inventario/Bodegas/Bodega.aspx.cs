using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;

/// <summary>
/// Ficha de una bodega y sus ubicaciones (HU-052).
///
/// LAS UBICACIONES VIVEN AQUI Y NO EN SU PROPIO MANTENEDOR
///   Una ubicacion sin bodega no significa nada. Un mantenedor aparte
///   obligaria a elegir la bodega otra vez, en una pantalla que ya sabe
///   cual es.
/// </summary>
public partial class View_Inventario_Bodegas_Bodega : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// La ubicación que se está editando. Cero es "ninguna, se va a
    /// agregar una nueva". Vive en ViewState porque el alta y la edición
    /// comparten los mismos dos campos: sin esto, al guardar no habría
    /// forma de saber cuál de las dos cosas se pidió.
    /// </summary>
    public int UbicacionId
    {
        get { return ViewState["UbicacionId"] != null ? (int)ViewState["UbicacionId"] : 0; }
        set { ViewState["UbicacionId"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        /* Querystring.Entero recibe el valor TAL COMO VIENE de la URL:
           descifra por dentro. Pasarle el resultado de Descifrar lo hace
           descifrar dos veces, la segunda falla, y como el helper no lanza
           devuelve 0 en silencio: la ficha se abre en blanco como si fuera
           un registro nuevo. */
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack && sender is RadComboBox2)
        {
            RadComboBox2 ctrl = (RadComboBox2)sender;

            if (ctrl.ID == "cboPlanta")
            {
                ClienteInstalacionController controller = new ClienteInstalacionController();

                /* filtro_cliente y filtro_habilitado son STRING en este
                   modelo, no int ni bool. Es la convencion heredada de
                   ClienteInstalacion y se respeta tal cual: cambiarla aca
                   dejaria dos formas de llamar al mismo controller. */
                ClienteInstalacion filtro = new ClienteInstalacion();
                filtro.filtro_cliente = SitioBase.Session.ClienteId().ToString();
                filtro.filtro_habilitado = "1";

                ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                ctrl.AppendDataBoundItems = true;
                ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                ctrl.DataValueField = "cin_id";
                ctrl.DataTextField = "cin_nombre";
                ctrl.DataBind();
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        CargarUbicaciones();
        CargarEtiquetas();
        Bloqueo();

        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnAgregarUbicacion);

        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            BodegaController controller = new BodegaController();
            Bodega entidad = controller.GetBodega(Id);

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Bodega", entidad.bod_codigo);
            txtNombre.Text = entidad.bod_nombre;
            txtDescripcion.Text = entidad.bod_descripcion;

            if (entidad.bod_cliente_instalacion > 0)
                cboPlanta.SelectedValue = entidad.bod_cliente_instalacion.ToString();

            rdbSi.Checked = entidad.bod_habilitado;
            rdbNo.Checked = !entidad.bod_habilitado;

            string met = new BodegaAlmacenamientoController().Metodo(Id);
            RadComboBoxItem im = ddlMetodo.FindItemByValue(met);
            if (im != null) im.Selected = true;

            wucAuditoria.Mostrar(entidad.usuario_creacion_nombre, entidad.bod_fecha_creacion,
                                 entidad.usuario_actualizacion_nombre, entidad.bod_fecha_actualizacion);
        }
        else
        {
            lblId.Text = "Nueva";
        }
    }

    /// <summary>
    /// La grilla de ubicaciones se recarga en cada PreRender, no solo al
    /// entrar: despues de agregar una, la lista tiene que mostrarla sin que
    /// nadie recargue la pantalla.
    /// </summary>
    protected void CargarUbicaciones()
    {
        /* La pestaña se oculta entera, no el panel: una pestaña que al
           abrirla no tiene nada se lee como que la pantalla se rompió. */
        tabUbicaciones.Visible = (Id > 0);
        pnlUbicaciones.Visible = (Id > 0);

        string mapa = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx");
        hlMapa.Visible = Id > 0 && Token.Puede("VER BODEGAS");
        hlMapa.NavigateUrl = mapa + "?ir=BOD-" + Id;

        if (Id == 0) return;

        BodegaAlmacenamientoController alm = new BodegaAlmacenamientoController();
        DataTable racks = alm.Ubicaciones(Id);
        Racks = racks;

        // la convencion de esta bodega y el ultimo numero de cada pasillo, para la vista previa
        List<string> codigos = racks.Rows.Cast<DataRow>().Select(r => Convert.ToString(r["CODIGO"])).ToList();
        string prefijo = BodegaAlmacenamientoController.Prefijo(codigos, CodigoBodega());
        litConvencion.Text = Server.HtmlEncode(BodegaAlmacenamientoController.CodigoRack(prefijo, "A", 1));
        Dictionary<string, int> max = MaximosPorPasillo(codigos);
        litRacksDatos.Text = "<span id=\"bodRacksDatos\" hidden data-prefijo=\"" + Server.HtmlEncode(prefijo) + "\" data-max=\"" +
            Server.HtmlEncode("{" + string.Join(",", max.Select(kv => "\"" + kv.Key + "\":" + kv.Value)) + "}") + "\"></span>" +
            "<script>setTimeout(bodPreview, 0);</script>";
        /* Un boton por pasillo que ya existe y uno para abrir el siguiente:
           elegir con un clic en vez de adivinar que letra escribir. */
        string siguiente = SiguientePasillo(max.Keys);
        System.Text.StringBuilder chips = new System.Text.StringBuilder();
        foreach (string k in max.Keys.OrderBy(x => x.Length).ThenBy(x => x))
            chips.Append("<button type=\"button\" class=\"bod-pas\" data-pasillo=\"").Append(k).Append("\" onclick=\"bodElegir('")
                 .Append(k).Append("')\"><i class=\"mdi mdi-road-variant\"></i>").Append(k).Append(" <small>").Append(max[k])
                 .Append(max[k] == 1 ? " rack" : " racks").Append("</small></button>");
        chips.Append("<button type=\"button\" class=\"bod-pas es-nuevo\" data-nuevo=\"1\" data-pasillo=\"").Append(siguiente)
             .Append("\" onclick=\"bodElegir('").Append(siguiente).Append("')\"><i class=\"mdi mdi-plus\"></i>Nuevo pasillo ").Append(siguiente).Append("</button>");
        litPasillos.Text = chips.ToString();
        if (!IsPostBack && string.IsNullOrEmpty(txtPasillo.Text))
            txtPasillo.Text = max.Count > 0 ? max.Keys.OrderBy(k => k.Length).ThenBy(k => k).Last() : "A";

        // resumen de la pestaña Datos
        DataTable res = alm.Resumen(Id);
        if (res.Rows.Count > 0)
        {
            DataRow r0 = res.Rows[0];
            int movidos = Convert.ToInt32(r0["MOVIDOS"]), contados = Convert.ToInt32(r0["CONTADOS_30"]);
            litResumenMapa.Text = "<div class=\"bod-dato\"><b>" + racks.Rows.Count + "</b> racks en <b>" + max.Count + "</b> pasillo" + (max.Count == 1 ? "" : "s") +
                " · <b>" + contados + "</b> contados en 30 días" + (movidos > 0 ? " · <b>" + movidos + "</b> movidos en el plano" : "") + "</div>";
        }

        pnlSinUbicaciones.Visible = racks.Rows.Count == 0;
        pasilloAnterior = null;
        rptUbicaciones.DataSource = racks;
        rptUbicaciones.DataBind();
    }

    private DataTable Racks;
    private string pasilloAnterior;

    private string CodigoBodega()
    {
        Bodega b = new BodegaController().GetBodega(Id);
        return b != null ? b.bod_codigo : "";
    }

    /// <summary>La letra que sigue a la ultima de una sola letra (C -> D); sin pasillos, A.</summary>
    private static string SiguientePasillo(IEnumerable<string> pasillos)
    {
        List<string> una = pasillos.Where(x => x.Length == 1).OrderBy(x => x).ToList();
        if (una.Count == 0) return "A";
        char c = una.Last()[0];
        return c < 'Z' ? ((char)(c + 1)).ToString() : "AA";
    }

    private static Dictionary<string, int> MaximosPorPasillo(IEnumerable<string> codigos)
    {
        Dictionary<string, int> max = new Dictionary<string, int>();
        foreach (string c in codigos)
        {
            string pa; int n;
            if (!BodegaAlmacenamientoController.LeerCodigo(c, out pa, out n)) continue;
            int v;
            if (!max.TryGetValue(pa, out v) || n > v) max[pa] = n;
        }
        return max;
    }

    private static string Num(decimal v)
    {
        return v.ToString(v == Math.Floor(v) ? "#,##0" : "#,##0.##", new CultureInfo("es-CL"));
    }

    protected void rptUbicaciones_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem)
            return;

        DataRowView u = (DataRowView)e.Item.DataItem;
        int bubId = Convert.ToInt32(u["BUB_ID"]);
        string codigo = Convert.ToString(u["CODIGO"]);
        bool editando = (bubId == UbicacionId);
        bool puedeEditar = Token.Puede("CREAR EDITAR BODEGAS");

        /* Cabecera de pasillo cuando cambia: la lista se lee como el mapa,
           un pasillo detras del otro. Los codigos que no calzan con la
           convencion van juntos al final, como el mapa los pone aparte. */
        string pa; int n;
        string grupo = BodegaAlmacenamientoController.LeerCodigo(codigo, out pa, out n) ? pa : "·";
        if (grupo != pasilloAnterior)
        {
            int cuantos = Racks.Rows.Cast<DataRow>().Count(r =>
            {
                string p2; int n2;
                return (BodegaAlmacenamientoController.LeerCodigo(Convert.ToString(r["CODIGO"]), out p2, out n2) ? p2 : "·") == grupo;
            });
            ((Literal)e.Item.FindControl("litPasillo")).Text = "<div class=\"bod-pasillo\"><i class=\"mdi mdi-road-variant\"></i>" +
                (grupo == "·" ? "Fuera de la convención" : "Pasillo " + Server.HtmlEncode(grupo)) +
                "<span class=\"bod-chip es-muted chip\">" + cuantos + " rack" + (cuantos == 1 ? "" : "s") +
                (grupo == "·" ? " · el mapa los pone en un pasillo aparte" : "") + "</span></div>";
            pasilloAnterior = grupo;
        }

        /* El id viaja en el CommandArgument de cada botón: es el único dato
           que el evento va a recibir, y sacarlo del índice de la fila se
           rompe en cuanto la lista se reordena entre un clic y el otro. */
        string id = bubId.ToString();
        LinkButton editar = (LinkButton)e.Item.FindControl("lnkEditar");
        LinkButton guardar = (LinkButton)e.Item.FindControl("lnkGuardar");
        LinkButton cancelar = (LinkButton)e.Item.FindControl("lnkCancelar");
        editar.CommandArgument = id;
        guardar.CommandArgument = id;
        cancelar.CommandArgument = id;

        Panel vista = (Panel)e.Item.FindControl("pnlVista");
        Panel edicion = (Panel)e.Item.FindControl("pnlEdicion");
        Panel carga = (Panel)e.Item.FindControl("pnlCarga");
        vista.Visible = !editando;
        edicion.Visible = editando;
        carga.Visible = editando;

        /* Mientras una fila se edita, el lápiz del resto desaparece: dos
           filas abiertas a la vez dejarían dudando cuál se va a guardar. */
        editar.Visible = (!editando && UbicacionId == 0 && puedeEditar);
        guardar.Visible = editando;
        cancelar.Visible = editando;

        decimal? kg = u["CARGA"] == DBNull.Value ? (decimal?)null : Convert.ToDecimal(u["CARGA"]);
        if (editando)
        {
            ((TextBox2)e.Item.FindControl("txtNombre")).Text = Convert.ToString(u["NOMBRE"]);
            ((TextBox2)e.Item.FindControl("txtCarga")).Text = kg.HasValue ? kg.Value.ToString("0.##", CultureInfo.InvariantCulture) : "";
        }
        else
        {
            ((Literal)e.Item.FindControl("litNombre")).Text = Server.HtmlEncode(Convert.ToString(u["NOMBRE"])) +
                (Convert.ToBoolean(u["MOVIDO"]) ? " <span class=\"bod-chip es-blue\" title=\"Se movió a mano en el plano del mapa 3D\"><i class=\"mdi mdi-cursor-move\"></i>movido</span>" : "");
            ((Literal)e.Item.FindControl("litCarga")).Text = kg.HasValue ? "<b>" + Num(kg.Value) + "</b> kg" : "1.000 kg <span style=\"opacity:.7\">(estándar)</span>";
        }

        int reps = Convert.ToInt32(u["REPUESTOS"]);
        ((Literal)e.Item.FindControl("litGuarda")).Text = reps == 0
            ? "<span class=\"bod-chip es-muted\">vacío</span>"
            : "<b>" + reps + "</b> rep. · " + Num(Convert.ToDecimal(u["CANTIDAD"])) + " un";

        if (u["CONTEO_FECHA"] == DBNull.Value)
            ((Literal)e.Item.FindControl("litConteo")).Text = "<span class=\"bod-chip es-warning\">nunca</span>";
        else
        {
            DateTime f = Convert.ToDateTime(u["CONTEO_FECHA"]);
            int dias = (int)(DateTime.Now.Date - f.Date).TotalDays;
            ((Literal)e.Item.FindControl("litConteo")).Text = "<span class=\"bod-chip " + (dias > 90 ? "es-warning" : "es-cyan") + "\">" +
                (dias <= 0 ? "hoy" : dias == 1 ? "ayer" : "hace " + dias + " días") + "</span>";
        }

        HyperLink hl = (HyperLink)e.Item.FindControl("hlMapaRack");
        hl.Visible = Token.Puede("VER BODEGAS");
        hl.NavigateUrl = ResolveUrl("~/View/Inventario/Bodegas/BodegaMapa3D.aspx") + "?ir=UBI-" + bubId;
    }

    protected void rptUbicaciones_ItemCommand(object source, RepeaterCommandEventArgs e)
    {
        try
        {
            int id = 0;
            int.TryParse(Convert.ToString(e.CommandArgument), out id);

            if (e.CommandName == "Cancelar")
            {
                UbicacionId = 0;
            }
            else if (e.CommandName == "Editar")
            {
                if (!Token.Puede("CREAR EDITAR BODEGAS"))
                    throw new Exception("No tiene permiso para editar ubicaciones.");

                UbicacionId = id;
            }
            else if (e.CommandName == "Guardar")
            {
                TextBox2 txt = (TextBox2)e.Item.FindControl("txtNombre");
                string nombre = txt.Text.Trim();

                if (nombre.Length == 0)
                    throw new Exception("Indique el nombre de la ubicación.");

                /* Solo viaja el nombre. El código identifica la ubicación y ya
                   está impreso en la etiqueta del estante: cambiarlo dejaría
                   las etiquetas pegadas apuntando a algo que no existe, así
                   que no se ofrece siquiera. */
                BodegaUbicacion entidad = new BodegaUbicacion();
                entidad.bub_id = id;
                entidad.bub_bodega = Id;
                entidad.bub_nombre = nombre;
                entidad.bub_habilitado = true;

                /* La carga por nivel va por su propio SP (el mismo del mapa):
                   se lee antes de guardar nada, para que un numero mal escrito
                   no deje el nombre guardado y la carga no. */
                string tc = ((TextBox2)e.Item.FindControl("txtCarga")).Text.Trim().Replace(" ", "");
                if (tc.Contains(",") && !tc.Contains(".")) tc = tc.Replace(",", ".");
                decimal kg = 0;
                if (tc.Length > 0 && (!decimal.TryParse(tc, NumberStyles.Number, CultureInfo.InvariantCulture, out kg) || kg <= 0))
                    throw new Exception("La carga por nivel es un número mayor que cero, en kg (vacío = 1.000 kg).");

                BodegaController controller = new BodegaController();
                Respuesta respuesta = controller.GuardarUbicacion(entidad);

                if (respuesta.error)
                {
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                    return;
                }

                Respuesta rc = new BodegaAlmacenamientoController().GuardarCarga(id, tc.Length > 0 ? (decimal?)kg : null);
                if (rc.error)
                {
                    Tools.tools.ClientAlert("El nombre se guardó, pero no la carga: " + rc.detalle, "alerta");
                    return;
                }

                UbicacionId = 0;
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }

            /* Page_PreRender vuelve a cargar la lista, así que no se recarga
               acá: hacerlo dos veces por clic es trabajo de base repetido. */
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// Los tres accesos de impresión.
    ///
    /// Van como onclick a una ventana emergente y no como postback porque lo
    /// que abren es una pantalla que se imprime: dentro del modal, el
    /// navegador imprimiría la ficha de la bodega en lugar de las etiquetas.
    /// </summary>
    protected void CargarEtiquetas()
    {
        /* Sin bodega guardada no hay nada que rotular, y las ubicaciones
           todavía no existen. */
        pnlEtiquetas.Visible = (Id > 0 && Token.Puede("IMPRIMIR ETIQUETAS"));

        if (!pnlEtiquetas.Visible) return;

        btnEtiquetaBodega.Attributes["onclick"] =
            "return abrirEtiquetas('" + QueryEtiqueta("BODEGA") + "');";

        btnEtiquetaUbicaciones.Attributes["onclick"] =
            "return abrirEtiquetas('" + QueryEtiqueta("UBICACION") + "');";

        /* La etiqueta con el repuesto solo tiene sentido si hay algo
           guardado: en una bodega recién creada saldría una hoja en blanco y
           el bodeguero creería que la impresión falló.

           Deshabilitada dice POR QUE, en la nota de la propia tarjeta: una
           opción apagada sin explicación se lee como que algo se rompió. */
        if (HayExistencia())
        {
            btnEtiquetaConRepuesto.Attributes["onclick"] =
                "return abrirEtiquetas('" + QueryEtiqueta("UBICACION_REPUESTO") + "');";
        }
        else
        {
            btnEtiquetaConRepuesto.Attributes["disabled"] = "disabled";
            litNotaConRepuesto.Text = "Todavía no hay existencia registrada en esta bodega.";
        }
    }

    /// <summary>
    /// La etiqueta de bodega lleva el id de la bodega; las de ubicación se
    /// acotan con @BODEGA para no imprimir los estantes de todas.
    /// </summary>
    protected string QueryEtiqueta(string origen)
    {
        string datos = "Origen=" + origen + "&Bodega=" + Id;

        if (origen == "BODEGA") datos += "&Ids=" + Id;

        return Server.UrlEncode(Tools.Crypto.Encrypt(datos));
    }

    protected bool HayExistencia()
    {
        InventarioController controller = new InventarioController();

        List<InventarioSaldo> saldos = controller.GetSaldos(
            new InventarioSaldo { isa_bodega = Id });

        return (saldos != null && saldos.Count > 0);
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR BODEGAS");

        // El codigo solo se escribe al crear: despues identifica la bodega.
        /* Nunca se escribe a mano: lo genera el SP al crear, y despues
               identifica el registro. */
            litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Bodega");
            txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues el codigo ya esta impreso en su etiqueta
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        cboPlanta.ReadOnly = !puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;

        btnGuardar.Visible = puedeEditar;
        pnlAltaRacks.Visible = puedeEditar;
        ddlMetodo.ReadOnly = !puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrEmpty(cboPlanta.SelectedValue))
                throw new Exception("Debe elegir la planta a la que pertenece la bodega.");

            Bodega entidad = new Bodega();
            BodegaController controller = new BodegaController();

            entidad.bod_id = Id;
            /* ---- CODIGO AUTOMATICO ----
               Al crear se manda AUTO y el SP lo genera como BOD-<id>: el
               codigo depende del ID, y el ID no existe hasta despues del
               INSERT, asi que no hay forma de calcularlo antes.

               AUTO y no vacio: el SP valida que el codigo venga ANTES de
               insertar, asi que un vacio se rechaza con "indique el codigo".
               AUTO pasa esa validacion, nunca queda guardado, y el SP lo
               reemplaza en cuanto conoce el ID.

               Al editar viaja el que ya tiene. No se regenera nunca: el
               codigo esta impreso en su etiqueta, y cambiarlo dejaria la
               etiqueta pegada apuntando a algo que no existe. */
            entidad.bod_codigo = SitioBase.CodigoModulo.Componer("Bodega", txtCodigo.Text);
            entidad.bod_nombre = txtNombre.Text.Trim();
            entidad.bod_descripcion = txtDescripcion.Text.Trim();
            entidad.bod_cliente_instalacion = int.Parse(cboPlanta.SelectedValue);
            entidad.bod_habilitado = rdbSi.Checked;

            /* Deshabilitar pasa por DEL_BODEGA, que es el camino con guarda:
               UPD_BODEGA tambien lo haria, pero sin comprobar la existencia
               ni arrastrar las ubicaciones. Si rechaza, no se guarda nada
               mas: seguir seria entrar por la puerta que acaba de cerrarse. */
            if (Id > 0 && rdbNo.Checked)
            {
                Respuesta baja = controller.DeleteBodega(Id);

                if (baja.error)
                {
                    Tools.tools.ClientAlert(baja.detalle, "alerta");
                    return;
                }
            }

            Respuesta respuesta = (Id > 0)
                ? controller.UpdateBodega(entidad)
                : controller.InsertBodega(entidad);

            if (!respuesta.error)
            {
                /* El metodo va por UPD_BODEGA_METODO_SALIDA, el mismo SP del
                   mapa. Si falla, la bodega ya quedo guardada: se avisa y no
                   se cierra. */
                Respuesta rm = new BodegaAlmacenamientoController().GuardarMetodo(Id > 0 ? Id : respuesta.codigo, ddlMetodo.SelectedValue);
                if (rm.error)
                {
                    if (Id == 0) Id = respuesta.codigo;
                    Tools.tools.ClientAlert(respuesta.detalle + " Pero el método de salida no se guardó: " + rm.detalle, "alerta");
                    return;
                }

                /* Al crear NO se cierra: la bodega recien nacida no tiene
                   ubicaciones, y cerrar aca dejaria la sensacion de haber
                   terminado algo que esta a medias. */
                if (Id == 0)
                {
                    Id = respuesta.codigo;
                    Tools.tools.ClientAlert(respuesta.detalle + " Agregue sus racks por pasillo.", "ok");
                    return;
                }

                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>
    /// El lápiz de cada fila. Va como control y no como un &lt;a&gt; con
    /// javascript porque la edición ocurre dentro del UpdatePanel: un
    /// enlace tendría que reconstruir el postback a mano.
    /// </summary>
    protected void btnAgregarUbicacion_Click(object sender, EventArgs e)
    {
        try
        {
            if (Id == 0) throw new Exception("Primero guarde la bodega.");
            if (!Token.Puede("CREAR EDITAR BODEGAS")) throw new Exception("No tiene permiso para crear racks.");

            int cantidad;
            if (!int.TryParse(txtCantidad.Text.Trim(), out cantidad)) throw new Exception("Indique cuántos racks crear (1 a 30).");

            /* El codigo sigue la convencion del mapa 3D: <prefijo>-<pasillo>-R<nn>,
               desde el siguiente numero libre del pasillo. Antes se generaba
               UBI-<id> y el mapa no sabia en que pasillo ponerlo. */
            List<string> codigos = new BodegaAlmacenamientoController().Ubicaciones(Id).Rows.Cast<DataRow>()
                .Select(r => Convert.ToString(r["CODIGO"])).ToList();
            Respuesta respuesta = new BodegaAlmacenamientoController().CrearRacks(Id, CodigoBodega(), codigos,
                txtPasillo.Text, cantidad, txtUbiNombre.Text.Trim());

            if (!respuesta.error)
            {
                UbicacionId = 0;
                txtUbiNombre.Text = "";
                txtCantidad.Text = "1";
            }
            Tools.tools.ClientAlert(respuesta.detalle, respuesta.error ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
