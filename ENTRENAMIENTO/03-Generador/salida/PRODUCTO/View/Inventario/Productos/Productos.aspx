<%--
    PAGINA DE LISTADO - Productos.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - La pagina casi no tiene HTML propio: hereda el Master y coloca
        el UserControl de listado dentro del placeholder cphBody.
      - Su unica responsabilidad real esta en el code-behind: validar
        permisos y setear las propiedades de seguridad del UserControl.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="Productos.aspx.cs" Inherits="View_Inventario_Productos_Productos" %>

<%@ Register Src="~/View/Inventario/Controls/Producto/Productos.ascx" TagPrefix="wuc" TagName="Productos" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Productos
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <%-- URLNuevoProducto se pasa como ruta relativa con ~: el UserControl
         la resuelve con ResolveUrl para que funcione en cualquier carpeta. --%>
    <wuc:Productos ID="wucProductos" runat="server"
        URLNuevoProducto="~/View/Inventario/Productos/Producto.aspx" />

</asp:Content>
