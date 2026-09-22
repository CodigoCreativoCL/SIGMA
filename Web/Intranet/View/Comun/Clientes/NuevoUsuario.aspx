<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevoUsuario.aspx.cs" Inherits="View_Comun_Clientes_NuevoUsuario" %>

<asp:Content ID="ContenHead" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript" language="javascript">       

        //Cierra el RadWindow"
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

        function validarCorreoOnBlur(input) {
            const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

            if (!regex.test(input.value) && input.value.trim() !== "") {
                alert("❌ El correo ingresado no es válido. Se limpiará el campo.");
                input.value = "";  
                input.focus();
            }
        }

        // También para el CustomValidator
        function validaControl(source, args) {
            const regex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
            args.IsValid = regex.test(args.Value);
        }
    </script>
</asp:Content>

<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
    <h1 class="sigma-modal-title">Usuarios</h1>



    <div class="sigma-modal-grid">
    <div class="sigma-modal-field" id="divID" runat="server" visible="false">
        <label>ID(*)</label>
        <asp:Label ID="lblID" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Identificador(*)</label>
        <WebControls:TextBox2 ID="txtIdentificador" runat="server" MaxLength="100" ValidaMaxLength="true"
        OnTextChanged="txtIdentificador_TextChanged" AutoPostBack="true" />
        <asp:CustomValidator ID="CustomValidator1" runat="server"
        ControlToValidate="txtIdentificador"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    </div>
            <asp:Panel runat="server" ID="pnlIdentidad" Visible="false">
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Login(*)</label>
        <WebControls:TextBox2 ID="textLogin" runat="server" />
        <asp:CustomValidator ID="CustomValidator10" runat="server"
        ControlToValidate="textLogin"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label><asp:Literal ID="litPassword" runat="server" Text="Contraseña(*)" /></label>
        <WebControls:TextBox2 ID="textPassword" runat="server" TextMode="Password" />
        <asp:CustomValidator ID="CustomValidator4" runat="server"
        ControlToValidate="textPassword"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
        <asp:Literal ID="litPasswordAyuda" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Perfil(*)</label>
        <rad:RadComboBox2 ID="cboPerfil" runat="server" OnLoad="LoadControls" CheckBoxes="true" Filter="Contains" style="width:100% !important;" />
        <asp:CustomValidator ID="CustomValidator6" runat="server"
        ControlToValidate="cboPerfil"
        ValidateEmptyText="true"
        ValidationGroup="Identidad" />
    </div>
    <%-- HU-014 #2 y #3: sin planta no hay usuario operativo. La lista y la
         vigencia van al SP UPS_CLIENTE_USUARIO_PLANTA, que es quien rechaza
         «Debe asignar al menos una planta» y quien deshabilita las que ya
         no estan (no las borra: hay ordenes historicas que se apoyan en que
         la persona estuvo autorizada). --%>
    <div class="sigma-modal-field">
        <label>Plantas(*)</label>
        <rad:RadComboBox2 ID="cboPlantas" runat="server" OnLoad="LoadControls" CheckBoxes="true" Filter="Contains" style="width:100% !important;" />
    </div>
    <div class="sigma-modal-field">
        <label>Vigente en las plantas hasta (opcional)</label>
        <WebControls:Calendar ID="calVigenciaFin" runat="server" />
        <small style="color:#6b7280;">Al vencer la fecha, la persona deja de ver esas plantas. Vacío = sin vencimiento.</small>
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="TextNombre" runat="server" />
        <asp:CustomValidator ID="CustomValidator5" runat="server"
        ControlToValidate="TextNombre"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Apellido Paterno(*)</label>
        <WebControls:TextBox2 ID="txtPaterno" runat="server" />
        <asp:CustomValidator ID="CustomValidator2" runat="server"
        ControlToValidate="txtPaterno"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Apellido Materno(*)</label>
        <WebControls:TextBox2 ID="TextMaterno" runat="server" />
        <asp:CustomValidator ID="CustomValidator3" runat="server"
        ControlToValidate="TextMaterno"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Numero de teléfono(*)</label>
        <WebControls:TextBox2 ID="Textfono" runat="server" TextMode="Number" />
        <asp:CustomValidator ID="CustomValidator7" runat="server"
        ControlToValidate="Textfono"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Correo(*)</label>
        <WebControls:TextBox2 ID="TextCorreo" runat="server" CssClass="form-control"
        onblur="validarCorreoOnBlur(this)" />
        <asp:CustomValidator ID="CustomValidator8" runat="server"
        ControlToValidate="TextCorreo"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad"
        ErrorMessage="El correo no es válido."
        Display="Dynamic" />
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_OnClick" ValidationGroup="Identidad" />
</div>
            </asp:Panel>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</div>
</asp:Content>
