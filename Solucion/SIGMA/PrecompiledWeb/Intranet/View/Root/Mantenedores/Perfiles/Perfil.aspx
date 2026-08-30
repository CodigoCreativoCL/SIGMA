<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Sistema_Perfiles_Perfil, App_Web_kdodfh0l" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        //Cierra el RadWindow"
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
            console.log("entro?", window)
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContenHead" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
    <h1 class="sigma-modal-title">Perfil</h1>
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>ID</label>
        <asp:Label ID="lblId" runat="server"></asp:Label>
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
        <asp:CustomValidator ID="CustomValidator14" runat="server"
        ControlToValidate="txtNombre"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Perfil" />
    </div>
    <div class="sigma-modal-field">
        <label>Tipo(*)</label>
        <rad:RadComboBox2 ID="cboTipoPerfil" runat="server" OnLoad="LoadControls" Filter="Contains"/>
        <asp:CustomValidator ID="CustomValidator2" runat="server"
        ControlToValidate="cboTipoPerfil"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Perfil" />
    </div>
    <div class="sigma-modal-field is-ancho">
        <label>Descripción</label>
        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="8000" />
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado(*):</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow()" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Perfil" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
