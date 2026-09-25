<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistProgramacion.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistProgramacion" %>
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

    <h1 class="sigma-modal-title">Programación de pauta</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-clock"></i>Identificación</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Prog" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Pauta(*)</label>
                <rad:RadComboBox2 ID="cboPauta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPauta" runat="server" ControlToValidate="cboPauta"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Prog" />
                <span class="sigma-modal-ayuda">Solo pautas con una versión publicada.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Recurrencia(*)</label>
                <rad:RadComboBox2 ID="cboRecurrencia" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvRec" runat="server" ControlToValidate="cboRecurrencia"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Prog" />
                <span class="sigma-modal-ayuda">Cada cuánto se ejecuta (diaria, semanal…).</span>
            </div>
        </div>
    </div>

    <%-- ============ OBJETIVO ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-target"></i>Objetivo</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Activo</label>
                <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Área</label>
                <rad:RadComboBox2 ID="cboArea" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-grande">
                <span class="sigma-modal-ayuda">Indique <b>un activo</b> o <b>un área</b> (al menos uno). Si elige activo, la ronda se genera sobre ese equipo; si elige área, sobre el área.</span>
            </div>
        </div>
    </div>

    <%-- ============ ASIGNACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-account-hard-hat"></i>Asignación</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Grupo de trabajo</label>
                <rad:RadComboBox2 ID="cboGrupo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Responsable</label>
                <rad:RadComboBox2 ID="cboResponsable" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Quién queda a cargo de ejecutarla.</span>
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
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Prog" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
