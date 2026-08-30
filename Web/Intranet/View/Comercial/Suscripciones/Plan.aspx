<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Plan.aspx.cs" Inherits="View_Comercial_Suscripciones_Plan" %>

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
                    Comercial &middot; Oferta
                </div>

                <h1 class="sigma-modal-title"><asp:Literal ID="litTitulo" runat="server" /></h1>

                <div class="sigma-modal-hero">
                    <div class="sigma-modal-hero-icon">
                        <i class="mdi mdi-tag-multiple-outline"></i>
                    </div>
                    <div class="sigma-modal-hero-body">
                        <asp:Literal ID="litChipEstado" runat="server" />
                        <div class="sigma-modal-hero-titulo"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
                        <p class="sigma-modal-hero-detalle"><asp:Literal ID="litHeroDetalle" runat="server" /></p>
                    </div>
                </div>

                <div class="sigma-modal-grid">

                    <div class="sigma-modal-field">
                        <span class="sigma-modal-label">ID</span>
                        <div class="sigma-modal-valor"><asp:Label ID="lblId" runat="server" /></div>
                    </div>

                    <div class="sigma-modal-field">
                        <label>Código (*)</label>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" />
                        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Plan" />
                        <span class="sigma-modal-ayuda">
                            No se puede cambiar después: es la llave con la que los scripts y las
                            integraciones identifican al plan.
                        </span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Nombre (*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="100" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Plan" />
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
                    </div>

                    <div class="sigma-modal-field">
                        <label>Orden (*)</label>
                        <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="4" />
                        <asp:CustomValidator ID="cvOrden" runat="server" ControlToValidate="txtOrden"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Plan" />
                        <span class="sigma-modal-ayuda">
                            Define qué es <strong>subir</strong> y qué es <strong>bajar</strong> de plan.
                            Es único, y se compara por orden y no por precio: un plan superior en oferta
                            seguiría siendo superior.
                        </span>
                    </div>

                    <div class="sigma-modal-field">
                        <label>Días de gracia (*)</label>
                        <WebControls:TextBox2 ID="txtDiasGracia" runat="server" MaxLength="4" />
                        <span class="sigma-modal-ayuda">
                            Cuántos días sigue operando el cliente después de vencer.
                        </span>
                    </div>

                    <div class="sigma-modal-field">
                        <label>Público</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbPublicoSi" runat="server" Text="SI" GroupName="Publico" Checked="true" />
                            <asp:RadioButton ID="rdbPublicoNo" runat="server" Text="NO" GroupName="Publico" />
                        </div>
                        <span class="sigma-modal-ayuda">Un plan no público se cotiza pero no se ofrece solo.</span>
                    </div>

                    <asp:Panel ID="pnlHabilitado" runat="server" CssClass="sigma-modal-field">
                        <label>Habilitado</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                        <span class="sigma-modal-ayuda">
                            Deshabilitar es retirar el plan del catálogo. No se puede si hay
                            suscripciones vigentes en él: primero hay que migrarlas.
                        </span>
                    </asp:Panel>

                </div>

                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Plan" />
                </div>

                <%-- ================== PRECIOS ==================
                     Solo con el plan ya creado: un precio necesita un plan al
                     que colgarse. Un plan sin precio no se vende, y eso es la
                     regla del modelo, no un estado a medio terminar. --%>
                <asp:Panel ID="pnlPrecios" runat="server" Visible="false">

                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-cash-multiple"></i> Precios
                    </div>

                    <div class="sigma-modal-note">
                        <i class="mdi mdi-information-outline"></i>
                        <div>
                            Un precio no se edita: <strong>se reemplaza</strong>. Al fijar uno nuevo, el
                            vigente se cierra con la fecha anterior y queda como histórico. Así, una
                            cotización de la semana pasada sigue diciendo lo mismo y un período emitido
                            en marzo se puede explicar con el precio que regía en marzo.
                        </div>
                    </div>

                    <div class="sigma-modal-grid">

                        <div class="sigma-modal-field">
                            <label>Periodicidad</label>
                            <rad:RadComboBox2 ID="cboPeriodicidad" runat="server" OnLoad="LoadControls" Width="100%" />
                        </div>

                        <div class="sigma-modal-field">
                            <label>Valor en UF</label>
                            <WebControls:TextBox2 ID="txtValorUf" runat="server" MaxLength="12" />
                        </div>

                        <div class="sigma-modal-field">
                            <label>Descuento %</label>
                            <WebControls:TextBox2 ID="txtDescuento" runat="server" MaxLength="6" />
                            <span class="sigma-modal-ayuda">Opcional. Solo informativo, no altera el valor en UF.</span>
                        </div>

                        <div class="sigma-modal-field">
                            <label>Rige desde</label>
                            <WebControls:TextBox2 ID="txtDesde" runat="server" MaxLength="10" />
                            <span class="sigma-modal-ayuda">
                                Vacío = hoy. Se acepta una fecha futura y el precio entra solo ese día.
                                No se acepta pasada.
                            </span>
                        </div>

                    </div>

                    <div class="sigma-modal-actions">
                        <WebControls:PushButton ID="btnFijarPrecio" runat="server" Text="Fijar precio" OnClick="btnFijarPrecio_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Confirma el precio? El vigente se cierra y este pasa a regir.');" />
                    </div>

                    <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrPrecios_ItemDataBound">
                        <MasterTableView CommandItemDisplay="None" DataKeyNames="pcp_id" />
                    </rad:RadGrid2>

                    <%-- ================== CONTENIDO ================== --%>
                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-format-list-checks"></i> Qué incluye el plan
                    </div>

                    <div class="sigma-modal-note">
                        <i class="mdi mdi-information-outline"></i>
                        <div>
                            Una funcionalidad <strong>sin marcar no se tiene</strong>: la ausencia es
                            negación, no "sin definir".<br />
                            En los cuatro topes, dejar el número <strong>vacío</strong> con la casilla
                            marcada significa <strong>sin límite</strong> — así está el plan Full. Cero
                            no es lo mismo: cero es no poder crear ninguno.
                        </div>
                    </div>

                    <asp:Repeater ID="rptFuncionalidades" runat="server" OnItemDataBound="rptFuncionalidades_ItemDataBound">
                        <HeaderTemplate>
                            <div class="sigma-plan-matriz">
                        </HeaderTemplate>
                        <ItemTemplate>
                            <div class="sigma-plan-fila">
                                <asp:HiddenField ID="hdfFuncionalidad" runat="server" />
                                <div class="sigma-plan-check">
                                    <asp:CheckBox ID="chkIncluida" runat="server" />
                                </div>
                                <div class="sigma-plan-nombre">
                                    <asp:Label ID="lblNombre" runat="server" />
                                    <asp:Literal ID="litOrigen" runat="server" />
                                </div>
                                <div class="sigma-plan-tope">
                                    <asp:TextBox ID="txtTope" runat="server" CssClass="form-control" Visible="false" />
                                    <asp:Literal ID="litUnidad" runat="server" />
                                </div>
                            </div>
                        </ItemTemplate>
                        <FooterTemplate>
                            </div>
                        </FooterTemplate>
                    </asp:Repeater>

                    <div class="sigma-modal-actions">
                        <span class="sigma-modal-actions-nota">
                            Cambiar esto afecta a <strong>todos</strong> los clientes en este plan.
                        </span>
                        <WebControls:PushButton ID="btnGuardarContenido" runat="server" Text="Guardar contenido" OnClick="btnGuardarContenido_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Confirma? Afecta a todos los clientes que estén en este plan.');" />
                    </div>

                </asp:Panel>

            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
