<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Comercial_Clientes_ReasignacionesClientes, App_Web_gahd0cg3" %>
<%@ Register TagPrefix="wuc" TagName="Clientes" Src="~/View/Comun/Controls/Cliente/Clientes.ascx" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">

</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">

</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Reasignaciones Clientes
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">

</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    
    <wuc:Clientes runat="server" ID="wucClientes" URLNuevoCliente="~/View/Comercial/Clientes/ReasignacionCliente.aspx" />        
    
</asp:Content>