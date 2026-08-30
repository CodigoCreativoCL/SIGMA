<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Comercial_Suscripciones_Planes, App_Web_q4im1csg" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPlan(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Comercial/Suscripciones/Plan.aspx") %>?query=' + query);
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
    Planes
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    La oferta comercial y su precio vigente de hoy.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="960" Height="640" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlUf" runat="server" CssClass="card-box" Style="margin-bottom: 14px;">
                <asp:Literal ID="litUf" runat="server" />
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrPlanes_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="plc_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo plan" CssClass="icono_guardar" OnClientClick="abrirPlan(0)" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Los montos en pesos son <strong>referenciales</strong>: se calculan con el valor de
                la UF de hoy. Lo que se cobra se congela recién al emitir el período, y desde ahí
                no vuelve a cambiar aunque la UF suba.<br />
                Una fila por plan <strong>y periodicidad</strong>: el mismo plan aparece varias veces
                porque el precio es lo que cambia entre mensual, trimestral y anual.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
