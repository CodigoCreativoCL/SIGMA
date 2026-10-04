using SitioBase.Controller;
using SitioBase.Model;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Drawing;
using System.Web.UI.HtmlControls;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using WebControls;


public partial class View_Comun_Controls_Cliente_Usuarios : System.Web.UI.UserControl
{
    public bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState.Add("ReadOnly", value); }
    }

    public bool VerComboCliente
    {
        get { return Convert.ToBoolean(ViewState["VerComboCliente"]); }
        set { ViewState.Add("VerComboCliente", value); }
    }

    public int IdCliente
    {
        get { return Convert.ToInt32(ViewState["IdCliente"]); }
        set { ViewState.Add("IdCliente", value); }
    }

    public int TipoPerfil
    {
        get { return Convert.ToInt32(ViewState["TipoPerfil"]); }
        set { ViewState.Add("TipoPerfil", value); }
    }

    public string Perfiles
    {
        get { return Convert.ToString(ViewState["Perfiles"]); }
        set { ViewState.Add("Perfiles", value); }
    }

    public int IdClienteInstalacion
    {
        get { return Convert.ToInt32(ViewState["IdClienteInstalacion"]); }
        set { ViewState.Add("IdClienteInstalacion", value); }
    }

    public bool Asociar
    {
        get { return Convert.ToBoolean(ViewState["Asociar"]); }
        set { ViewState.Add("Asociar", value); }
    }

    /// <summary>
    /// Modo de la ficha de planta: la grilla muestra a todo el personal del
    /// cliente, llega con los responsables ya marcados y destacados, y el
    /// boton Guardar de la ficha sincroniza lo que se marco o desmarco
    /// (ver GuardarResponsables). Sin este modo, marcar filas y guardar no
    /// hacia nada: la seleccion solo servia para los botones Asociar y
    /// Desasociar, y al volver a entrar no quedaba nadie registrado.
    /// </summary>
    public bool SeleccionResponsables
    {
        get { return Convert.ToBoolean(ViewState["SeleccionResponsables"]); }
        set { ViewState.Add("SeleccionResponsables", value); }
    }

    /// <summary>Los usu_id que hoy son responsables de la planta.</summary>
    protected HashSet<int> ResponsablesActuales
    {
        get
        {
            HashSet<int> ids = new HashSet<int>();
            string csv = Convert.ToString(ViewState["ResponsablesActuales"]);
            foreach (string x in csv.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
                ids.Add(int.Parse(x));
            return ids;
        }
        set { ViewState["ResponsablesActuales"] = string.Join(",", value); }
    }

    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;
                switch (ctrl.ID)
                {

                    case "cboPerfiles":

                        PerfilController perfilController = new PerfilController();
                        Perfil perfil = new Perfil();
                        ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));
                        ctrl.AppendDataBoundItems = true;
                        ctrl.DataValueField = "per_id";
                        ctrl.DataTextField = "per_nombre";

                        /* Esta grilla lista usuarios DEL CLIENTE, asi que el
                           filtro por perfil ofrece perfiles de tipo Cliente.
                           Si la pantalla trae un TipoPerfil explicito se
                           respeta; si no, el que corresponde es el 2.

                           Antes, cuando el usuario en sesion era Root,
                           Soporte o Gerente Comercial, se le inyectaba la
                           lista fija "3,4,5,6,7". Esos ids eran los perfiles
                           de FacilityGes y en SIGMA apuntan a otra cosa: el
                           combo terminaba ofreciendo Gerente Comercial y
                           Bodeguero mezclados, y omitiendo los perfiles
                           operativos reales. */
                        perfil.tipo = TipoPerfil > 0 ? TipoPerfil.ToString() : "2";
                        perfil.filtro_habilitado = "1";

                        ctrl.DataSource = perfilController.ListoPerfiles(perfil);
                        ctrl.DataBind();

                        break;

                }
            }

            if (TipoPerfil == 0)
            {
                HtmlGenericControl cboTipoPanel = (HtmlGenericControl)wucFiltro.FindControl("cboTipoPanel");
                cboTipoPanel.Visible = true;
            }
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        bool conCliente = IdCliente > 0;
        pnlContenido.Visible = conCliente;
        wucPanelSinSeleccion.MostrarPanel = !conCliente;

        if (!IsPostBack)
        {
            Grid.Columns.Clear();

            if (!ReadOnly && !SeleccionResponsables)
                Grid.AddSelectColumn();
            if (Asociar)
            {
                Grid.AddColumn("USU_ID", "", Width: "2%");
                Grid.AddColumn("USU_ID", "ID", Width: "4%");
                Grid.AddColumn("NOMBRE_COMPLETO", "NOMBRE", Width: "30%");
                Grid.AddColumn("usu_identificador", "IDENTIFICADOR");
                Grid.AddColumn("usu_correo", "CORREO");
                Grid.AddColumn("usu_telefono", "TELEFONO");
                if (TipoPerfil == 1)
                    Grid.AddColumn("PERFILES", "PERFIL");
                else
                    Grid.AddColumn("PERFILES", "PERFIL");
                Grid.AddCheckboxColumn("USU_HABILITADO", "ESTADO");
            }
            else
            {
                Grid.AddColumn("USU_ID", "", Width: "2%");
                Grid.AddColumn("USU_ID", "ID", Width: "4%");
                Grid.AddColumn("NOMBRE_COMPLETO", "NOMBRE", Width: "30%");
                Grid.AddColumn("usu_login", "LOGIN", Width: "20%");
                Grid.AddColumn("usu_identificador", "IDENTIFICADOR");
                if (TipoPerfil == 1)
                    Grid.AddColumn("PERFILES", "PERFIL");
                else
                    Grid.AddColumn("PERFILES", "PERFIL");
                Grid.AddCheckboxColumn("USU_HABILITADO", "ESTADO");
            }
        }

        if (!conCliente)
        {
            udPanel.Update();
            udPanelContenedor.Update();
            return;
        }

        Tools.tools.RegisterPostBackScript(Grid);

        CargarDatos();
        udPanel.Update();
        udPanelContenedor.Update();


        if (ReadOnly || SeleccionResponsables)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        Grid.DataBind();

        if (!ReadOnly) PintarBotonera();
    }

    /// <summary>
    /// Muestra los botones que corresponden al modo: crear gente nueva, o
    /// asociar gente que ya existe.
    ///
    /// POR QUE COMPRUEBA QUE LA BARRA EXISTA
    ///   Antes tomaba GetItems(CommandItem)[0] a secas, cinco veces. La
    ///   barra de comandos NO siempre esta: no se dibuja cuando la grilla
    ///   vive dentro de una pestana que no es la seleccionada -el
    ///   RadMultiPage solo arma la pagina visible- ni cuando alguien dejo
    ///   CommandItemDisplay en None. En esos casos el indice [0] reventaba
    ///   con "Indice fuera de los limites de la matriz" y se llevaba puesta
    ///   la pantalla entera, cuando lo unico que pasaba es que no habia
    ///   botonera que configurar.
    /// </summary>
    protected void PintarBotonera()
    {
        GridItem[] comandos = Grid.MasterTableView.GetItems(GridItemType.CommandItem);

        if (comandos == null || comandos.Length == 0) return;

        GridItem barra = comandos[0];

        LinkButton lnkNuevo = barra.FindControl("lnkNuevo") as LinkButton;
        LinkButton lnkDeshabilitar = barra.FindControl("lnkDeshabilitar") as LinkButton;
        LinkButton lnkCargaMasiva = barra.FindControl("lnkCargaMasiva") as LinkButton;
        LinkButton lnkAsociar = barra.FindControl("lnkAsociar") as LinkButton;
        LinkButton lnkDesasociar = barra.FindControl("lnkDesasociar") as LinkButton;

        /* Asociar es el modo "esta persona ya existe, sumala aqui"; el otro
           es "crea una persona nueva". Los botones de un modo no tienen
           sentido en el otro. */
        if (lnkNuevo != null) lnkNuevo.Visible = !Asociar;
        if (lnkDeshabilitar != null) lnkDeshabilitar.Visible = !Asociar;
        if (lnkCargaMasiva != null) lnkCargaMasiva.Visible = !Asociar;

        if (lnkAsociar != null) lnkAsociar.Visible = Asociar;
        if (lnkDesasociar != null) lnkDesasociar.Visible = Asociar;
    }

    protected void CargarDatos()
    {
        ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
        ClienteUsuario clienteUsuario = new ClienteUsuario();
        clienteUsuario.ucl_id_cliente = IdCliente;
        clienteUsuario.id_perfiles = Perfiles;
        /* En modo seleccion se lista a todo el cliente: la planta solo decide
           quien llega marcado. */
        clienteUsuario.cin_id_instalacion = SeleccionResponsables ? 0 : IdClienteInstalacion;
        RadComboBox2 cboPerfiles = (RadComboBox2)wucFiltro.FindControl("cboPerfiles");
        if (cboPerfiles.SelectedValue != "") clienteUsuario.id_perfiles = cboPerfiles.SelectedValue;
        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");
        if (cboHabilitado.SelectedValue == "1") clienteUsuario.usu_habilitado = true;
        if (cboHabilitado.SelectedValue == "0") clienteUsuario.usu_habilitado = false;
        if (wucFiltro.Filtro() != null) clienteUsuario.filtro = wucFiltro.Filtro();

        if (TipoPerfil > 0)
            clienteUsuario.tipo_perfil = TipoPerfil;
        else
        {
            RadComboBox2 cboTipo = (RadComboBox2)wucFiltro.FindControl("cboTipo");
            clienteUsuario.tipo_perfil = int.Parse(cboTipo.SelectedValue);
        }

        Grid.DataSource = clienteUsuarioController.GetClienteUsuarios(clienteUsuario);

        List<ClienteUsuario> lista = (List<ClienteUsuario>)Grid.DataSource;

        if (SeleccionResponsables && IdClienteInstalacion > 0)
        {
            ResponsablesActuales = clienteUsuarioController.GetResponsablesPlanta(IdCliente, IdClienteInstalacion);

            /* Responsables primero: es lo que se viene a mirar. */
            HashSet<int> resp = ResponsablesActuales;
            lista = lista.OrderByDescending(u => resp.Contains(u.usu_id)).ToList();
            Grid.DataSource = lista;

            /* Se llena en ItemDataBound: solo cuentan las filas de la pagina
               que se dibuja, que son las unicas con casilla. */
            ViewState["IdsVisibles"] = "";
        }
    }

    /// <summary>Nombre del campo de formulario de las casillas de responsable.</summary>
    protected string CampoResponsable
    {
        get { return "resp_" + ClientID; }
    }

    /// <summary>
    /// Sincroniza los responsables de la planta con lo marcado en la grilla:
    /// asocia a los marcados que no lo eran y quita a los desmarcados que si.
    /// Solo toca las filas visibles, para que un filtro de busqueda no
    /// desasocie a quien simplemente no aparece en pantalla.
    /// </summary>
    public Respuesta GuardarResponsables()
    {
        Respuesta resultado = new Respuesta();
        if (!SeleccionResponsables || ReadOnly || IdClienteInstalacion <= 0) return resultado;

        HashSet<int> antes = ResponsablesActuales;

        HashSet<int> marcados = new HashSet<int>();
        string[] posted = Request.Form.GetValues(CampoResponsable);
        if (posted != null)
            foreach (string v in posted) { int n; if (int.TryParse(v, out n)) marcados.Add(n); }

        List<int> marcar = new List<int>(), desmarcar = new List<int>();
        foreach (string v in Convert.ToString(ViewState["IdsVisibles"]).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
        {
            int id = int.Parse(v);
            bool ahora = marcados.Contains(id);
            if (ahora && !antes.Contains(id)) marcar.Add(id);
            if (!ahora && antes.Contains(id)) desmarcar.Add(id);
        }

        if (marcar.Count + desmarcar.Count == 0) return resultado;

        resultado = new ClienteUsuarioController().GuardarResponsablesPlanta(IdCliente, IdClienteInstalacion, marcar, desmarcar);
        if (!resultado.error)
            resultado.detalle = "Responsables: " + marcar.Count + " agregado(s), " + desmarcar.Count + " quitado(s).";
        return resultado;
    }

    protected void Grid_ItemDataBound(object sender, GridItemEventArgs e)
    {
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (((e.Item) is GridDataItem))
            {
                GridDataItem item = e.Item as GridDataItem;
                string id = item.GetDataKeyValue("usu_id").ToString();
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + id + "&IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly
                    + "&Asociar=" + Asociar + "&TipoPerfil=" + TipoPerfil + "&UsuarioCliente=" + true + "&Perfiles=" + Perfiles));

                //Creo el link
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkAnular" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrirUsuario('" + query + "')");

                //Asigno el Link a la celda
                GridDataItem DataItem = e.Item as GridDataItem;
                TableCell USU_ID = DataItem["usu_id"];

                USU_ID.Controls.Add(Editar);

                /* Casilla propia, no la seleccion de Telerik: la seleccion
                   no se pinta al cargar y se pierde entre postbacks. La
                   casilla viaja en el formulario y Guardar la lee. */
                if (SeleccionResponsables)
                {
                    bool esResp = ResponsablesActuales.Contains(Convert.ToInt32(id));
                    string chk = "<label class=\"sigma-resp-toggle\" title=\"Responsable de la planta\">"
                        + "<input type=\"checkbox\" name=\"" + CampoResponsable + "\" value=\"" + id + "\""
                        + (esResp ? " checked" : "") + (ReadOnly ? " disabled" : "")
                        + " onchange=\"sigmaMarcarResponsable(this)\" /></label>";
                    USU_ID.Controls.AddAt(0, new System.Web.UI.LiteralControl(chk));

                    /* Se conserva la clase de Telerik (rgRow / rgAltRow): asignar solo
                       la propia le quitaba el relleno a las celdas y la fila
                       quedaba descuadrada, con la casilla pegada al borde. */
                    if (esResp)
                        item.CssClass = (e.Item.ItemType == GridItemType.AlternatingItem ? "rgAltRow" : "rgRow")
                                      + " sigma-fila-responsable";
                    ViewState["IdsVisibles"] = Convert.ToString(ViewState["IdsVisibles"]) + "," + id;
                }
            }
        }
    }

    protected void lnkNuevoUsuario_Click(object sender, EventArgs e)
    {
        string query = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + 0 + "&IdCliente=" + IdCliente + "&ReadOnly=" + ReadOnly
              + "&Asociar=" + Asociar + "&TipoPerfil=" + TipoPerfil + "&Perfiles=" + Perfiles));
        Tools.tools.ClientExecute("abrirUsuario('" + query + "')");
    }

    protected void lnkDeshabilitar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
                List<ClienteUsuario> clienteUsuarios = new List<ClienteUsuario>();

                foreach (string item in Grid.SelectedIndexes)
                {
                    Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                    int id = Int32.Parse(value["usu_id"].ToString());

                    ClienteUsuario clienteUsuario = new ClienteUsuario();
                    clienteUsuario.usu_id = id;
                    clienteUsuario.ucl_id_cliente = IdCliente;

                    clienteUsuarios.Add(clienteUsuario);

                }

                Respuesta respuesta = clienteUsuarioController.DeshabilitarClienteUsuario(clienteUsuarios);

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message);
        }
    }

    protected void lnkAsociar_Click(object sender, EventArgs e)
    {
        if (TipoPerfil == 1)
        {
            if (IdClienteInstalacion > 0)
            {
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdCliente=" + IdCliente + "&TipoPerfil=" + TipoPerfil + "&IdClienteInstalacion=" + IdClienteInstalacion +
               "&Perfiles=" + Perfiles));
                Tools.tools.ClientExecute("asociarUsuario('" + query + "')");
            }
            else
            {
                string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdCliente=" + IdCliente + "&TipoPerfil=" + TipoPerfil +
              "&Perfiles=" + Perfiles));
                Tools.tools.ClientExecute("asociarUsuario('" + query + "')");
            }

        }
        else
        {
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("IdCliente=" + IdCliente + "&TipoPerfil=" + TipoPerfil +
               "&Perfiles=" + Perfiles));
            Tools.tools.ClientExecute("asociarUsuario('" + query + "')");
        }
    }

    protected void lnkDesasociar_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
            }
            else
            {
                Respuesta respuesta = new Respuesta();

                foreach (string item in Grid.SelectedIndexes)
                {
                    if (TipoPerfil == 1)
                    {
                        // Si IdClienteInstalacion es mayor que 0, pasa por el primer bloque
                        if (IdClienteInstalacion > 0)
                        {
                            Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                            int id = Int32.Parse(value["usu_id"].ToString());

                            ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
                            ClienteUsuario clienteUsuario = new ClienteUsuario();

                            clienteUsuario.usu_id = id;
                            clienteUsuario.ucl_id_cliente = IdCliente;
                            clienteUsuario.cin_id_instalacion = IdClienteInstalacion;

                            respuesta = clienteUsuarioController.DeleteUsuarioAsociacion(clienteUsuario);
                        }
                        // Si IdClienteInstalacion es NULL o 0, pasa por el else
                        else
                        {
                            Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                            int id = Int32.Parse(value["usu_id"].ToString());

                            ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
                            ClienteUsuario clienteUsuario = new ClienteUsuario();

                            clienteUsuario.usu_id = id;
                            clienteUsuario.ucl_id_cliente = IdCliente;


                            respuesta = clienteUsuarioController.DeleteUsuarioAsociacion(clienteUsuario);
                        }
                    }
                    else
                    {
                        // Si TipoPerfil no es igual a 1, pasa por este bloque
                        Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[Int32.Parse(item)];
                        int id = Int32.Parse(value["usu_id"].ToString());

                        ClienteUsuarioController clienteUsuarioController = new ClienteUsuarioController();
                        ClienteUsuario clienteUsuario = new ClienteUsuario();

                        clienteUsuario.usu_id = id;
                        clienteUsuario.ucl_id_cliente = IdCliente;
                        clienteUsuario.cin_id_instalacion = IdClienteInstalacion;

                        respuesta = clienteUsuarioController.DeleteUsuarioAsociacion(clienteUsuario);
                    }
                }

                if (!respuesta.error)
                    Tools.tools.ClientAlert(respuesta.detalle, "ok");
                else
                    Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    protected void lnkCargaMasiva_Click(object sender, EventArgs e)
    {

        if (TipoPerfil == 1)
        {
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("&IdCliente=" + IdCliente +
                "&TipoPerfil=" + TipoPerfil + "&Perfiles=" + Perfiles));
            Tools.tools.ClientExecute("cargaMasiva('" + query + "')");
        }
        else
        {
            string query = Server.UrlEncode(Tools.Crypto.Encrypt("&IdCliente=" + IdCliente +
                "&TipoPerfil=" + TipoPerfil + "&Perfiles=" + Perfiles));
            Tools.tools.ClientExecute("cargaMasiva('" + query + "')");
        }
    }

}