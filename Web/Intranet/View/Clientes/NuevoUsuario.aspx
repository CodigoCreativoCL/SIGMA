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
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Usuarios</div>



            <div class="row col-lg-12 col-md-12 col-xs-12 " id="divID" runat="server" visible="false">
                <div class="col-lg-2 col-md-2 col-xs-2">
                    <label>ID(*)</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-10">
                    <asp:Label ID="lblID" runat="server" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12 ">
                <div class="form-group col-lg-2 col-md-2 col-xs-12">
                    <label>Identificador(*)</label>
                </div>
                <div class="form-group col-lg-10 col-md-10 col-xs-12">
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
                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Login(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <WebControls:TextBox2 ID="textLogin" runat="server" />
                        <asp:CustomValidator ID="CustomValidator10" runat="server"
                            ControlToValidate="textLogin"
                            ValidateEmptyText="true"
                            ClientValidationFunction="validaControl"
                            ValidationGroup="Identidad" />
                    </div>
                </div>
                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Contraseña(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <WebControls:TextBox2 ID="textPassword" runat="server" />
                        <asp:CustomValidator ID="CustomValidator4" runat="server"
                            ControlToValidate="textPassword"
                            ValidateEmptyText="true"
                            ClientValidationFunction="validaControl"
                            ValidationGroup="Identidad" />
                    </div>
                </div>
                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Perfil(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <rad:RadComboBox2 ID="cboPerfil" runat="server" OnLoad="LoadControls" CheckBoxes="true" Filter="Contains" style="width:100% !important;" />
                        <asp:CustomValidator ID="CustomValidator6" runat="server"
                            ControlToValidate="cboPerfil"
                            ValidateEmptyText="true"
                            ValidationGroup="Identidad" />
                    </div>
                </div>

                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Nombre(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <WebControls:TextBox2 ID="TextNombre" runat="server" />
                        <asp:CustomValidator ID="CustomValidator5" runat="server"
                            ControlToValidate="TextNombre"
                            ValidateEmptyText="true"
                            ClientValidationFunction="validaControl"
                            ValidationGroup="Identidad" />
                    </div>
                </div>

                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Apellido Paterno(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <WebControls:TextBox2 ID="txtPaterno" runat="server" />
                        <asp:CustomValidator ID="CustomValidator2" runat="server"
                            ControlToValidate="txtPaterno"
                            ValidateEmptyText="true"
                            ClientValidationFunction="validaControl"
                            ValidationGroup="Identidad" />
                    </div>
                </div>

                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Apellido Materno(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <WebControls:TextBox2 ID="TextMaterno" runat="server" />
                        <asp:CustomValidator ID="CustomValidator3" runat="server"
                            ControlToValidate="TextMaterno"
                            ValidateEmptyText="true"
                            ClientValidationFunction="validaControl"
                            ValidationGroup="Identidad" />
                    </div>
                </div>

                <div class="row col-lg-12 col-md-12 col-xs-12 ">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Numero de teléfono(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
                        <WebControls:TextBox2 ID="Textfono" runat="server" TextMode="Number" />
                        <asp:CustomValidator ID="CustomValidator7" runat="server"
                            ControlToValidate="Textfono"
                            ValidateEmptyText="true"
                            ClientValidationFunction="validaControl"
                            ValidationGroup="Identidad" />
                    </div>
                </div>

                <div class="row col-lg-12 col-md-12 col-xs-12">
                    <div class="form-group col-lg-2 col-md-2 col-xs-12">
                        <label>Correo(*)</label>
                    </div>
                    <div class="form-group col-lg-10 col-md-10 col-xs-12">
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

                <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_OnClick" ValidationGroup="Identidad" />
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
                </div>
            </asp:Panel>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</asp:Content>
