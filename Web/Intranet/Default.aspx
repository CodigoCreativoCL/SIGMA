<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="_Default" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-inicio.css") %>?v=<%=System.IO.File.GetLastWriteTime(Server.MapPath("~/Css/LookAndFeel/sigma-inicio.css")).Ticks %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-inicio.js") %>?v=<%=System.IO.File.GetLastWriteTime(Server.MapPath("~/Js/sigma-inicio.js")).Ticks %>'></script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="server">
    <span class="sg-page-eyebrow">
        <asp:Literal ID="litFecha" runat="server" />
    </span>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    ¡Hola, <asp:Literal ID="litNombre" runat="server" />! 👋
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="server">
    <p class="sg-page-sub">Aquí tienes el resumen operativo de hoy.</p>
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">

    <%-- El inicio se dibuja en el navegador con lo que devuelve WsInicio (BD/377): ninguna cifra
         esta escrita aqui. Sin ordenes de trabajo ni predicciones, cada bloque muestra su estado vacio. --%>
    <div class="sgin" id="sgin" data-ws='<%=ResolveUrl("~/WebService/WsInicio.asmx") %>' data-img='<%=ResolveUrl("~/Imagen/") %>'>
        <section aria-labelledby="hAcc">
            <div class="sec-h"><h2 id="hAcc">Accesos directos</h2><button type="button" class="btn plain sm" id="editBtn" data-edit="1">Personalizar</button></div>
            <div class="tiles" id="tiles"><div class="skel"></div><div class="skel"></div><div class="skel"></div><div class="skel"></div></div>
        </section>

        <div class="grid">
            <div class="col">
                <section class="ai" id="ai" aria-label="SIGMA AI · predicciones en tiempo real"></section>
                <div id="ops" class="col"><div class="skel" style="min-height:220px"></div></div>
            </div>
            <div class="col side-col" id="sideCol"><div class="skel" style="min-height:240px"></div></div>
        </div>
        <div id="layer"></div>
    </div>

</asp:Content>
