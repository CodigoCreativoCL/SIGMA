<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="_Default" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="server">
    <span class="sg-page-eyebrow">
        <asp:Literal ID="litFecha" runat="server" />
    </span>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    ¡Hola, <asp:Literal ID="litNombre" runat="server" />! 👋
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="server">
    <p class="sg-page-sub">Aquí tienes el resumen operativo de hoy.</p>
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">

    <%-- Los indicadores del panel de inicio (órdenes por estado, por
         prioridad y OT recientes) todavía no se pueden calcular: las
         tablas del modelo estan creadas pero sin datos, y no existen
         los SP de consulta. Poner cifras fijas aqui seria inventarlas.

         Cuando existan Orden_Trabajo y sus SP, este bloque se reemplaza
         por las tarjetas y graficos del diseño. --%>
    <p style="margin: 0; color: #6F7789; font-size: 14px;">
        El panel de indicadores se activa cuando existan órdenes de trabajo registradas.
    </p>

</asp:Content>
