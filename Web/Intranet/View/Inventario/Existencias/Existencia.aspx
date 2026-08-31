<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Existencia.aspx.cs" Inherits="View_Inventario_Existencias_Existencia" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Existencia del repuesto</h1>

    <div class="sigma-modal-hero">
        <div class="sigma-modal-hero-icon"><i class="mdi mdi-package-variant-closed"></i></div>
        <div class="sigma-modal-hero-text">
            <div class="sigma-modal-hero-title"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
            <div class="sigma-modal-hero-detail"><asp:Literal ID="litHeroDetalle" runat="server" /></div>
        </div>
        <div class="sigma-modal-hero-chip"><asp:Literal ID="litChipEstado" runat="server" /></div>
    </div>

    <div class="sigma-modal-section">
        <div class="sigma-modal-section-title">
            <i class="mdi mdi-warehouse"></i>
            <span>Dónde está</span>
        </div>

        <rad:RadGrid2 ID="GridBodegas" runat="server" OnItemDataBound="GridBodegas_ItemDataBound">
            <MasterTableView CommandItemDisplay="None" />
        </rad:RadGrid2>
    </div>

    <div class="sigma-modal-section">
        <div class="sigma-modal-section-title">
            <i class="mdi mdi-history"></i>
            <span>Últimos movimientos</span>
        </div>

        <rad:RadGrid2 ID="GridMovimientos" runat="server" OnItemDataBound="GridMovimientos_ItemDataBound">
            <MasterTableView CommandItemDisplay="None" />
        </rad:RadGrid2>
    </div>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
