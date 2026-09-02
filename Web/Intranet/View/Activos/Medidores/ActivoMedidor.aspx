<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoMedidor.aspx.cs" Inherits="View_Activos_Medidores_ActivoMedidor" %>
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

    <h1 class="sigma-modal-title">Medidor del activo</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-gauge"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Activo(*)</label>
                <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Medidor" />
                <span class="sigma-modal-ayuda">La máquina a la que pertenece el medidor. No se cambia después.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código</label>
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" ReadOnly="true" />
                <span class="sigma-modal-ayuda">Se genera solo al guardar: <strong>MED-</strong> más el número.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Medidor" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
                <span class="sigma-modal-ayuda">Deshabilitar es la baja lógica: el medidor conserva su historia.</span>
            </div>
        </div>
    </div>

    <%-- ============ MEDICIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-counter"></i>Medición</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Unidad de medida(*)</label>
                <rad:RadComboBox2 ID="cboUnidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvUnidad" runat="server" ControlToValidate="cboUnidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Medidor" />
                <span class="sigma-modal-ayuda">Horas, ciclos, kilómetros…</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Valor actual</label>
                <WebControls:TextBox2 ID="txtValorActual" runat="server" MaxLength="18" />
                <span class="sigma-modal-ayuda">La lectura de hoy. Vacío se toma como 0.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Permite reinicio(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbReinicioSi" runat="server" Text="SI" GroupName="Reinicio" />
                    <asp:RadioButton ID="rdbReinicioNo" runat="server" Text="NO" GroupName="Reinicio" Checked="true" />
                </div>
                <span class="sigma-modal-ayuda">Un contador que vuelve a cero tras una intervención (overhaul).</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Valor de reinicio</label>
                <WebControls:TextBox2 ID="txtValorReinicio" runat="server" MaxLength="18" />
                <span class="sigma-modal-ayuda">A qué valor vuelve al reiniciarse. Vacío indica sin dato.</span>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Medidor" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
