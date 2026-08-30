<%--
    USERCONTROL DE TAB / SUB-FORMULARIO - Identidad.ascx  (USUARIO)

    PATRON (ver PATRON_MVC.md seccion 6 y PATRON_CONTROLES.md secciones 5 y 6):
      - Todo el contenido va dentro de un asp:UpdatePanel UpdateMode="Conditional".
      - Layout con la grilla Bootstrap de 12 columnas.
      - Se usan SIEMPRE los controles propios del proyecto, nunca los nativos.
      - Cada campo obligatorio lleva su asp:CustomValidator con
        ClientValidationFunction="validaControl" y el MISMO ValidationGroup
        que el boton Guardar.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Identidad.ascx.cs" Inherits="View_Seguridad_Controls_Usuario_Identidad" %>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

        <div class="row col-lg-12 col-md-12 col-xs-12">

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>RUT</label>
                <WebControls:TextBox2 ID="txtRut" runat="server" MaxLength="12" />
                <asp:CustomValidator ID="cvRut" runat="server"
                    ControlToValidate="txtRut"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Nombres</label>
                <WebControls:TextBox2 ID="txtNombres" runat="server" MaxLength="200" UpperCase="true" />
                <asp:CustomValidator ID="cvNombres" runat="server"
                    ControlToValidate="txtNombres"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Apellidos</label>
                <WebControls:TextBox2 ID="txtApellidos" runat="server" MaxLength="200" UpperCase="true" />
                <asp:CustomValidator ID="cvApellidos" runat="server"
                    ControlToValidate="txtApellidos"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Email</label>
                <WebControls:TextBox2 ID="txtEmail" runat="server" MaxLength="200" LowerCase="true" />
                <asp:CustomValidator ID="cvEmail" runat="server"
                    ControlToValidate="txtEmail"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Telefono</label>
                <%-- Campo con icono dentro del input (PATRON_CONTROLES.md 7.4) --%>
                <div class="identidad-field-icon">
                    <i class="fas fa-phone"></i>
                    <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="20" />
                </div>
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Contrasena</label>
                <%-- Password: NUNCA usar ReadOnly="true" en un TextBox2 de tipo Password,
                     porque renderiza un <span> con el texto plano. Usar Enabled="false". --%>
                <div class="identidad-password-field">
                    <WebControls:TextBox2 ID="txtPassword" runat="server" TextMode="Password" MaxLength="200" />
                    <i class="fas fa-eye identidad-password-toggle"
                       onclick="togglePasswordVisibility('<%= txtPassword.ClientID %>', this)"></i>
                </div>
                <asp:CustomValidator ID="cvPassword" runat="server"
                    ControlToValidate="txtPassword"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Perfil</label>
                <%-- OnLoad="LoadControls": el combo se puebla desde el Controller
                     una sola vez (dentro del !IsPostBack del code-behind). --%>
                <rad:RadComboBox2 ID="cboPerfil" runat="server"
                    OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPerfil" runat="server"
                    ControlToValidate="cboPerfil"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Pais</label>
                <%-- OnLoad="LoadControls": el combo se puebla desde el Controller
                     una sola vez (dentro del !IsPostBack del code-behind). --%>
                <rad:RadComboBox2 ID="cboPais" runat="server"
                    OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPais" runat="server"
                    ControlToValidate="cboPais"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Usuario" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Habilitado</label>
                <WebControls:CheckBox2 ID="chkHabilitado" runat="server" Checked="true" />
            </div>

        </div>

        <div class="row col-lg-12 col-md-12 col-xs-12" style="text-align: right;">
            <%-- ValidationGroup DEBE coincidir con el de todos los CustomValidator. --%>
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
                CssClass="Button IcoGuardar"
                OnClick="btnGuardar_Click"
                ValidationGroup="Usuario" />
        </div>

    </ContentTemplate>
</asp:UpdatePanel>

<script type="text/javascript">
    function togglePasswordVisibility(inputId, icono) {
        var input = document.getElementById(inputId);
        if (input.type === "password") {
            input.type = "text";
            icono.classList.replace("fa-eye", "fa-eye-slash");
        } else {
            input.type = "password";
            icono.classList.replace("fa-eye-slash", "fa-eye");
        }
    }
</script>
