<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Perfil.aspx.cs" Inherits="View_Sistema_Perfiles_Perfil" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
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
            console.log("entro?", window)
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContenHead" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Perfil</div>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>ID</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <asp:Label ID="lblId" runat="server"></asp:Label>
                </div>
            </div>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Nombre(*)</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                    <asp:CustomValidator ID="CustomValidator14" runat="server"
                        ControlToValidate="txtNombre"
                        ValidateEmptyText="true"
                        ClientValidationFunction="validaControl"
                        ValidationGroup="Perfil" />
                </div>
            </div>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Tipo(*)</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <rad:RadComboBox2 ID="cboTipoPerfil" runat="server" OnLoad="LoadControls" Filter="Contains"/>
                    <asp:CustomValidator ID="CustomValidator2" runat="server"
                        ControlToValidate="cboTipoPerfil"
                        ValidateEmptyText="true"
                        ClientValidationFunction="validaControl"
                        ValidationGroup="Perfil" />
                </div>
            </div>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Descripción</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="8000" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Habilitado(*):</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
            </div>
            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Perfil" />
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow()" />
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
