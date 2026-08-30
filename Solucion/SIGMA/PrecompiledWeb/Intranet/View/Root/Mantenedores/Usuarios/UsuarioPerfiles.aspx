<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Sistema_Usuarios_UsuarioPerfiles, App_Web_fxfeqo2s" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript" >
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
    </script>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="cphBody" runat="server" >
<div class="sigma-modal">
    <h1 class="sigma-modal-title">Asociar Perfiles</h1>
    <asp:UpdatePanel runat="server" ID="udPanel"  UpdateMode="Conditional" >
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server">
                <MasterTableView DataKeyNames="upe_perfil"/>
                <ClientSettings>
                    <Scrolling AllowScroll="True" UseStaticHeaders="True" SaveScrollPosition="True" ></Scrolling>
                </ClientSettings>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
    <WebControls:PushButton ID="btnAsociar" runat="server" Text="Asociar" OnClick="btnAsociar_Click"/>
</div>
</div>
</asp:Content>