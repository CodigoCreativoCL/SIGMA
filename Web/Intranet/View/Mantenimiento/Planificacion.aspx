<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Planificacion.aspx.cs" Inherits="View_Mantenimiento_Planificacion" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La cáscara de tarjetas y chips es la misma de la bandeja y del
         centro del plan: se reusa tal cual, no se vuelve a inventar. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-plan360.css") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Centro de Mantenimiento
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Planificación
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Un solo lugar para lo que hay que hacer, lo que está planificado y cada cuánto se dispara.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <%-- SIN UpdatePanel, SIN grilla Telerik A PROPÓSITO.

         Este hub es la puerta de entrada a los tres módulos, no un reemplazo
         de ninguno: cada tarjeta linkea a su pantalla real, que sigue siendo
         donde se trabaja. Meter aquí la bandeja o el listado de planes
         dentro del mismo ViewState es exactamente lo que el análisis de
         viabilidad de la unificación desaconsejó -son las dos pantallas más
         pesadas del sitio-, así que esta página se queda liviana y deja que
         cada módulo siga siendo su propia página, con su propio ciclo de
         postback. --%>
    <div class="sg-a3 sg-ot">

        <div class="sg-a3-kpis">
            <a href='<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx") %>' class="sg-a3-kpi">
                <span class="sg-a3-kpi-ico es-rojo"><i class="mdi mdi-alert-octagon-outline"></i></span>
                <div>
                    <span class="sg-a3-kpi-etq">Requiere atención</span>
                    <span class="sg-a3-kpi-val"><asp:Literal ID="litUrgente" runat="server" /></span>
                    <span class="sg-a3-kpi-pie">Vencidas y atrasadas</span>
                </div>
            </a>

            <a href='<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx") %>' class="sg-a3-kpi">
                <span class="sg-a3-kpi-ico es-verde"><i class="mdi mdi-play-circle-outline"></i></span>
                <div>
                    <span class="sg-a3-kpi-etq">Disponibles</span>
                    <span class="sg-a3-kpi-val"><asp:Literal ID="litDisponibles" runat="server" /></span>
                    <span class="sg-a3-kpi-pie">Se pueden adelantar</span>
                </div>
            </a>

            <a href='<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimientos.aspx") %>' class="sg-a3-kpi">
                <span class="sg-a3-kpi-ico es-azul"><i class="mdi mdi-clipboard-text-outline"></i></span>
                <div>
                    <span class="sg-a3-kpi-etq">Planes activos</span>
                    <span class="sg-a3-kpi-val"><asp:Literal ID="litPlanes" runat="server" /></span>
                    <span class="sg-a3-kpi-pie"><asp:Literal ID="litPlanesPie" runat="server" /></span>
                </div>
            </a>

            <a href='<%=ResolveUrl("~/View/Mantenimiento/Programaciones/Programaciones.aspx") %>' class="sg-a3-kpi">
                <span class="sg-a3-kpi-ico es-teal"><i class="mdi mdi-calendar-sync-outline"></i></span>
                <div>
                    <span class="sg-a3-kpi-etq">Programaciones</span>
                    <span class="sg-a3-kpi-val"><asp:Literal ID="litProgramaciones" runat="server" /></span>
                    <span class="sg-a3-kpi-pie">Reglas activas</span>
                </div>
            </a>
        </div>

        <asp:Literal ID="litContexto" runat="server" />

        <%-- Las tres puertas, en el orden en que se usan: primero se define
             cada cuánto (Programaciones), después se arma el plan que las
             agrupa (Plan de mantenimiento), y el trabajo del día a día se
             mira en la Bandeja -por eso ella va primero en el KPI de arriba
             y última aquí: es adonde se vuelve, no de donde se parte. --%>
        <div class="sg-a3-cols">
            <div class="sg-a3-col">

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-calendar-sync-outline"></i></span>
                        <div>
                            <h3>Programaciones</h3>
                            <p class="sg-ot-card-sub">Cada cuánto se dispara un hito: fecha única, calendario, intervalo, medidor o condición.</p>
                        </div>
                        <a class="sg-ot-btn es-accion" href='<%=ResolveUrl("~/View/Mantenimiento/Programaciones/Programaciones.aspx") %>'>Abrir</a>
                    </header>
                    <asp:Literal ID="litProgramacionesResumen" runat="server" />
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-clipboard-text-outline"></i></span>
                        <div>
                            <h3>Planes de mantenimiento</h3>
                            <p class="sg-ot-card-sub">Qué se le hace a cada familia de equipos, agrupado en hitos y actividades.</p>
                        </div>
                        <a class="sg-ot-btn es-accion" href='<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimientos.aspx") %>'>Abrir</a>
                    </header>
                    <asp:Literal ID="litPlanesResumen" runat="server" />
                </div>

            </div>

            <div class="sg-a3-col es-angosta">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico es-grande es-rojo"><i class="mdi mdi-inbox-arrow-down-outline"></i></span>
                        <div>
                            <h3>Bandeja de mantenciones</h3>
                            <p class="sg-ot-card-sub">Lo que está por vencer o ya venció, de todos los planes.</p>
                        </div>
                        <a class="sg-ot-btn es-accion" href='<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx") %>'>Abrir</a>
                    </header>
                    <asp:Literal ID="litBandejaResumen" runat="server" />
                </div>
            </div>
        </div>

        <div class="sg-ot-nota es-chica">
            <i class="mdi mdi-information-outline"></i>
            <span>Cada tarjeta abre su pantalla completa: esta vista solo reúne el estado de las tres, no reemplaza a ninguna. Un plan cuelga de una programación, y la bandeja muestra lo que los planes ya generaron.</span>
        </div>

    </div>

</asp:Content>
