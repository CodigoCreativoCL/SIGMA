<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Comercial_Clientes_ReasignacionCliente, App_Web_tftk3qfs" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Identidad.ascx" TagPrefix="wuc" TagName="Identidad" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Usuarios" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function closeWindow() {
            window.location = ('<%=ResolveUrl(URLVolverCliente) %>');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Reasignación de Cliente
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    <wuc:Identidad runat="server" ID="wucIdentidad" />
    <wuc:Usuarios runat="server" ID="wucUsuario" />
    <br />
     <div class="col-lg-12 col-md-12 col-xs-12 form-col-center" >
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;"/>
        </div>
</asp:Content>
