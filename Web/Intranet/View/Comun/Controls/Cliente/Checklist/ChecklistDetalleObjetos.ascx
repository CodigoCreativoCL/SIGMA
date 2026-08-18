<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ChecklistDetalleObjetos.ascx.cs" Inherits="View_Comun_Controls_Cliente_Checklist_ChecklistDetalleObjetos" %>


<script type="text/javascript" language="javascript">
    //Cierra el RadWindow"
    function getRadWindow() {
        var oWindow = null;
        if (window.radWindow)
            oWindow = window.radWindow;
        else if (window.frameElement.radWindow)
            oWindow = window.frameElement.radWindow;
        return oWindow;
    }

    function closeWindow() {
        var window = getRadWindow();
        if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
        window.close();
    }



    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }

</script>

<div class="SubTitulos col-lg-12 col-md-12 col-xs-12">
    Lista Desplegable
</div>
<rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
    <MasterTableView CommandItemDisplay="Top" DataKeyNames="cdc_id, cdc_id_checklist_detalle">
        <CommandItemTemplate>
            <div>
                <asp:LinkButton ID="lnkAñadir" runat="server" Text="Añadir" CssClass="icono_guardar" OnClick="lnkAñadir_Click" />
                <asp:LinkButton ID="lnkEliminar" runat="server" Text="Quitar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                    OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
            </div>
        </CommandItemTemplate>
    </MasterTableView>
    <ClientSettings>
        <Scrolling AllowScroll="True" ScrollHeight="380px" />
    </ClientSettings>
</rad:RadGrid2>
<div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
</div>
