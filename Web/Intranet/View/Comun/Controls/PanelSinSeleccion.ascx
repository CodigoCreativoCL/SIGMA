<%@ Control Language="C#" AutoEventWireup="true" CodeFile="PanelSinSeleccion.ascx.cs" Inherits="View_Comun_Controls_PanelSinSeleccion" %>
<asp:PlaceHolder ID="phPanel" runat="server" Visible="false">
    <div class="panel-sin-seleccion">
        <div class="pss-icono">
            <i class="<%= Icono %>"></i>
        </div>
        <p class="pss-titulo"><%= Titulo %></p>
        <p class="pss-descripcion"><%= Descripcion %></p>
    </div>
</asp:PlaceHolder>
