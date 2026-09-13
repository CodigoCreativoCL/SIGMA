<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="TareaProgramacion.aspx.cs" Inherits="View_Mantenimiento_Tareas_TareaProgramacion" %>

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

    <h1 class="sigma-modal-title">Programación de la tarea</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-clock"></i>Cada cuánto</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Tarea(*)</label>
                <rad:RadComboBox2 ID="cboTarea" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTarea" runat="server" ControlToValidate="cboTarea"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="TareaProgramacion" />
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Programación(*)</label>
                <rad:RadComboBox2 ID="cboProgramacion" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvProgramacion" runat="server" ControlToValidate="cboProgramacion"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="TareaProgramacion" />
                <span class="sigma-modal-ayuda">El calendario, intervalo o medidor que dispara la tarea. Se crean en <em>Programaciones</em>. Al editar no se cambia: se quita una y se agrega otra.</span>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-account-hard-hat"></i>Quién</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Responsable</label>
                <rad:RadComboBox2 ID="cboResponsable" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Una persona. Le aparece en «Mis tareas».</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Grupo de trabajo</label>
                <rad:RadComboBox2 ID="cboGrupo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">O un grupo: la toma cualquiera de sus integrantes.</span>
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

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="TareaProgramacion" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
