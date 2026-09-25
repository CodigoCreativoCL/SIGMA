using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// Publicar una versión de plan de mantenimiento (HU-084). Muestra el historial
/// de versiones del plan y permite publicar la versión en borrador. El proceso y
/// las reglas viven en el SP UPD_PLAN_VERSION_PUBLICAR; aquí solo se dispara y se
/// muestra el resultado. La acción la habilita Token.Puede("CREAR EDITAR PLANES
/// MANTENIMIENTO") en el servidor (no se esconde el botón por CSS) y todo se acota
/// al cliente en sesión.
/// </summary>
public partial class View_Mantenimiento_Planes_PlanVersion : System.Web.UI.Page
{
    /// <summary>Id del plan (pma_id) recibido por querystring.</summary>
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    /// <summary>Id de la versión en borrador que se publicaría (pmv_id), o 0.</summary>
    public int BorradorId
    {
        get { return ViewState["BorradorId"] != null ? (int)ViewState["BorradorId"] : 0; }
        set { ViewState["BorradorId"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
            Id = SitioBase.Querystring.Entero(Request.QueryString["query"], "Id");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        Cargar();
        udPanel.Update();
    }

    protected void Cargar()
    {
        if (Id <= 0) return;
        int cliente = SitioBase.Session.ClienteId();

        List<PlanVersion> versiones = new PlanVersionController().GetVersiones(Id, cliente) ?? new List<PlanVersion>();

        // Cabecera: el plan viene en cada fila de versión.
        if (versiones.Count > 0)
        {
            litCodigo.Text = Server.HtmlEncode(versiones[0].plan_codigo);
            litNombre.Text = Server.HtmlEncode(versiones[0].plan_nombre);
        }

        rptVersiones.DataSource = versiones;
        rptVersiones.DataBind();
        pnlVacio.Visible = versiones.Count == 0;

        // ¿Hay un borrador para publicar? Guardamos su pmv_id.
        BorradorId = 0;
        foreach (PlanVersion v in versiones) if (v.pmv_estado == 1) { BorradorId = v.pmv_id; break; }

        bool puede = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO");
        pnlPublicar.Visible = BorradorId > 0 && puede;
        pnlSinBorrador.Visible = versiones.Count > 0 && BorradorId == 0;
    }

    /// <summary>Clase CSS del badge según el estado (1 borrador, 2 publicado, 3 retirado).</summary>
    public string EstadoClase(int estado)
    {
        switch (estado) { case 2: return "p"; case 3: return "r"; default: return "b"; }
    }

    protected void rptVersiones_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem) return;
        PlanVersion v = (PlanVersion)e.Item.DataItem;
        Literal lit = (Literal)e.Item.FindControl("litMeta");
        if (lit == null) return;

        StringBuilder sb = new StringBuilder();
        if (v.pmv_estado == 2 && v.pmv_fecha_publicacion != null)
            sb.Append("Publicada el ").Append(v.pmv_fecha_publicacion.Value.ToString("dd-MM-yyyy"))
              .Append(!string.IsNullOrEmpty(v.usuario_publicacion_nombre) ? " por " + Server.HtmlEncode(v.usuario_publicacion_nombre) : "");
        else if (v.pmv_estado == 3 && v.pmv_fecha_retiro != null)
            sb.Append("Retirada el ").Append(v.pmv_fecha_retiro.Value.ToString("dd-MM-yyyy"));
        else
            sb.Append("En borrador");

        sb.Append(" · ").Append(v.hitos).Append(v.hitos == 1 ? " hito" : " hitos")
          .Append(", ").Append(v.activos).Append(v.activos == 1 ? " equipo" : " equipos");

        if (!string.IsNullOrEmpty(v.pmv_observacion))
            sb.Append(" — ").Append(Server.HtmlEncode(v.pmv_observacion));

        lit.Text = sb.ToString();
    }

    protected void btnPublicar_Click(object sender, EventArgs e)
    {
        try
        {
            // El servidor decide, no el botón: revalida el permiso aquí.
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
            {
                Tools.tools.ClientAlert("No tiene permiso para publicar versiones de plan.", "alerta");
                return;
            }
            if (BorradorId <= 0)
            {
                Tools.tools.ClientAlert("No hay una versión en borrador para publicar.", "alerta");
                return;
            }

            Respuesta r = new PlanVersionController().Publicar(BorradorId, txtObservacion.Text.Trim());
            if (!r.error)
            {
                txtObservacion.Text = "";
                Tools.tools.ClientAlert(r.detalle, "ok");
                Cargar();   // refresca el historial y oculta el panel de publicar
            }
            else
            {
                Tools.tools.ClientAlert(r.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
