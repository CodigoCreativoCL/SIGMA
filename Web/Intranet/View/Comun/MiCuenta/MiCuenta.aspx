<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="MiCuenta.aspx.cs" Inherits="View_Comun_MiCuenta_MiCuenta" %>

<%@ Register Src="~/View/Comun/Controls/MiCuenta/MiCuenta.ascx" TagPrefix="wuc" TagName="MiCuenta" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
    <%-- Mi cuenta, con el diseño estándar de SIGMA (igual que Accesibilidad): eyebrow, título y bajada del master,
         cards blancas, una acción principal morada. Paleta: CLAUDE.md. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-micuenta.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mi cuenta
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Mi perfil
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Tus datos de contacto, los clientes a los que perteneces y tu contraseña.
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    <wuc:MiCuenta runat="server" ID="wucMiCuenta" />
</asp:Content>
