<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevaPrivacidadModuloSistema.aspx.cs" Inherits="View_Root_PrivacidadModuloSistema_NuevaPrivacidadModuloSistema" %>

<asp:Content ID="contentHeader" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        .prv-audit fieldset { border: 1px solid #dee2e6; border-radius: 6px; padding: 14px 16px; }
        .prv-audit legend   { font-size: .85rem; font-weight: 600; width: auto; padding: 0 8px; color: #555; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var win = getRadWindow();
            if (win.BrowserWindow.refreshPrivacidades) win.BrowserWindow.refreshPrivacidades();
            win.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
    <h1 class="sigma-modal-title">Política de Privacidad — Módulo del Sistema</h1>

            <%-- ID (solo edición) --%>
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field" id="divID" runat="server" visible="false">
        <label>ID</label>
        <asp:Label ID="lblID" runat="server" />
    </div>
    </div>
            <%-- Módulo del Sistema --%>
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field is-ancho">
        <label>Módulo (*):</label>
        <rad:RadComboBox2 ID="cboModulo" runat="server" Width="100%"
            MarkFirstMatch="true" Filter="Contains" OnLoad="LoadControls" />
        <asp:CustomValidator ID="cvModulo" runat="server"
            ControlToValidate="cboModulo"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ErrorMessage="Seleccione un módulo."
            ValidationGroup="Privacidad" />
    </div>
    </div>

            <%-- Editor HTML --%>
    <div class="sigma-modal-seccion">Descripción (*)</div>
    <WebControls:Editor ID="txtDescripcion" runat="server" Width="100%" Height="420px" />

            <%-- Auditoría --%>
            <asp:Panel ID="pnlAuditoria" runat="server" Visible="false" CssClass="prv-audit mt-3 col-lg-12">
                <fieldset>
                    <legend>Auditoría</legend>
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Creado por</label>
        <asp:Label ID="lblUsuarioCreacion" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Fecha creación</label>
        <asp:Label ID="lblFechaCreacion" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Actualizado por</label>
        <asp:Label ID="lblUsuarioAct" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Fecha actualización</label>
        <asp:Label ID="lblFechaAct" runat="server" />
    </div>
    </div>
                </fieldset>
            </asp:Panel>

            <%-- Botones --%>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
        CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
        OnClick="btnGuardar_Click" ValidationGroup="Privacidad" />
</div>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</div>
</asp:Content>
