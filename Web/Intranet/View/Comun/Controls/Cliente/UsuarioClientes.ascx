<%@ Control Language="C#" AutoEventWireup="true" CodeFile="UsuarioClientes.ascx.cs" Inherits="View_Comun_Controls_Cliente_UsuarioClientes" %>

<style>

</style>

<div class="row cliente-container mt-2" style="margin-bottom: 0px !important; padding: 12px !important;">
    <div class="row col-12">
        <div class="col-4">
            <div class="cliente-label">
                <i class="fas fa-users"></i>
                <span>Selección de Cliente</span>
            </div>
            <rad:RadComboBox2 ID="cboCliente" runat="server" OnLoad="LoadControls" Width="100%"
                Filter="Contains" AutoPostBack="true" CssClass="combobox" />
        </div>
    </div>
</div>
