<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Instalaciones.ascx.cs" Inherits="View_Comun_Controls_Cliente_Instalaciones" %>
<script type="text/javascript">
    function abrirClienteInstalacion(query) {
        return SigmaModal.open({
            url: '<%=ResolveUrl("~/View/Organizacion/Plantas/Planta.aspx") %>?query=' + query,
            title: 'Planta',
            width: 1000,
            initialHeight: 380
        });
        //oWin.maximize();
        bloqueaScroll(false);
    }

    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <div class="sigma-modal-seccion">Plantas</div>
        <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrClienteInstalacion_ItemDataBound">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="cin_id">
                <CommandItemTemplate>
                    <div>
                        <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClick="lnkNuevoClienteInstalacion_Click" />
                        <%--<asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />--%>
                    </div>
                </CommandItemTemplate>
            </MasterTableView>
        </rad:RadGrid2>

    </ContentTemplate>
</asp:UpdatePanel>
