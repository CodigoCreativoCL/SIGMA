<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Clientes.ascx.cs" Inherits="View_Comun_Controls_Cliente_Clientes" %>


<script type="text/javascript">
    function abrirClientes(query) {
        window.location = ('<%=ResolveUrl(URLNuevoCliente) %>?query=' + query);
    }

    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>

<div class="col-lg-12 col-md-12 col-xs-12"> 
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrCliente_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="cli_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="abrirClientes(0)" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
