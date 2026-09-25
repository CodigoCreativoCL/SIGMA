<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoIndisponibilidad.aspx.cs" Inherits="View_Mantenimiento_Fallas_ActivoIndisponibilidad" %>

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

    <h1 class="sigma-modal-title">Indisponibilidad del equipo</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-power-plug-off-outline"></i>Cuándo y por qué</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Equipo(*)</label>
                <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo" ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Ind" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Inicio(*)</label>
                <WebControls:TextBox2 ID="txtInicio" runat="server" MaxLength="16" />
                <asp:CustomValidator ID="cvInicio" runat="server" ControlToValidate="txtInicio" ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Ind" />
                <span class="sigma-modal-ayuda">dd-mm-aaaa hh:mm</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Término</label>
                <WebControls:TextBox2 ID="txtFin" runat="server" MaxLength="16" />
                <span class="sigma-modal-ayuda">Vacío: sigue detenido; los minutos corren.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Planificada</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbPlanSi" runat="server" Text="SI" GroupName="Plan" />
                    <asp:RadioButton ID="rdbPlanNo" runat="server" Text="NO" GroupName="Plan" Checked="true" />
                </div>
                <span class="sigma-modal-ayuda">Planificada no penaliza la disponibilidad.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Detuvo producción</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbProdSi" runat="server" Text="SI" GroupName="Prod" />
                    <asp:RadioButton ID="rdbProdNo" runat="server" Text="NO" GroupName="Prod" Checked="true" />
                </div>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Motivo</label>
                <rad:RadComboBox2 ID="cboMotivo" runat="server" OnLoad="LoadControls" Width="100%" />
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Detalle</label>
                <WebControls:TextBox2 ID="txtMotivo" runat="server" MaxLength="1000" />
                <span class="sigma-modal-ayuda">Obligatorio si no elige un motivo del catálogo. «Corte de energía» sin orden asociada es válido.</span>
            </div>
        </div>
    </div>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Ind" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
