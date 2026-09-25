<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Posicion.aspx.cs" Inherits="View_Activos_Posiciones_Posicion" %>

<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

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

        function abrirEtiquetas(query) {
            var w = 980, h = 760;
            var x = window.screenX + Math.max(0, (window.outerWidth - w) / 2);
            var y = window.screenY + Math.max(0, (window.outerHeight - h) / 2);

            var vent = window.open(
                '<%=ResolveUrl("~/View/Comun/Impresion/Etiquetas.aspx") %>?query=' + query,
                'sigmaEtiquetas',
                'width=' + w + ',height=' + h + ',left=' + Math.round(x) + ',top=' + Math.round(y) +
                ',resizable=yes,scrollbars=yes');

            if (!vent) {
                alert('El navegador bloqueó la ventana de impresión. ' +
                      'Permita las ventanas emergentes para este sitio y vuelva a intentarlo.');
                return false;
            }

            vent.focus();
            return false;
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

    <h1 class="sigma-modal-title">Posición funcional</h1>

    <rad:RadTabStrip2 ID="tabFicha" runat="server" MultiPageID="mpFicha" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabDatos" Text="Datos" runat="server" PageViewID="pvDatos" />
            <rad:RadTab ID="tabOcupacion" Text="Ocupación" runat="server" PageViewID="pvOcupacion" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFicha" runat="server" SelectedIndex="0" Width="100%">

        <rad:RadPageView ID="pvDatos" runat="server">

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-map-marker-radius-outline"></i>Identificación</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>ID</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Código</label>
                        <div class="sg-codigo">
                            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="40" UpperCase="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Es lo que va en el QR: por ejemplo <em>CB01</em>. Único dentro del cliente y no se cambia después. Si lo deja vacío, se numera solo.</span>
                        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Posicion" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Nombre(*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Posicion" />
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-factory"></i>Dónde está</div>
                <div class="ayuda">La posición pertenece a un área de una planta. Al crearla se fija la planta; el área se puede corregir dentro de la misma planta.</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>Planta(*)</label>
                        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                            AutoPostBack="true" OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" />
                        <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Posicion" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Área(*)</label>
                        <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="100%" />
                        <asp:CustomValidator ID="cvArea" runat="server" ControlToValidate="cboArea"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Posicion" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Admite equipos del tipo</label>
                        <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Opcional. Si se indica, solo se puede asignar un equipo de ese tipo.</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-text-box-outline"></i>Características</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-grande">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Crítica(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbCriticaSi" runat="server" Text="SI" GroupName="Critica" />
                            <asp:RadioButton ID="rdbCriticaNo" runat="server" Text="NO" GroupName="Critica" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Una posición crítica es la que detiene la línea si queda vacía.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Habilitada(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                        <span class="sigma-modal-ayuda">Una posición ocupada no se puede deshabilitar: primero libere el equipo.</span>
                    </div>
                </div>
            </div>

            <%-- ============ ETIQUETA QR · HU-034 #1 ============ --%>
            <asp:Panel ID="pnlEtiqueta" runat="server" Visible="false" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-printer-outline"></i>Imprimir etiqueta</div>
                <div class="ayuda">
                    Una hoja con el QR, el código de la posición y su nombre. El QR codifica
                    la posición, no la máquina: al escanearlo desde la app se abre la ficha
                    del equipo que la ocupe ese día.
                </div>
                <div class="sigma-opciones">
                    <button type="button" runat="server" id="btnEtiqueta" class="sigma-opcion">
                        <span class="icono"><i class="mdi mdi-qrcode"></i></span>
                        <span class="cuerpo">
                            <span class="titulo">Etiqueta de esta posición</span>
                            <span class="nota">Para pegar en la sala, junto al equipo.</span>
                        </span>
                    </button>
                </div>
            </asp:Panel>

        </rad:RadPageView>

        <rad:RadPageView ID="pvOcupacion" runat="server">
            <%-- ============ OCUPACION · HU-033 #2 ============
                 Aparece con la posicion ya creada: sin posicion no hay nada
                 que ocupar. --%>
            <asp:Panel ID="pnlOcupacion" runat="server" Visible="false">

                <div class="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-engine-outline"></i>Equipo actual</div>
                    <asp:Literal ID="litActual" runat="server" />
                </div>

                <asp:Panel ID="pnlAsignar" runat="server" CssClass="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-swap-horizontal"></i>Poner un equipo en esta posición</div>
                    <div class="ayuda">Si ya había uno, su periodo se cierra y empieza el del nuevo. El equipo tiene que ser de la misma planta.</div>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-medio">
                            <label>Equipo</label>
                            <rad:RadComboBox2 ID="cboActivo" runat="server" Filter="Contains" Width="100%" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Motivo</label>
                            <rad:RadComboBox2 ID="cboMotivo" runat="server" OnLoad="LoadControls" Width="100%" />
                        </div>
                        <div class="sigma-modal-field is-grande">
                            <label>Observación</label>
                            <WebControls:TextBox2 ID="txtObservacion" runat="server" MaxLength="500" />
                        </div>
                    </div>

                    <%-- Los dos botones en una fila, como Cerrar/Guardar al pie:
                         «Dejar libre» es la acción secundaria y va a la izquierda. --%>
                    <div class="sigma-modal-actions" style="margin-top: 6px;">
                        <WebControls:PushButton ID="btnLiberar" runat="server" Text="Dejar libre" CssClass="ButtonCerrar" OnClick="btnLiberar_Click"
                            OnClientClick="if (!ConfirSweetAlert(this, '', '¿Dejar la posición libre? El periodo del equipo actual se cierra hoy.')) return false;" />
                        <WebControls:PushButton ID="btnOcupar" runat="server" Text="Asignar equipo" OnClick="btnOcupar_Click" />
                    </div>
                </asp:Panel>

                <div class="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-history"></i>Historial de ocupación</div>
                    <div class="ayuda">Cada periodo dice qué equipo estuvo, desde cuándo y hasta cuándo. El vigente no tiene fecha de término.</div>

                    <rad:RadGrid2 ID="GridHistorial" runat="server" AllowPaging="false" OnItemDataBound="GridHistorial_ItemDataBound">
                        <MasterTableView DataKeyNames="aph_id" CommandItemDisplay="None" />
                    </rad:RadGrid2>
                </div>

            </asp:Panel>
        </rad:RadPageView>

    </rad:RadMultiPage>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Posicion" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
