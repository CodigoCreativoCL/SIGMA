<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevoModuloSistema.aspx.cs" Inherits="View_Root_ModulosSistema_NuevoModuloSistema" %>

<asp:Content ID="contentHeader" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var win = getRadWindow();
            if (win.BrowserWindow.refreshModulos) win.BrowserWindow.refreshModulos();
            win.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Módulo del Sistema</div>

            <div class="row col-lg-12 col-md-12 col-xs-12" id="divID" runat="server" visible="false">
                <div class="col-lg-2 col-md-2 col-xs-2"><label>ID</label></div>
                <div class="col-lg-10 col-md-10 col-xs-10">
                    <asp:Label ID="lblID" runat="server" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-xs-12"><label>Nombre(*):</label></div>
                <div class="col-lg-9 col-md-9 col-xs-12">
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                    <asp:CustomValidator ID="cvNombre" runat="server"
                        ControlToValidate="txtNombre"
                        ValidateEmptyText="true"
                        ClientValidationFunction="validaControl"
                        ValidationGroup="Modulo" />
                </div>
            </div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-xs-12"><label>Habilitado:</label></div>
                <div class="col-lg-9 col-md-9 col-xs-12" style="padding-top:6px;">
                    <asp:CheckBox ID="chkHabilitado" runat="server" Checked="true" />
                </div>
            </div>

            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center mt-1">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Modulo" />
                <WebControls:PushButton ID="btnCerrar"  runat="server" Text="Cerrar"  CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</asp:Content>
