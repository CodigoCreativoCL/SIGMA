<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="AsociarUsuario.aspx.cs" Inherits="View_Comun_Clientes_AsociarUsuario" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Usuarios" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>


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
    </script>
</asp:Content>

<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" runat="Server">

    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="container-fluid">
                <div class="row">
                    <div class="col-lg-2 col-md-2 col-xs-12">
                        <label>Perfiles:</label>
                    </div>
                    <div class="col-lg-2 col-md-2 col-xs-12">
                        <rad:RadComboBox2 ID="cboPerfiles" runat="server" OnLoad="LoadControls" MarkFirstMatch="true" EnableLoadOnDemand="true" Width="100%" Filter="Contains" AutoPostBack="true" />
                    </div>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>


    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Asociar usuarios a la instalación</div>
            <rad:RadGrid2 ID="Grid" runat="server">
                <MasterTableView CommandItemDisplay="none" DataKeyNames="usu_id">
                    <CommandItemTemplate>
                        <wuc:Usuarios runat="server" ID="wucUsuarios" />
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
            <br />
            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Asociar" OnClick="btnGuardar_OnClick" ValidationGroup="Identidad" />
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>

        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</asp:Content>
