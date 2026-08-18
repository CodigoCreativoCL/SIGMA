<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Clientes.aspx.cs" Inherits="View_Comercial_Clientes" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>

<%@ Register TagPrefix="wuc" TagName="Clientes" Src="~/View/Comun/Controls/Cliente/Clientes.ascx" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Clientes
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <filtropersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12">
                    <label>Habilitado</label>
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <rad:RadComboBox2 ID="cboHabilitados" runat="server" Filter="Contains" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Habilitados" Value="True" />
                            <rad:RadComboBoxItem Text="Deshabilitados" Value="False" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-1 col-md-1 col-12"></div>
                <div class="col-lg-2 col-md-2 col-12">
                    <label>Pais</label>
                </div>
                <div class="col-lg-4 col-md-4 col-12">
                    <rad:RadComboBox2 ID="cboPais" runat="server" OnLoad="LoadControls" MarkFirstMatch="true" EnableLoadOnDemand="true" Width="80%" Filter="Contains" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-12">
                    <label>Usuario</label>
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <WebControls:TextBox2 ID="txtUsuario" runat="server" MaxLength="200" Width="100%" />
                </div>
            </div>
        </filtropersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">

    <wuc:Clientes runat="server" ID="wucClientes" URLNuevoCliente="~/View/Comercial/Clientes/Cliente.aspx" />

</asp:Content>
