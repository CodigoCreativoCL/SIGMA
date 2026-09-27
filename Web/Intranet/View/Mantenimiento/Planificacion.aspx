<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Planificacion.aspx.cs" Inherits="View_Mantenimiento_Planificacion" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-planificacion360.css") %>' rel="stylesheet" />
    <script>window.Planificacion360Config={url:'<%=ResolveUrl("~/WebService/WsPlanificacion360.asmx/") %>',hoy:'<%=HoyIso %>'};</script>
    <script src='<%=Asset("~/Js/sigma-planificacion360.js") %>' type="text/javascript"></script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <%-- Planificación 360. Sin UpdatePanel ni RadGrid A PROPÓSITO: las pestañas
         cambian en el navegador y cada una pide sus datos por AJAX la primera
         vez que se abre (WsPlanificacion360.asmx). Nada de esta página depende
         del ViewState, que va apagado. Los editores (Centro del plan, OT,
         wizard de Programación) se abren aparte: en otra pestaña o en modal. --%>
    <div class="p3" id="sgP360">

        <header class="p3-head">
            <div class="p3-head-txt">
                <nav class="p3-migas" aria-label="Ruta"><span>Centro de Mantenimiento</span><i aria-hidden="true">/</i><span>Planificación</span></nav>
                <h1>Planificación<span id="p3TituloPlanta"></span></h1>
                <p>Un solo lugar para lo que hay que hacer, lo que está planificado y cada cuánto se dispara.</p>
            </div>
            <div class="p3-filtros">
                <label class="p3-campo"><span class="p3-campo-etq">Planta</span>
                    <span class="p3-select"><i class="mdi mdi-factory" aria-hidden="true"></i><select id="p360Planta"><asp:Literal ID="litPlantas" runat="server" /></select></span>
                </label>
                <%-- Período: selector propio de mes y año (no la lista larga del
                     navegador). El <select> oculto sigue siendo el valor. --%>
                <div class="p3-campo"><span class="p3-campo-etq" id="p3PeriodoEtq">Período</span>
                    <div class="p3-periodo">
                        <button type="button" class="p3-periodo-btn" id="p3PeriodoBtn" aria-haspopup="dialog" aria-expanded="false" aria-labelledby="p3PeriodoEtq p3PeriodoTxt">
                            <i class="mdi mdi-calendar-blank-outline" aria-hidden="true"></i><span id="p3PeriodoTxt"></span><i class="mdi mdi-chevron-down p3-periodo-chev" aria-hidden="true"></i>
                        </button>
                        <select id="p360Periodo" hidden aria-hidden="true" tabindex="-1"><asp:Literal ID="litPeriodos" runat="server" /></select>
                        <div class="p3-pop" id="p3PeriodoPop" role="dialog" aria-label="Elegir período" hidden></div>
                    </div>
                </div>
            </div>
        </header>

        <div class="p3-kpis">
            <button type="button" class="p3-kpi" data-ir="bandeja" data-kpi-situacion="URGENTE">
                <span class="p3-kpi-ico es-ambar"><i class="mdi mdi-alert-circle-outline"></i></span>
                <span class="p3-kpi-txt"><span class="p3-kpi-etq">Requieren atención</span><strong data-kpi="urgente">—</strong><span class="p3-kpi-pie" data-kpi="urgentePie">&nbsp;</span></span>
                <i class="mdi mdi-chevron-right p3-kpi-ir" aria-hidden="true"></i>
            </button>
            <button type="button" class="p3-kpi" data-ir="bandeja" data-kpi-situacion="DISPONIBLE">
                <span class="p3-kpi-ico es-turquesa"><i class="mdi mdi-play-circle-outline"></i></span>
                <span class="p3-kpi-txt"><span class="p3-kpi-etq">Disponibles</span><strong data-kpi="disponibles">—</strong><span class="p3-kpi-pie">Se pueden adelantar hoy</span></span>
                <i class="mdi mdi-chevron-right p3-kpi-ir" aria-hidden="true"></i>
            </button>
            <button type="button" class="p3-kpi" data-ir="cumplimiento">
                <span class="p3-kpi-ico es-azul"><i class="mdi mdi-chart-bar"></i></span>
                <span class="p3-kpi-txt"><span class="p3-kpi-etq">Cumplimiento anual</span><strong data-kpi="cumplimiento">—</strong><span class="p3-kpi-pie" data-kpi="cumplimientoPie">&nbsp;</span></span>
                <i class="mdi mdi-chevron-right p3-kpi-ir" aria-hidden="true"></i>
            </button>
            <button type="button" class="p3-kpi" data-ir="calendario" data-kpi-vista="semana">
                <span class="p3-kpi-ico es-lila"><i class="mdi mdi-calendar-month-outline"></i></span>
                <span class="p3-kpi-txt"><span class="p3-kpi-etq">Carga próximas 4 semanas</span><strong data-kpi="carga">—</strong><span class="p3-kpi-pie" data-kpi="cargaPie">&nbsp;</span></span>
                <i class="mdi mdi-chevron-right p3-kpi-ir" aria-hidden="true"></i>
            </button>
        </div>

        <div class="p3-caja">
            <div class="p3-tabs" role="tablist" aria-label="Vistas de Planificación">
                <button type="button" role="tab" id="p3t-resumen" aria-controls="p3p-resumen" data-sec="resumen" aria-selected="true"><i class="mdi mdi-home-outline"></i>Resumen</button>
                <button type="button" role="tab" id="p3t-bandeja" aria-controls="p3p-bandeja" data-sec="bandeja" aria-selected="false" tabindex="-1"><i class="mdi mdi-inbox-arrow-down-outline"></i>Bandeja</button>
                <button type="button" role="tab" id="p3t-calendario" aria-controls="p3p-calendario" data-sec="calendario" aria-selected="false" tabindex="-1"><i class="mdi mdi-calendar-blank-outline"></i>Calendario</button>
                <button type="button" role="tab" id="p3t-planes" aria-controls="p3p-planes" data-sec="planes" aria-selected="false" tabindex="-1"><i class="mdi mdi-clipboard-text-outline"></i>Planes</button>
                <button type="button" role="tab" id="p3t-programaciones" aria-controls="p3p-programaciones" data-sec="programaciones" aria-selected="false" tabindex="-1"><i class="mdi mdi-calendar-sync-outline"></i>Programaciones</button>
                <button type="button" role="tab" id="p3t-cumplimiento" aria-controls="p3p-cumplimiento" data-sec="cumplimiento" aria-selected="false" tabindex="-1"><i class="mdi mdi-chart-bar"></i>Cumplimiento</button>
                <button type="button" role="tab" id="p3t-cobertura" aria-controls="p3p-cobertura" data-sec="cobertura" aria-selected="false" tabindex="-1"><i class="mdi mdi-shield-check-outline"></i>Cobertura</button>
            </div>
            <section role="tabpanel" id="p3p-resumen" aria-labelledby="p3t-resumen" class="p3-panel" data-panel="resumen"></section>
            <section role="tabpanel" id="p3p-bandeja" aria-labelledby="p3t-bandeja" class="p3-panel" data-panel="bandeja" hidden></section>
            <section role="tabpanel" id="p3p-calendario" aria-labelledby="p3t-calendario" class="p3-panel" data-panel="calendario" hidden></section>
            <section role="tabpanel" id="p3p-planes" aria-labelledby="p3t-planes" class="p3-panel" data-panel="planes" hidden></section>
            <section role="tabpanel" id="p3p-programaciones" aria-labelledby="p3t-programaciones" class="p3-panel" data-panel="programaciones" hidden></section>
            <section role="tabpanel" id="p3p-cumplimiento" aria-labelledby="p3t-cumplimiento" class="p3-panel" data-panel="cumplimiento" hidden></section>
            <section role="tabpanel" id="p3p-cobertura" aria-labelledby="p3t-cobertura" class="p3-panel" data-panel="cobertura" hidden></section>
        </div>
    </div>

</asp:Content>
