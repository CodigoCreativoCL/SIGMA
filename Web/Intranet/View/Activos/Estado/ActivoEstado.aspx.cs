using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Cambiar el estado de un activo indicando el motivo (HU-038).
///
/// Es una ACCION, no un mantenedor: se elige el activo, se ve su estado, se
/// elige el nuevo y se registra el motivo. Las reglas viven en el SP
/// ACTIVO_CAMBIAR_ESTADO (misma respuesta para web y app). La seguridad la
/// dan el permiso CAMBIAR ESTADO ACTIVO y el filtro por cliente del SP.
/// </summary>
public partial class View_Activos_Estado_ActivoEstado : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            Grid.AddColumn("FECHA_INICIO", "DESDE", Width: "16%");
            Grid.AddColumn("FECHA_FIN", "HASTA", Width: "16%");
            Grid.AddColumn("ESTADO_NOMBRE", "ESTADO", Width: "18%");
            Grid.AddColumn("AEH_MOTIVO", "MOTIVO", Width: "32%");
            Grid.AddColumn("USUARIO_NOMBRE", "USUARIO", Width: "18%");
        }
        Tools.tools.RegisterPostBackScript(Grid);
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (IsPostBack || !(sender is RadComboBox2)) return;
        RadComboBox2 ctrl = (RadComboBox2)sender;
        int cliente = SitioBase.Session.ClienteId();

        if (ctrl.ID == "cboActivo")
        {
            ActivoController c = new ActivoController();
            List<Activo> l = c.GetActivos(new Activo { act_cliente = cliente, filtro_habilitado = true });
            ctrl.Items.Add(new RadComboBoxItem("Seleccione un activo...", ""));
            ctrl.AppendDataBoundItems = true;
            if (l != null) foreach (Activo a in l)
                ctrl.Items.Add(new RadComboBoxItem(a.act_codigo + " — " + a.act_nombre, a.act_id.ToString()));
        }
        else if (ctrl.ID == "cboNuevoEstado")
        {
            ActivoEstadoController c = new ActivoEstadoController();
            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
            ctrl.AppendDataBoundItems = true;
            ctrl.DataSource = c.GetActivoEstados(new ActivoEstado { filtro_habilitado = true });
            ctrl.DataValueField = "aes_id";
            ctrl.DataTextField = "aes_nombre";
            ctrl.DataBind();
        }
    }

    protected void cboActivo_SelectedIndexChanged(object sender, EventArgs e)
    {
        // El postback recarga en PreRender.
    }

    protected int ActivoSeleccionado()
    {
        RadComboBox2 cbo = (RadComboBox2)wucFiltro.FindControl("cboActivo");
        int id;
        if (cbo != null && int.TryParse(cbo.SelectedValue, out id)) return id;
        return 0;
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool hayCliente = SitioBase.Session.ClienteId() > 0;
        pnlSinCliente.Visible = !hayCliente;
        udPanel.Visible = hayCliente;
        if (!hayCliente) return;

        Cargar();
        udPanel.Update();
    }

    protected void Cargar()
    {
        int activo = ActivoSeleccionado();
        bool hay = activo > 0;

        pnlSinActivo.Visible = !hay;
        pnlCambio.Visible = hay;
        pnlHistorial.Visible = hay;
        btnCambiar.Visible = hay && Token.Puede("CAMBIAR ESTADO ACTIVO");

        if (!hay) return;

        // Estado actual, del activo (verificando que sea del cliente).
        ActivoController ac = new ActivoController();
        Activo a = ac.GetActivo(activo);
        if (a == null || a.act_id == 0 || a.act_cliente != SitioBase.Session.ClienteId())
        {
            pnlSinActivo.Visible = true; pnlCambio.Visible = false; pnlHistorial.Visible = false;
            return;
        }
        lblEstadoActual.Text = a.estado_nombre;

        // Historial.
        ActivoEstadoHistorialController hc = new ActivoEstadoHistorialController();
        Grid.DataSource = hc.GetHistorial(activo, SitioBase.Session.ClienteId());
        Grid.DataBind();
    }

    protected void rgrHistorial_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (!(e.Item is GridDataItem)) return;
        GridDataItem item = (GridDataItem)e.Item;

        object ini = DataBinder.Eval(item.DataItem, "aeh_fecha_inicio_utc");
        if (ini != null && ini != DBNull.Value)
            item["FECHA_INICIO"].Text = Convert.ToDateTime(ini).ToString("dd-MM-yyyy HH:mm");

        object fin = DataBinder.Eval(item.DataItem, "aeh_fecha_fin_utc");
        item["FECHA_FIN"].Text = (fin == null || fin == DBNull.Value)
            ? "Vigente" : Convert.ToDateTime(fin).ToString("dd-MM-yyyy HH:mm");
    }

    protected void btnCambiar_Click(object sender, EventArgs e)
    {
        try
        {
            int activo = ActivoSeleccionado();
            if (activo == 0) { Tools.tools.ClientAlert("Elija un activo."); return; }

            RadComboBox2 cbo = (RadComboBox2)pnlCambio.FindControl("cboNuevoEstado");
            if (cbo == null || string.IsNullOrEmpty(cbo.SelectedValue))
                throw new Exception("Debe elegir el nuevo estado.");

            ActivoEstadoHistorial x = new ActivoEstadoHistorial();
            x.aeh_activo = activo;
            x.nuevo_estado = int.Parse(cbo.SelectedValue);

            ActivoEstadoHistorialController c = new ActivoEstadoHistorialController();
            Respuesta r = c.CambiarEstado(x, SitioBase.Session.ClienteId(), txtMotivo.Text.Trim());

            if (!r.error)
            {
                txtMotivo.Text = "";
                Tools.tools.ClientAlert(r.detalle, "ok");
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
