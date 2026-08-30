using SitioBase.Controller;
using SitioBase.Model;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
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

            if (!ReadOnly)
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


        if (ReadOnly)
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
        clienteUsuario.cin_id_instalacion = IdClienteInstalacion;
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