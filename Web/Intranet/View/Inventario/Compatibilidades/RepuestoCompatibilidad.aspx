<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="RepuestoCompatibilidad.aspx.cs" Inherits="View_Inventario_Compatibilidades_RepuestoCompatibilidad" %>
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

    <h1 class="sigma-modal-title">Compatibilidad</h1>

    <div class="sigma-modal-note">
        <i class="mdi mdi-information-outline"></i>
        <div>
            Cada fila declara <strong>un solo alcance</strong>. Si el repuesto sirve para un tipo
            de activo <em>y</em> además para un modelo concreto, se crean dos: así se puede quitar
            una sin tocar la otra, y no queda una fila que admita dos lecturas distintas.
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-package-variant-closed"></i>Qué repuesto</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>

            <div class="sigma-modal-field is-mitad">
                <label>Repuesto(*)</label>
                <rad:RadComboBox2 ID="cboRepuesto" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvRepuesto" runat="server" ControlToValidate="cboRepuesto"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Compatibilidad" />
                <span class="sigma-modal-ayuda">
                    No se puede cambiar después: mover una compatibilidad a otro repuesto no es
                    editarla, es hacer otra afirmación distinta.
                </span>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-crosshairs-gps"></i>A qué aplica</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Alcance(*)</label>
                <rad:RadComboBox2 ID="cboAlcance" runat="server" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboAlcance_Changed">
                    <Items>
                        <rad:RadComboBoxItem Text="Tipo de activo" Value="TIPO" Selected="true" />
                        <rad:RadComboBoxItem Text="Modelo" Value="MODELO" />
                        <rad:RadComboBoxItem Text="Componente" Value="COMPONENTE" />
                    </Items>
                </rad:RadComboBox2>
                <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaAlcance" runat="server" /></span>
            </div>

            <asp:Panel ID="pnlTipo" runat="server" CssClass="sigma-modal-field is-mitad">
                <label>Tipo de activo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="100%" />
            </asp:Panel>

            <asp:Panel ID="pnlModelo" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                <label>Modelo(*)</label>
                <rad:RadComboBox2 ID="cboModelo" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="100%" />
            </asp:Panel>

            <asp:Panel ID="pnlComponente" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                <label>Componente(*)</label>
                <rad:RadComboBox2 ID="cboComponente" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaComponente" runat="server" /></span>
            </asp:Panel>

            <div class="sigma-modal-field is-ancho">
                <label>Observación</label>
                <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="500" />
                <span class="sigma-modal-ayuda">
                    Lo que hay que saber antes de montarla: una medida a verificar, una salvedad,
                    el modelo parecido en el que <strong>no</strong> calza.
                </span>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Compatibilidad" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
