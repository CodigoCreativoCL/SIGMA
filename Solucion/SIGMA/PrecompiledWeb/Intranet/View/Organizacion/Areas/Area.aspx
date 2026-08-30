<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Organizacion_Areas_Area, App_Web_2hie4pkw" %>

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
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
    <h1 class="sigma-modal-title">Área</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>ID</label>
        <asp:Label ID="lblId" runat="server"></asp:Label>
    </div>
    <div class="sigma-modal-field">
        <label>Planta(*)</label>
        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains"
        Width="80%" AutoPostBack="true" OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" />
        <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Area" />
    </div>
    <div class="sigma-modal-field">
        <label>Área superior</label>
        <rad:RadComboBox2 ID="cboPadre" runat="server" Filter="Contains" Width="80%" />
        <span class="sigma-modal-ayuda">
        Vacío indica área de primer nivel. Solo se ofrecen áreas de la misma planta.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Código(*)</label>
        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Area" />
        <span class="sigma-modal-ayuda">Mayúsculas sin espacios. Único dentro de la planta.</span>
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Area" />
    </div>
    <div class="sigma-modal-field">
        <label>Tipo de área</label>
        <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="60%" />
    </div>
    <div class="sigma-modal-field is-ancho">
        <label>Descripción</label>
        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado(*)</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Area" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Area" />
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Area" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
