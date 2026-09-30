<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ChecklistCentro.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistCentro" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La cascara -tarjetas, chips, hero, pestañas- se reusa del centro del
         activo (Bryan, HU Control de activos). Aca solo va lo propio de la
         pauta. Mantiene topbar y sidebar del sistema (Default.master). --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <style type="text/css">
        /* Tokens de la paleta SIGMA (CLAUDE.md). No repetir hex sueltos. */
        .sg-pc {
            --sigma-purple: #6732F4; --sigma-purple-soft: #F2EFFF;
            --sigma-cyan-soft: #E8FBFB; --sigma-cyan-dark: #007F8A;
            --ink: #17223B; --muted: #68738A; --line: #E2E7F0;
            --success: #16855B; --warning: #B65C00;
        }
        /* Chips: fondo suave + texto del tono. Estado de negocio = semántico;
           versión = morado de marca. */
        .pc-badge { font-size: 11px; font-weight: 800; padding: 3px 10px; border-radius: 999px; display: inline-block; }
        .pc-badge.es-ver { background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .pc-badge.es-pub { background: #E7F4EE; color: var(--success); }
        .pc-badge.es-bor { background: #FBF0E3; color: var(--warning); }
        .pc-badge.es-ret { background: #EEF1F6; color: var(--muted); }
        .pc-badge.es-on  { background: #E7F4EE; color: var(--success); }
        .pc-badge.es-off { background: #EEF1F6; color: var(--muted); }
        .pc-proximo { padding: 26px; text-align: center; color: var(--muted); }
        .pc-proximo i { font-size: 34px; display: block; margin-bottom: 8px; color: var(--sigma-cyan-dark); }
        /* KPIs y tarjetas propias del Resumen (ccard blanca; color solo en icono/chip). */
        .sg-a3-kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 12px; }
        .sg-a3-kpi { display: flex; align-items: center; gap: 12px; background: #fff; border: 1px solid var(--line); border-radius: 14px; padding: 14px; }
        .sg-a3-kpi-ico { width: 40px; height: 40px; border-radius: 11px; display: flex; align-items: center; justify-content: center; background: var(--sigma-purple-soft); color: var(--sigma-purple); font-size: 20px; flex: 0 0 auto; }
        .sg-a3-kpi-txt b { display: block; font-size: 20px; font-weight: 800; color: var(--ink); line-height: 1.1; }
        .sg-a3-kpi-txt span { color: var(--muted); font-size: 12.5px; }
        .sg-ot-nota { display: flex; gap: 8px; align-items: flex-start; color: var(--muted); font-size: 12px; background: var(--sigma-cyan-soft); border-radius: 10px; padding: 9px 12px; margin-bottom: 14px; }
        .sg-ot-aviso { display: flex; gap: 10px; align-items: flex-start; background: var(--sigma-purple-soft); border-radius: 12px; padding: 12px 14px; margin-bottom: 14px; color: var(--ink); font-size: 13px; }
        .sg-ot-vacio-min { padding: 14px 4px; color: var(--muted); font-size: 13px; text-align: center; }
        @media (max-width: 980px) { .sg-a3-kpis { grid-template-columns: repeat(2, 1fr); } }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* Abrir el centro de una pauta: el id viaja en un campo oculto y el
           servidor arma el centro (mismo patrón que el centro del activo). */
        function abrirCentro(id) {
            document.getElementById('hdnPlantilla').value = id;
            document.getElementById('<%=lnkRecargar.ClientID %>').click();
            return false;
        }

        /* Alta/edición de la pauta en el mismo modal de siempre. */
        function abrirPauta(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistPlantilla.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva pauta de inspección' : 'Editar pauta de inspección',
                width: 860, initialHeight: 560
            });
        }
        function refresh() { document.getElementById('<%=lnkRecargar.ClientID %>').click(); }

        /* ---- Cambio de pestaña en el navegador (sin postback: los paneles ya
               vienen armados). hdnSeccion recuerda cuál quedó abierta. ---- */
        (function () {
            function irA(sec) {
                if (!sec) sec = 'resumen';
                var h = document.getElementById('hdnSeccion'); if (h) h.value = sec;
                var tabs = document.querySelectorAll('.sg-a3-tab[data-sec]');
                for (var i = 0; i < tabs.length; i++)
                    tabs[i].classList.toggle('es-activa', tabs[i].getAttribute('data-sec') === sec);
                var pans = document.querySelectorAll('.sg-a3-panel[data-panel]');
                for (var p = 0; p < pans.length; p++)
                    pans[p].classList.toggle('es-activo', pans[p].getAttribute('data-panel') === sec);
            }
            document.addEventListener('click', function (e) {
                var t = e.target.closest ? e.target.closest('[data-sec],[data-ir-sec]') : null;
                if (!t) return;
                e.preventDefault();
                irA(t.getAttribute('data-sec') || t.getAttribute('data-ir-sec'));
            });
            window.sigmaPautaIrA = irA;
            document.addEventListener('DOMContentLoaded', function () {
                var h = document.getElementById('hdnSeccion');
                irA(h ? h.value : 'resumen');
            });
        })();
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Pautas de inspección</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Un solo centro: diseña, publica, programa y revisa resultados.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus pautas de inspección.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:HiddenField ID="hdnPlantilla" runat="server" Value="0" ClientIDMode="Static" />
            <asp:HiddenField ID="hdnSeccion" runat="server" Value="resumen" ClientIDMode="Static" />
            <asp:LinkButton ID="lnkRecargar" runat="server" style="display:none" CausesValidation="false" OnClick="lnkRecargar_Click" />

            <%-- ==================== LISTADO ==================== --%>
            <asp:Panel ID="pnlLista" runat="server" CssClass="sg-a3 sg-pc">
                <div class="sg-a3-cols" style="align-items:flex-start;">
                    <div class="sg-a3-col">
                        <div class="sg-ot-card">
                            <header class="sg-ot-card-cab">
                                <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-clipboard-list-outline"></i></span>
                                <div>
                                    <h3>Pautas de inspección</h3>
                                    <p class="sg-ot-card-sub">Toque <b>Abrir</b> para entrar al centro de la pauta.</p>
                                </div>
                                <div class="sg-ot-card-acc">
                                    <asp:LinkButton ID="lnkNueva" runat="server" CssClass="sg-ot-btn es-primario"
                                        OnClientClick="return abrirPauta(0);"><i class="mdi mdi-plus"></i>Nueva pauta</asp:LinkButton>
                                </div>
                            </header>

                            <div class="sg-a3-filtros">
                                <label class="sg-a3-filtro"><i class="mdi mdi-office-building-outline"></i>
                                    <span>Planta</span>
                                    <rad:RadComboBox2 ID="cboPlanta" runat="server" AutoPostBack="true" Width="100%"
                                        OnLoad="LoadControls" Filter="Contains" />
                                </label>
                                <label class="sg-a3-filtro"><i class="mdi mdi-check-circle-outline"></i>
                                    <span>Estado</span>
                                    <rad:RadComboBox2 ID="cboEstado" runat="server" AutoPostBack="true" Width="100%">
                                        <Items>
                                            <rad:RadComboBoxItem Text="Todos" Value="" />
                                            <rad:RadComboBoxItem Text="Habilitadas" Value="1" />
                                            <rad:RadComboBoxItem Text="Deshabilitadas" Value="0" />
                                        </Items>
                                    </rad:RadComboBox2>
                                </label>
                                <span class="sg-a3-filtro-buscar">
                                    <i class="mdi mdi-magnify"></i>
                                    <input type="search" id="sgPautaBuscar" autocomplete="off"
                                        placeholder="Buscar por código, nombre o descripción..." onkeyup="sgPautaFiltrar(this.value)" />
                                </span>
                            </div>

                            <asp:Literal ID="litLista" runat="server" />
                            <asp:Panel ID="pnlListaVacia" runat="server" Visible="false" CssClass="sg-ot-vacio">
                                <i class="mdi mdi-clipboard-off-outline"></i>
                                <p>No hay pautas que coincidan</p>
                                <span>Ajuste el filtro o cree una nueva pauta.</span>
                            </asp:Panel>
                        </div>
                    </div>

                    <aside class="sg-a3-lado">
                        <div class="sg-ot-card">
                            <header class="sg-ot-card-cab">
                                <span class="sg-ot-card-ico"><i class="mdi mdi-clipboard-check-outline"></i></span>
                                <h3>Un solo centro</h3>
                            </header>
                            <div style="padding:2px 4px 6px;color:#475569;font-size:13px;line-height:1.5;">
                                Las pautas de inspección se crean una vez, se versionan y se ejecutan
                                en las rondas programadas o en inspecciones puntuales.
                            </div>
                            <div class="sg-ot-card-pie">
                                <asp:HyperLink ID="hlHallazgos" runat="server" CssClass="sg-ot-btn es-plano">
                                    <i class="mdi mdi-alert-outline"></i>Ir a hallazgos de inspección
                                </asp:HyperLink>
                            </div>
                        </div>
                    </aside>
                </div>
            </asp:Panel>

            <%-- ==================== CENTRO DE LA PAUTA ==================== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sg-a3 sg-ot sg-pc">

                <div class="sg-a3-miga">
                    <span>Pautas de inspección</span>
                    <span class="sep">/</span>
                    <asp:LinkButton ID="lnkVolver" runat="server" OnClick="lnkVolver_Click" CausesValidation="false">Listado</asp:LinkButton>
                    <span class="sep">/</span><asp:Literal ID="litMiga" runat="server" />
                </div>

                <header class="sg-a3-hero">
                    <div class="sg-a3-hero-txt">
                        <h1><asp:Literal ID="litHeroNombre" runat="server" /></h1>
                        <div class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></div>
                    </div>
                    <div class="sg-a3-hero-acc">
                        <asp:HyperLink ID="hlEditar" runat="server" CssClass="sg-ot-btn es-plano" NavigateUrl="javascript:void(0)"
                            ToolTip="Editar la configuración de la pauta"><i class="mdi mdi-pencil-outline"></i>Editar</asp:HyperLink>
                    </div>
                </header>

                <nav class="sg-a3-nav">
                    <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-view-dashboard-outline"></i>Resumen</a>
                    <a href="#" class="sg-a3-tab" data-sec="configuracion"><i class="mdi mdi-cog-outline"></i>Configuración</a>
                    <a href="#" class="sg-a3-tab" data-sec="estructura"><i class="mdi mdi-file-tree-outline"></i>Estructura</a>
                    <a href="#" class="sg-a3-tab" data-sec="versiones"><i class="mdi mdi-history"></i>Versiones</a>
                    <a href="#" class="sg-a3-tab" data-sec="programaciones"><i class="mdi mdi-calendar-clock"></i>Programaciones</a>
                    <a href="#" class="sg-a3-tab" data-sec="ocurrencias"><i class="mdi mdi-play-circle-outline"></i>Ocurrencias y ejecuciones</a>
                    <a href="#" class="sg-a3-tab" data-sec="hallazgos"><i class="mdi mdi-alert-outline"></i>Hallazgos</a>
                </nav>

                <%-- 1. RESUMEN --%>
                <section class="sg-a3-panel" data-panel="resumen">
                    <asp:Literal ID="litResumenAviso" runat="server" />
                    <asp:Literal ID="litKpis" runat="server" />
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-play-circle-outline"></i></span>
                                    <div><h3>Última ejecución</h3><p class="sg-ot-card-sub">La ronda más reciente de esta pauta.</p></div>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="ocurrencias">Ver ejecuciones <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litUltima" runat="server" />
                            </div>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-alerta"><i class="mdi mdi-alert-outline"></i></span>
                                    <div><h3>Hallazgos que requieren atención</h3><p class="sg-ot-card-sub">Lo abierto sobre esta pauta.</p></div>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="hallazgos">Ver hallazgos <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litHallazgos" runat="server" />
                            </div>
                        </div>
                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab"><span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span><h3>Información general</h3></header>
                                <asp:Literal ID="litInfo" runat="server" />
                            </div>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab"><span class="sg-ot-card-ico"><i class="mdi mdi-cube-outline"></i></span><h3>Versión actual</h3></header>
                                <asp:Literal ID="litVersion" runat="server" />
                                <div class="sg-ot-card-pie">
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="estructura"><i class="mdi mdi-file-tree-outline"></i>Ver estructura</a>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="versiones"><i class="mdi mdi-history"></i>Versiones</a>
                                </div>
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- 2-7: en construcción (fases siguientes) --%>
                <section class="sg-a3-panel" data-panel="configuracion"><div class="sg-ot-card"><div class="pc-proximo"><i class="mdi mdi-cog-outline"></i>Configuración de la pauta — llega en la próxima fase.<br/>Por ahora se edita con el botón <b>Editar</b> de arriba.</div></div></section>
                <section class="sg-a3-panel" data-panel="estructura"><div class="sg-ot-card"><div class="pc-proximo"><i class="mdi mdi-file-tree-outline"></i>Estructura (secciones, ítems, opciones, validaciones y dependencias) — llega en la próxima fase.</div></div></section>
                <section class="sg-a3-panel" data-panel="versiones"><div class="sg-ot-card"><div class="pc-proximo"><i class="mdi mdi-history"></i>Versiones de la pauta — llega en la próxima fase.</div></div></section>
                <section class="sg-a3-panel" data-panel="programaciones"><div class="sg-ot-card"><div class="pc-proximo"><i class="mdi mdi-calendar-clock"></i>Programaciones — llega en la próxima fase.</div></div></section>
                <section class="sg-a3-panel" data-panel="ocurrencias"><div class="sg-ot-card"><div class="pc-proximo"><i class="mdi mdi-play-circle-outline"></i>Ocurrencias y ejecuciones — llega en la próxima fase.</div></div></section>
                <section class="sg-a3-panel" data-panel="hallazgos"><div class="sg-ot-card"><div class="pc-proximo"><i class="mdi mdi-alert-outline"></i>Hallazgos de la pauta — llega en la próxima fase.</div></div></section>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

    <script type="text/javascript">
        /* Filtro cliente-side del listado por texto (código/nombre/descripción). */
        function sgPautaFiltrar(q) {
            q = (q || '').toLowerCase();
            var filas = document.querySelectorAll('#sgPautaLista .sg-ot-fila');
            for (var i = 0; i < filas.length; i++) {
                var t = (filas[i].getAttribute('data-buscar') || '').toLowerCase();
                filas[i].style.display = (!q || t.indexOf(q) >= 0) ? '' : 'none';
            }
        }
    </script>
</asp:Content>
