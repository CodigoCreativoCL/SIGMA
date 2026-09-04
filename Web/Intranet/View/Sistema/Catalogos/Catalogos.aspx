<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Catalogos.aspx.cs" Inherits="View_Sistema_Catalogos_Catalogos" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirValor(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Sistema/Catalogos/CatalogoValor.aspx") %>?query=' + query,
                title: 'Catalogo valor',
                width: 900,
                initialHeight: 480
            });
        }

        function refresh() {
            __doPostBack("<%=GridValores.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Sistema
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Catálogos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Los valores que va a ver el usuario en cada lista del sistema.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- ---------- Buscador transversal (HU-020 escenario 2) ---------- --%>
            <div class="card-box" style="margin-bottom: 16px;">
                <div class="row col-lg-12 col-md-12 col-xs-12">
                    <div class="col-lg-2 col-md-2 col-xs-12 d-flex align-items-center">
                        <label style="margin: 0;">Buscar en todos:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12">
                        <WebControls:TextBox2 ID="txtBusqueda" runat="server" MaxLength="100" />
                    </div>
                    <div class="col-lg-6 col-md-6 col-xs-12">
                        <WebControls:PushButton ID="btnBuscar" runat="server" Text="Buscar" OnClick="btnBuscar_Click" />
                        <WebControls:PushButton ID="btnLimpiar" runat="server" Text="Limpiar" CssClass="ButtonCerrar" OnClick="btnLimpiar_Click" />
                        <span style="font-size: 11px; color: #777; display: block; margin-top: 4px;">
                            Busca el texto en el código y el nombre de los valores de todos los catálogos.
                        </span>
                    </div>
                </div>
            </div>

            <%-- ---------- Resultado de la búsqueda transversal ---------- --%>
            <asp:Panel ID="pnlBusqueda" runat="server" Visible="false">
                <div class="SubTitulos">Resultados de la búsqueda</div>
                <rad:RadGrid2 ID="GridBusqueda" runat="server">
                    <MasterTableView CommandItemDisplay="None" DataKeyNames="ctl_id, valor_id">
                    </MasterTableView>
                </rad:RadGrid2>
                <br />
            </asp:Panel>

            <%-- ---------- Selección de catálogo ---------- --%>
            <div class="card-box" style="margin-bottom: 16px;">
                <div class="row col-lg-12 col-md-12 col-xs-12">
                    <div class="col-lg-2 col-md-2 col-xs-12 d-flex align-items-center">
                        <label style="margin: 0;">Catálogo:</label>
                    </div>
                    <div class="col-lg-6 col-md-6 col-xs-12">
                        <rad:RadComboBox2 ID="cboCatalogo" runat="server" Filter="Contains" Width="90%"
                            AutoPostBack="true" OnSelectedIndexChanged="cboCatalogo_SelectedIndexChanged" />
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center">
                        <asp:Label ID="lblTipoCatalogo" runat="server" CssClass="grid-estado-chip is-neutro" />
                    </div>
                </div>
            </div>

            <%-- ---------- Valores del catálogo elegido ---------- --%>
            <rad:RadGrid2 ID="GridValores" runat="server" OnItemDataBound="GridValores_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="valor_id, valor_cliente">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo valor" CssClass="icono_guardar" OnClientClick="abrirValor(0)" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
