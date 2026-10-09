<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Planificacion.aspx.cs" Inherits="View_Mantenimiento_Planificacion" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Centro de Planificación (08-10-2026). Reemplaza a Planificación 360:
         la misma cáscara (planta y período, KPI, pestañas por AJAX, estado en
         la URL) con el workspace de planes adentro. Referencia visual:
         docs/rediseno-planificacion/sigma-centro-planificacion-referencia.html;
         alcance: MD/CENTRO_PLANIFICACION_ALCANCE.md. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-planificacion.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript">window.CentroPlanificacionConfig = <%=ConfigJson %>;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-centro-planificacion.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <%-- Sin UpdatePanel ni controles de servidor A PROPÓSITO: todo se pinta en
         el navegador desde WsCentroPlanificacion.asmx (lecturas y escrituras)
         y WsPlanificacion360.asmx (KPI, ejecuciones, cumplimiento y
         cobertura). El ViewState va apagado: no hay postback que pueda perder
         lo que se está editando. --%>
    <div class="cp-root" id="cpRoot">
        <div class="cp-wrap">
            <header class="cp-hero">
                <div class="cp-hero-title">
                    <span class="cp-hero-eyebrow">Centro de Mantenimiento</span>
                    <h1>Centro de Planificación<span id="cpTituloPlanta"></span></h1>
                    <p>Qué se mantiene, cómo, cada cuánto y quién lo ejecuta.</p>
                </div>
                <div class="cp-hero-actions" id="cpHeroAcc"></div>
            </header>

            <section class="cp-kpis" id="cpKpis" aria-label="Resumen de la planificación" hidden></section>

            <section class="cp-panel">
                <nav class="cp-mtabs" role="tablist" aria-label="Secciones del Centro de Planificación" id="cpTabs"></nav>
                <div id="cpBody" role="tabpanel" aria-live="polite"></div>
            </section>
        </div>

        <div id="cpLayer"></div>
        <div id="cpLayer2"></div>
        <div id="cpPop"></div>
        <div class="cp-toasts" id="cpToasts" aria-live="polite"></div>
    </div>

</asp:Content>
