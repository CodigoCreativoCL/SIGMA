<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="CentroCargaDatos.aspx.cs" Inherits="View_Comun_CargaDatos_CentroCargaDatos" %>

<%-- Centro de carga de datos (bloques 334 y 335).

     Un solo lugar para dejar cada modulo listo para operar desde planillas:
     se descarga la plantilla del modulo, se sube, SIGMA la revisa sin
     escribir nada y despues se carga. Miles de filas: el proceso corre en la
     base, en segundo plano, y aqui se ve su avance con el tiempo transcurrido.

     SIN POSTBACK
       Todo va por WsCargaDatos en JSON. Un postback a mitad de una carga
       perderia el seguimiento del proceso (que igual sigue en el servidor).

     ACCESO
       Permiso GESTIONAR CARGAS MASIVAS: Administrador del Cliente, o el
       usuario al que el se lo asigne (es delegable). --%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="<%=ResolveUrl("~/Css/Comun/sigma-carga-datos.css") %>?vrs=2" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Utilidades
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Centro de carga de datos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Deja cada módulo listo para operar desde planillas: se revisa antes de escribir, y miles de filas se cargan en segundo plano.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <div class="cd" id="cd" data-ws="<%=ResolveUrl("~/WebService/WsCargaDatos.asmx") %>">

        <%-- ---------------------------------------------------- escena --%>
        <section class="cd-hero">
            <div class="cd-escena" id="cdEscena" aria-hidden="true"></div>
            <div class="cd-hero-texto">
                <span class="cd-hero-eyebrow"><i class="mdi mdi-database-import-outline"></i>Puesta en marcha</span>
                <h2>De la planilla a la operación, módulo por módulo</h2>
                <p>Cada módulo trae su plantilla con todo lo que necesita para quedar listo: lo que se crea primero y lo que depende de ello, en un solo archivo.</p>
                <ol class="cd-pasos-hero">
                    <li><b>1</b>Descarga la plantilla</li>
                    <li><b>2</b>SIGMA la revisa sin escribir nada</li>
                    <li><b>3</b>Cargas y sigues el avance</li>
                </ol>
            </div>
            <div class="cd-hero-leyenda" id="cdLeyenda"></div>
        </section>

        <%-- ---------------------------------------------------- módulos --%>
        <section class="cd-modulos" id="cdModulos" aria-label="Módulos">
            <div class="cd-cargando"><div class="cd-loader"><span></span><span></span><span></span></div>Cargando módulos…</div>
        </section>

        <%-- ---------------------------------------------------- asistente --%>
        <section class="cd-card cd-asistente" id="cdAsistente" hidden></section>

        <%-- ---------------------------------------------------- resultado --%>
        <section class="cd-card cd-resultado" id="cdResultado" hidden></section>

        <%-- ---------------------------------------------------- historial --%>
        <section class="cd-card">
            <div class="cd-card-cab">
                <h3><i class="mdi mdi-history"></i>Historial de cargas</h3>
                <span class="cd-muted" id="cdHistN"></span>
            </div>
            <div class="cd-tabla-scroll"><table class="cd-tabla" id="cdHistorial"></table></div>
        </section>

        <%-- ---------------------------------------------------- avance flotante --%>
        <div class="cd-avance" id="cdAvance" hidden role="status" aria-live="polite"></div>
        <div class="cd-toasts" id="cdToasts" aria-live="assertive"></div>
    </div>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="importmap">
        {
            "imports": {
                "three": "<%=ResolveUrl("~/Js/three/three.module.min.js") %>",
                "three/addons/": "<%=ResolveUrl("~/Js/three/addons/") %>"
            }
        }
    </script>
    <script type="module" src="<%=ResolveUrl("~/Js/sigma-carga-datos.js") %>?vrs=3"></script>
</asp:Content>
