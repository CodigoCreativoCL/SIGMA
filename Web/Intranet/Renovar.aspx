<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Renovar.aspx.cs" Inherits="Renovar" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPago(query) {
            var oWin = $find("<%=rwiPago.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Comercial/Suscripciones/Pago.aspx") %>?query=' + query);
            oWin.show();
        }

        function refresh() {
            __doPostBack("<%=GridPagos.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Suscripción
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Mi suscripción
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El estado de tu plan y lo que necesitas para seguir trabajando.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <%-- El estado, primero y grande: es a lo que se viene. --%>
    <div class="card-box">
        <div class="sg-renovar-estado">
            <span class="grid-estado-chip"><asp:Literal ID="litChipEstado" runat="server" /></span>
            <h2><asp:Literal ID="litTitulo" runat="server" /></h2>
            <p><asp:Literal ID="litMensaje" runat="server" /></p>
        </div>

        <div class="row col-lg-12 col-md-12 col-xs-12">
            <div class="col-lg-4 col-md-4 col-xs-12 identidad-readonly-item">
                <label>Plan</label>
                <div class="identidad-readonly-chip-sm"><asp:Label ID="lblPlan" runat="server" /></div>
            </div>
            <div class="col-lg-4 col-md-4 col-xs-12 identidad-readonly-item">
                <label>Vigente hasta</label>
                <div class="identidad-readonly-chip-sm"><asp:Label ID="lblVigencia" runat="server" /></div>
            </div>
            <div class="col-lg-4 col-md-4 col-xs-12 identidad-readonly-item">
                <label>Saldo pendiente</label>
                <div class="identidad-readonly-chip-sm"><asp:Label ID="lblSaldo" runat="server" /></div>
            </div>
        </div>
    </div>

    <%-- Los períodos impagos: lo concreto que hay que pagar. --%>
    <asp:Panel ID="pnlPeriodos" runat="server" Visible="false">
        <div class="SubTitulos">Períodos pendientes de pago</div>
        <rad:RadGrid2 ID="GridPeriodos" runat="server">
            <MasterTableView CommandItemDisplay="None" DataKeyNames="spe_id">
            </MasterTableView>
        </rad:RadGrid2>
        <br />
    </asp:Panel>

    <%-- El consumo del plan. Sirve tanto para el que está al día como para
         el que se está preguntando por qué no puede crear una planta más. --%>
    <asp:Panel ID="pnlLimites" runat="server" Visible="false">
        <div class="SubTitulos">Uso de tu plan</div>
        <rad:RadGrid2 ID="GridLimites" runat="server" OnItemDataBound="GridLimites_ItemDataBound">
            <MasterTableView CommandItemDisplay="None" DataKeyNames="fun_codigo">
            </MasterTableView>
        </rad:RadGrid2>
        <br />
    </asp:Panel>

    <%-- Declarar un pago.

         La funcion vivia en Comercial > Pagos, que es la vista de TODAS las
         suscripciones y dejo de ser del cliente cuando se le quitaron los
         permisos de plataforma. Aqui es donde corresponde: el cliente ve su
         saldo, declara contra el, y sigue el estado de lo declarado.

         El cliente NO verifica su propio pago -eso lo hace SIGMA-, asi que
         esta grilla es de solo lectura salvo por el boton. --%>
    <asp:Panel ID="pnlPagos" runat="server" Visible="false">
        <div class="SubTitulos">Mis pagos declarados</div>

        <rad:RadWindow2 ID="rwiPago" runat="server" Width="900" Height="620" />

        <rad:RadGrid2 ID="GridPagos" runat="server" OnItemDataBound="GridPagos_ItemDataBound">
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="spa_id">
                <CommandItemTemplate>
                    <div>
                        <asp:LinkButton ID="lnkDeclarar" runat="server" Text="Declarar pago"
                            CssClass="icono_guardar" OnClick="lnkDeclarar_Click" />
                    </div>
                </CommandItemTemplate>
            </MasterTableView>
        </rad:RadGrid2>
        <br />
    </asp:Panel>

    <div class="card-box">
        <div class="sg-renovar-contacto">
            <i class="mdi mdi-lifebuoy"></i>
            <div>
                <strong>¿Necesitas ayuda para regularizar?</strong>
                <p>
                    Escríbenos a <a href="mailto:contacto@sigma.cl">contacto@sigma.cl</a>
                    indicando el nombre de tu empresa. Tus datos están completos y
                    se recuperan íntegros al renovar: <strong>nada se borra por falta de pago</strong>.
                </p>
            </div>
        </div>
    </div>

</asp:Content>
