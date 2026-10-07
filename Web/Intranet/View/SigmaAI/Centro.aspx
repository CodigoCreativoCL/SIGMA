<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Centro.aspx.cs" Inherits="View_SigmaAI_Centro" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="Server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-ai-centro.css") %>?v=<%=System.IO.File.GetLastWriteTime(Server.MapPath("~/Css/LookAndFeel/sigma-ai-centro.css")).Ticks %>' rel="stylesheet" />
    <%-- three.js bajo demanda: el importmap deja que sigma-ai-planta3d.js (modulo ES) encuentre "three". --%>
    <script type="importmap">
        {
            "imports": {
                "three": "<%=ResolveUrl("~/Js/three/three.module.min.js") %>"
            }
        }
    </script>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-ai-centro.js") %>?v=<%=System.IO.File.GetLastWriteTime(Server.MapPath("~/Js/sigma-ai-centro.js")).Ticks %>'></script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="server"></asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="server">Centro de monitoreo SIGMA AI</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="server"></asp:Content>
<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="server"></asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <%-- Todo se dibuja en el navegador con lo que devuelve WsAiCentro (BD/379): ninguna cifra esta escrita aqui. --%>
    <div class="sgai" id="sgai" data-ws='<%=ResolveUrl("~/WebService/WsAiCentro.asmx") %>' data-img='<%=ResolveUrl("~/Imagen/") %>' data-js3d='<%=ResolveUrl("~/Js/sigma-ai-planta3d.js") %>?v=<%=System.IO.File.GetLastWriteTime(Server.MapPath("~/Js/sigma-ai-planta3d.js")).Ticks %>'>
        <div class="cc">
            <div class="ccm" id="ccm"><div class="xskel"></div><div class="xskel"></div></div>
            <aside class="rail" id="rail" aria-label="SIGMA AI Chat"></aside>
        </div>
        <button type="button" class="railbtn" data-rail="1" aria-label="Abrir SIGMA AI Chat"><span class="o" id="railO"></span>SIGMA AI Chat</button>
        <div id="layer"></div>
    </div>
</asp:Content>
