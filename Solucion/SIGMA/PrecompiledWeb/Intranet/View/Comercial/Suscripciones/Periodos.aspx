<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Comercial_Suscripciones_Periodos, App_Web_hcstghdl" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPeriodo(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Comercial/Suscripciones/Periodo.aspx") %>?query=' + query);
            oWin.show();
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Comercial
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Períodos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Lo que se le cobró al cliente y con qué valor de UF se calculó.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboImpagos" style="margin: 0;">Mostrar:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboImpagos" runat="server" Width="70%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos los períodos" Value="" />
                            <rad:RadComboBoxItem Text="Solo con saldo pendiente" Value="1" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-6 col-md-6 col-xs-12 d-flex align-items-center"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="900" Height="620" />

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para ver sus períodos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlAviso" runat="server" Visible="false" CssClass="card-box" Style="margin-bottom: 14px;">
                <asp:Literal ID="litAviso" runat="server" />
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrPeriodos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="spe_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Emitir período" CssClass="icono_guardar" OnClientClick="abrirPeriodo(0)" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
