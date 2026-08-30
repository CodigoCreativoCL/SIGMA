<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Clientes_Cliente_Identidad, App_Web_v54ilygn" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/UsuarioClientes.ascx" TagPrefix="wuc" TagName="Cliente" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Identidad.ascx" TagPrefix="wuc" TagName="Identidad" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Identidad
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphComboCliente" runat="server">
    <wuc:Cliente runat="server" ID="wucCliente" />
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    <wuc:Identidad runat="server" ID="wucIdentidad" />
</asp:Content>