<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoVariable.aspx.cs" Inherits="View_Activos_Variables_ActivoVariable" %>
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

    <h1 class="sigma-modal-title">Variable de condición del equipo</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-thermometer-lines"></i>Qué se mide y dónde</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Equipo(*)</label>
                <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                    OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Variable" />
                <span class="sigma-modal-ayuda">La máquina. No se cambia después: si se midió en otra, es otra variable.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Componente</label>
                <rad:RadComboBox2 ID="cboComponente" runat="server" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Vacío: se mide en el equipo completo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Variable(*)</label>
                <rad:RadComboBox2 ID="cboVariable" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvVariable" runat="server" ControlToValidate="cboVariable"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Variable" />
                <span class="sigma-modal-ayuda">Temperatura, vibración, corriente… Las globales y las del cliente.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Unidad</label>
                <rad:RadComboBox2 ID="cboUnidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Vacío: la unidad propia de la variable.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Habilitada(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-chart-bell-curve"></i>Umbrales</div>
        <div class="ayuda">En orden: mínimo ≤ advertencia ≤ crítico ≤ máximo. Los que se dejen vacíos no se evalúan.</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Mínimo</label>
                <WebControls:TextBox2 ID="txtMinimo" runat="server" MaxLength="18" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Advertencia</label>
                <WebControls:TextBox2 ID="txtAdvertencia" runat="server" MaxLength="18" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Crítico</label>
                <WebControls:TextBox2 ID="txtCritico" runat="server" MaxLength="18" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Máximo</label>
                <WebControls:TextBox2 ID="txtMaximo" runat="server" MaxLength="18" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Cada cuántas horas se espera una medición</label>
                <WebControls:TextBox2 ID="txtFrecuencia" runat="server" MaxLength="6" />
                <span class="sigma-modal-ayuda">Si pasa más tiempo sin lectura, la variable aparece atrasada (SIGMA AI).</span>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Variable" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
