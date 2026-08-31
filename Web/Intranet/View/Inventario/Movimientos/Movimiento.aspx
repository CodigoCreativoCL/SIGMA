<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Movimiento.aspx.cs" Inherits="View_Inventario_Movimientos_Movimiento" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

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

    <h1 class="sigma-modal-title">Movimiento de inventario</h1>

    <%-- ================== ALTA ================== --%>
    <asp:Panel ID="pnlAlta" runat="server" Visible="false">

        <div class="sigma-modal-note">
            <i class="mdi mdi-information-outline"></i>
            <div>
                Un movimiento <strong>no se edita ni se borra</strong>: es el registro de algo que
                pasó. Si queda mal, se corrige con otro movimiento en sentido contrario.
            </div>
        </div>

        <div class="sigma-modal-grid">

            <div class="sigma-modal-field">
                <label>Qué se hace (*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboTipo_Changed" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
            </div>

            <div class="sigma-modal-field">
                <label>Repuesto (*)</label>
                <rad:RadComboBox2 ID="cboRepuesto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboRepuesto_Changed" />
                <asp:CustomValidator ID="cvRepuesto" runat="server" ControlToValidate="cboRepuesto"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
            </div>

            <div class="sigma-modal-field">
                <label>Bodega (*)</label>
                <rad:RadComboBox2 ID="cboBodega" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboBodega_Changed" />
                <asp:CustomValidator ID="cvBodega" runat="server" ControlToValidate="cboBodega"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
                <span class="sigma-modal-ayuda"><asp:Literal ID="litSaldo" runat="server" /></span>
            </div>

            <div class="sigma-modal-field">
                <label>Cantidad (*)</label>
                <WebControls:TextBox2 ID="txtCantidad" runat="server" MaxLength="12" />
                <asp:CustomValidator ID="cvCantidad" runat="server" ControlToValidate="txtCantidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
                <span class="sigma-modal-ayuda">Siempre positiva: el signo lo pone el tipo.</span>
            </div>

            <div class="sigma-modal-field">
                <label>Ubicación</label>
                <rad:RadComboBox2 ID="cboUbicacion" runat="server" Width="100%" />
                <span class="sigma-modal-ayuda">En qué estante quedó. Se muestra al consultar el repuesto.</span>
            </div>

            <asp:Panel ID="pnlLote" runat="server" Visible="false" CssClass="sigma-modal-field is-ancho">
                <label>Lote (*)</label>

                <div class="sigma-modal-note">
                    <i class="mdi mdi-barcode"></i>
                    <div>
                        Este repuesto <strong>controla lote</strong>. Elija uno que ya haya entrado, o
                        escriba abajo el código del que viene llegando. El lote se crea al recibir la
                        mercadería: nadie sabe el número hasta que llega el camión.
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field">
                        <label>Lote existente</label>
                        <rad:RadComboBox2 ID="cboLote" runat="server" Width="100%" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>o código del lote nuevo</label>
                        <WebControls:TextBox2 ID="txtLoteNuevo" runat="server" MaxLength="200" />
                        <span class="sigma-modal-ayuda">El que viene impreso en el envase.</span>
                    </div>
                    <div class="sigma-modal-field">
                        <label>Vence el</label>
                        <WebControls:TextBox2 ID="txtLoteVence" runat="server" MaxLength="10" />
                        <span class="sigma-modal-ayuda">
                            Formato dd-mm-aaaa. Solo para el lote nuevo. Vacío si no vence.<br />
                            <strong>Sin fecha no hay forma de avisar</strong> que un lote venció, y es
                            justamente para eso que este repuesto controla lote.
                        </span>
                    </div>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlCosto" runat="server" CssClass="sigma-modal-field">
                <label>Costo unitario</label>
                <WebControls:TextBox2 ID="txtCosto" runat="server" MaxLength="14" />
                <span class="sigma-modal-ayuda">Recalcula el costo promedio de la bodega.</span>
            </asp:Panel>

            <asp:Panel ID="pnlDestino" runat="server" Visible="false" CssClass="sigma-modal-field">
                <label>Bodega de destino (*)</label>
                <rad:RadComboBox2 ID="cboDestino" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </asp:Panel>

            <asp:Panel ID="pnlOrden" runat="server" Visible="false" CssClass="sigma-modal-field">
                <label>Orden de trabajo</label>
                <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="10" />
                <span class="sigma-modal-ayuda">
                    El consumo queda registrado en la orden con su costo. Devolver reduce lo consumido.
                </span>
            </asp:Panel>

            <div class="sigma-modal-field is-ancho">
                <label><asp:Literal ID="litRotuloMotivo" runat="server" Text="Observación" /></label>
                <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="1000" />
                <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaMotivo" runat="server" /></span>
            </div>

        </div>

        <div class="sigma-modal-actions">
            <WebControls:PushButton ID="btnCerrarAlta" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
            <WebControls:PushButton ID="btnRegistrar" runat="server" Text="Registrar" OnClick="btnRegistrar_Click" ValidationGroup="Movimiento" />
        </div>

    </asp:Panel>

    <%-- ================== DETALLE ================== --%>
    <asp:Panel ID="pnlDetalle" runat="server" Visible="false">

        <div class="sigma-modal-hero">
            <div class="sigma-modal-hero-icon"><i class="mdi mdi-swap-vertical"></i></div>
            <div class="sigma-modal-hero-text">
                <div class="sigma-modal-hero-title"><asp:Literal ID="litDetTitulo" runat="server" /></div>
                <div class="sigma-modal-hero-detail"><asp:Literal ID="litDetDetalle" runat="server" /></div>
            </div>
            <div class="sigma-modal-hero-chip"><asp:Literal ID="litDetChip" runat="server" /></div>
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field">
                <label>Repuesto</label>
                <asp:Label ID="lblDetRepuesto" runat="server" />
            </div>
            <div class="sigma-modal-field">
                <label>Bodega</label>
                <asp:Label ID="lblDetBodega" runat="server" />
            </div>
            <div class="sigma-modal-field">
                <label>Ubicación</label>
                <asp:Label ID="lblDetUbicacion" runat="server" />
            </div>
            <div class="sigma-modal-field">
                <label>Lote</label>
                <asp:Label ID="lblDetLote" runat="server" />
            </div>
            <div class="sigma-modal-field">
                <label>Orden de trabajo</label>
                <asp:Label ID="lblDetOrden" runat="server" />
            </div>
            <div class="sigma-modal-field">
                <label>Registrado por</label>
                <asp:Label ID="lblDetUsuario" runat="server" />
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Motivo u observación</label>
                <asp:Label ID="lblDetObservacion" runat="server" />
            </div>
        </div>

        <wuc:Auditoria runat="server" ID="wucAuditoria" />

        <div class="sigma-modal-actions">
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        </div>

    </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
