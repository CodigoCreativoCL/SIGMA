<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="UsuarioPaises.aspx.cs" Inherits="View_Sistema_Usuarios_UsuarioPaises" %>

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
    <div class="SubTitulos">Asociar Paises</div>
    <asp:UpdatePanel runat="server" ID="udPanel"  UpdateMode="Conditional" >
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server">
                <MasterTableView DataKeyNames="pai_id"/>
                <ClientSettings>
                    <Scrolling AllowScroll="True" UseStaticHeaders="True" SaveScrollPosition="True" ></Scrolling>
                </ClientSettings>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
    <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
        <WebControls:PushButton ID="btnAsociar" runat="server" Text="Asociar" OnClick="btnAsociar_Click"/>
        <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
    </div>
</asp:Content>