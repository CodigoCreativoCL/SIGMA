<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" Inherits="SitioBase.SoportePagina" Title="Problemas detectados · SIGMA" %>
<%-- Soporte · Problemas detectados. La dibuja Js/sigma-soporte.js (vista «tickets»), que
     carga el master; ver docs/rediseno-soporte/sigma-soporte-referencia.html. --%>
<asp:Content ID="cTitulo" ContentPlaceHolderID="cphTitulo" runat="server">Problemas detectados</asp:Content>
<asp:Content ID="cBody" ContentPlaceHolderID="cphBody" runat="server">
    <div id="sgs-app" class="sgs sgs-app" data-vista="tickets" data-id="<%= RegistroId > 0 ? RegistroId.ToString() : "" %>" aria-live="polite"></div>
</asp:Content>
