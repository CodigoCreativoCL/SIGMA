<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PlanActivo.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanActivo" %>

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

    <h1 class="sigma-modal-title">Equipo del plan</h1>

    <asp:Panel ID="pnlBloqueado" runat="server" Visible="false" CssClass="sigma-modal-ayuda" style="margin-bottom:12px;">
        <i class="mdi mdi-lock-outline"></i>
        Este vínculo pertenece a una versión <strong><asp:Literal ID="litEstadoVersion" runat="server" /></strong> y ya no se puede modificar. Para cambiarlo, abra una versión nueva del plan.
    </asp:Panel>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-link-variant"></i>Plan y equipo</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Plan(*)</label>
                <rad:RadComboBox2 ID="cboPlan" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPlan" runat="server" ControlToValidate="cboPlan"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanActivo" />
                <span class="sigma-modal-ayuda">Solo los planes con una versión en borrador.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Equipo(*)</label>
                <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                    OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanActivo" />
                <span class="sigma-modal-ayuda">Tiene que caber en el alcance del plan: su planta, su tipo y su modelo, si el plan los acota.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Componente</label>
                <rad:RadComboBox2 ID="cboComponente" runat="server" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Vacío: el plan aplica al equipo completo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Medidor</label>
                <rad:RadComboBox2 ID="cboMedidor" runat="server" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">El contador con el que se miden los hitos por medidor de este equipo.</span>
            </div>
        </div>
    </div>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="PlanActivo" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
