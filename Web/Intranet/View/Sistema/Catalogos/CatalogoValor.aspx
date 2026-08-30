<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CatalogoValor.aspx.cs" Inherits="View_Sistema_Catalogos_CatalogoValor" %>

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
    <h1 class="sigma-modal-title">Valor del catálogo</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Catálogo</label>
        <asp:Label ID="lblCatalogo" runat="server"></asp:Label>
    </div>
    <div class="sigma-modal-field">
        <label>Código(*)</label>
        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Valor" />
        <span class="sigma-modal-ayuda">
        Mayúsculas sin acentos. Único dentro del catálogo, contando los valores del sistema.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Nombre visible(*)</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Valor" />
        <span class="sigma-modal-ayuda">Es el texto que ve el usuario final.</span>
    </div>
    <div class="sigma-modal-field is-ancho">
        <label>Descripción</label>
        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
    </div>
    <div class="sigma-modal-field">
        <label>Orden</label>
        <rad:RadNumericBox2 ID="txtOrden" runat="server" Width="30%">
        <NumberFormat DecimalDigits="0" />
        </rad:RadNumericBox2>
        <span class="sigma-modal-ayuda">Define la posición en las listas. Los valores sin orden van al final.</span>
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado(*)</label>
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Valor" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Valor" />
        <asp:Panel ID="pnlUso" runat="server" Visible="false" style="margin-top: 8px;">
        <span class="grid-estado-chip is-alerta"><asp:Literal ID="litUso" runat="server" /></span>
        </asp:Panel>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Valor" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
