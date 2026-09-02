<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Movimiento.aspx.cs" Inherits="View_Inventario_Movimientos_Movimiento" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">

    <link href="../../../Css/LookAndFeel/sigma-escaneo.css?vrs=2" rel="stylesheet" />
    <script type="text/javascript" src="<%=ResolveUrl("~/Js/sigma-escaneo.js") %>?vrs=2"></script>

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

<%-- EL VISOR DE LA CAMARA VIVE FUERA DEL UPDATEPANEL

     Si estuviera dentro, cada postback lo destruiría y el teléfono volvería a
     pedir permiso de cámara en cada lectura. Es la misma razón por la que en
     Escanear.aspx está afuera. --%>
<div class="esc-camara" id="escCamara" style="display: none;">
    <video id="escVideo" playsinline muted></video>
    <div class="esc-mira"></div>
    <button type="button" class="esc-cerrar" onclick="sigmaEscaneo.detener(); return false;"
            title="Cerrar la cámara">
        <i class="mdi mdi-close"></i>
    </button>
    <div class="esc-camara-pista">Encuadre el QR de la etiqueta dentro del marco</div>
</div>

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

        <%-- ============================================================
             PASO 1 — QUE SE HACE

             Va primero y solo porque determina todo lo demás: qué campos
             se piden, si se elige lote, si hace falta bodega de destino.
             Pedir el repuesto antes obligaría a mostrar todos los campos
             posibles y dejar que la persona adivine cuáles ignorar.
             ============================================================ --%>
        <div class="sigma-form-seccion">
            <div class="titulo">
                <span class="paso">1</span><i class="mdi mdi-swap-vertical"></i>Qué se hace
            </div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-mitad">
                    <label>Tipo de movimiento (*)</label>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Width="100%"
                        AutoPostBack="true" OnSelectedIndexChanged="cboTipo_Changed" />
                    <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
                    <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaTipo" runat="server" /></span>
                </div>
            </div>
        </div>

        <%-- ============================================================
             PASO 2 — QUE REPUESTO

             Con el botón de escaneo al lado. El bodeguero está de pie
             frente al estante con el teléfono en la mano: leer la etiqueta
             es más rápido y más seguro que buscar el código en una lista
             de quinientos.
             ============================================================ --%>
        <asp:Panel ID="pnlPaso2" runat="server" CssClass="sigma-form-seccion">
            <div class="titulo">
                <span class="paso">2</span><i class="mdi mdi-package-variant-closed"></i>Qué repuesto
            </div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-mitad">
                    <label>Repuesto (*)</label>

                    <div class="sigma-campo-escaneo">
                        <rad:RadComboBox2 ID="cboRepuesto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                            AutoPostBack="true" OnSelectedIndexChanged="cboRepuesto_Changed" />

                        <button type="button" id="escBtnCamara" class="sigma-btn-escaneo"
                                onclick="sigmaEscaneo.iniciar(); return false;" title="Escanear la etiqueta">
                            <i class="mdi mdi-qrcode-scan"></i>
                        </button>
                    </div>

                    <asp:CustomValidator ID="cvRepuesto" runat="server" ControlToValidate="cboRepuesto"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />

                    <div class="esc-aviso" id="escAviso" style="display: none;"></div>

                    <span class="sigma-modal-ayuda">
                        Escanee la etiqueta del repuesto (<strong>REP-</strong>) o del estante
                        (<strong>UBI-</strong>): la de la ubicación completa también la bodega.
                    </span>
                </div>
            </div>
        </asp:Panel>

        <%-- ============================================================
             PASO 3 — DE DONDE SALE / DONDE QUEDA

             Acá estaba el error que reportó el bodeguero. La pantalla
             mostraba la existencia de la BODEGA y el SP validaba contra el
             cubo (bodega, ubicación, lote): decía "hay 340" y después
             "hay 0", y las dos cosas eran ciertas.

             En una SALIDA ahora se elige el origen de una lista de cubos
             que realmente tienen algo, con la cantidad al lado. En una
             ENTRADA se elige el estante libremente, porque el punto es
             justamente dejar la mercadería donde todavía no hay nada.
             ============================================================ --%>
        <asp:Panel ID="pnlPaso3" runat="server" CssClass="sigma-form-seccion">
            <div class="titulo">
                <span class="paso">3</span><i class="mdi mdi-warehouse"></i>
                <asp:Literal ID="litRotuloLugar" runat="server" Text="Dónde" />
            </div>

            <div class="sigma-modal-grid">

                <div class="sigma-modal-field is-mitad">
                    <label>Bodega (*)</label>
                    <rad:RadComboBox2 ID="cboBodega" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                        AutoPostBack="true" OnSelectedIndexChanged="cboBodega_Changed" />
                    <asp:CustomValidator ID="cvBodega" runat="server" ControlToValidate="cboBodega"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
                </div>

                <%-- SALIDA: el cubo de origen, con lo que hay en cada uno. --%>
                <asp:Panel ID="pnlOrigen" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                    <label>De dónde sale (*)</label>
                    <rad:RadComboBox2 ID="cboOrigen" runat="server" Width="100%"
                        AutoPostBack="true" OnSelectedIndexChanged="cboOrigen_Changed" />
                    <span class="sigma-modal-ayuda">
                        Solo los estantes que tienen existencia de este repuesto, con la
                        cantidad y el lote. El primero de la lista es el que vence antes.
                    </span>
                </asp:Panel>

                <%-- ENTRADA: cualquier estante habilitado de la bodega. --%>
                <asp:Panel ID="pnlUbicacion" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                    <label><asp:Literal ID="litRotuloUbicacion" runat="server" Text="Ubicación" /></label>
                    <rad:RadComboBox2 ID="cboUbicacion" runat="server" Width="100%" />
                    <span class="sigma-modal-ayuda">En qué estante queda. Se muestra al consultar el repuesto.</span>
                </asp:Panel>

                <div class="sigma-modal-field is-ancho">
                    <div class="sigma-saldo-caja"><asp:Literal ID="litSaldo" runat="server" /></div>
                </div>

                <%-- Bodega de destino: solo en el traslado. --%>
                <asp:Panel ID="pnlDestino" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                    <label>Bodega de destino (*)</label>
                    <rad:RadComboBox2 ID="cboDestino" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                </asp:Panel>

            </div>

            <%-- El lote nuevo: solo al ingresar un repuesto que controla lote.
                 En una salida el lote ya viene elegido dentro del origen, que
                 es donde la existencia realmente está. --%>
            <asp:Panel ID="pnlLote" runat="server" Visible="false">

                <div class="sigma-modal-note">
                    <i class="mdi mdi-barcode"></i>
                    <div>
                        Este repuesto <strong>controla lote</strong>. Elija uno que ya haya entrado, o
                        escriba el código del que viene llegando. El lote se crea al recibir la
                        mercadería: nadie sabe el número hasta que llega el camión.
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>Lote existente</label>
                        <rad:RadComboBox2 ID="cboLote" runat="server" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>o código del lote nuevo</label>
                        <WebControls:TextBox2 ID="txtLoteNuevo" runat="server" MaxLength="200" />
                        <span class="sigma-modal-ayuda">El que viene impreso en el envase.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Vence el</label>
                        <div class="sigma-modal-fecha">
                            <WebControls:Calendar2 ID="txtLoteVence" runat="server" Width="100%" />
                        </div>
                        <span class="sigma-modal-ayuda">
                            Solo para el lote nuevo. Vacío si no vence.
                            <strong>Sin fecha no hay forma de avisar</strong> que un lote venció.
                        </span>
                    </div>
                </div>
            </asp:Panel>

        </asp:Panel>

        <%-- ============================================================
             PASO 4 — CUANTO
             ============================================================ --%>
        <asp:Panel ID="pnlPaso4" runat="server" CssClass="sigma-form-seccion">
            <div class="titulo">
                <span class="paso">4</span><i class="mdi mdi-counter"></i>Cuánto
            </div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-chico">
                    <label>Cantidad (*)</label>
                    <WebControls:TextBox2 ID="txtCantidad" runat="server" MaxLength="12" />
                    <asp:CustomValidator ID="cvCantidad" runat="server" ControlToValidate="txtCantidad"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Movimiento" />
                    <span class="sigma-modal-ayuda">Siempre positiva: el signo lo pone el tipo.</span>
                </div>

                <asp:Panel ID="pnlCosto" runat="server" CssClass="sigma-modal-field is-chico">
                    <label>Costo unitario</label>
                    <WebControls:TextBox2 ID="txtCosto" runat="server" MaxLength="14" />
                    <span class="sigma-modal-ayuda">Recalcula el costo promedio de la bodega.</span>
                </asp:Panel>
            </div>
        </asp:Panel>

        <%-- ============================================================
             PASO 5 — CONTRA QUE SE CONSUME

             Era una caja de texto de diez caracteres donde se escribía el
             id de la orden a mano. El SP verificaba que existiera, pero
             recién al final: se llenaba todo el formulario para enterarse
             de que el número estaba mal.
             ============================================================ --%>
        <asp:Panel ID="pnlOrden" runat="server" Visible="false" CssClass="sigma-form-seccion">
            <div class="titulo">
                <span class="paso">5</span><i class="mdi mdi-clipboard-text-outline"></i>Contra qué orden
            </div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-mitad">
                    <label>Orden de trabajo</label>
                    <rad:RadComboBox2 ID="cboOrden" runat="server" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaOrden" runat="server" /></span>
                </div>
            </div>
        </asp:Panel>

        <%-- ============================================================
             PASO 6 — POR QUE
             ============================================================ --%>
        <asp:Panel ID="pnlPaso6" runat="server" CssClass="sigma-form-seccion">
            <div class="titulo">
                <span class="paso"><asp:Literal ID="litNumeroMotivo" runat="server" Text="5" /></span>
                <i class="mdi mdi-text-box-outline"></i>
                <asp:Literal ID="litRotuloMotivo" runat="server" Text="Observación" />
            </div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-ancho">
                    <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="1000" />
                    <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaMotivo" runat="server" /></span>
                </div>
            </div>
        </asp:Panel>

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

    <%-- El puente del escaneo: la cámara escribe acá y dispara el postback.
         Es el mismo mecanismo de Escanear.aspx. --%>
    <asp:HiddenField ID="hdnLeido" runat="server" />
    <asp:Button ID="btnLeido" runat="server" OnClick="btnLeido_Click" style="display: none;" />

        </ContentTemplate>
        <Triggers>
            <asp:AsyncPostBackTrigger ControlID="btnLeido" EventName="Click" />
        </Triggers>
    </asp:UpdatePanel>
</div>
</asp:Content>
