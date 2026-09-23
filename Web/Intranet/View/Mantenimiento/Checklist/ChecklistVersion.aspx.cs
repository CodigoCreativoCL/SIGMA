using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// Publicar una versión de checklist (HU-093). Muestra el historial de versiones
/// de la pauta y permite publicar la versión en borrador. El proceso y las reglas
/// viven en el SP PUBLICAR_CHECKLIST_VERSION; aquí solo se dispara y se muestra el
/// resultado. La escritura la habilita Token.Puede("CREAR EDITAR PAUTAS") y todo
/// se acota al cliente en sesión.
/// </summary>
public partial class View_Mantenimiento_Checklist_ChecklistVersion : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
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

        // Cabecera (fiable aunque no haya versiones aún).
        ChecklistPlantilla pla = new ChecklistPlantillaController().GetChecklistPlantilla(Id);
        if (pla != null && pla.cpl_id > 0)
        {
            litCodigo.Text = Server.HtmlEncode(pla.cpl_codigo);
            litNombre.Text = Server.HtmlEncode(pla.cpl_nombre);
        }

        List<ChecklistVersion> versiones = new ChecklistVersionController().GetVersiones(Id, cliente) ?? new List<ChecklistVersion>();

        rptVersiones.DataSource = versiones;
        rptVersiones.DataBind();
        pnlVacio.Visible = versiones.Count == 0;

        // ¿Hay un borrador para publicar?
        bool hayBorrador = false;
        foreach (ChecklistVersion v in versiones) if (v.cpv_estado == 1) { hayBorrador = true; break; }

        bool puede = Token.Puede("CREAR EDITAR PAUTAS");
        pnlPublicar.Visible = hayBorrador && puede;
        pnlSinBorrador.Visible = !hayBorrador;
    }

    /// <summary>Clase CSS del badge según el estado (1 borrador, 2 publicado, 3 retirado).</summary>
    public string EstadoClase(int estado)
    {
        switch (estado) { case 2: return "p"; case 3: return "r"; default: return "b"; }
    }

    protected void rptVersiones_ItemDataBound(object sender, RepeaterItemEventArgs e)
    {
        if (e.Item.ItemType != ListItemType.Item && e.Item.ItemType != ListItemType.AlternatingItem) return;
        ChecklistVersion v = (ChecklistVersion)e.Item.DataItem;
        Literal lit = (Literal)e.Item.FindControl("litMeta");
        if (lit == null) return;

        StringBuilder sb = new StringBuilder();
        if (v.cpv_estado == 2 && v.cpv_fecha_publicacion != null)
            sb.Append("Publicada el ").Append(v.cpv_fecha_publicacion.Value.ToString("dd-MM-yyyy"))
              .Append(!string.IsNullOrEmpty(v.usuario_publicacion_nombre) ? " por " + Server.HtmlEncode(v.usuario_publicacion_nombre) : "");
        else if (v.cpv_estado == 3 && v.cpv_fecha_retiro != null)
            sb.Append("Retirada el ").Append(v.cpv_fecha_retiro.Value.ToString("dd-MM-yyyy"));
        else
            sb.Append("En borrador");

        sb.Append(" · ").Append(v.items).Append(v.items == 1 ? " ítem" : " ítems")
          .Append(", ").Append(v.secciones).Append(v.secciones == 1 ? " sección" : " secciones");

        if (!string.IsNullOrEmpty(v.cpv_observacion))
            sb.Append(" — ").Append(Server.HtmlEncode(v.cpv_observacion));

        lit.Text = sb.ToString();
    }

    protected void btnPublicar_Click(object sender, EventArgs e)
    {
        try
        {
            Respuesta r = new ChecklistVersionController().Publicar(Id, txtObservacion.Text.Trim());
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
