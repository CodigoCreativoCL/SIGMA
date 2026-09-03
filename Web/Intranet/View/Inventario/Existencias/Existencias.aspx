<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Existencias.aspx.cs" Inherits="View_Inventario_Existencias_Existencias" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirExistencia(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Existencias/Existencia.aspx") %>?query=' + query,
                title: 'Existencia',
                width: 960,
                initialHeight: 600
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Existencias
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cuántas unidades hay y en qué estante están.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboEstado" style="margin: 0;">Estado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboEstado" runat="server" Width="80%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Fuera de umbral" Value="FUERA" />
                            <rad:RadComboBoxItem Text="Bajo el mínimo" Value="BAJO" />
                            <rad:RadComboBoxItem Text="Sobre el máximo" Value="SOBRE" />
                            <rad:RadComboBoxItem Text="Hora de pedir" Value="PEDIR" />
                            <rad:RadComboBoxItem Text="En rango" Value="RANGO" />
                            <rad:RadComboBoxItem Text="Sin umbral definido" Value="SIN" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboBodega" style="margin: 0;">Bodega:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboBodega" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" />
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlAlertas" runat="server" CssClass="card-box" Style="margin-bottom: 14px;">
                <asp:Literal ID="litAlertas" runat="server" />
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="isa_repuesto" />
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                <strong>Ubicación</strong> es dónde se dejó el repuesto la última vez que se movió,
                no una propiedad fija: la misma pieza puede estar en dos estantes de la misma bodega.<br />
                <strong>Disponible</strong> descuenta lo reservado por órdenes de trabajo.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
