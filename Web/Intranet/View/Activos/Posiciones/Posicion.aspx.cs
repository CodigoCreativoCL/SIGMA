using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;

/// <summary>
/// Ficha de una posicion funcional (HU-033): sus datos, la etiqueta QR
/// (HU-034 #1) y la ocupacion —que equipo esta hoy y cuales estuvieron
/// antes (HU-033 #2)—.
/// </summary>
public partial class View_Activos_Posiciones_Posicion : System.Web.UI.Page
{
    public int Id
    {
        get { return ViewState["Id"] != null ? (int)ViewState["Id"] : 0; }
        set { ViewState["Id"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (Request.QueryString["query"] != null)
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
                    }
                }
            }

            GridHistorial.AddColumn("ACTIVO_CODIGO", "EQUIPO", Width: "14%");
            GridHistorial.AddColumn("ACTIVO_NOMBRE", "", Width: "24%");
            GridHistorial.AddColumn("APH_FECHA_INICIO", "DESDE", Width: "14%", DataFormat: "{0:dd-MM-yyyy HH:mm}");
            GridHistorial.AddTemplateColumn("HASTA", "", "HASTA", Width: "14%");
            GridHistorial.AddColumn("DIAS", "DÍAS", Width: "6%");
            GridHistorial.AddColumn("MOTIVO_NOMBRE", "MOTIVO", Width: "14%");
            GridHistorial.AddColumn("USUARIO_NOMBRE", "REGISTRÓ", Width: "14%");
        }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                int cliente = SitioBase.Session.ClienteId();

                switch (ctrl.ID)
                {
                    case "cboPlanta":
                        {
                            ClienteInstalacionController controller = new ClienteInstalacionController();

                            ClienteInstalacion filtro = new ClienteInstalacion();
                            filtro.filtro_cliente = cliente.ToString();
                            filtro.filtro_habilitado = "1";

                            ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                            ctrl.AppendDataBoundItems = true;
                            ctrl.DataSource = controller.GetClienteInstalaciones(filtro);
                            ctrl.DataValueField = "cin_id";
                            ctrl.DataTextField = "cin_nombre";
                            ctrl.DataBind();
                            break;
                        }

                    case "cboTipo":
                        {
                            ActivoTipoController controller = new ActivoTipoController();
                            List<ActivoTipo> lista = controller.GetActivoTipos(
                                new ActivoTipo { filtro_cliente = cliente, filtro_habilitado = true });

                            ctrl.Items.Add(new RadComboBoxItem("Cualquier tipo", ""));
                            ctrl.AppendDataBoundItems = true;
                            ctrl.DataSource = lista;
                            ctrl.DataValueField = "ati_id";
                            ctrl.DataTextField = "ati_nombre";
                            ctrl.DataBind();
                            break;
                        }

                    case "cboMotivo":
                        {
                            ActivoPosicionController controller = new ActivoPosicionController();

                            ctrl.Items.Add(new RadComboBoxItem("Según corresponda", ""));
                            ctrl.AppendDataBoundItems = true;
                            ctrl.DataSource = controller.GetMotivos();
                            ctrl.DataValueField = "apm_id";
                            ctrl.DataTextField = "apm_nombre";
                            ctrl.DataBind();
                            break;
                        }
                }
            }
        }
    }

    /// <summary>
    /// Las areas dependen de la planta: se recargan cuando cambia. La
    /// planta se elige al crear; al editar queda fija (la posicion no se
    /// muda de planta: eso seria otra posicion).
    /// </summary>
    protected void cboPlanta_SelectedIndexChanged(object sender, RadComboBoxSelectedIndexChangedEventArgs e)
    {
        CargarAreas();
        udPanel.Update();
    }

    protected void CargarAreas()
    {
        cboArea.Items.Clear();
        cboArea.Items.Add(new RadComboBoxItem("Seleccione...", ""));

        int planta;
        if (!int.TryParse(cboPlanta.SelectedValue, out planta) || planta == 0) return;

        InstalacionAreaController controller = new InstalacionAreaController();
        List<InstalacionArea> lista = controller.GetInstalacionAreas(
            new InstalacionArea { iar_cliente = SitioBase.Session.ClienteId(), iar_cliente_instalacion = planta, filtro_habilitado = true });

        if (lista == null) return;

        foreach (InstalacionArea a in lista)
            cboArea.Items.Add(new RadComboBoxItem(a.ruta, a.iar_id.ToString()));
    }

    /// <summary>
    /// Los equipos que se pueden poner en la posicion: los de su planta y,
    /// si la posicion declara tipo, solo los de ese tipo. Se listan con lo
    /// que ocupan hoy para que se vea que asignar uno lo saca de donde esta.
    /// </summary>
    protected void CargarActivos(ActivoPosicion p)
    {
        cboActivo.Items.Clear();
        cboActivo.Items.Add(new RadComboBoxItem("Seleccione...", ""));

        ActivoController controller = new ActivoController();
        Activo filtro = new Activo();
        filtro.act_cliente = SitioBase.Session.ClienteId();
        filtro.filtro_cliente_instalacion = p.apo_cliente_instalacion;
        if (p.apo_activo_tipo != null) filtro.filtro_activo_tipo = p.apo_activo_tipo.Value;
        filtro.filtro_habilitado = true;

        List<Activo> lista = controller.GetActivos(filtro);
        if (lista == null) return;

        foreach (Activo a in lista)
        {
            if (p.activo_id != null && a.act_id == p.activo_id.Value) continue;
            cboActivo.Items.Add(new RadComboBoxItem(a.act_codigo + " · " + a.act_nombre, a.act_id.ToString()));
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnOcupar);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnLiberar);
        udPanel.Update();
    }

    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id > 0)
        {
            ActivoPosicionController controller = new ActivoPosicionController();
            ActivoPosicion p = controller.GetPosicion(new ActivoPosicion { apo_id = Id });

            lblId.Text = Id.ToString();
            txtCodigo.Text = SitioBase.CodigoModulo.Sufijo("Activo_Posicion", p.apo_codigo);
            txtNombre.Text = p.apo_nombre;
            txtDescripcion.Text = p.apo_descripcion;

            cboPlanta.SelectedValue = p.apo_cliente_instalacion.ToString();
            CargarAreas();
            cboArea.SelectedValue = p.apo_instalacion_area.ToString();
            if (p.apo_activo_tipo != null) cboTipo.SelectedValue = p.apo_activo_tipo.ToString();

            rdbCriticaSi.Checked = p.apo_critica;
            rdbCriticaNo.Checked = !p.apo_critica;
            rdbSi.Checked = p.apo_habilitado;
            rdbNo.Checked = !p.apo_habilitado;

            wucAuditoria.Mostrar(p.usuario_creacion_nombre, p.apo_fecha_creacion,
                                 p.usuario_actualizacion_nombre, p.apo_fecha_actualizacion);

            CargarOcupacion(p);
            CargarEtiqueta();
        }
        else
        {
            lblId.Text = "Nuevo";
            tabOcupacion.Visible = false;   // sin posicion no hay nada que ocupar
        }
    }

    protected void CargarOcupacion(ActivoPosicion p)
    {
        pnlOcupacion.Visible = true;

        if (p.activo_id == null)
            litActual.Text = "<span class=\"grid-estado-chip is-neutro\"><i class=\"mdi mdi-map-marker-off-outline\"></i>Libre</span> "
                           + "Ningún equipo ocupa esta posición hoy.";
        else
            litActual.Text = "<span class=\"grid-estado-chip is-exito\"><i class=\"mdi mdi-engine-outline\"></i>"
                           + Server.HtmlEncode(p.activo_codigo) + "</span> <strong>" + Server.HtmlEncode(p.activo_nombre) + "</strong>"
                           + (p.ocupada_desde != null ? " · desde el " + p.ocupada_desde.Value.ToString("dd-MM-yyyy HH:mm") : "");

        btnLiberar.Visible = p.activo_id != null;

        /* HU-035 #2: si la posicion ya esta ocupada, asignar otro equipo
           pide confirmacion diciendo QUIEN la ocupa. Al confirmar, el SP
           cierra el periodo del anterior y abre el del nuevo. Con la
           posicion libre no hay nada que confirmar. */
        if (p.activo_id != null)
        {
            string quien = (p.activo_codigo + " " + p.activo_nombre).Trim().Replace("\\", "\\\\").Replace("'", "\\'");
            btnOcupar.OnClientClick = "if (!ConfirSweetAlert(this, 'Posición ocupada', 'Hoy la ocupa " + quien +
                                      ". ¿Asignarla al equipo elegido? El periodo de " + quien +
                                      " se cierra ahora y se abre el del nuevo.')) return false;";
        }
        else
            btnOcupar.OnClientClick = "";

        CargarActivos(p);

        ActivoPosicionController controller = new ActivoPosicionController();
        GridHistorial.DataSource = controller.GetHistorial(Id);
        GridHistorial.DataBind();
    }

    protected void GridHistorial_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item is GridDataItem)
        {
            GridDataItem item = e.Item as GridDataItem;
            ActivoPosicionHistorial h = (ActivoPosicionHistorial)item.DataItem;

            string hasta = h.aph_fecha_fin == null
                ? "<span class=\"grid-estado-chip is-exito\">Vigente</span>"
                : h.aph_fecha_fin.Value.ToString("dd-MM-yyyy HH:mm");

            item["HASTA"].Controls.Add(new Literal { Text = hasta });
        }
    }

    protected void CargarEtiqueta()
    {
        pnlEtiqueta.Visible = (Id > 0 && Token.Puede("IMPRIMIR ETIQUETAS"));
        if (!pnlEtiqueta.Visible) return;

        string datos = "Origen=" + EtiquetaOrigen.Posicion + "&Ids=" + Id;
        btnEtiqueta.Attributes["onclick"] = "return abrirEtiquetas('" + Server.UrlEncode(Tools.Crypto.Encrypt(datos)) + "');";
    }

    protected void Bloqueo()
    {
        bool puedeEditar = Token.Puede("CREAR EDITAR POSICIONES");

        litPrefijo.Text = SitioBase.CodigoModulo.Etiqueta("Activo_Posicion");
        txtCodigo.ReadOnly = Id > 0;   // se escribe al crear; despues ya esta impreso en el QR
        cboPlanta.ReadOnly = Id > 0 || !puedeEditar;
        cboArea.ReadOnly = !puedeEditar;
        cboTipo.ReadOnly = !puedeEditar;
        txtNombre.ReadOnly = !puedeEditar;
        txtDescripcion.ReadOnly = !puedeEditar;
        rdbCriticaSi.Enabled = puedeEditar;
        rdbCriticaNo.Enabled = puedeEditar;
        rdbSi.Enabled = puedeEditar;
        rdbNo.Enabled = puedeEditar;
        btnGuardar.Visible = puedeEditar;
        pnlAsignar.Visible = puedeEditar;
    }

    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            ActivoPosicion entidad = new ActivoPosicion();
            ActivoPosicionController controller = new ActivoPosicionController();

            entidad.apo_id = Id;
            entidad.apo_cliente = SitioBase.Session.ClienteId();
            /* AUTO cuando viene vacio: el SP lo reemplaza por POS-<id> en cuanto
               conoce el ID (bloque 77). Al editar viaja el que ya tiene y el SP
               no lo toca. */
            entidad.apo_codigo = SitioBase.CodigoModulo.Componer("Activo_Posicion", txtCodigo.Text);
            entidad.apo_nombre = txtNombre.Text.Trim();
            entidad.apo_descripcion = string.IsNullOrEmpty(txtDescripcion.Text.Trim()) ? null : txtDescripcion.Text.Trim();
            entidad.apo_critica = rdbCriticaSi.Checked;
            entidad.apo_habilitado = rdbSi.Checked;

            int v;
            if (int.TryParse(cboPlanta.SelectedValue, out v)) entidad.apo_cliente_instalacion = v;
            if (int.TryParse(cboArea.SelectedValue, out v)) entidad.apo_instalacion_area = v;
            if (int.TryParse(cboTipo.SelectedValue, out v)) entidad.apo_activo_tipo = v;
            else entidad.quita_tipo = true;

            Respuesta respuesta = (Id > 0)
                ? controller.UpdatePosicion(entidad)
                : controller.InsertPosicion(entidad);

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

    protected void btnOcupar_Click(object sender, EventArgs e)
    {
        try
        {
            int activo;
            if (!int.TryParse(cboActivo.SelectedValue, out activo) || activo == 0)
            {
                Tools.tools.ClientAlert("Elija el equipo que va a ocupar la posición.", "alerta");
                return;
            }

            int? motivo = null; int m;
            if (int.TryParse(cboMotivo.SelectedValue, out m) && m > 0) motivo = m;

            ActivoPosicionController controller = new ActivoPosicionController();
            Respuesta respuesta = controller.Ocupar(Id, activo, motivo, txtObservacion.Text.Trim());

            if (!respuesta.error)
            {
                txtObservacion.Text = "";
                Refrescar();
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    protected void btnLiberar_Click(object sender, EventArgs e)
    {
        try
        {
            int? motivo = null; int m;
            if (int.TryParse(cboMotivo.SelectedValue, out m) && m > 0) motivo = m;

            ActivoPosicionController controller = new ActivoPosicionController();
            Respuesta respuesta = controller.Liberar(Id, motivo, txtObservacion.Text.Trim());

            if (!respuesta.error)
            {
                txtObservacion.Text = "";
                Refrescar();
                Tools.tools.ClientAlert(respuesta.detalle, "ok");
            }
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    /// <summary>Vuelve a leer la ocupacion despues de asignar o liberar.</summary>
    private void Refrescar()
    {
        ActivoPosicionController controller = new ActivoPosicionController();
        ActivoPosicion p = controller.GetPosicion(new ActivoPosicion { apo_id = Id });
        CargarOcupacion(p);
        tabFicha.SelectedIndex = 1;
        mpFicha.SelectedIndex = 1;
    }
}
