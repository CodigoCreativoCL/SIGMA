<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Desempeno.aspx.cs" Inherits="View_SigmaAI_Desempeno" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- SIGMA AI · Desempeño (EP-17, BD/475): misma cáscara que Operación (header .cp-hero, pestañas por hash y panel). --%>
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
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-ai-desempeno.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-ai-desempeno.js") %>'></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <div class="cp-root" id="cpRoot">
        <div class="cp-wrap">
            <header class="cp-hero">
                <div class="cp-hero-title">
                    <span class="cp-hero-eyebrow">SIGMA AI</span>
                    <h1>Desempeño del modelo</h1>
                    <p>Evalúa las predicciones vencidas y mide cómo rinde cada versión del modelo.</p>
                </div>
                <div class="cp-hero-actions" id="mlAcc"></div>
            </header>
            <section class="cp-panel cp-bare">
                <nav class="cp-mtabs" role="tablist" aria-label="Secciones del desempeño de SIGMA AI" id="mlTabs"></nav>
                <div id="mlBody" role="tabpanel" aria-live="polite"></div>
            </section>
        </div>
        <div id="cpLayer"></div>
        <div id="cpPop"></div>
        <div class="cp-toasts" id="cpToasts" aria-live="polite"></div>
    </div>
</asp:Content>
