<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ChecklistDetalleLista.ascx.cs" Inherits="View_Comun_Controls_Cliente_Checklist_ChecklistDetalleLista" %>


<div class="SubTitulos">Ítem Lista</div>
<div class="col-lg-12 col-md-12 col-xs-12 ">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Nombre(*)</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <WebControls:TextBox2 ID="txtNombre" runat="server" />
        <asp:CustomValidator ID="CustomValidator1" runat="server"
            ControlToValidate="txtNombre"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ValidationGroup="ItemCombobox" />
    </div>
</div>
<div class="col-lg-12 col-md-12 col-xs-12 ">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Orden(*)</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <WebControls:TextBox2 ID="txtValor" runat="server" />
        <asp:CustomValidator ID="CustomValidator5" runat="server"
            ControlToValidate="txtValor"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ValidationGroup="ItemCombobox" />
    </div>
</div>

<div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
    </br>
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_OnClick" ValidationGroup="ItemCombobox" />
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
</div>

