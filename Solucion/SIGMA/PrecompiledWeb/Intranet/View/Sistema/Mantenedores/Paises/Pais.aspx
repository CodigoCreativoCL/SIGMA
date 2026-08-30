<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Sistema_Mantenedores_Pais, App_Web_koj1c5f0" %>

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
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContenHead" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel"  UpdateMode="Conditional" >
        <ContentTemplate>
    <h1 class="sigma-modal-title">Pais</h1>
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
        ValidationGroup="Pais" />
    </div>
    <div class="sigma-modal-field">
        <label>Diferencia(*):</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rbtmas" runat="server" Text="+" GroupName="Diferencia" ValidationGroup="Pais"/>
        <asp:RadioButton ID="rbtmenos" runat="server" Text="-" GroupName="Diferencia" ValidationGroup="Pais"/>
        </div>
    </div>
    <div class="sigma-modal-field">
        <label>Hora(*):</label>
        <WebControls:TextBox2 ID="txtHora" runat="server" MaxLength="200" />
        <asp:CustomValidator ID="CustomValidator1" runat="server"
        ControlToValidate="txtHora"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Pais" />
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado(*):</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Pais"/>
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Pais"/>
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();"/>
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Pais"/>
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>