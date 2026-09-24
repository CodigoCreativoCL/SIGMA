<%--
    PAGINA DE FORMULARIO - Tarea.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - Misma estructura que la pagina de listado, pero coloca el UserControl
        de FORMULARIO y ademas lee el querystring CIFRADO que le mando el grid.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true"
    CodeFile="Tarea.aspx.cs" Inherits="View_Mantenimiento_Tareas_Tarea" %>

<%@ Register Src="~/View/Mantenimiento/Controls/Tarea/Tarea.ascx" TagPrefix="wuc" TagName="Tarea" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Ficha de Tarea
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <wuc:Tarea ID="wucTarea" runat="server"
        URLVolverTarea="~/View/Mantenimiento/Tareas/Tareas.aspx" />

</asp:Content>
