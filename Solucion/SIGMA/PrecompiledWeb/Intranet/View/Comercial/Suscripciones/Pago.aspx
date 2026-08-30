<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Comercial_Suscripciones_Pago, App_Web_q4im1csg" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
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
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-modal">

                <div class="sigma-modal-eyebrow">
                    <i class="mdi mdi-briefcase-outline"></i>
                    Comercial &middot; <asp:Literal ID="litCliente" runat="server" />
                </div>

                <h1 class="sigma-modal-title"><asp:Literal ID="litTitulo" runat="server" /></h1>

                <div class="sigma-modal-hero">
                    <div class="sigma-modal-hero-icon">
                        <i class="mdi mdi-cash-usd"></i>
                    </div>
                    <div class="sigma-modal-hero-body">
                        <asp:Literal ID="litChipEstado" runat="server" />
                        <div class="sigma-modal-hero-titulo"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
                        <p class="sigma-modal-hero-detalle"><asp:Literal ID="litHeroDetalle" runat="server" /></p>
                    </div>
                </div>

                <asp:Panel ID="pnlAviso" runat="server" Visible="false" CssClass="sigma-modal-note is-alerta">
                    <i class="mdi mdi-alert-outline"></i>
                    <div><asp:Literal ID="litAviso" runat="server" /></div>
                </asp:Panel>

                <%-- ================== DECLARAR ================== --%>
                <asp:Panel ID="pnlDeclarar" runat="server" Visible="false">

                    <div class="sigma-modal-note">
                        <i class="mdi mdi-information-outline"></i>
                        <div>
                            Declarar <strong>no es pagar</strong>. Esto queda pendiente hasta que alguien
                            lo coteje contra la cartola del banco; recién ahí descuenta saldo y extiende
                            la vigencia de la suscripción.
                        </div>
                    </div>

                    <div class="sigma-modal-grid">

                        <div class="sigma-modal-field is-ancho">
                            <label>Período (*)</label>
                            <rad:RadComboBox2 ID="cboPeriodo" runat="server" OnLoad="LoadControls" Width="100%" />
                            <asp:CustomValidator ID="cvPeriodo" runat="server" ControlToValidate="cboPeriodo"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Pago" />
                        </div>

                        <div class="sigma-modal-field">
                            <label>Monto transferido (*)</label>
                            <WebControls:TextBox2 ID="txtMonto" runat="server" MaxLength="14" />
                            <asp:CustomValidator ID="cvMonto" runat="server" ControlToValidate="txtMonto"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Pago" />
                            <span class="sigma-modal-ayuda">En pesos.</span>
                        </div>

                        <div class="sigma-modal-field">
                            <label>Fecha de la transferencia (*)</label>
                            <WebControls:TextBox2 ID="txtFecha" runat="server" MaxLength="10" />
                            <asp:CustomValidator ID="cvFecha" runat="server" ControlToValidate="txtFecha"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Pago" />
                            <span class="sigma-modal-ayuda">Formato dd-mm-aaaa.</span>
                        </div>

                        <div class="sigma-modal-field">
                            <label>Banco</label>
                            <WebControls:TextBox2 ID="txtBanco" runat="server" MaxLength="100" />
                        </div>

                        <div class="sigma-modal-field">
                            <label>N° de operación</label>
                            <WebControls:TextBox2 ID="txtOperacion" runat="server" MaxLength="100" />
                            <span class="sigma-modal-ayuda">
                                No se puede repetir: impide que el mismo comprobante se cargue dos veces.
                            </span>
                        </div>

                        <div class="sigma-modal-field is-ancho">
                            <label>Comprobante (*)</label>
                            <asp:FileUpload ID="fldComprobante" runat="server" />
                            <span class="sigma-modal-ayuda">
                                Obligatorio. Sin respaldo no hay nada que cotejar contra la cartola, y sin
                                cotejo la declaración nunca se convierte en pago.
                            </span>
                        </div>

                    </div>

                    <div class="sigma-modal-actions">
                        <WebControls:PushButton ID="btnCerrarDeclarar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                        <WebControls:PushButton ID="btnDeclarar" runat="server" Text="Declarar" OnClick="btnDeclarar_Click" ValidationGroup="Pago" />
                    </div>

                </asp:Panel>

                <%-- ================== DETALLE Y VERIFICACION ================== --%>
                <asp:Panel ID="pnlDetalle" runat="server" Visible="false">

                    <div class="sigma-modal-grid">

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Transferido el</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblFecha" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Banco</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblBanco" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">N° de operación</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblOperacion" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Comprobante</span>
                            <div class="sigma-modal-valor">
                                <asp:LinkButton ID="lnkComprobante" runat="server" Text="Descargar" OnClick="lnkComprobante_Click" />
                                <asp:Label ID="lblComprobante" runat="server" />
                            </div>
                        </div>

                        <div class="sigma-modal-field is-ancho">
                            <span class="sigma-modal-label">Período</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblPeriodo" runat="server" /></div>
                        </div>

                    </div>

                    <asp:Panel ID="pnlRechazo" runat="server" Visible="false" CssClass="sigma-modal-note is-alerta">
                        <i class="mdi mdi-close-circle-outline"></i>
                        <div>
                            <strong>Motivo del rechazo</strong><br />
                            <asp:Label ID="lblMotivoRechazo" runat="server" />
                        </div>
                    </asp:Panel>

                    <%-- Verificar: solo mientras el pago siga esperando. --%>
                    <asp:Panel ID="pnlVerificar" runat="server" Visible="false">

                        <div class="sigma-modal-seccion">
                            <i class="mdi mdi-check-decagram"></i> Verificar contra la cartola
                        </div>

                        <div class="sigma-modal-note">
                            <i class="mdi mdi-information-outline"></i>
                            <div>
                                Al verificar se recalcula lo pagado del período sumando solo los pagos
                                verificados y, si queda cubierto dentro de la tolerancia, se extiende la
                                vigencia de la suscripción. Es una sola operación: no puede quedar a medias.
                            </div>
                        </div>

                        <div class="sigma-modal-grid">

                            <div class="sigma-modal-field">
                                <label>Monto verificado</label>
                                <WebControls:TextBox2 ID="txtMontoVerificado" runat="server" MaxLength="14" />
                                <span class="sigma-modal-ayuda">
                                    Vacío acepta el monto declarado. Se llena solo cuando en la cartola
                                    figura otra cifra.
                                </span>
                            </div>

                            <div class="sigma-modal-field">
                                <label>Motivo del rechazo</label>
                                <WebControls:TextArea2 ID="txtMotivo" runat="server" MaxLength="500" />
                                <span class="sigma-modal-ayuda">
                                    Obligatorio si rechaza. Sin motivo, quien declaró tiene que adivinar
                                    qué estuvo mal.
                                </span>
                            </div>

                        </div>

                        <div class="sigma-modal-actions">
                            <WebControls:PushButton ID="btnRechazar" runat="server" Text="Rechazar" CssClass="ButtonCerrar" OnClick="btnRechazar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Confirma el rechazo de este pago?');" />
                            <WebControls:PushButton ID="btnVerificar" runat="server" Text="Verificar" OnClick="btnVerificar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Confirma que este pago figura en la cartola?');" />
                        </div>

                    </asp:Panel>

                    <div class="sigma-modal-actions">
                        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                    </div>

                </asp:Panel>

            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
