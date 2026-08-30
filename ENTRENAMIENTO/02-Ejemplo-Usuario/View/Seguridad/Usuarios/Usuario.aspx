<%--
    PAGINA DE FORMULARIO - Usuario.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - Misma estructura que la pagina de listado, pero coloca el UserControl
        de FORMULARIO y ademas lee el querystring CIFRADO que le mando el grid.
--%>
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="Usuario.aspx.cs" Inherits="View_Seguridad_Usuarios_Usuario" %>

<%@ Register Src="~/View/Seguridad/Controls/Usuario/Usuario.ascx" TagPrefix="wuc" TagName="Usuario" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Ficha de Usuario
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <wuc:Usuario ID="wucUsuario" runat="server"
        URLVolverUsuario="~/View/Seguridad/Usuarios/Usuarios.aspx" />

</asp:Content>
