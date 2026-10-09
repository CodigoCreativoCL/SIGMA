<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Operacion.aspx.cs" Inherits="View_Mantenimiento_Operacion_Operacion" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Operación (09-10-2026, parte a del rediseño de Mantenimiento en cinco lugares).
         Misma cáscara que el Centro de Planificación: header .cp-hero, pestañas por hash
         y panel; el contenido de cada pestaña lo registra su parte (MantLugar.tab).
         Plan: MD/PLAN_MODERNIZACION_MANTENIMIENTO.md --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-planificacion.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-mant-lugares.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-mant-ot.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript">window.MantLugarConfig = <%=ConfigJson %>;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mant-comun.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mant-lugar.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <div class="cp-root" id="cpRoot">
        <div class="cp-wrap">
            <header class="cp-hero">
                <div class="cp-hero-title">
                    <span class="cp-hero-eyebrow">Mantenimiento</span>
                    <h1>Operación</h1>
                    <p>Qué pasa hoy en mantenimiento y qué está atrasado.</p>
                </div>
                <div class="cp-hero-actions" id="mlAcc"></div>
            </header>
            <section class="cp-panel">
                <nav class="cp-mtabs" role="tablist" aria-label="Secciones de Operación" id="mlTabs"></nav>
                <div id="mlBody" role="tabpanel" aria-live="polite"></div>
            </section>
        </div>
        <div id="cpLayer"></div>
        <div id="cpPop"></div>
        <div class="cp-toasts" id="cpToasts" aria-live="polite"></div>
    </div>
</asp:Content>
