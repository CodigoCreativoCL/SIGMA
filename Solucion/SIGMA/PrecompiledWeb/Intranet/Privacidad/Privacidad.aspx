<%@ page language="C#" masterpagefile="~/Master/Privacidad.master" autoeventwireup="true" inherits="Privacidad_Privacidad, App_Web_tqvtprfg" %>

<asp:Content ID="cHead" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<%-- Hero dinámico: título cambia según el módulo o muestra el índice --%>
<asp:Content ID="cHero" ContentPlaceHolderID="cphHero" runat="server">
    <asp:Literal ID="ltlHero" runat="server" Mode="PassThrough" />
</asp:Content>

<asp:Content ID="cBody" ContentPlaceHolderID="cphBody" runat="server">
    <%-- Contenido del módulo (HTML del editor) o lista de módulos --%>
    <asp:Literal ID="ltlContenido" runat="server" Mode="PassThrough" />
</asp:Content>

<asp:Content ID="cScript" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>
  