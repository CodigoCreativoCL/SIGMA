<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Sistema_Usuarios_Usuario, App_Web_zilkot4z" %>

<%@ Register TagPrefix="exp" TagName="UsuarioPerfil" Src="~/View/Root/Mantenedores/Usuarios/Controls/Perfiles.ascx" %>
<%@ Register TagPrefix="exp" TagName="Paises" Src="~/View/Root/Mantenedores/Usuarios/Controls/Paises.ascx" %>



<asp:Content ID="ContenHead" ContentPlaceHolderID="chpScript" runat="server">
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
        function refresh() {
            __doPostBack("<%=udPanel.ClientID %>", '')
        }

        function ValidaEmailFormat() {
            var TextCorreo = $('#<%=TextCorreo.ClientID %>');
            if (TextCorreo.val() != "") {
                if (!ValidaEmail(TextCorreo.val())) {
                    TextCorreo.val('');
                    AlertSweet('', 'Formato correo invalido', 'alerta');
                }
            }
        }

       <%-- $(function () {
            $('#<%=Textfono.ClientID %>').keydown(function (event) {
                //alert(event.keyCode);
                if ((event.keyCode < 48 || event.keyCode > 57) && (event.keyCode < 96 || event.keyCode > 105) && event.keyCode !== 190 && event.keyCode !== 110 && event.keyCode !== 8 && event.keyCode !== 9) {
                    return false;
                }
            });
        });--%>

        const inputElement = document.getElementById('#<%=Textfono.ClientID %>');

        inputElement.addEventListener("keydown", function (event) {
            const key = event.key;

            // Permitir solo números y el signo más (+)
            if (!/^\d$|\+$/.test(key)) {
                event.preventDefault();
            }
        });


    </script>
</asp:Content>

<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>


            <rad:RadTabStrip2 ID="ragTab" runat="server" MultiPageID="MultiPage">
                <Tabs>
                    <rad:RadTab Text="Identidad" runat="server" PageViewID="rtvIdentidad" />
                    <rad:RadTab Text="Perfiles" runat="server" PageViewID="rtvUsuarioPerfil" />
                    <rad:RadTab Text="Paises" runat="server" PageViewID="rtvUsuarioPais" />
                </Tabs>
            </rad:RadTabStrip2>
    <h1 class="sigma-modal-title"><asp:Label ID="lblTituloUsuario" runat="server" /></h1>
            <rad:RadMultiPage ID="MultiPage" runat="server" SelectedIndex="0" Width="100%">
                <rad:RadPageView ID="rtvIdentidad" runat="server">
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>ID</label>
        <asp:Label ID="lblID" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <asp:Image ID="imgLogo" runat="server" Width="90" Height="90" />
        <asp:FileUpload ID="fudLogo" runat="server" /><br />
        <asp:Label Text="(.jpg, .png)" runat="server"></asp:Label>
    </div>
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
        <label>
                                <asp:Label ID="lblPass" runat="server" Text="Contraseña(*)"></asp:Label></label>
        <WebControls:TextBox2 ID="textPassword" runat="server" TextMode="Password" />
        <asp:CustomValidator ID="CustomValidator4" runat="server"
        ControlToValidate="textPassword"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
        <asp:Literal ID="litPasswordAyuda" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Identificador(*)</label>
        <WebControls:TextBox2 ID="txtIdentificador" runat="server" MaxLength="100" ValidaMaxLength="true" />
        <asp:CustomValidator ID="CustomValidator1" runat="server"
        ControlToValidate="txtIdentificador"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="TextNombre" runat="server" onkeypress="return soloLetras(event)" />
        <asp:CustomValidator ID="CustomValidator5" runat="server"
        ControlToValidate="TextNombre"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Paterno(*)</label>
        <WebControls:TextBox2 ID="txtPaterno" runat="server" onkeypress="return soloLetras(event)" />
        <asp:CustomValidator ID="CustomValidator2" runat="server"
        ControlToValidate="txtPaterno"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Materno(*)</label>
        <WebControls:TextBox2 ID="TextMaterno" runat="server" onkeypress="return soloLetras(event)" />
        <asp:CustomValidator ID="CustomValidator3" runat="server"
        ControlToValidate="TextMaterno"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Teléfono(*)</label>
        <WebControls:TextBox2 ID="Textfono" runat="server" Style="height: 35px !important;" />
        <asp:CustomValidator ID="CustomValidator7" runat="server"
        ControlToValidate="Textfono"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Correo(*)</label>
        <WebControls:TextBox2 ID="TextCorreo" runat="server" onblur="ValidaEmailFormat()" />
        <asp:CustomValidator ID="CustomValidator8" runat="server"
        ControlToValidate="TextCorreo"
        ValidateEmptyText="true"
        ClientValidationFunction="validaControl"
        ValidationGroup="Identidad" />
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" ValidationGroup="Identidad" OnClick="btnGuardar_OnClick" />
</div>
                </rad:RadPageView>
                <rad:RadPageView ID="rtvUsuarioPerfil" runat="server">
                    <exp:UsuarioPerfil runat="server" ID="wucUsuarioPerfil" />
                </rad:RadPageView>
                <rad:RadPageView ID="rtvUsuarioPais" runat="server">
                    <exp:Paises runat="server" ID="wucUsuarioPaises" />
                </rad:RadPageView>
            </rad:RadMultiPage>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</div>
</asp:Content>
