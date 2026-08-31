<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Comercial_Suscripciones_Periodo, App_Web_hcstghdl" %>

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
                        <i class="mdi mdi-calendar-clock"></i>
                    </div>
                    <div class="sigma-modal-hero-body">
                        <asp:Literal ID="litChipEstado" runat="server" />
                        <div class="sigma-modal-hero-titulo"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
                        <p class="sigma-modal-hero-detalle"><asp:Literal ID="litHeroDetalle" runat="server" /></p>
                    </div>
                </div>

                <%-- ================== EMITIR ================== --%>
                <asp:Panel ID="pnlEmitir" runat="server" Visible="false">

                    <div class="sigma-modal-note">
                        <i class="mdi mdi-information-outline"></i>
                        <div>
                            Emitir es <strong>facturar</strong>. Se congelan tres números que ya no vuelven
                            a cambiar: las UF que cuesta el plan, cuánto vale la UF hoy y el monto en pesos
                            que sale de multiplicarlos.<br />
                            El período arranca donde terminó el anterior, no hoy: pagar con atraso no
                            regala ni quita días.
                        </div>
                    </div>

                    <div class="sigma-modal-grid">

                        <div class="sigma-modal-field">
                            <label>Periodicidad (*)</label>
                            <rad:RadComboBox2 ID="cboPeriodicidad" runat="server" OnLoad="LoadControls" Width="100%" />
                            <asp:CustomValidator ID="cvPeriodicidad" runat="server" ControlToValidate="cboPeriodicidad"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Periodo" />
                        </div>

                        <div class="sigma-modal-field">
                            <label>Plan</label>
                            <rad:RadComboBox2 ID="cboPlan" runat="server" OnLoad="LoadControls" Width="100%" />
                            <span class="sigma-modal-ayuda">Vacío usa el plan contratado.</span>
                        </div>

                        <div class="sigma-modal-field">
                            <label>Monto en UF</label>
                            <WebControls:TextBox2 ID="txtValorUf" runat="server" MaxLength="12" />
                            <span class="sigma-modal-ayuda">Vacío usa el precio vigente del plan.</span>
                        </div>

                        <div class="sigma-modal-field">
                            <label>Es implantación</label>
                            <div class="sigma-modal-opciones">
                                <asp:CheckBox ID="chkImplantacion" runat="server" Text="Sí" />
                            </div>
                            <span class="sigma-modal-ayuda">
                                El modelo comercial no define un precio de implantación. Sin monto explícito
                                se emite en cero: facturar un número que nadie acordó es peor.
                            </span>
                        </div>

                        <div class="sigma-modal-field is-ancho">
                            <label>Observación</label>
                            <WebControls:TextArea2 ID="txtObservacionNueva" runat="server" MaxLength="1000" />
                        </div>

                    </div>

                    <div class="sigma-modal-actions">
                        <span class="sigma-modal-actions-nota">
                            El monto queda congelado y el período no se puede editar después.
                        </span>
                        <WebControls:PushButton ID="btnCerrarEmitir" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                        <WebControls:PushButton ID="btnEmitir" runat="server" Text="Emitir" OnClick="btnEmitir_Click" ValidationGroup="Periodo"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Confirma la emisión? El monto queda congelado y el período no se puede editar después.');" />
                    </div>

                </asp:Panel>

                <%-- ================== DETALLE ================== --%>
                <asp:Panel ID="pnlDetalle" runat="server" Visible="false">

                    <div class="sigma-modal-grid">

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Plan</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblPlan" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Periodicidad</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblPeriodicidad" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Desde</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblDesde" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field">
                            <span class="sigma-modal-label">Hasta</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblHasta" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field is-ancho">
                            <span class="sigma-modal-label">Observación</span>
                            <div class="sigma-modal-valor"><asp:Label ID="lblObservacion" runat="server" /></div>
                        </div>

                    </div>

                    <div class="sigma-modal-note">
                        <i class="mdi mdi-calculator-variant"></i>
                        <div><asp:Literal ID="litCalculo" runat="server" /></div>
                    </div>

                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-cash-usd"></i> Pagos declarados sobre este período
                    </div>

                    <rad:RadGrid2 ID="Grid" runat="server">
                        <MasterTableView DataKeyNames="spa_id" />
                    </rad:RadGrid2>

                    <div class="sigma-modal-actions">
                        <span class="sigma-modal-actions-nota">
                            Un pago solo descuenta saldo cuando alguien lo verifica contra la cartola,
                            desde <strong>Comercial &rsaquo; Pagos</strong>.
                        </span>
                        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                    </div>

                </asp:Panel>

            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
