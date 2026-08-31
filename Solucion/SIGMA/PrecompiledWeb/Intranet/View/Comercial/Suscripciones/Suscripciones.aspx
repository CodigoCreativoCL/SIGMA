<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Comercial_Suscripciones_Suscripciones, App_Web_hcstghdl" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirSuscripcion(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Comercial/Suscripciones/Suscripcion.aspx") %>?query=' + query);
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
    Suscripción
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El plan contratado por el cliente y hasta cuándo lo habilita.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="960" Height="620" />

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para ver su suscripción.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlEstado" runat="server" Visible="false" CssClass="card-box" Style="margin-bottom: 14px;">
                <asp:Literal ID="litEstado" runat="server" />
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrSuscripciones_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="sus_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Crear suscripción" CssClass="icono_guardar" OnClientClick="abrirSuscripcion(0)" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
