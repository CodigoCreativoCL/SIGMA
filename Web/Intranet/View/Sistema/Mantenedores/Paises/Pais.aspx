<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Pais.aspx.cs" Inherits="View_Sistema_Mantenedores_Pais" %>

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
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContenHead" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel"  UpdateMode="Conditional" >
        <ContentTemplate>
            <div class="SubTitulos">Pais</div>
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
                        ValidationGroup="Pais" /> 
                </div>
            </div>
             <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Diferencia(*):</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <asp:RadioButton ID="rbtmas" runat="server" Text="+" GroupName="Diferencia" ValidationGroup="Pais"/>
                    <asp:RadioButton ID="rbtmenos" runat="server" Text="-" GroupName="Diferencia" ValidationGroup="Pais"/>
                </div>
            </div>
             <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Hora(*):</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:TextBox2 ID="txtHora" runat="server" MaxLength="200" />
                    <asp:CustomValidator ID="CustomValidator1" runat="server" 
                        ControlToValidate="txtHora" 
                        ValidateEmptyText="true"
                        ClientValidationFunction="validaControl" 
                        ValidationGroup="Pais" /> 
                </div>
            </div>
            
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12">
                    <label>Habilitado(*):</label>
                </div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Pais"/>
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Pais"/>
                </div>
            </div>
            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Pais"/>
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();"/>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>