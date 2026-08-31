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

    <%-- Pestañas y no secciones apiladas: dos grillas una debajo de otra
         obligan a bajar para ver la segunda, y en una ventana modal eso
         significa que la mitad de la ficha no se sabe que existe.

         El hero se queda ARRIBA de las pestañas: es la identidad del
         repuesto, no una de sus vistas. --%>
    <rad:RadTabStrip2 ID="tabFicha" runat="server" MultiPageID="mpFicha" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabDonde" Text="Dónde está" runat="server" PageViewID="pvDonde" />
            <rad:RadTab ID="tabMovimientos" Text="Últimos movimientos" runat="server" PageViewID="pvMovimientos" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFicha" runat="server" SelectedIndex="0" Width="100%">

        <rad:RadPageView ID="pvDonde" runat="server">
            <rad:RadGrid2 ID="GridBodegas" runat="server" OnItemDataBound="GridBodegas_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" />
            </rad:RadGrid2>
        </rad:RadPageView>

        <rad:RadPageView ID="pvMovimientos" runat="server">
            <rad:RadGrid2 ID="GridMovimientos" runat="server" OnItemDataBound="GridMovimientos_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" />
            </rad:RadGrid2>
        </rad:RadPageView>

    </rad:RadMultiPage>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
