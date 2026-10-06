<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" Inherits="SitioBase.SoportePagina" Title="Analítica de soporte · SIGMA" %>
<%-- Soporte · Analítica de soporte. La dibuja Js/sigma-soporte.js (vista «analytics»), que
     carga el master; ver docs/rediseno-soporte/sigma-soporte-referencia.html. --%>
<asp:Content ID="cTitulo" ContentPlaceHolderID="cphTitulo" runat="server">Analítica de soporte</asp:Content>
<asp:Content ID="cBody" ContentPlaceHolderID="cphBody" runat="server">
    <div id="sgs-app" class="sgs sgs-app" data-vista="analytics" data-id="<%= RegistroId > 0 ? RegistroId.ToString() : "" %>" aria-live="polite"></div>
</asp:Content>
