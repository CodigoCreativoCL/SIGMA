<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="LogApp.aspx.cs" Inherits="View_Root_LogSistema_LogApp" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirDetalle(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Sistema/Mantenedores/LogSistemas/LogAppDetalle.aspx") %>?query=' + query);
            oWin.show();
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    API APP - Log de Endpoints
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12"> 

                <div class="col-lg-3 col-md-3 col-sm-6 mb-2">
                    <label>Endpoint:</label>
                    <asp:TextBox ID="txtEndpoint" runat="server" CssClass="form-control" placeholder="Buscar endpoint..." />
                </div>

                <div class="col-lg-2 col-md-2 col-sm-6 mb-2">
                    <label>Error:</label>
                    <rad:RadComboBox2 ID="cboError" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos"  Value=""  />
                            <rad:RadComboBoxItem Text="S&iacute;" Value="1" />
                            <rad:RadComboBoxItem Text="No"    Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>

                <div class="col-lg-2 col-md-2 col-sm-6 mb-2">
                    <label>Usuario:</label>
                    <rad:RadComboBox2 ID="cboUsuario" runat="server" Width="100%" />
                </div>

                <div class="col-lg-2 col-md-2 col-sm-6 mb-2">
                    <label>Fecha Desde:</label>
                    <br />
                    <WebControls:Calendar ID="radFechaDesde" runat="server" Width="100%" AutoPostBack="True" />
                </div>

                <div class="col-lg-2 col-md-2 col-sm-6 mb-2">
                    <label>Fecha Hasta:</label>
                    <br />
                    <WebControls:Calendar ID="radFechaHasta" runat="server" Width="100%" AutoPostBack="True" />
                </div>

            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <rad:RadWindow2 ID="rwiDetalle" Title="Detalle Log Endpoint" runat="server" Width="900" Height="600" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView DataKeyNames="lot_id">
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>

</asp:Content>
