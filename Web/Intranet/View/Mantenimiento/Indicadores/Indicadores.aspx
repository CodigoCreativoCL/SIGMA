<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Indicadores.aspx.cs" Inherits="View_Mantenimiento_Indicadores_Indicadores" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Indicadores de gestión (EP-18, BD/474): misma cáscara que Operación (header .cp-hero, pestañas por hash y panel). --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-carga.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-centro-planificacion.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-mant-lugares.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-mant-ot.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-carga.js") %>'></script>
    <script type="text/javascript">window.MantLugarConfig = <%=ConfigJson %>;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mant-comun.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-mant-lugar.js") %>'></script>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-indicadores.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-indicadores.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <div class="cp-root" id="cpRoot">
        <div class="cp-wrap">
            <header class="cp-hero">
                <div class="cp-hero-title">
                    <span class="cp-hero-eyebrow">Mantenimiento</span>
                    <h1>Indicadores de gestión</h1>
                    <p>Cómo va el mantenimiento: cumplimiento, disponibilidad, tiempos medios y costos.</p>
                </div>
                <div class="cp-hero-actions" id="mlAcc"></div>
            </header>
            <section class="cp-panel cp-bare">
                <nav class="cp-mtabs" role="tablist" aria-label="Secciones de Indicadores de gestión" id="mlTabs"></nav>
                <div id="mlBody" role="tabpanel" aria-live="polite"></div>
            </section>
        </div>
        <div id="cpLayer"></div>
        <div id="cpPop"></div>
        <div class="cp-toasts" id="cpToasts" aria-live="polite"></div>
    </div>
</asp:Content>
