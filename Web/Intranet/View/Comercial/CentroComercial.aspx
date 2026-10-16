<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="CentroComercial.aspx.cs" Inherits="View_Comercial_CentroComercial" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Centro Comercial (15-10-2026). Del formulario web al cliente activo en
         una sola pantalla: Resumen, Pipeline y Clientes, con la ficha del lead
         y todo lo que se crea (demo, propuesta, contrato, reunión) en el cajón
         lateral. Diseño: Fase 2/.../Redisenos/CentroComercial/artefacto;
         prompt: MD/PROMPT_CLAUDE_IMPLEMENTAR_CENTRO_COMERCIAL.md. --%>
    <%-- El Centro Comercial es de Código Creativo (la plataforma), no de un
         cliente: no se filtra por el cliente en sesión, así que el selector de
         cliente del encabezado no aplica aquí y se oculta. --%>
    <style>.sg-cliente-actual{display:none!important}</style>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-planificacion.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-comercial.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript">window.MantLugarConfig = <%=ConfigJson %>;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mant-comun.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-cc-cobros.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-centro-comercial.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <%-- Sin controles de servidor: todo lo pinta sigma-centro-comercial.js
         desde WsComercial.asmx. --%>
    <div class="cp-root cc-root" id="cpRoot">
        <div class="cp-wrap">
            <header class="cp-hero">
                <div class="cp-hero-title">
                    <span class="cp-hero-eyebrow">Comercial</span>
                    <h1>Centro Comercial</h1>
                    <p>Del formulario web al cliente activo: leads, demos, propuestas y contratos en un solo lugar.</p>
                </div>
                <div class="cp-hero-actions" id="ccAcc"></div>
            </header>
            <nav class="cp-mtabs" role="tablist" aria-label="Secciones del Centro Comercial" id="ccTabs"></nav>
            <div id="ccBody" role="tabpanel" aria-live="polite"><div class="cc-cargando">Cargando el Centro Comercial…</div></div>
        </div>
        <div id="cpLayer"></div>
        <div id="cpPop"></div>
        <div class="cp-toasts" id="cpToasts" aria-live="polite"></div>
    </div>
</asp:Content>
