using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using Telerik.Web.UI;

/// <summary>
/// Ficha de un vinculo plan-equipo (HU-083).
///
/// El combo de equipos trae todos los del cliente y NO se filtra por el
/// alcance del plan: hacerlo obligaria a repetir en la pantalla la regla
/// que el SP ya hace cumplir, y el dia que cambie una de las dos se
/// desincronizan. El SP rechaza con un mensaje que dice por que -otra
/// planta, otro tipo, otro modelo- y eso es mejor que un combo que
/// esconde equipos sin explicar.
///
/// Componente y medidor dependen del equipo elegido: se reconstruyen en
/// cada postback a partir de el, como los modelos en la ficha del activo.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanActivo : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>
    /// El plan desde el que se abrio este modal. Viene cifrado en el query
    /// desde el centro de operaciones: el combo queda fijo en el, para no
    /// pedir elegir un plan que ya se eligio al entrar.
    /// </summary>
    public int Plan
    {
        get { return ViewState["Plan"] != null ? (int)ViewState["Plan"] : 0; }
        set { ViewState["Plan"] = value; }
    }

    private bool VersionCerrada
    {
        get { return ViewState["VersionCerrada"] != null && (bool)ViewState["VersionCerrada"]; }
        set { ViewState["VersionCerrada"] = value; }
    }

    private string _componenteEditar = null;
    private string _medidorEditar = null;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack && Request.QueryString["query"] != null)
        {
            string[] query = SitioBase.Querystring.Descifrar(Request.QueryString["query"]).Split('&');

            foreach (string arr in query)
            {
                string[] array = arr.ToString().Split('=');
                switch (array[0].ToString())
                {
                    case "Id":
                        Id = Int32.Parse(array[1].ToString());
                        break;
                    case "Plan":
                        Plan = Int32.Parse(array[1].ToString());
                        break;
                }
            }
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack) return;
        if (!(sender is RadComboBox2)) return;

        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        switch (ctrl.ID)
        {
            case "cboPlan":
                {
                    List<PlanMantenimiento> planes = new PlanMantenimientoController().GetPlanesMantenimiento(
                        new PlanMantenimiento { pma_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (planes != null)
                        foreach (PlanMantenimiento p in planes)
                        {
                            bool enBorrador = string.Equals(p.version_estado_codigo, "BORRADOR", StringComparison.OrdinalIgnoreCase);
                            if (Id == 0 && !enBorrador) continue;
                            ctrl.Items.Add(new RadComboBoxItem(p.pma_codigo + " — " + p.pma_nombre, p.pma_id.ToString()));
                        }
                    break;
                }

            case "cboActivo":
                {
                    List<Activo> lista = new ActivoController().GetActivos(
                        new Activo { act_cliente = cliente, filtro_habilitado = true });

                    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));

                    if (lista != null)
                        foreach (Activo a in lista)
                            ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
                    break;
                }
        }
    }

    protected void cboActivo_SelectedIndexChanged(object sender, EventArgs e) { }

    /// <summary>
    /// El plan vuelve a quedar elegido en CADA carga, no solo en la primera.
    ///
    /// Cuando se entra desde el centro del plan, el combo va fijo con
    /// Enabled = false para que nadie lo cambie... y un control deshabilitado
    /// NO viaja en el postback: al elegir el equipo -que sí postea- el plan se
    /// perdía y Guardar rechazaba por «Plan(*)» sin que el usuario hubiera
    /// tocado ese campo. CargarDatos() no alcanza porque se salta en los
    /// postbacks, que es justo cuando hace falta.
    /// </summary>
    private void FijarPlan()
    {
        if (Plan > 0) Seleccionar(cboPlan, Plan.ToString());
    }

    /// <summary>
    /// Si el equipo elegido ya está cubierto por otro plan vigente (HU-083 #3).
    ///
    /// ES UN AVISO Y NO UN RECHAZO, y por eso vive acá y no dentro del SP:
    /// una validación en el INS solo puede dejar pasar o rechazar, y lo que
    /// el criterio pide es una tercera cosa —mostrar y seguir—. Se consulta
    /// al elegir el equipo, que es cuando el dato sirve para decidir, y no al
    /// apretar Guardar, que es cuando ya se decidió.
    /// </summary>
    private void Cobertura()
    {
        pnlCobertura.Visible = false;

        int activo;
        if (!int.TryParse(cboActivo.SelectedValue, out activo) || activo <= 0) return;

        int plan;
        if (!int.TryParse(cboPlan.SelectedValue, out plan)) plan = 0;

        List<PlanCobertura> otros = new PlanActivoController().GetCobertura(activo, plan);

        if (otros == null || otros.Count == 0) return;

        StringBuilder s = new StringBuilder();

        s.Append("<span class=\"sigma-modal-ayuda\" style=\"display:block; margin-bottom:8px;\">")
         .Append(otros.Count == 1
                ? "Hay <strong>otro plan vigente</strong> que ya incluye este equipo. "
                : "Hay <strong>" + otros.Count + " planes vigentes</strong> que ya incluyen este equipo. ")
         .Append("No es un impedimento —un equipo puede tener un plan de lubricación y otro de inspección—, ")
         .Append("pero si los dos hacen lo mismo se va a generar trabajo repetido.</span>");

        s.Append("<table class=\"sigma-tabla-simple\" style=\"width:100%; font-size:13px;\">")
         .Append("<thead><tr><th style=\"text-align:left;\">Plan</th><th style=\"text-align:left;\">Versión</th>")
         .Append("<th style=\"text-align:left;\">Tipo</th><th style=\"text-align:right;\">Hitos</th>")
         .Append("<th style=\"text-align:right;\">Corriendo</th></tr></thead><tbody>");

        foreach (PlanCobertura c in otros)
        {
            s.Append("<tr><td><strong>").Append(Server.HtmlEncode(c.plan_codigo)).Append("</strong> ")
             .Append(Server.HtmlEncode(c.plan_nombre)).Append("</td>");

            s.Append("<td>v").Append(c.version_numero).Append(" ")
             .Append(Server.HtmlEncode((c.version_estado_nombre ?? "").ToLower())).Append("</td>");

            /* El mismo tipo de activo es el caso que el criterio nombra: dos
               planes para la misma familia de equipos es donde se pisan. */
            s.Append("<td>").Append(string.IsNullOrEmpty(c.tipo_nombre)
                    ? "<span class=\"sigma-inv-vacio\">cualquiera</span>"
                    : Server.HtmlEncode(c.tipo_nombre))
             .Append(c.mismo_tipo ? " <span class=\"grid-estado-chip is-advertencia\">mismo tipo</span>" : "")
             .Append("</td>");

            s.Append("<td style=\"text-align:right;\">").Append(c.hitos).Append("</td>");

            /* Lo que de verdad se pisa: dos planes que se solapan en el papel
               pero no generan nada no son el mismo problema que dos que ya
               tienen mantenciones corriendo sobre el mismo equipo. */
            s.Append("<td style=\"text-align:right;\">")
             .Append(c.ocurrencias_abiertas == 0
                    ? "<span class=\"sigma-inv-vacio\">nada</span>"
                    : "<span class=\"grid-estado-chip is-advertencia\">" + c.ocurrencias_abiertas + "</span>")
             .Append("</td></tr>");
        }

        s.Append("</tbody></table>");

        litCobertura.Text = s.ToString();
        pnlCobertura.Visible = true;
    }

    /// <summary>
    /// Componente y medidor del equipo elegido, preservando la seleccion
    /// entre postbacks. Sin equipo, los combos van vacios.
    /// </summary>
    private void CargarDependientes()
    {
        string selC = string.IsNullOrEmpty(_componenteEditar) ? cboComponente.SelectedValue : _componenteEditar;
        string selM = string.IsNullOrEmpty(_medidorEditar) ? cboMedidor.SelectedValue : _medidorEditar;

        cboComponente.Items.Clear();
        cboComponente.Items.Add(new RadComboBoxItem("Equipo completo", ""));
        cboMedidor.Items.Clear();
        cboMedidor.Items.Add(new RadComboBoxItem("Sin medidor", ""));

        int activo;
        if (int.TryParse(cboActivo.SelectedValue, out activo) && activo > 0)
        {
            int cliente = SitioBase.Session.ClienteId();

            List<ActivoComponente> comps = new ActivoComponenteController().GetComponentes(
                new ActivoComponente { aco_cliente = cliente, filtro_activo = activo, filtro_habilitado = true });
            if (comps != null)
                foreach (ActivoComponente c in comps)
                    cboComponente.Items.Add(new RadComboBoxItem(c.aco_codigo + " — " + c.aco_nombre, c.aco_id.ToString()));

            List<ActivoMedidor> meds = new ActivoMedidorController().GetActivoMedidores(
                new ActivoMedidor { ame_cliente = cliente, filtro_activo = activo, filtro_habilitado = true });
            if (meds != null)
                foreach (ActivoMedidor m in meds)
                    cboMedidor.Items.Add(new RadComboBoxItem(m.ame_codigo + " — " + m.ame_nombre, m.ame_id.ToString()));
        }

        RadComboBoxItem ic = cboComponente.FindItemByValue(selC ?? "");
        if (ic != null) ic.Selected = true;
        RadComboBoxItem im = cboMedidor.FindItemByValue(selM ?? "");
        if (im != null) im.Selected = true;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        FijarPlan();            // ANTES de lo demas: un combo deshabilitado no viaja
        CargarDependientes();   // depende del equipo ya seleccionado por CargarDatos
        Cobertura();            // y del mismo equipo: que otro plan vigente lo cubre
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            PlanActivo v = new PlanActivoController().GetPlanActivo(new PlanActivo { pac_id = Id });

            lblId.Text = Id.ToString();
            Seleccionar(cboPlan, v.plan_id.ToString());
            Seleccionar(cboActivo, v.pac_activo.ToString());
            if (v.pac_activo_componente != null) _componenteEditar = v.pac_activo_componente.Value.ToString();
            if (v.pac_activo_medidor != null) _medidorEditar = v.pac_activo_medidor.Value.ToString();

            VersionCerrada = !v.version_editable;
            litEstadoVersion.Text = "v" + v.version_numero + " " + Server.HtmlEncode((v.version_estado_nombre ?? "").ToLower());
        }
        else
        {
            lblId.Text = "Nuevo";
            if (Plan > 0) Seleccionar(cboPlan, Plan.ToString());
        }
    }

    private static void Seleccionar(RadComboBox2 cbo, string valor)
    {
        RadComboBoxItem item = cbo.FindItemByValue(valor ?? "");
        if (item != null) item.Selected = true;
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO") && !VersionCerrada;

        pnlBloqueado.Visible = VersionCerrada;

        // Al editar, el plan y el equipo no se cambian: cambiar el equipo es
        // quitar uno y asociar otro, y eso se hace asi, a la vista. Lo que se
        // edita es sobre que componente y con que medidor.
        // Fijo con Enabled y no con ReadOnly: un RadComboBox ReadOnly no
        // renderiza sus items y validaControl se cae al recorrerlos.
        cboPlan.Enabled = !(Id > 0 || Plan > 0);
        cboPlan.ReadOnly = !puedeEditar;
        cboActivo.Enabled = Id == 0;
        cboActivo.ReadOnly = !puedeEditar;
        cboComponente.ReadOnly = !puedeEditar;
        cboMedidor.ReadOnly = !puedeEditar;
        btnGuardar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            PlanActivo entidad = new PlanActivo();
            PlanActivoController controller = new PlanActivoController();

            entidad.pac_id = Id;
            entidad.plan_id = string.IsNullOrEmpty(cboPlan.SelectedValue) ? 0 : int.Parse(cboPlan.SelectedValue);
            entidad.pac_activo = string.IsNullOrEmpty(cboActivo.SelectedValue) ? 0 : int.Parse(cboActivo.SelectedValue);

            if (!string.IsNullOrEmpty(cboComponente.SelectedValue))
                entidad.pac_activo_componente = int.Parse(cboComponente.SelectedValue);
            else entidad.quita_componente = true;

            if (!string.IsNullOrEmpty(cboMedidor.SelectedValue))
                entidad.pac_activo_medidor = int.Parse(cboMedidor.SelectedValue);
            else entidad.quita_medidor = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdatePlanActivo(entidad)
                : controller.InsertPlanActivo(entidad);

            if (!respuesta.error)
            {
                Id = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }
}
