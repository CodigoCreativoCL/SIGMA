<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="OrdenTrabajoAsignacion.aspx.cs" Inherits="View_Mantenimiento_Ordenes_OrdenTrabajoAsignacion" %>

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

    <h1 class="sigma-modal-title">Asignar la orden</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-account-hard-hat"></i>Quién la ejecuta</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Técnico</label>
                <rad:RadComboBox2 ID="cboUsuario" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Una persona del cliente. Le aparece en su bandeja y recibe una notificación.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>… o empresa externa</label>
                <rad:RadComboBox2 ID="cboProveedor" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Del registro de contratistas; no hace falta crearle un usuario.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Grupo de trabajo</label>
                <rad:RadComboBox2 ID="cboGrupo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Es el responsable</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbRespSi" runat="server" Text="SI" GroupName="Resp" Checked="true" />
                    <asp:RadioButton ID="rdbRespNo" runat="server" Text="NO (apoyo)" GroupName="Resp" />
                </div>
                <span class="sigma-modal-ayuda">Un solo responsable: el anterior pasa a apoyo.</span>
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Observación</label>
                <WebControls:TextBox2 ID="txtObservacion" runat="server" MaxLength="1000" />
            </div>
        </div>
    </div>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Asignar" OnClick="btnGuardar_Click" CausesValidation="false" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
