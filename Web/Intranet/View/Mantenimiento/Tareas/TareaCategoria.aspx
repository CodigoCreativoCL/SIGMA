<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="TareaCategoria.aspx.cs" Inherits="View_Mantenimiento_Tareas_TareaCategoria" %>

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
    <h1 class="sigma-modal-title">Categoría de tarea</h1>

    <div class="sigma-modal-grid">
        <div class="sigma-modal-field">
            <label>ID</label>
            <asp:Label ID="lblId" runat="server"></asp:Label>
        </div>
        <div class="sigma-modal-field">
            <label>Código(*)</label>
            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" />
            <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="TareaCategoria" />
            <span class="sigma-modal-ayuda">Único dentro del cliente (por ejemplo <em>PREVENTIVO</em>).</span>
        </div>
        <div class="sigma-modal-field">
            <label>Nombre(*)</label>
            <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
            <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="TareaCategoria" />
        </div>
        <div class="sigma-modal-field">
            <label>Color</label>
            <WebControls:TextBox2 ID="txtColor" runat="server" MaxLength="20" />
            <span class="sigma-modal-ayuda">Color de la etiqueta (por ejemplo <em>#22c55e</em>). Opcional.</span>
        </div>
        <div class="sigma-modal-field">
            <label>Orden</label>
            <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="4" />
            <span class="sigma-modal-ayuda">Posición en las listas. Opcional.</span>
        </div>
        <div class="sigma-modal-field">
            <label>Habilitado(*)</label>
            <div class="sigma-modal-opciones">
                <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
            </div>
        </div>
    </div>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="TareaCategoria" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
