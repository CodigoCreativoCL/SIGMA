<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CargaMasivaActivos.aspx.cs" Inherits="View_Activos_Ficha_CargaMasivaActivos" %>

<%-- Carga masiva de activos (se abre desde el Centro de activos).

     Es el Centro de carga de datos fijo en el modulo ACTIVOS (bloque 367):
     la misma plantilla de Excel con hojas por paso -activos, datos tecnicos,
     componentes, variables, medidores y repuestos compatibles-, la revision
     que no escribe nada, el avance en segundo plano y los errores por fila en
     Excel. Antes era un CSV con doce columnas que solo creaba el activo: lo
     demas de la ficha habia que completarlo a mano, equipo por equipo. --%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="<%=ResolveUrl("~/Css/Comun/sigma-carga-datos.css") %>?vrs=3" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <div class="cd es-fijo" id="cd" data-ws="<%=ResolveUrl("~/WebService/WsCargaDatos.asmx") %>" data-modulo="ACTIVOS">
        <section class="cd-hero" hidden><div class="cd-escena" id="cdEscena" aria-hidden="true"></div><div class="cd-hero-leyenda" id="cdLeyenda"></div></section>
        <section class="cd-modulos" id="cdModulos" aria-label="Módulos" hidden></section>
        <section class="cd-card cd-asistente" id="cdAsistente">
            <div class="cd-cargando"><div class="cd-loader"><span></span><span></span><span></span></div>Preparando la carga de activos…</div>
        </section>
        <section class="cd-card cd-resultado" id="cdResultado" hidden></section>
        <section class="cd-card">
            <div class="cd-card-cab">
                <h3><i class="mdi mdi-history"></i>Cargas de activos anteriores</h3>
                <span class="cd-muted" id="cdHistN"></span>
            </div>
            <div class="cd-tabla-scroll"><table class="cd-tabla" id="cdHistorial"></table></div>
        </section>
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
    <script type="module" src="<%=ResolveUrl("~/Js/sigma-carga-datos.js") %>?vrs=4"></script>
</asp:Content>
