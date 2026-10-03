<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="BodegaMapa3D.aspx.cs" Inherits="View_Inventario_Bodegas_BodegaMapa3D" %>

<%-- Mapa 3D de bodegas: consulta Y administracion de la bodega en un solo lugar.

     SIN POSTBACK, SIN MODALES
       La pagina no tiene ni un control de servidor. Todo -la carga, crear una
       bodega, un rack, un repuesto, registrar un movimiento- va por
       WsBodegaMapa en JSON, y los formularios viven en el panel del propio
       mapa. Un postback rearmaria la escena y tiraria la camara a su posicion
       inicial: justo lo que no se quiere despues de navegar hasta un rack.

     OCUPA TODO EL CENTRO
       El visor se fija entre la barra superior y el menu lateral: no queda
       margen blanco alrededor, y se reacomoda si se pliega el menu.

     THREE VA DENTRO DEL PROYECTO (Js/three, version 0.160.0)
       No depende de que un CDN responda el dia de la demo. --%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="<%=ResolveUrl("~/Css/Inventario/sigma-bodega3d.css") %>?vrs=21" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Mapa 3D de bodegas
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <div id="bm3d" class="bm3d" data-ws="<%=ResolveUrl("~/WebService/WsBodegaMapa.asmx") %>">

        <div class="bm3d-escena" id="bm3dEscena" aria-label="Vista 3D de la bodega"></div>

        <!-- ---------- barra superior ---------- -->
        <header class="bm3d-barra">
            <div class="bm3d-marca"><i class="mdi mdi-warehouse"></i><span>Mapa de bodegas</span></div>
            <div class="bm3d-sep"></div>
            <select id="bm3dPlanta" class="bm3d-select" aria-label="Planta"></select>
            <nav class="bm3d-bodegas" id="bm3dBodegas" role="tablist" aria-label="Bodegas"></nav>
            <div class="bm3d-buscar">
                <i class="mdi mdi-magnify" aria-hidden="true"></i>
                <input type="search" id="bm3dBuscar" placeholder="Buscar repuesto, código, tipo o rack…  ( / )" autocomplete="off" aria-label="Buscar" />
                <div class="bm3d-resultados" id="bm3dResultados" role="listbox" hidden></div>
            </div>
            <div class="bm3d-acciones" role="group" aria-label="Acciones">
                <button type="button" class="bm3d-btn es-primario es-chico" data-accion="nuevo" hidden><i class="mdi mdi-plus"></i><span>Repuesto</span></button>
                <button type="button" class="bm3d-ico" data-accion="picking" title="Preparar picking: lo que pide una OT o un retiro libre" hidden><i class="mdi mdi-cart-arrow-down"></i></button>
                <button type="button" class="bm3d-ico" data-modo="alertas" title="Resaltar alertas de stock"><i class="mdi mdi-alert-decagram-outline"></i></button>
                <button type="button" class="bm3d-ico" data-accion="analisis" title="Análisis: rotación ABC, quiebre, vencimientos, compatibles"><i class="mdi mdi-chart-box-outline"></i></button>
                <button type="button" class="bm3d-ico" data-vista="general" title="Encuadrar la bodega completa"><i class="mdi mdi-fit-to-screen-outline"></i></button>
                <button type="button" class="bm3d-ico" data-accion="pantalla" title="Pantalla completa"><i class="mdi mdi-fullscreen"></i></button>
                <%-- Lo que se usa menos, en un menu: la barra no alcanza para todo
                     sin cortar las pestanas de las bodegas. --%>
                <div class="bm3d-mas">
                    <button type="button" class="bm3d-ico" data-accion="mas" title="Más acciones" aria-haspopup="true"><i class="mdi mdi-dots-vertical"></i></button>
                    <div class="bm3d-mas-menu" id="bm3dMas" hidden>
                        <button type="button" data-accion="editar" hidden><i class="mdi mdi-pencil-ruler"></i>Modo edición: racks y pasillos</button>
                        <button type="button" data-accion="bodega"><i class="mdi mdi-cog-outline"></i>Datos de la bodega</button>
                        <button type="button" data-vista="planta"><i class="mdi mdi-floor-plan"></i>Vista de planta</button>
                        <button type="button" data-accion="historial"><i class="mdi mdi-history"></i>Historial y reproducción</button>
                        <button type="button" data-accion="escanear"><i class="mdi mdi-qrcode-scan"></i>Escanear o ir a un código</button>
                        <button type="button" data-accion="refrescar"><i class="mdi mdi-refresh"></i>Actualizar stock</button>
                        <button type="button" data-accion="simbolo"><i class="mdi mdi-barcode"></i>Ver etiquetas con código de barras</button>
                    </div>
                </div>
            </div>
        </header>

        <div class="bm3d-kpis" id="bm3dKpis"></div>
        <div class="bm3d-leyenda" id="bm3dLeyenda" aria-label="Tipos de repuesto"></div>
        <aside class="bm3d-panel" id="bm3dPanel" aria-live="polite"></aside>
        <div class="bm3d-tip" id="bm3dTip" hidden></div>
        <div class="bm3d-pick" id="bm3dPick" hidden></div>
        <div class="bm3d-toasts" id="bm3dToasts" aria-live="assertive"></div>

        <!-- recorrido de pasillo: barras de cine, etiquetas sobre las cajas y la tablet -->
        <div class="bm3d-callouts" id="bm3dCallouts" aria-hidden="true"></div>

        <!-- historial: linea de tiempo y la leyenda de lo que se reproduce -->
        <div class="bm3d-historia" id="bm3dHistoria" hidden></div>
        <div class="bm3d-hs-caption" id="bm3dHsCaption" hidden></div>

        <!-- escanear o escribir un codigo -->
        <div class="bm3d-scan" id="bm3dScan" hidden></div>
        <div class="bm3d-cine" id="bm3dCine" hidden></div>
        <div class="bm3d-tablet" id="bm3dTablet" hidden></div>

        <!-- ficha del repuesto: ventana dentro del mapa, se arrastra por la cabecera -->
        <section class="bm3d-ficha" id="bm3dFicha" role="dialog" aria-label="Ficha del repuesto" hidden></section>

        <div class="bm3d-visor" id="bm3dVisor" hidden>
            <button type="button" class="bm3d-visor-cerrar" aria-label="Cerrar"><i class="mdi mdi-close"></i></button>
            <button type="button" class="bm3d-visor-nav es-ant" aria-label="Anterior"><i class="mdi mdi-chevron-left"></i></button>
            <img alt="" />
            <button type="button" class="bm3d-visor-nav es-sig" aria-label="Siguiente"><i class="mdi mdi-chevron-right"></i></button>
            <div class="bm3d-visor-pie"></div>
        </div>

        <div class="bm3d-estado" id="bm3dEstado">
            <div class="bm3d-loader"><span></span><span></span><span></span></div>
            <p>Construyendo la bodega…</p>
        </div>

        <div class="bm3d-ayuda" id="bm3dAyuda">
            <span><i class="mdi mdi-mouse"></i> Arrastra para girar · rueda para acercar · clic derecho para desplazar</span>
            <span><i class="mdi mdi-keyboard-outline"></i> ← → cambian de bodega o de caja · ↑ ↓ de nivel · / busca</span>
            <span><i class="mdi mdi-cursor-default-click-outline"></i> Clic en una caja, un rack o el piso para ver su detalle</span>
        </div>
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
    <script type="text/javascript" src="<%=ResolveUrl("~/Js/sigma-fabricante.js") %>?vrs=2"></script>
    <script type="module" src="<%=ResolveUrl("~/Js/sigma-bodega3d.js") %>?vrs=21"></script>
</asp:Content>
