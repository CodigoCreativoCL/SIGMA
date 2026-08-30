<%--
    PAGINA DE FORMULARIO - Cliente.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - Misma estructura que la pagina de listado, pero coloca el UserControl
        de FORMULARIO y ademas lee el querystring CIFRADO que le mando el grid.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="Cliente.aspx.cs" Inherits="View_Comun_Clientes_Cliente" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Cliente.ascx" TagPrefix="wuc" TagName="Cliente" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Ficha de Cliente
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <wuc:Cliente ID="wucCliente" runat="server"
        URLVolverCliente="~/View/Comun/Clientes/Clientes.aspx" />

</asp:Content>
