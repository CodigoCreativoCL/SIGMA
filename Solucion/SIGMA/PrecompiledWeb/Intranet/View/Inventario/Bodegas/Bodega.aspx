<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Inventario_Bodegas_Bodega, App_Web_o0i4z2q3" %>
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

    <h1 class="sigma-modal-title">Bodega</h1>

    <%-- Pestañas y no secciones apiladas: cada bloque se ve entero y la
         ventana no crece. --%>
    <rad:RadTabStrip2 ID="tabFicha" runat="server" MultiPageID="mpFicha" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabDatos" Text="Datos" runat="server" PageViewID="pvDatos" />
            <rad:RadTab ID="tabUbicaciones" Text="Ubicaciones" runat="server" PageViewID="pvUbicaciones" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFicha" runat="server" SelectedIndex="0" Width="100%">

        <rad:RadPageView ID="pvDatos" runat="server">

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-warehouse"></i>Identificación</div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field">
                    <label>ID</label>
                    <asp:Label ID="lblId" runat="server"></asp:Label>
                </div>
                <div class="sigma-modal-field">
                    <label>Código(*)</label>
                    <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                    <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Bodega" />
                    <span class="sigma-modal-ayuda">Único dentro del cliente. No se puede cambiar después.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Nombre(*)</label>
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Bodega" />
                </div>
                <div class="sigma-modal-field">
                    <label>Planta(*)</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Bodega" />
                </div>
                <div class="sigma-modal-field is-ancho">
                    <label>Descripción</label>
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
                </div>
                <div class="sigma-modal-field">
                    <label>Habilitada(*)</label>
                    <div class="sigma-modal-opciones">
                        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                    </div>
                    <span class="sigma-modal-ayuda">Una bodega con existencia no se puede deshabilitar.</span>
                </div>
            </div>
            </div>
        </rad:RadPageView>

        <rad:RadPageView ID="pvUbicaciones" runat="server">
            <%-- ============ UBICACIONES · HU-052 criterio 2 ============
                 Aparecen con la bodega ya creada: una ubicación sin bodega no
                 existe, y ofrecer el formulario antes de guardar promete algo
                 que no se puede cumplir. --%>
            <asp:Panel ID="pnlUbicaciones" runat="server" Visible="false" CssClass="sigma-modal-section">

                <div class="sigma-modal-section-title">
                    <i class="mdi mdi-view-grid-outline"></i>
                    <span>Ubicaciones</span>
                </div>

                <div class="sigma-modal-note">
                    <i class="mdi mdi-information-outline"></i>
                    <div>
                        El código es la etiqueta que el bodeguero lee en el pasillo:
                        <strong>PA-E3-N2</strong> para "Pasillo A · Estante 3 · Nivel 2".
                        Al consultar un repuesto se muestra dónde se dejó la última vez.
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field">
                        <label>Código</label>
                        <WebControls:TextBox2 ID="txtUbiCodigo" runat="server" MaxLength="100" UpperCase="true" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Nombre</label>
                        <WebControls:TextBox2 ID="txtUbiNombre" runat="server" MaxLength="400" />
                    </div>
                </div>

                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnAgregarUbicacion" runat="server" Text="Agregar ubicación" OnClick="btnAgregarUbicacion_Click" />
                </div>

                <rad:RadGrid2 ID="GridUbicaciones" runat="server">
                    <MasterTableView DataKeyNames="bub_id" CommandItemDisplay="None" />
                </rad:RadGrid2>

            </asp:Panel>
        </rad:RadPageView>

    </rad:RadMultiPage>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Bodega" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
