<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Usuarios.aspx.cs" Inherits="View_Clientes_Cliente_Usuarios" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/UsuarioClientes.ascx" TagPrefix="wuc" TagName="Cliente" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Usuarios" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
    <style>
    .filtro{
       border: none !important;
   }
    </style>
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Usuarios
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphComboCliente" runat="server">
    <wuc:Cliente runat="server" ID="wucCliente" />
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    <wuc:Usuarios runat="server" ID="wucUsuarios" />
</asp:Content>
