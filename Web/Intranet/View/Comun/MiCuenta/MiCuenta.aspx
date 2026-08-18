<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="MiCuenta.aspx.cs" Inherits="View_Comun_MiCuenta_MiCuenta" %>

<%@ Register Src="~/View/Comun/Controls/MiCuenta/MiCuenta.ascx" TagPrefix="wuc" TagName="MiCuenta" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Mi Cuenta
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    <wuc:MiCuenta runat="server" ID="wucMiCuenta" />
</asp:Content>
