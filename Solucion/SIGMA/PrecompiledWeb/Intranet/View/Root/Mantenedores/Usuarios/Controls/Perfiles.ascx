<%@ control language="C#" autoeventwireup="true" inherits="View_Sistema_Usuarios_Controls_Perfiles, App_Web_deonikfi" %>

<script type="text/javascript">
    function abrirPerfil(query) {
        var oWin = $find("<%=rwiDetalle.ClientID %>");
        oWin.setUrl('<%=ResolveUrl("~/View/Root/Mantenedores/Usuarios/UsuarioPerfiles.aspx") %>?query=' + query);
        oWin.show();
    }
    function refreshUsuarioPerfil() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>


<rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
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
