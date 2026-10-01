<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistItemDependencia.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistItemDependencia" %>
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

    <h1 class="sigma-modal-title">Dependencia entre ítems</h1>

    <%-- ============ ÍTEM DEPENDIENTE Y ACCIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-sitemap-outline"></i>Qué ítem y qué le pasa</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <asp:Panel ID="pnlItemNuevo" runat="server" CssClass="sigma-modal-field is-grande">
                <label>Ítem dependiente(*)</label>
                <rad:RadComboBox2 ID="cboItem" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvItem" runat="server" ControlToValidate="cboItem"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Dep" />
                <span class="sigma-modal-ayuda">El ítem que se muestra u oculta según otro. Debe ser de la misma pauta que la condición.</span>
            </asp:Panel>
            <asp:Panel ID="pnlItemEdita" runat="server" Visible="false" CssClass="sigma-modal-field is-grande">
                <label>Ítem dependiente</label>
                <asp:Literal ID="litItem" runat="server" />
            </asp:Panel>
            <div class="sigma-modal-field is-medio">
                <label>Acción(*)</label>
                <rad:RadComboBox2 ID="cboAccion" runat="server" Width="100%" />
                <span class="sigma-modal-ayuda">Mostrar / Ocultar / Requerir / Bloquear cuando se cumple la condición.</span>
            </div>
        </div>
    </div>

    <%-- ============ CONDICIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-help-rhombus-outline"></i>Cuándo se aplica</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-grande">
                <label>Ítem de condición(*)</label>
                <rad:RadComboBox2 ID="cboCondicion" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvCond" runat="server" ControlToValidate="cboCondicion"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Dep" />
                <span class="sigma-modal-ayuda">El ítem cuya respuesta decide. No puede ser el mismo ítem dependiente.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Operador(*)</label>
                <rad:RadComboBox2 ID="cboOperador" runat="server" Width="100%" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Valor</label>
                <WebControls:TextBox2 ID="txtValor" runat="server" MaxLength="400" />
                <span class="sigma-modal-ayuda">El valor con que se compara la respuesta (por ejemplo «Sí», «No», un número).</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Dep" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
