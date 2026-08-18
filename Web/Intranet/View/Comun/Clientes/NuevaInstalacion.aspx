<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevaInstalacion.aspx.cs" Inherits="View_Comun_Clientes_NuevoInstalacion" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Instalaciones/Identidad.ascx" TagPrefix="wuc" TagName="Identidad" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Responsable" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Administrativo" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Instalaciones/ConfiguracionApp.ascx" TagPrefix="wuc" TagName="ConfiguracionApp" %>

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
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadTabStrip2 ID="ragTab" runat="server" MultiPageID="MultiPage" Skin="Bootstrap" RenderMode="Lightweight" SelectedIndex="0">
                <Tabs>
                    <rad:RadTab Text="Identidad" runat="server" PageViewID="rtvIdentidad" />
                    <rad:RadTab Text="Configuracion APP" runat="server" PageViewID="rtvConfApp" />
                    <rad:RadTab Text="Responsable" runat="server" PageViewID="rtvResponsable" />
                </Tabs>
            </rad:RadTabStrip2>
            <rad:RadMultiPage ID="MultiPage" runat="server" SelectedIndex="0">
                <rad:RadPageView ID="rtvIdentidad" runat="server">
                    <wuc:Identidad runat="server" ID="wucIdentidad" />
                </rad:RadPageView>
                <rad:RadPageView ID="rtvConfApp" runat="server">
                    <div class="SubTitulos">Configuración App</div>
                    <wuc:ConfiguracionApp runat="server" ID="wucConfiguracionApp" />
                </rad:RadPageView>
                <rad:RadPageView ID="rtvResponsable" runat="server">
                    <div class="SubTitulos">Responsables de la instalación</div>
                    <wuc:Responsable runat="server" ID="wucResponsable" />
                </rad:RadPageView>
            </rad:RadMultiPage>
            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center" style="margin-top: 10px;">
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" Width="102px"
                    OnClientClick="closeWindow();" />
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
