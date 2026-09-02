<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoModelo.aspx.cs" Inherits="View_Activos_Modelos_ActivoModelo" %>
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

    <h1 class="sigma-modal-title">Modelo de activo</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-shape-outline"></i>Identificación</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Tipo de activo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Mod" />
                <span class="sigma-modal-ayuda">La familia de equipos a la que aplica este modelo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Fabricante</label>
                <WebControls:TextBox2 ID="txtFabricante" runat="server" MaxLength="200" />
                <span class="sigma-modal-ayuda">Quién lo fabrica (WEG, Grundfos…). Opcional.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Modelo(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Mod" />
                <span class="sigma-modal-ayuda">La designación del fabricante (W22 132S, NB 65-200…).</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
                <span class="sigma-modal-ayuda">Ficha técnica breve: potencia, caudal, etc. Opcional.</span>
            </div>
        </div>
    </div>

    <asp:Panel ID="pnlGlobal" runat="server" Visible="false" CssClass="card-box">
        <p><i class="mdi mdi-information-outline"></i> Este es un modelo <strong>global de la plataforma</strong>: se puede usar pero no se edita desde aquí.</p>
    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Mod" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
