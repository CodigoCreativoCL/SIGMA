<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PlanHito.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanHito" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

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

    <h1 class="sigma-modal-title">Hito de plan</h1>

    <asp:Panel ID="pnlBloqueado" runat="server" Visible="false" CssClass="sigma-modal-ayuda" style="margin-bottom:12px;">
        <%-- La version de este hito ya no esta en borrador: se lee, no se edita.
             Se dice arriba y no al apretar Guardar, que es cuando ya se escribio. --%>
        <i class="mdi mdi-lock-outline"></i>
        Este hito pertenece a una versión <strong><asp:Literal ID="litEstadoVersion" runat="server" /></strong> y ya no se puede modificar. Para cambiarlo, abra una versión nueva del plan.
    </asp:Panel>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-flag-checkered"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Plan(*)</label>
                <rad:RadComboBox2 ID="cboPlan" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPlan" runat="server" ControlToValidate="cboPlan"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanHito" />
                <span class="sigma-modal-ayuda">Solo los planes con una versión en borrador. El hito se cuelga de esa versión.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código(*)</label>
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanHito" />
                <span class="sigma-modal-ayuda">Único dentro de la versión. Por ejemplo <em>LUB-500</em>.</span>
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Orden</label>
                <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="3" />
                <span class="sigma-modal-ayuda">Vacío: al final.</span>
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanHito" />
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
            </div>
        </div>
    </div>

    <%-- ============ CADA CUÁNTO ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-clock"></i>Cada cuánto</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Programación(*)</label>
                <rad:RadComboBox2 ID="cboProgramacion" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvProgramacion" runat="server" ControlToValidate="cboProgramacion"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanHito" />
                <span class="sigma-modal-ayuda">El calendario, intervalo o medidor que dispara este hito. ¿No está? Se crea en <em>Programaciones</em>.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Valor del medidor</label>
                <WebControls:TextBox2 ID="txtValorMedidor" runat="server" MaxLength="14" />
                <span class="sigma-modal-ayuda">Solo si la programación es por medidor: a las cuántas horas o ciclos.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Unidad</label>
                <rad:RadComboBox2 ID="cboUnidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
        </div>
    </div>

    <%-- ============ LA ORDEN QUE GENERA ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-clipboard-text-outline"></i>La orden que genera</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Tipo de OT</label>
                <rad:RadComboBox2 ID="cboOtTipo" runat="server" OnLoad="LoadControls" Width="100%" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Prioridad</label>
                <rad:RadComboBox2 ID="cboOtPrioridad" runat="server" OnLoad="LoadControls" Width="100%" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Duración estimada (min)</label>
                <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="6" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Requiere parada</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbParadaSi" runat="server" Text="SI" GroupName="Parada" />
                    <asp:RadioButton ID="rdbParadaNo" runat="server" Text="NO" GroupName="Parada" Checked="true" />
                </div>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Es overhaul</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbOverhaulSi" runat="server" Text="SI" GroupName="Overhaul" />
                    <asp:RadioButton ID="rdbOverhaulNo" runat="server" Text="NO" GroupName="Overhaul" Checked="true" />
                </div>
                <span class="sigma-modal-ayuda">Intervención mayor: se planifica con parada larga y repuestos.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="PlanHito" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="PlanHito" />
                </div>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="PlanHito" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
