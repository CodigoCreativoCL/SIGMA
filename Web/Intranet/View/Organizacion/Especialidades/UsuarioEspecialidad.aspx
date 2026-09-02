<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="UsuarioEspecialidad.aspx.cs" Inherits="View_Organizacion_Especialidades_UsuarioEspecialidad" %>

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
    <h1 class="sigma-modal-title">Especialidad de la persona</h1>

    <%-- SECCIONADO Y CON ANCHOS DEL ESTANDAR

         Los seis campos estaban en una sola rejilla y con anchos sueltos
         —80%, 80%, 60%— que dejaban los bordes derechos sin alinear entre
         filas. Ahora el ancho lo decide la clase del campo (is-mitad,
         is-chico) y el control ocupa el 100% de su celda, que es como
         funcionan el resto de las fichas del sitio. --%>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-account-check-outline"></i>Quién y en qué</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mitad">
                <label>Persona(*)</label>
                <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvUsuario" runat="server" ControlToValidate="cboUsuario"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Especialidad" />
                <span class="sigma-modal-ayuda">La lista muestra el perfil de cada persona.</span>
            </div>

            <div class="sigma-modal-field is-mitad">
                <label>Especialidad(*)</label>
                <rad:RadComboBox2 ID="cboEspecialidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvEspecialidad" runat="server" ControlToValidate="cboEspecialidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Especialidad" />
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Nivel</label>
                <rad:RadComboBox2 ID="cboNivel" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Habilitada(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Especialidad" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Especialidad" />
                </div>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-certificate-outline"></i>Certificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mitad">
                <label>Certificación</label>
                <WebControls:TextBox2 ID="txtCertificacion" runat="server" MaxLength="200" />
                <span class="sigma-modal-ayuda">Nombre o número del certificado.</span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Vence el</label>
                <div class="sigma-modal-fecha">
                    <WebControls:Calendar ID="calVencimiento" runat="server" />
                </div>
                <span class="sigma-modal-ayuda">
                    Vacío indica sin vencimiento. Una certificación vencida no impide asignar
                    trabajo: se muestra la advertencia y queda registrada en la orden.
                </span>
            </div>
        </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Especialidad" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
