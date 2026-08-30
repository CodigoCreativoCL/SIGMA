<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Comun_Clientes_InformeUsuarioMarcacionFoto, App_Web_gmat4w2s" %>
<asp:Content ID="Content2" ContentPlaceHolderID="cphHeder" runat="server">

</asp:Content>
<asp:Content ID="Content1" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
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

<asp:Content ID="ContenHead" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">       
        <ContentTemplate>
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12 col-md-12 col-xs-12" style="text-align:center;">
                         <asp:Image ID="imgNovedad" runat="server" style="width:50vh; height:50vh;"/>
                    </div>
                </div>
            </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" Width="102px"
                        OnClientClick="closeWindow();"/>
</div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
