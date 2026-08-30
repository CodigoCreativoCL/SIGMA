<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PermisoUsuario.aspx.cs" Inherits="View_Root_Mantenedores_PermisosUsuario_PermisoUsuario" %>

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
    <h1 class="sigma-modal-title">Permiso puntual</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Usuario(*)</label>
        <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="80%" />
        <asp:CustomValidator ID="cvUsuario" runat="server" ControlToValidate="cboUsuario"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
    </div>
    <div class="sigma-modal-field">
        <label>Permiso(*)</label>
        <rad:RadComboBox2 ID="cboPermiso" runat="server" Filter="Contains" Width="80%" />
        <asp:CustomValidator ID="cvPermiso" runat="server" ControlToValidate="cboPermiso"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
        <span class="sigma-modal-ayuda">
        Sólo aparecen los permisos que pueden concederse a una persona.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Efecto(*)</label>
        <asp:RadioButton ID="rdbConcede" runat="server" Text="Concede" GroupName="Efecto" Checked="true" />
        <asp:RadioButton ID="rdbDeniega" runat="server" Text="Deniega" GroupName="Efecto" />
        <span class="sigma-modal-ayuda">
        Denegar prevalece sobre el permiso del perfil.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Ámbito(*)</label>
        <rad:RadComboBox2 ID="cboAmbito" runat="server" Width="50%"
        AutoPostBack="true" OnSelectedIndexChanged="cboAmbito_SelectedIndexChanged">
        <Items>
        <rad:RadComboBoxItem Text="Todo el cliente" Value="CLIENTE" Selected="true" />
        <rad:RadComboBoxItem Text="Una planta" Value="PLANTA" />
        <rad:RadComboBoxItem Text="Un área" Value="AREA" />
        </Items>
        </rad:RadComboBox2>
    </div>
    </div>
            <asp:Panel ID="pnlPlanta" runat="server" Visible="false" CssClass="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-xs-12"><label>Planta(*)</label></div>
                <div class="col-lg-9 col-md-9 col-xs-12">
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Filter="Contains" Width="80%"
                        AutoPostBack="true" OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" />
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlArea" runat="server" Visible="false" CssClass="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-xs-12"><label>Área(*)</label></div>
                <div class="col-lg-9 col-md-9 col-xs-12">
                    <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="80%" />
                </div>
            </asp:Panel>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Vigente desde</label>
        <WebControls:Calendar ID="calDesde" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Vigente hasta</label>
        <WebControls:Calendar ID="calHasta" runat="server" />
        <span class="sigma-modal-ayuda">Vacío indica sin vencimiento.</span>
    </div>
    <div class="sigma-modal-field is-ancho">
        <label>Motivo(*)</label>
        <WebControls:TextArea2 ID="txtMotivo" runat="server" MaxLength="500" />
        <asp:CustomValidator ID="cvMotivo" runat="server" ControlToValidate="txtMotivo"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
        <span class="sigma-modal-ayuda">
        Al menos 10 caracteres. Queda registrado junto a quién lo concedió y cuándo.
        </span>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Permiso" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
