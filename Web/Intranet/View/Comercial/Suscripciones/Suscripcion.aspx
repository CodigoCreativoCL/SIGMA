<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Suscripcion.aspx.cs" Inherits="View_Comercial_Suscripciones_Suscripcion" %>

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

                <%-- Hero: que es y como esta, antes de leer un solo campo. --%>
                <div class="sigma-modal-hero">
                    <div class="sigma-modal-hero-icon">
                        <i class="mdi mdi-file-document-box"></i>
                    </div>
                    <div class="sigma-modal-hero-body">
                        <asp:Literal ID="litChipEstado" runat="server" />
                        <div class="sigma-modal-hero-titulo"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
                        <p class="sigma-modal-hero-detalle"><asp:Literal ID="litHeroDetalle" runat="server" /></p>
                    </div>
                </div>

                <%-- La clave: solo se ve una vez, recien creada. --%>
                <asp:Panel ID="pnlClave" runat="server" Visible="false" CssClass="sigma-modal-note">
                    <i class="mdi mdi-key-variant"></i>
                    <div><asp:Literal ID="litClave" runat="server" /></div>
                </asp:Panel>

                <div class="sigma-modal-grid">

                    <div class="sigma-modal-field">
                        <span class="sigma-modal-label">ID</span>
                        <div class="sigma-modal-valor"><asp:Label ID="lblId" runat="server" /></div>
                    </div>

                    <div class="sigma-modal-field">
                        <span class="sigma-modal-label">Clave de suscripción</span>
                        <div class="sigma-modal-valor"><asp:Label ID="lblKey" runat="server" /></div>
                        <span class="sigma-modal-ayuda">
                            Solo el prefijo. El resto no está guardado en claro: se vio una única vez y
                            <strong>no se puede reenviar</strong>. Si se perdió, hay que reemitirla.
                        </span>
                    </div>

                    <div class="sigma-modal-field">
                        <label>Plan (*)</label>
                        <rad:RadComboBox2 ID="cboPlan" runat="server" OnLoad="LoadControls" Width="100%" />
                        <asp:CustomValidator ID="cvPlan" runat="server" ControlToValidate="cboPlan"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Suscripcion" />
                        <asp:Literal ID="litPlanActual" runat="server" />
                    </div>

                    <asp:Panel ID="pnlEstado" runat="server" CssClass="sigma-modal-field">
                        <label>Estado</label>
                        <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Width="100%" />
                        <span class="sigma-modal-ayuda">
                            El estado que alguien decide. Vencida y En gracia no se eligen: se calculan
                            con el calendario y salen arriba.
                        </span>
                    </asp:Panel>

                </div>

                <div class="sigma-modal-seccion">
                    <i class="mdi mdi-email-outline"></i> Contacto de cobranza
                </div>

                <div class="sigma-modal-grid">

                    <div class="sigma-modal-field">
                        <label>Nombre</label>
                        <WebControls:TextBox2 ID="txtContactoNombre" runat="server" MaxLength="200" />
                    </div>

                    <div class="sigma-modal-field">
                        <label>Correo</label>
                        <WebControls:TextBox2 ID="txtContactoEmail" runat="server" MaxLength="200" />
                    </div>

                    <div class="sigma-modal-field">
                        <label>Teléfono</label>
                        <WebControls:TextBox2 ID="txtContactoTelefono" runat="server" MaxLength="50" />
                    </div>

                    <asp:Panel ID="pnlHabilitada" runat="server" CssClass="sigma-modal-field">
                        <label>Habilitada (*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Suscripcion" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Suscripcion" />
                        </div>
                    </asp:Panel>

                    <div class="sigma-modal-field is-ancho">
                        <label>Observación</label>
                        <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="1000" />
                    </div>

                </div>

                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Suscripcion" />
                </div>

                <%-- Cambio de plan: seccion aparte y boton propio porque NO es
                     parte de guardar la ficha, dispara un cobro. Bajo el mismo
                     Guardar seria un efecto colateral de corregir un telefono. --%>
                <asp:Panel ID="pnlCambioPlan" runat="server" Visible="false">

                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-swap-horizontal"></i> Cambiar de plan
                    </div>

                    <div class="sigma-modal-note">
                        <i class="mdi mdi-information-outline"></i>
                        <div>
                            <strong>Subir de plan</strong> se aplica hoy mismo: se cierra el período vigente
                            y se emite uno nuevo por los días que faltaban, cobrando solo la diferencia
                            prorrateada.<br />
                            <strong>Bajar de plan</strong> se aplica al cierre del período y no genera
                            devolución. Lo que exceda los límites del plan nuevo no se borra: queda en
                            solo lectura.
                        </div>
                    </div>

                    <div class="sigma-modal-grid">

                        <div class="sigma-modal-field">
                            <label>Plan nuevo</label>
                            <rad:RadComboBox2 ID="cboPlanNuevo" runat="server" OnLoad="LoadControls" Width="100%" />
                        </div>

                        <div class="sigma-modal-field">
                            <label>Periodicidad</label>
                            <rad:RadComboBox2 ID="cboPeriodicidad" runat="server" OnLoad="LoadControls" Width="100%" />
                        </div>

                    </div>

                    <div class="sigma-modal-actions">
                        <span class="sigma-modal-actions-nota">
                            Si es una subida, se cobra la diferencia hoy mismo.
                        </span>
                        <WebControls:PushButton ID="btnCambiarPlan" runat="server" Text="Cambiar de plan" OnClick="btnCambiarPlan_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Confirma el cambio de plan? Si es una subida, se cobra la diferencia hoy mismo.');" />
                    </div>

                </asp:Panel>

                <%-- ================== REEMITIR LA CLAVE ==================
                     Detrás de su propio permiso y con motivo obligatorio: es
                     de las pocas operaciones que rompen algo que estaba
                     funcionando. --%>
                <asp:Panel ID="pnlReemitir" runat="server" Visible="false">

                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-key-variant"></i> Reemitir la clave
                    </div>

                    <div class="sigma-modal-note is-alerta">
                        <i class="mdi mdi-alert-outline"></i>
                        <div>
                            La clave actual <strong>deja de servir en el momento</strong>. Si el cliente
                            ya la tiene configurada en su instalación o en la app, esa integración se
                            corta hasta que le carguen la nueva.<br />
                            La nueva se muestra <strong>una sola vez</strong>, aquí mismo.
                        </div>
                    </div>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-ancho">
                            <label>Motivo (*)</label>
                            <WebControls:TextBox2 ID="txtMotivoKey" runat="server" MaxLength="500" />
                            <span class="sigma-modal-ayuda">
                                Queda en la observación de la suscripción. Dentro de seis meses alguien
                                va a querer saber por qué se cortó.
                            </span>
                        </div>
                    </div>

                    <div class="sigma-modal-actions">
                        <WebControls:PushButton ID="btnReemitirKey" runat="server" Text="Reemitir clave" CssClass="ButtonCerrar" OnClick="btnReemitirKey_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Reemitir la clave? La actual deja de servir inmediatamente.');" />
                    </div>

                </asp:Panel>

            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
