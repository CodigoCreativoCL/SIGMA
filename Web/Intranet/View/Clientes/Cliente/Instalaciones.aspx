<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Instalaciones.aspx.cs" Inherits="View_Clientes_Cliente_Instalaciones" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Instalaciones.ascx" TagPrefix="wuc" TagName="Instalaciones" %>


<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    Instalaciones
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
    <div style="float: right; padding: 12px;">
        Cliente: 
        <rad:RadComboBox2 ID="cboCliente" runat="server" OnLoad="LoadControls" AutoPostBack="true" />
    </div>
    <wuc:Instalaciones runat="server" ID="wucInstalaciones" />
</asp:Content>
