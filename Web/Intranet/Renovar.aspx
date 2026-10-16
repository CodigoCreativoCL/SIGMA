<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Renovar.aspx.cs" Inherits="Renovar" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Mi suscripción (P6, Centro Comercial V2). Es la única pantalla que sigue abierta cuando la
         suscripción venció (SuscripcionAcceso.EXENTAS y Token.EXENTAS): el drawer se abre solo y todo
         lo pide al servicio WsMiSuscripcion, que trabaja siempre con el cliente en sesión.
         Diseño: Redisenos/CentroComercial/artefacto/MiSuscripcion.dc.html. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-planificacion.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-comercial.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript">window.MantLugarConfig = <%=ConfigJson %>;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mant-comun.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mi-suscripcion.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <div class="cp-root cc-root" id="cpRoot">
        <div class="cp-wrap">
            <header class="cp-hero">
                <div class="cp-hero-title">
                    <span class="cp-hero-eyebrow">Suscripción</span>
                    <h1>Mi suscripción</h1>
                    <p>El estado de tu plan y lo que necesitas para seguir trabajando.</p>
                </div>
                <div class="cp-hero-actions"><button type="button" class="cp-btn cp-pri" data-a="abrir">Ver mi suscripción</button></div>
            </header>
            <div id="msBody" aria-live="polite"><div class="cc-cargando">Cargando tu suscripción…</div></div>
            <noscript><div class="cc-vacio">Esta pantalla necesita JavaScript. Escribe a comercial@codigocreativo.tech y te ayudamos.</div></noscript>
        </div>
        <div id="cpLayer"></div>
        <div id="cpPop"></div>
        <div class="cp-toasts" id="cpToasts" aria-live="polite"></div>
    </div>
</asp:Content>
