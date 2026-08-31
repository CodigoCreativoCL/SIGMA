<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Activo.aspx.cs" Inherits="View_Activos_Activos_Activo" %>
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

    <h1 class="sigma-modal-title">Activo</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-cog-outline"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código</label>
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" />
                        <span class="sigma-modal-ayuda">Se genera solo al guardar: <strong>ACT-</strong>más el número del registro.</span>
                <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
                <span class="sigma-modal-ayuda">Único dentro del cliente.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Tipo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Estado(*)</label>
                <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Criticidad(*)</label>
                <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
                <span class="sigma-modal-ayuda">Deshabilitar es la baja lógica: el activo conserva su historia.</span>
            </div>
        </div>
    </div>

    <%-- ============ UBICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Ubicación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Planta(*)</label>
                <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Activo" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Área</label>
                <rad:RadComboBox2 ID="cboArea" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Posición funcional dentro de la planta.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Centro de costo</label>
                <rad:RadComboBox2 ID="cboCentroCosto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Activo superior</label>
                <rad:RadComboBox2 ID="cboPadre" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Vacío indica que es un activo de primer nivel. Úselo para un subactivo.</span>
            </div>
        </div>
    </div>

    <%-- ============ FICHA TÉCNICA ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-file-document-outline"></i>Ficha técnica</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>N° de serie</label>
                <WebControls:TextBox2 ID="txtSerie" runat="server" MaxLength="100" />
                <span class="sigma-modal-ayuda">La identidad física real de la máquina.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Fabricante</label>
                <WebControls:TextBox2 ID="txtFabricante" runat="server" MaxLength="200" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Año fabricación</label>
                <rad:RadComboBox2 ID="cboAnio" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Elija el año de la lista. Vacío indica sin dato.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Puesta en marcha</label>
                <div class="sigma-modal-fecha">
                    <WebControls:Calendar ID="calPuestaMarcha" runat="server" />
                </div>
                <span class="sigma-modal-ayuda">Elija la fecha en el calendario. Vacío indica sin dato.</span>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
