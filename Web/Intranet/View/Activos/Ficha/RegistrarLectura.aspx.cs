using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Registro manual de una lectura: una medicion de condicion o una lectura de
/// contador (bloque 278).
///
/// POR QUE EXISTE
///   Hasta ahora las lecturas solo entraban por la app. El planificador que
///   recibe un valor por telefono -"el horno marca 86"- no tenia donde
///   anotarlo, y la variable seguia diciendo "sin lectura" con el dato ya
///   sabido.
///
///   Variables y contadores comparten pantalla porque quien anota un numero
///   sabe QUE midio, no en cual de las dos tablas termina. Lo que cambia es el
///   SP: la medicion compara contra umbrales, la lectura del contador acumula
///   y dispara las ocurrencias por uso.
/// </summary>
public partial class View_Activos_Ficha_RegistrarLectura : System.Web.UI.Page
{
    public int ActivoFijo
    {
        get { return ViewState["ActivoFijo"] != null ? (int)ViewState["ActivoFijo"] : 0; }
        set { ViewState["ActivoFijo"] = value; }
    }

    /// <summary>Lo que venia preseleccionado: "v12" una variable, "m8" un contador.</summary>
    public string Elegido
    {
        get { return ViewState["Elegido"] as string ?? ""; }
        set { ViewState["Elegido"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (IsPostBack) return;

        ActivoFijo = SitioBase.Querystring.Entero(Request.QueryString["query"], "Activo");
        Elegido = SitioBase.Querystring.Texto(Request.QueryString["query"], "Que") ?? "";

        calFecha.Value = SitioBase.Hora.Ahora;
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;

        if (ctrl.ID != "cboHora") return;

        ctrl.Items.Add(new RadComboBoxItem("--:--", ""));

        for (int minuto = 0; minuto < 24 * 60; minuto += 15)
        {
            string h = (minuto / 60).ToString("00") + ":" + (minuto % 60).ToString("00");
            ctrl.Items.Add(new RadComboBoxItem(h, h));
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarQue();

        /* La hora se propone, no se pide: quien anota una lectura recien
           tomada no deberia tener que buscarla en la lista, y dejarla vacia
           mandaba todas las lecturas del dia a la medianoche. */
        if (!IsPostBack && string.IsNullOrEmpty(cboHora.SelectedValue))
        {
            DateTime ahora = SitioBase.Hora.Ahora;
            string h = ahora.Hour.ToString("00") + ":" + (ahora.Minute / 15 * 15).ToString("00");

            RadComboBoxItem item = cboHora.FindItemByValue(h);
            if (item != null) item.Selected = true;
        }

        Contexto();
        udPanel.Update();
    }

    /// <summary>
    /// Las variables y los contadores del equipo, en una sola lista.
    ///
    /// El valor lleva prefijo -"v12", "m8"- porque los dos ids vienen de
    /// tablas distintas y el 8 de una variable no es el 8 de un contador.
    /// </summary>
    private void CargarQue()
    {
        if (cboQue.Items.Count > 0) return;

        int cliente = SitioBase.Session.ClienteId();

        cboQue.Items.Add(new RadComboBoxItem("Seleccione...", ""));

        Activo a = new ActivoController().GetActivo(ActivoFijo);
        lblActivo.Text = a == null ? "—" : Server.HtmlEncode(
            (string.IsNullOrEmpty(a.act_codigo) ? "" : a.act_codigo + " — ") + a.act_nombre);

        if (Token.Puede("REGISTRAR MEDICION"))
        {
            List<ActivoVariable> variables = new ActivoVariableController().GetVariables(
                new ActivoVariable { ava_cliente = cliente, filtro_activo = ActivoFijo, filtro_habilitado = true })
                ?? new List<ActivoVariable>();

            foreach (ActivoVariable v in variables)
                cboQue.Items.Add(new RadComboBoxItem(
                    v.variable_nombre +
                    (string.IsNullOrEmpty(v.componente_nombre) ? "" : " · " + v.componente_nombre) +
                    (string.IsNullOrEmpty(v.unidad_simbolo) ? "" : " (" + v.unidad_simbolo + ")"),
                    "v" + v.ava_id));
        }

        if (Token.Puede("REGISTRAR LECTURA"))
        {
            List<ActivoMedidor> medidores = new ActivoMedidorController().GetActivoMedidores(
                new ActivoMedidor { ame_cliente = cliente, filtro_activo = ActivoFijo, filtro_habilitado = true })
                ?? new List<ActivoMedidor>();

            foreach (ActivoMedidor m in medidores)
                cboQue.Items.Add(new RadComboBoxItem(
                    m.ame_nombre + " · contador" +
                    (string.IsNullOrEmpty(m.unidad_simbolo) ? "" : " (" + m.unidad_simbolo + ")"),
                    "m" + m.ame_id));
        }

        if (Elegido.Length > 0)
        {
            RadComboBoxItem item = cboQue.FindItemByValue(Elegido);
            if (item != null) item.Selected = true;
        }
    }

    /// <summary>
    /// Contra que se va a comparar el numero que se esta por escribir: sus
    /// umbrales si es variable, su valor actual si es contador.
    ///
    /// Sin esto se anota a ciegas y el error se descubre en la grilla.
    /// </summary>
    private void Contexto()
    {
        string valor = cboQue.SelectedValue ?? "";

        litUnidad.Text = "";
        litContexto.Text = "";
        pnlReinicio.Visible = false;

        if (valor.Length < 2) return;

        int id;
        if (!int.TryParse(valor.Substring(1), out id) || id <= 0) return;

        if (valor[0] == 'v')
        {
            ActivoVariable v = new ActivoVariableController().GetVariable(id);
            if (v == null) return;

            litUnidad.Text = string.IsNullOrEmpty(v.unidad_simbolo)
                ? "Sin unidad configurada."
                : "En " + Server.HtmlEncode(v.unidad_simbolo) + ".";

            List<string> partes = new List<string>();
            if (v.ava_valor_minimo != null || v.ava_valor_maximo != null)
                partes.Add("Normal " +
                           (v.ava_valor_minimo == null ? "" : v.ava_valor_minimo.Value.ToString("0.##")) + " – " +
                           (v.ava_valor_maximo == null ? "" : v.ava_valor_maximo.Value.ToString("0.##")));
            if (v.ava_valor_advertencia != null) partes.Add("Aviso " + v.ava_valor_advertencia.Value.ToString("0.##"));
            if (v.ava_valor_critico != null) partes.Add("Crítico " + v.ava_valor_critico.Value.ToString("0.##"));

            litContexto.Text = "<p class=\"sigma-modal-nota\"><i class=\"mdi mdi-information-outline\"></i><span>" +
                               (partes.Count == 0
                                   ? "Esta variable no tiene rangos configurados: la lectura se guarda sin semáforo."
                                   : "Se compara contra " + Server.HtmlEncode(string.Join("  ·  ", partes.ToArray())) + ".") +
                               "</span></p>";
            return;
        }

        ActivoMedidor m = new ActivoMedidorController().GetActivoMedidor(id);
        if (m == null) return;

        pnlReinicio.Visible = m.ame_permite_reinicio;

        litUnidad.Text = string.IsNullOrEmpty(m.unidad_simbolo)
            ? "Valor acumulado."
            : "Acumulado, en " + Server.HtmlEncode(m.unidad_simbolo) + ".";

        litContexto.Text = "<p class=\"sigma-modal-nota\"><i class=\"mdi mdi-information-outline\"></i><span>" +
                           "Hoy marca " + m.ame_valor_actual.ToString("N0") +
                           (string.IsNullOrEmpty(m.unidad_simbolo) ? "" : " " + Server.HtmlEncode(m.unidad_simbolo)) +
                           ". Un contador acumula: el valor nuevo no puede ser menor" +
                           (m.ame_permite_reinicio ? ", salvo que declare un reinicio." : ".") +
                           "</span></p>";
    }

    protected void cboQue_SelectedIndexChanged(object sender, EventArgs e) { }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            string que = cboQue.SelectedValue ?? "";

            if (que.Length < 2)
                throw new Exception("Elija la variable o el contador que se midió.");

            int id;
            if (!int.TryParse(que.Substring(1), out id) || id <= 0)
                throw new Exception("Elija la variable o el contador que se midió.");

            decimal valor;
            string txt = (txtValor.Text ?? "").Trim().Replace(",", ".");

            if (txt.Length == 0 || !decimal.TryParse(txt, NumberStyles.Any, CultureInfo.InvariantCulture, out valor))
                throw new Exception("El valor tiene que ser un número.");

            if (calFecha.Value == null)
                throw new Exception("Indique la fecha de la lectura.");

            DateTime fecha = Juntar();

            /* Una lectura del futuro descuadra la serie y el semaforo: la
               variable quedaria "al dia" por un dato que todavia no existe. */
            if (fecha > SitioBase.Hora.Ahora.AddMinutes(5))
                throw new Exception("La lectura no puede quedar con fecha futura.");

            ActivoCentroController c = new ActivoCentroController();

            Respuesta r = que[0] == 'v'
                ? c.RegistrarMedicion(id, valor, fecha, txtObservacion.Text.Trim())
                : c.RegistrarLecturaMedidor(id, valor, fecha, txtObservacion.Text.Trim(), rdbReinicioSi.Checked);

            if (!r.error)
            {
                txtValor.Text = "";
                txtObservacion.Text = "";
                Tools.tools.ClientAlert(r.detalle, "ok", true);
            }
            else Tools.tools.ClientAlert(r.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    /// <summary>La fecha del calendario con la hora del desplegable.</summary>
    private DateTime Juntar()
    {
        DateTime d = calFecha.Value.Value.Date;

        string h = (string.IsNullOrEmpty(cboHora.SelectedValue) ? cboHora.Text : cboHora.SelectedValue).Trim();
        if (h.Length == 0) return d;

        TimeSpan t;
        if (TimeSpan.TryParse(h, CultureInfo.InvariantCulture, out t) && t < TimeSpan.FromDays(1)) return d.Add(t);

        return d;
    }
}
