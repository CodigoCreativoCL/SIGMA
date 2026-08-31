<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Inventario_Movimientos_Movimientos, App_Web_z1kxe1ru" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirMovimiento(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Inventario/Movimientos/Movimiento.aspx") %>?query=' + query);
            oWin.show();
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }

        /* El popover de la lupa vive en Js/sigma-popover.js: lo usan esta
           grilla y la ficha de existencia, y dos copias se separan. */
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Movimientos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Todo lo que entró, salió o se corrigió, con quién lo hizo y por qué.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboTipo" style="margin: 0;">Tipo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboBodega" style="margin: 0;">Bodega:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboBodega" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" />
                </div>

                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboUsuario" style="margin: 0;">Registró:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <%-- Solo quienes registraron al menos un movimiento. Con todos los
                         usuarios del cliente serían decenas y casi ninguna tocó nunca el
                         inventario. --%>
                    <rad:RadComboBox2 ID="cboUsuario" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" />
                </div>

                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="txtDesde" style="margin: 0;">Desde:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <WebControls:TextBox2 ID="txtDesde" runat="server" MaxLength="10" Width="80%" />
                </div>

                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="txtHasta" style="margin: 0;">Hasta:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <WebControls:TextBox2 ID="txtHasta" runat="server" MaxLength="10" Width="80%" />
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="960" Height="660" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="imo_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkIngreso" runat="server" Text="Registrar ingreso"
                                CssClass="icono_guardar" OnClientClick="abrirMovimiento(0)" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Los <strong>ajustes</strong> se distinguen de los ingresos y de los consumos por su
                familia. El <i class="mdi mdi-magnify"></i> de la última columna abre el motivo,
                el lote y la bodega de destino sin estirar la fila.<br />
                Un movimiento <strong>no se edita ni se borra</strong>: es el registro de algo que
                pasó. Si quedó mal, se corrige con otro movimiento en sentido contrario.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
