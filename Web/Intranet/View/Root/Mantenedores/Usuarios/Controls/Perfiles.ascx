<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Perfiles.ascx.cs" Inherits="View_Sistema_Usuarios_Controls_Perfiles" %>

<script type="text/javascript">
    function abrirPerfil(query) {
        return SigmaModal.open({
            url: '<%=ResolveUrl("~/View/Root/Mantenedores/Usuarios/UsuarioPerfiles.aspx") %>?query=' + query,
            title: 'Usuario perfiles',
            width: 1000,
            initialHeight: 380
        });
    }
    function refreshUsuarioPerfil() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>


<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <rad:RadGrid2 ID="Grid" runat="server">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="upe_id">
                <CommandItemTemplate>
                    <div style="margin-bottom: 10px;">
                        <asp:LinkButton ID="lnkNuevo" runat="server" Text="Asociar" CssClass="icono_guardar" OnClick="lnkNuevo_Click" />
                        <asp:LinkButton ID="lnkEliminar" runat="server" Text="Desvincular" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea desvincular los perfiles seleccionados?');" />
                    </div>
                </CommandItemTemplate>
            </MasterTableView>
        </rad:RadGrid2>
        <div class="col-lg-12 col-md-12 col-xs-12 form-col-center mt-2">
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
        </div>
    </ContentTemplate>
</asp:UpdatePanel>
