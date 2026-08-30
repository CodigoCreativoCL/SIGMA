<%--
    PAGINA DE FORMULARIO - Producto.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - Misma estructura que la pagina de listado, pero coloca el UserControl
        de FORMULARIO y ademas lee el querystring CIFRADO que le mando el grid.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="Producto.aspx.cs" Inherits="View_Inventario_Productos_Producto" %>

<%@ Register Src="~/View/Inventario/Controls/Producto/Producto.ascx" TagPrefix="wuc" TagName="Producto" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Ficha de Producto
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <wuc:Producto ID="wucProducto" runat="server"
        URLVolverProducto="~/View/Inventario/Productos/Productos.aspx" />

</asp:Content>
