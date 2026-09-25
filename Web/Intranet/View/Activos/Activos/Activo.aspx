<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Activo.aspx.cs" Inherits="View_Activos_Activos_Activo" %>
<%@ Register TagPrefix="wuc" TagName="ActivoForm" Src="~/View/Activos/Activos/ActivoForm.ascx" %>

<%-- La ficha del activo en modal. Todo lo que se ve vive en ActivoForm.ascx,
     que es el mismo formulario que muestra la pestaña Ficha del centro. --%>
<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <div class="sigma-modal">
        <h1 class="sigma-modal-title">Activo</h1>
        <wuc:ActivoForm runat="server" ID="frmActivo" />
    </div>
</asp:Content>
