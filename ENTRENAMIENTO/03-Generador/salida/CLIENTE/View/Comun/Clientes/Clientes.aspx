<%--
    PAGINA DE LISTADO - Clientes.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - La pagina casi no tiene HTML propio: hereda el Master y coloca
        el UserControl de listado dentro del placeholder cphBody.
      - Su unica responsabilidad real esta en el code-behind: validar
        permisos y setear las propiedades de seguridad del UserControl.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="Clientes.aspx.cs" Inherits="View_Comun_Clientes_Clientes" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Clientes.ascx" TagPrefix="wuc" TagName="Clientes" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Clientes
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <%-- URLNuevoCliente se pasa como ruta relativa con ~: el UserControl
         la resuelve con ResolveUrl para que funcione en cualquier carpeta. --%>
    <wuc:Clientes ID="wucClientes" runat="server"
        URLNuevoCliente="~/View/Comun/Clientes/Cliente.aspx" />

</asp:Content>
