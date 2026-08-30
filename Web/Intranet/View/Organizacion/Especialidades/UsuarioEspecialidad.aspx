<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="UsuarioEspecialidad.aspx.cs" Inherits="View_Organizacion_Especialidades_UsuarioEspecialidad" %>

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
    <h1 class="sigma-modal-title">Especialidad de la persona</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Persona(*)</label>
        <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="80%" />
        <asp:CustomValidator ID="cvUsuario" runat="server" ControlToValidate="cboUsuario"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Especialidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Especialidad(*)</label>
        <rad:RadComboBox2 ID="cboEspecialidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="80%" />
        <asp:CustomValidator ID="cvEspecialidad" runat="server" ControlToValidate="cboEspecialidad"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Especialidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Nivel</label>
        <rad:RadComboBox2 ID="cboNivel" runat="server" OnLoad="LoadControls" Filter="Contains" Width="60%" />
    </div>
    <div class="sigma-modal-field">
        <label>Certificación</label>
        <WebControls:TextBox2 ID="txtCertificacion" runat="server" MaxLength="200" />
        <span class="sigma-modal-ayuda">Nombre o número del certificado.</span>
    </div>
    <div class="sigma-modal-field">
        <label>Vence el</label>
        <WebControls:Calendar ID="calVencimiento" runat="server" />
        <span class="sigma-modal-ayuda">
        Vacío indica sin vencimiento. Una certificación vencida no impide asignar
        trabajo: se muestra la advertencia y queda registrada en la orden.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Habilitada(*)</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Especialidad" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Especialidad" />
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Especialidad" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
