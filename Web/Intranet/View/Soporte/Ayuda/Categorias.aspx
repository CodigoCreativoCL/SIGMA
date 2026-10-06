<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" Inherits="SitioBase.SoportePagina" Title="Categorías de ayuda · SIGMA" %>
<%-- Soporte · Categorías de ayuda. La dibuja Js/sigma-soporte.js (vista «cats»), que
     carga el master; ver docs/rediseno-soporte/sigma-soporte-referencia.html. --%>
<asp:Content ID="cTitulo" ContentPlaceHolderID="cphTitulo" runat="server">Categorías de ayuda</asp:Content>
<asp:Content ID="cBody" ContentPlaceHolderID="cphBody" runat="server">
    <div id="sgs-app" class="sgs sgs-app" data-vista="cats" data-id="<%= RegistroId > 0 ? RegistroId.ToString() : "" %>" aria-live="polite"></div>
</asp:Content>
