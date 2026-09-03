<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Programaciones.aspx.cs" Inherits="View_Mantenimiento_Programaciones_Programaciones" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-programacion.css?vrs=12") %>' rel="stylesheet" />
    <script type="text/javascript">
        document.documentElement.className += " sgp-page";
    </script>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirProgramacion(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Programaciones/Programacion.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva programación' : 'Editar programación',
                width: 1240,
                initialHeight: 760,
                minHeight: 520
            });
        }

        function refresh() {
            __doPostBack("<%=lnkRecargar.UniqueID %>", "");
        }
    </script>
    <script src='<%=ResolveUrl("~/Js/sigma-programaciones.js?vrs=2") %>' type="text/javascript"></script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="server"></asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="server"></asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="server"></asp:Content>
<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="server"></asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <asp:HiddenField ID="hfSeleccionadas" runat="server" ClientIDMode="Static" />
            <asp:HiddenField ID="hfAccionId" runat="server" ClientIDMode="Static" />

            <asp:LinkButton ID="lnkRecargar" runat="server" CssClass="sgp-postback" OnClick="lnkRecargar_Click"
                CausesValidation="false" aria-hidden="true" TabIndex="-1">Actualizar</asp:LinkButton>

            <div id="sgpProgramaciones" class="sgp-shell">
                <main class="sgp-main">
                    <header class="sgp-head">
                        <div>
                            <span class="sgp-eyebrow">Mantenimiento</span>
                            <h1>Programaciones</h1>
                            <p>Define cuándo deben ejecutarse las actividades de mantenimiento.</p>
                        </div>

                        <div class="sgp-head-actions">
                            <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sgp-button is-primary"
                                OnClientClick="return abrirProgramacion(0);" CausesValidation="false">
                                <i class="mdi mdi-plus" aria-hidden="true"></i><span>Nueva programación</span>
                            </asp:LinkButton>

                            <button type="button" class="sgp-icon-button" data-sgp-action="header-menu"
                                aria-label="Más acciones" aria-haspopup="true" aria-expanded="false">
                                <i class="mdi mdi-dots-vertical" aria-hidden="true"></i>
                            </button>

                            <div id="sgpHeaderMenu" class="sgp-menu is-header" role="menu" hidden>
                                <button type="button" role="menuitem" data-sgp-action="refresh">
                                    <i class="mdi mdi-refresh" aria-hidden="true"></i>Actualizar listado
                                </button>
                                <button type="button" role="menuitem" data-sgp-action="select-visible">
                                    <i class="mdi mdi-checkbox-multiple-marked-outline" aria-hidden="true"></i>Seleccionar visibles
                                </button>
                            </div>
                        </div>
                    </header>

                    <section class="sgp-stats" aria-label="Resumen de programaciones">
                        <button type="button" class="sgp-stat is-total" data-sgp-tab="todas">
                            <span class="sgp-stat-icon"><i class="mdi mdi-calendar-blank-outline" aria-hidden="true"></i></span>
                            <span class="sgp-stat-copy"><strong><asp:Literal ID="ltlTotal" runat="server" /></strong><span>Programaciones</span></span>
                            <i class="mdi mdi-chevron-right sgp-stat-arrow" aria-hidden="true"></i>
                        </button>

                        <button type="button" class="sgp-stat is-enabled" data-sgp-tab="habilitadas">
                            <span class="sgp-stat-icon"><i class="mdi mdi-check-circle-outline" aria-hidden="true"></i></span>
                            <span class="sgp-stat-copy"><strong><asp:Literal ID="ltlHabilitadas" runat="server" /></strong><span>Habilitadas</span></span>
                            <i class="mdi mdi-chevron-right sgp-stat-arrow" aria-hidden="true"></i>
                        </button>

                        <button type="button" class="sgp-stat is-unassigned" data-sgp-tab="sin-responsable">
                            <span class="sgp-stat-icon"><i class="mdi mdi-account-off-outline" aria-hidden="true"></i></span>
                            <span class="sgp-stat-copy"><strong><asp:Literal ID="ltlSinResponsable" runat="server" /></strong><span>Sin responsable</span></span>
                            <i class="mdi mdi-chevron-right sgp-stat-arrow" aria-hidden="true"></i>
                        </button>

                        <button type="button" class="sgp-stat is-exclusions" data-sgp-tab="con-exclusiones">
                            <span class="sgp-stat-icon"><i class="mdi mdi-alert-circle-outline" aria-hidden="true"></i></span>
                            <span class="sgp-stat-copy"><strong><asp:Literal ID="ltlConExclusiones" runat="server" /></strong><span>Con exclusiones</span></span>
                            <i class="mdi mdi-chevron-right sgp-stat-arrow" aria-hidden="true"></i>
                        </button>
                    </section>

                    <section class="sgp-list-card" aria-label="Listado de programaciones">
                        <div class="sgp-list-tools">
                            <nav class="sgp-tabs" aria-label="Vistas del listado">
                                <button type="button" class="is-active" data-sgp-tab="todas" aria-current="page">
                                    Todas <span><asp:Literal ID="ltlTabTotal" runat="server" /></span>
                                </button>
                                <button type="button" data-sgp-tab="habilitadas">
                                    Habilitadas <span><asp:Literal ID="ltlTabHabilitadas" runat="server" /></span>
                                </button>
                                <button type="button" data-sgp-tab="sin-responsable">
                                    Sin responsable <span><asp:Literal ID="ltlTabSinResponsable" runat="server" /></span>
                                </button>
                                <button type="button" data-sgp-tab="con-exclusiones">
                                    Con exclusiones <span><asp:Literal ID="ltlTabConExclusiones" runat="server" /></span>
                                </button>
                                <button type="button" data-sgp-tab="proximas">Próximas</button>
                            </nav>

                            <div class="sgp-toolbar">
                                <label class="sgp-search">
                                    <i class="mdi mdi-magnify" aria-hidden="true"></i>
                                    <span class="sr-only">Buscar programación</span>
                                    <input id="sgpSearch" type="search" placeholder="Buscar programación..." autocomplete="off" />
                                </label>

                                <div class="sgp-filter-wrap">
                                    <button type="button" class="sgp-button is-light" data-sgp-action="filters"
                                        aria-controls="sgpFilters" aria-expanded="false">
                                        <i class="mdi mdi-filter-variant" aria-hidden="true"></i><span>Filtros</span>
                                        <b id="sgpFilterCount" hidden>0</b>
                                    </button>

                                    <div id="sgpFilters" class="sgp-filter-panel" hidden>
                                        <div class="sgp-filter-head">
                                            <strong>Filtrar programaciones</strong>
                                            <button type="button" data-sgp-action="clear-filters">Limpiar</button>
                                        </div>
                                        <label>Tipo
                                            <select id="sgpFilterType">
                                                <option value="">Todos los tipos</option>
                                                <asp:Repeater ID="rptTipos" runat="server">
                                                    <ItemTemplate><option value='<%# Atributo(Eval("codigo")) %>'><%# Html(Eval("nombre")) %></option></ItemTemplate>
                                                </asp:Repeater>
                                            </select>
                                        </label>
                                        <label>Estado
                                            <select id="sgpFilterStatus">
                                                <option value="">Todos los estados</option>
                                                <option value="1">Habilitadas</option>
                                                <option value="0">Deshabilitadas</option>
                                            </select>
                                        </label>
                                        <label>Asignación
                                            <select id="sgpFilterAssignment">
                                                <option value="">Todas</option>
                                                <option value="1">Con responsable</option>
                                                <option value="0">Sin responsable</option>
                                            </select>
                                        </label>
                                        <label>Exclusiones
                                            <select id="sgpFilterExclusions">
                                                <option value="">Todas</option>
                                                <option value="1">Con exclusiones</option>
                                                <option value="0">Sin exclusiones</option>
                                            </select>
                                        </label>
                                    </div>
                                </div>

                                <label class="sgp-sort">
                                    <span class="sr-only">Ordenar por</span>
                                    <select id="sgpSort">
                                        <option value="next">Próxima ejecución</option>
                                        <option value="name">Nombre A–Z</option>
                                        <option value="type">Tipo</option>
                                        <option value="start">Inicio de vigencia</option>
                                    </select>
                                    <i class="mdi mdi-chevron-down" aria-hidden="true"></i>
                                </label>
                            </div>
                        </div>

                        <div id="sgpSelectionBar" class="sgp-selection" aria-live="polite">
                            <span class="sgp-selection-check"><i class="mdi mdi-check" aria-hidden="true"></i></span>
                            <strong id="sgpSelectionText">0 programaciones seleccionadas</strong>
                            <asp:LinkButton ID="lnkDeshabilitar" runat="server" CssClass="sgp-button is-selection"
                                OnClick="lnkDeshabilitar_Click"
                                OnClientClick="return sgpConfirmarSeleccion(this);" CausesValidation="false">
                                <i class="mdi mdi-pause-circle-outline" aria-hidden="true"></i><span>Deshabilitar</span>
                            </asp:LinkButton>
                            <button type="button" class="sgp-button is-ghost" data-sgp-action="cancel-selection">
                                <i class="mdi mdi-close" aria-hidden="true"></i><span>Cancelar selección</span>
                            </button>
                        </div>

                        <div class="sgp-table-scroll">
                            <table class="sgp-table">
                                <thead>
                                    <tr>
                                        <th class="sgp-check-cell"><input id="sgpCheckAll" type="checkbox" aria-label="Seleccionar página" /></th>
                                        <th>Programación</th>
                                        <th>Recurrencia</th>
                                        <th>Próxima ejecución</th>
                                        <th>Asignación</th>
                                        <th>Vigencia</th>
                                        <th>Estado</th>
                                        <th><span class="sr-only">Acciones</span></th>
                                    </tr>
                                </thead>
                                <tbody id="sgpRows">
                                    <asp:Repeater ID="rptProgramaciones" runat="server">
                                        <ItemTemplate>
                                            <tr class="sgp-row"
                                                data-id='<%# Eval("id") %>'
                                                data-query='<%# Atributo(Eval("query")) %>'
                                                data-name='<%# Atributo(Eval("nombre_orden")) %>'
                                                data-type='<%# Atributo(Eval("tipo_codigo")) %>'
                                                data-enabled='<%# Eval("habilitada_valor") %>'
                                                data-assigned='<%# Eval("asignada_valor") %>'
                                                data-exclusions='<%# Eval("exclusiones") %>'
                                                data-next='<%# Eval("proxima_orden") %>'
                                                data-start='<%# Eval("vigencia_orden") %>'>
                                                <td class="sgp-check-cell">
                                                    <input type="checkbox" class="sgp-row-check" value='<%# Eval("id") %>'
                                                        aria-label='<%# Atributo(Eval("seleccionar_texto")) %>' />
                                                </td>
                                                <td>
                                                    <button type="button" class="sgp-row-title" data-sgp-action="open-row">
                                                        <strong><%# Html(Eval("nombre")) %></strong>
                                                        <span class='sg-tipo <%# Eval("tipo_clase") %>'><%# Html(Eval("tipo_nombre")) %></span>
                                                    </button>
                                                </td>
                                                <td><%# Eval("regla_html") %></td>
                                                <td><%# Eval("proxima_html") %></td>
                                                <td><%# Eval("responsables_html") %></td>
                                                <td><%# Eval("vigencia_html") %></td>
                                                <td><%# Eval("estado_html") %></td>
                                                <td class="sgp-actions-cell">
                                                    <button type="button" class="sgp-row-more" data-sgp-action="row-menu"
                                                        aria-label='<%# Atributo(Eval("acciones_texto")) %>' aria-haspopup="true" aria-expanded="false">
                                                        <i class="mdi mdi-dots-horizontal" aria-hidden="true"></i>
                                                    </button>
                                                    <div class="sgp-drawer-data" hidden><%# Eval("detalle_html") %></div>
                                                    <div class="sgp-calendar-data" hidden><%# Eval("calendario_html") %></div>
                                                </td>
                                            </tr>
                                        </ItemTemplate>
                                    </asp:Repeater>

                                    <tr id="sgpEmpty" class="sgp-empty-row" hidden>
                                        <td colspan="8">
                                            <i class="mdi mdi-calendar-search" aria-hidden="true"></i>
                                            <strong>No encontramos programaciones</strong>
                                            <span>Prueba cambiando la búsqueda o limpiando los filtros.</span>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>

                        <footer class="sgp-pager">
                            <div class="sgp-page-buttons" aria-label="Paginación">
                                <button type="button" data-sgp-page="first" aria-label="Primera página"><i class="mdi mdi-page-first"></i></button>
                                <button type="button" data-sgp-page="prev" aria-label="Página anterior"><i class="mdi mdi-chevron-left"></i></button>
                                <span id="sgpPageNumbers"></span>
                                <button type="button" data-sgp-page="next" aria-label="Página siguiente"><i class="mdi mdi-chevron-right"></i></button>
                                <button type="button" data-sgp-page="last" aria-label="Última página"><i class="mdi mdi-page-last"></i></button>
                            </div>

                            <label class="sgp-page-size">Registros por página:
                                <select id="sgpPageSize">
                                    <option value="10">10</option>
                                    <option value="25" selected="selected">25</option>
                                    <option value="50">50</option>
                                </select>
                            </label>

                            <span id="sgpPageInfo" class="sgp-page-info"></span>
                        </footer>
                    </section>

                    <aside class="sgp-help">
                        <span><i class="mdi mdi-information-outline" aria-hidden="true"></i></span>
                        <p><strong>¿Cómo funcionan las programaciones?</strong>
                            Definen cuándo debe realizarse un trabajo. Los planes de mantenimiento generan las órdenes y deshabilitar conserva todo el historial.</p>
                        <button type="button" data-sgp-action="help">Más información <i class="mdi mdi-open-in-new" aria-hidden="true"></i></button>
                    </aside>
                </main>

                <aside id="sgpDrawer" class="sgp-drawer" aria-label="Detalle de programación" aria-live="polite">
                    <button type="button" class="sgp-drawer-close" data-sgp-action="close-drawer" aria-label="Cerrar detalle">
                        <i class="mdi mdi-close" aria-hidden="true"></i>
                    </button>
                    <div id="sgpDrawerContent" class="sgp-drawer-content">
                        <div class="sgp-drawer-placeholder">
                            <i class="mdi mdi-calendar-cursor" aria-hidden="true"></i>
                            <strong>Selecciona una programación</strong>
                            <span>Verás aquí su recurrencia, asignación y próximas ejecuciones.</span>
                        </div>
                    </div>
                    <div id="sgpDrawerActions" class="sgp-drawer-actions" hidden>
                        <a id="sgpEdit" href="#" class="sgp-button is-primary" data-sgp-action="edit">
                            <i class="mdi mdi-pencil-outline" aria-hidden="true"></i><span>Editar programación</span>
                        </a>
                        <div>
                            <asp:LinkButton ID="lnkDuplicar" runat="server" CssClass="sgp-button is-light"
                                OnClick="lnkDuplicar_Click" CausesValidation="false">
                                <i class="mdi mdi-content-copy" aria-hidden="true"></i><span>Duplicar</span>
                            </asp:LinkButton>
                            <button type="button" class="sgp-button is-light" data-sgp-action="calendar">
                                <i class="mdi mdi-calendar-month-outline" aria-hidden="true"></i><span>Ver calendario</span>
                            </button>
                        </div>
                        <asp:LinkButton ID="lnkDeshabilitarDetalle" runat="server" CssClass="sgp-button is-danger"
                            OnClick="lnkDeshabilitarDetalle_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '¿Deshabilitar esta programación?');"
                            CausesValidation="false">
                            <i class="mdi mdi-pause-circle-outline" aria-hidden="true"></i><span>Deshabilitar</span>
                        </asp:LinkButton>
                    </div>
                </aside>

                <div id="sgpRowMenu" class="sgp-menu is-row" role="menu" hidden>
                    <button type="button" role="menuitem" data-sgp-menu-action="edit"><i class="mdi mdi-pencil-outline"></i>Editar</button>
                    <button type="button" role="menuitem" data-sgp-menu-action="calendar"><i class="mdi mdi-calendar-month-outline"></i>Ver calendario</button>
                    <button type="button" role="menuitem" data-sgp-menu-action="duplicate"><i class="mdi mdi-content-copy"></i>Duplicar</button>
                    <button type="button" role="menuitem" class="is-danger" data-sgp-menu-action="disable"><i class="mdi mdi-pause-circle-outline"></i>Deshabilitar</button>
                </div>

                <div id="sgpCalendarModal" class="sgp-calendar-modal" role="dialog" aria-modal="true"
                    aria-labelledby="sgpCalendarTitle" hidden>
                    <div class="sgp-calendar-backdrop" data-sgp-action="close-calendar"></div>
                    <div class="sgp-calendar-dialog">
                        <header>
                            <div>
                                <span>Calendario proyectado</span>
                                <h2 id="sgpCalendarTitle">Próximas ejecuciones</h2>
                            </div>
                            <button type="button" data-sgp-action="close-calendar" aria-label="Cerrar calendario">
                                <i class="mdi mdi-close" aria-hidden="true"></i>
                            </button>
                        </header>
                        <div id="sgpCalendarContent" class="sgp-calendar-content"></div>
                        <footer>
                            <p><i class="mdi mdi-information-outline" aria-hidden="true"></i>La proyección es informativa: no crea órdenes de trabajo.</p>
                            <button type="button" class="sgp-button is-primary" data-sgp-action="close-calendar">Listo</button>
                        </footer>
                    </div>
                </div>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
