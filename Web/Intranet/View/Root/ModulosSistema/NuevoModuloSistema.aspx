<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevoModuloSistema.aspx.cs" Inherits="View_Root_ModulosSistema_NuevoModuloSistema" %>

<asp:Content ID="contentHeader" ContentPlaceHolderID="cphHeder" runat="server">
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
            if (win.BrowserWindow.refreshModulos) win.BrowserWindow.refreshModulos();
            win.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
    <h1 class="sigma-modal-title">Módulo del Sistema</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field" id="divID" runat="server" visible="false">
        <label>ID</label>
        <asp:Label ID="lblID" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*):</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
        <asp:CustomValidator ID="cvNombre" runat="server"
        ControlToValidate="txtNombre"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Modulo" />
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado:</label>
        <asp:CheckBox ID="chkHabilitado" runat="server" Checked="true" />
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar"  runat="server" Text="Cerrar"  CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Modulo" />
</div>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</div>
</asp:Content>
