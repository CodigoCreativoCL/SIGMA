<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoFicha.aspx.cs" Inherits="View_Activos_Ficha_ActivoFicha" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>
<%@ Register TagPrefix="wuc" TagName="ActivoForm" Src="~/View/Activos/Activos/ActivoForm.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />

    <%-- La cascara -tarjetas, chips, datos, vacios, botones- es la misma del
         centro de la orden de trabajo y se reusa tal cual. Aca va solo lo
         propio del centro del activo. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-orden.css?vrs=1") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-activo360.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* El listado suelto de Activos ya no esta en el menu: el alta vive
           aca, en el mismo modal que usa la edicion. */
        function abrirActivo(query) {
            seccionPendiente = null;
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Activos/Activo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo activo' : 'Editar activo',
                width: 1060,
                initialHeight: 620
            });
        }

        /* Los componentes se crean y se editan aca: el listado suelto no
           esta en el menu, y salir del centro para agregar una pieza del
           equipo que se esta mirando es perder el lugar. */
        function abrirComponente(query) {
            seccionPendiente = 'componentes';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Componentes/ActivoComponente.aspx") %>?query=' + query,
                title: query === queryNuevoComponente ? 'Nuevo componente' : 'Editar componente',
                width: 1040,
                initialHeight: 620
            });
        }

        function abrirVariable(query) {
            seccionPendiente = 'condicion';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Variables/ActivoVariable.aspx") %>?query=' + query,
                title: query === queryNuevaVariable ? 'Nueva variable de condición' : 'Editar variable',
                width: 940,
                initialHeight: 600
            });
        }

        function abrirMedidor(query) {
            seccionPendiente = 'condicion';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Medidores/ActivoMedidor.aspx") %>?query=' + query,
                title: query === queryNuevoMedidor ? 'Nuevo contador' : 'Editar contador',
                width: 920,
                initialHeight: 560
            });
        }

        /* Registrar una lectura a mano. `query` lo cifra el servidor: el de
           la tarjeta trae la variable o el contador ya elegido; el del boton
           de arriba trae solo el equipo. */
        function abrirLectura(query) {
            seccionPendiente = 'condicion';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Ficha/RegistrarLectura.aspx") %>?query=' + (query || queryLecturaSuelta),
                title: 'Registrar lectura',
                width: 860,
                initialHeight: 560
            });
        }

        /* Un cliente que parte con SIGMA llega con su catalogo en una
           planilla: doscientos equipos de a uno son doscientos modales. */
        function abrirCargaMasiva() {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Ficha/CargaMasivaActivos.aspx") %>',
                title: 'Carga masiva de activos',
                width: 1080,
                initialHeight: 640
            });
        }

        var seccionPendiente = null;

        /* El campo donde vive el equipo elegido. El JS de la lista lo escribe
           y hace postback: el centro se arma en el servidor. */
        window.sgCampoActivo = '<%=IdCampoActivo %>';

        /* Los ids nunca viajan a la vista: el activo va DENTRO del
           querystring cifrado que arma el servidor. */
        var queryNuevoComponente = '<%=QueryNuevoComponente %>';
        var queryNuevoMedidor = '<%=QueryNuevoMedidor %>';
        var queryNuevaVariable = '<%=QueryNuevaVariable %>';

        /* El querystring de la lectura tambien lo cifra el servidor. */
        var queryLecturaSuelta = '<%=QueryLectura %>';

        /* Al cerrar un modal se vuelve a la seccion desde donde se abrio, no
           al Resumen: el postback repinta el bloque entero. */
        function refresh() {
            var h = document.getElementById('hdnSeccion');
            if (h && seccionPendiente) h.value = seccionPendiente;
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
        }
    </script>

    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-activo360.js") %>?vrs=1'></script>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-orden.js") %>?vrs=1'></script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Activos</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server"><asp:Literal ID="litTitulo" runat="server" Text="Centro de activos 360°" /></asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" Text="Historial, mantenimiento y condición de tus equipos." />
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboArea" style="display:block; margin:0 0 4px;">Área:</label>
                    <rad:RadComboBox2 ID="cboArea" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboLinea" style="display:block; margin:0 0 4px;">Línea:</label>
                    <rad:RadComboBox2 ID="cboLinea" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboHabilitado" style="display:block; margin:0 0 4px;">Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para consultar sus activos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:HiddenField ID="hdnActivo" runat="server" Value="0" />

            <%-- La seccion abierta viaja en un campo oculto: un postback
                 asincrono repinta el bloque entero y sin esto siempre volveria
                 al Resumen. --%>
            <asp:HiddenField ID="hdnSeccion" runat="server" Value="resumen" ClientIDMode="Static" />
            <asp:LinkButton ID="lnkRecargar" runat="server" style="display:none" CausesValidation="false" />

            <%-- ====== LA LISTA DE EQUIPOS ====== --%>
            <asp:Panel ID="pnlLista" runat="server" Visible="false" CssClass="sg-a3 sg-ot sg-lista">

                <asp:Literal ID="litListaKpis" runat="server" />

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-cog-outline"></i></span>
                        <div>
                            <h3>Activos</h3>
                            <p class="sg-ot-card-sub">Toque un activo para abrir su centro.</p>
                        </div>
                        <div class="sg-ot-card-acc sg-lista-acc">
                            <asp:LinkButton ID="lnkExportarLista" runat="server" CssClass="sg-ot-btn es-accion"
                                OnClick="lnkExportarLista_Click"><i class="mdi mdi-download-outline"></i>Exportar</asp:LinkButton>
                            <asp:LinkButton ID="lnkCargaMasiva" runat="server" CssClass="sg-ot-btn es-accion"
                                OnClientClick="return abrirCargaMasiva();"><i class="mdi mdi-upload-outline"></i>Carga masiva</asp:LinkButton>
                            <asp:LinkButton ID="lnkNuevoActivo" runat="server" CssClass="sg-ot-btn es-primario"
                                OnClientClick="return abrirActivo(0);"><i class="mdi mdi-plus"></i>Nuevo activo</asp:LinkButton>
                        </div>
                    </header>

                    <div class="sg-ot-ev-filtros">
                        <div class="sg-ot-ev-tipos" id="sgListaChips">
                            <a href="#" class="sg-a3-chip es-activa" data-lista="todos">Todos <b><asp:Literal ID="litListaTodos" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-lista="atencion"><i class="mdi mdi-alert-outline"></i>Requieren atención <b><asp:Literal ID="litListaAtencion" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-lista="ot"><i class="mdi mdi-wrench-outline"></i>Con OT abiertas <b><asp:Literal ID="litListaOt" runat="server" Text="0" /></b></a>
                        </div>
                        <select id="sgListaPorPagina" class="sg-ot-select">
                            <option value="10">10 por página</option>
                            <option value="25" selected="selected">25 por página</option>
                            <option value="50">50 por página</option>
                            <option value="0">Todos</option>
                        </select>
                    </div>

                    <asp:Literal ID="litLista" runat="server" />

                    <div class="sg-lista-pie">
                        <span id="sgListaConteo" class="sg-ot-vacio-txt"></span>
                        <div class="sg-lista-paginas" id="sgListaPaginas"></div>
                    </div>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlSinActivo" runat="server" Visible="false" CssClass="sg-ot-vacio">
                <i class="mdi mdi-magnify"></i>
                <p>No hay equipos que coincidan</p>
                <span>Ajuste la búsqueda o la ubicación.</span>
            </asp:Panel>

            <%-- ====================================================================
                 EL CENTRO
                 ==================================================================== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sg-a3 sg-ot">

                <div class="sg-a3-miga">
                    <asp:LinkButton ID="lnkVolverLista" runat="server" OnClick="btnVolver_Click" CausesValidation="false">Activos</asp:LinkButton>
                    <span class="sep">/</span>Centro del activo
                </div>

                <header class="sg-a3-hero">
                    <div class="sg-a3-hero-txt">
                        <h1>
                            <asp:Literal ID="litHeroNombre" runat="server" />
                            <asp:Literal ID="litBadges" runat="server" />
                        </h1>
                        <div class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></div>
                    </div>

                    <div class="sg-a3-hero-acc">
                        <asp:HyperLink ID="hlGenerarOT" runat="server" CssClass="sg-ot-btn es-primario">
                            <i class="mdi mdi-plus"></i>Nueva OT
                        </asp:HyperLink>
                        <asp:HyperLink ID="hlEditar" runat="server" CssClass="sg-ot-btn es-plano" NavigateUrl="javascript:void(0)"
                            ToolTip="Editar la ficha del activo"><i class="mdi mdi-pencil-outline"></i></asp:HyperLink>
                    </div>
                </header>

                <%-- ---------------- navegacion: cuatro a la vista, el resto en Mas -------- --%>
                <nav class="sg-a3-nav">
                    <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-home-outline"></i>Resumen</a>
                    <a href="#" class="sg-a3-tab" data-sec="ficha"><i class="mdi mdi-file-document-outline"></i>Ficha</a>
                    <a href="#" class="sg-a3-tab" data-sec="historial"><i class="mdi mdi-clock-outline"></i>Historial</a>
                    <a href="#" class="sg-a3-tab" data-sec="ordenes"><i class="mdi mdi-clipboard-text-outline"></i>Órdenes de trabajo</a>
                    <a href="#" class="sg-a3-tab" data-sec="mantenimiento"><i class="mdi mdi-wrench-outline"></i>Mantenimiento</a>
                    <a href="#" class="sg-a3-tab" data-sec="inspecciones"><i class="mdi mdi-clipboard-check-outline"></i>Inspecciones y tareas</a>

                    <div class="sg-a3-mas">
                        <a href="#" class="sg-a3-tab sg-a3-mas-btn"><i class="mdi mdi-dots-horizontal"></i>Más<span class="sg-a3-mas-nombre" id="sgA3MasNombre"></span><i class="mdi mdi-chevron-down"></i></a>

                        <div class="sg-a3-mas-menu">
                            <a href="#" class="sg-a3-mas-op" data-sec="componentes"><i class="mdi mdi-puzzle-outline"></i>Componentes</a>
                            <a href="#" class="sg-a3-mas-op" data-sec="fallas"><i class="mdi mdi-alert-outline"></i>Fallas e indisponibilidad</a>
                            <a href="#" class="sg-a3-mas-op" data-sec="condicion"><i class="mdi mdi-gauge"></i>Condición y medidores</a>
                            <a href="#" class="sg-a3-mas-op" data-sec="documentos"><i class="mdi mdi-image-multiple-outline"></i>Documentos y galería</a>
                            <a href="#" class="sg-a3-mas-op" data-sec="repuestos"><i class="mdi mdi-package-variant-closed"></i>Repuestos y costos</a>
                            <a href="#" class="sg-a3-mas-op" data-sec="bitacora"><i class="mdi mdi-notebook-outline"></i>Bitácora y trazabilidad</a>
                        </div>
                    </div>

                    <%-- SIGMA AI va aparte y no dentro de Mas: es lo unico de esta
                         pantalla que no afirma hechos, sino que propone revisar. --%>
                    <a href="#" class="sg-a3-tab es-ia" data-sec="ia"><span class="sg-ai-ico" role="img" aria-label="" style="background-image:url('<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-symbol-gradient.svg") %>')"></span>SIGMA AI</a>
                </nav>

                <%-- ================================================================
                     1. RESUMEN
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="resumen">
                    <asp:Literal ID="litKpis" runat="server" />

                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-alerta"><i class="mdi mdi-alert-outline"></i></span>
                                    <div>
                                        <h3>Requiere atención</h3>
                                        <p class="sg-ot-card-sub">Lo abierto sobre este equipo, con acceso a su registro.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litAtencion" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-clock-outline"></i></span>
                                    <div>
                                        <h3>Actividad reciente</h3>
                                        <p class="sg-ot-card-sub">Lo último que se registró sobre el equipo.</p>
                                    </div>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="historial">Ver todo el historial <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litActividad" runat="server" />
                            </div>
                        </div>

                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-factory"></i></span>
                                    <h3>Identidad del activo</h3>
                                </header>
                                <asp:Literal ID="litIdentidad" runat="server" />
                                <div class="sg-ot-card-pie">
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="ficha"><i class="mdi mdi-file-document-outline"></i>Ver ficha técnica</a>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="documentos"><i class="mdi mdi-image-multiple-outline"></i>Galería</a>
                                </div>
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <%-- La marca de SIGMA AI es su simbolo, no una estrellita
                                         de la fuente de iconos: es lo unico de esta pantalla
                                         que no lo escribio una persona. --%>
                                    <img class="sg-ai-badge" src="<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-badge-light.svg") %>" alt="SIGMA AI" />
                                    <h3>SIGMA AI</h3>
                                </header>
                                <asp:Literal ID="litIA" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     2. HISTORIAL
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="historial">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-timeline-text-outline"></i></span>
                            <div>
                                <h3>Historial del activo</h3>
                                <p class="sg-ot-card-sub">Cambios de estado, de posición y mediciones, en orden.</p>
                            </div>
                            <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sg-ot-btn es-plano sg-ot-card-acc" OnClick="lnkExportar_Click">
                                <i class="mdi mdi-download"></i>Exportar
                            </asp:LinkButton>
                        </header>

                        <div class="sigma-modal-grid">
                            <div class="sigma-modal-field is-chico">
                                <label>Tipo de evento</label>
                                <rad:RadComboBox2 ID="cboTipo" runat="server" Width="100%" AutoPostBack="true" OnSelectedIndexChanged="btnBuscar_Click">
                                    <Items>
                                        <rad:RadComboBoxItem Text="Todos los tipos" Value="" />
                                        <rad:RadComboBoxItem Text="Cambios de estado" Value="ESTADO" />
                                        <rad:RadComboBoxItem Text="Cambios de posición" Value="POSICION" />
                                        <rad:RadComboBoxItem Text="Mediciones" Value="MEDICION" />
                                    </Items>
                                </rad:RadComboBox2>
                            </div>
                            <div class="sigma-modal-field is-chico">
                                <label>Desde</label>
                                <div class="sigma-modal-fecha"><WebControls:Calendar ID="calDesde" runat="server" /></div>
                            </div>
                            <div class="sigma-modal-field is-chico">
                                <label>Hasta</label>
                                <div class="sigma-modal-fecha"><WebControls:Calendar ID="calHasta" runat="server" /></div>
                            </div>
                        </div>

                        <div class="sg-ot-card-pie">
                            <WebControls:PushButton ID="btnBuscar" runat="server" Text="Filtrar" CssClass="sg-ot-btn es-plano" OnClick="btnBuscar_Click" />
                        </div>

                        <asp:Panel ID="pnlSinEventos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                            <i class="mdi mdi-timeline-text-outline"></i>
                            <p>Sin eventos en el período</p>
                            <span>Cambie el filtro o el rango de fechas.</span>
                        </asp:Panel>

                        <asp:Literal ID="litHistorial" runat="server" />
                    </div>
                </section>

                <%-- ================================================================
                     3. ÓRDENES DE TRABAJO
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="ordenes">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-clipboard-text-outline"></i></span>
                            <div>
                                <h3>Órdenes de trabajo del activo</h3>
                                <p class="sg-ot-card-sub">Todas las intervenciones, con acceso a su detalle y cierre.</p>
                            </div>
                            <asp:Literal ID="litOtConteos" runat="server" />
                        </header>

                        <asp:Literal ID="litOrdenes" runat="server" />

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>Toque una fila para ver su trabajo, repuestos, evidencias y cierre sin salir de acá.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     4. MANTENIMIENTO
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-mant" data-panel="mantenimiento">
                    <div class="sg-mant-cols">
                        <div class="sg-mant-centro">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-text-outline"></i></span>
                                    <div>
                                        <h3>Planes que lo cubren</h3>
                                        <p class="sg-ot-card-sub">Los planes de mantenimiento donde este equipo está incluido.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litPlanes" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-clock"></i></span>
                                    <div>
                                        <h3>Próximas actividades</h3>
                                        <p class="sg-ot-card-sub">Ocurrencias planificadas del plan de mantenimiento.</p>
                                    </div>
                                    <asp:Literal ID="litOcurrenciasConteo" runat="server" />
                                </header>
                                <asp:Literal ID="litOcurrencias" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-checkbox-marked-circle-outline"></i></span>
                                    <div>
                                        <h3>Tareas recurrentes</h3>
                                        <p class="sg-ot-card-sub">Rondas y revisiones que se repiten sobre el equipo.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litTareas" runat="server" />
                            </div>
                        </div>

                        <aside class="sg-mant-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-month-outline"></i></span>
                                    <div>
                                        <h3>Agenda de mantenimiento</h3>
                                        <p class="sg-ot-card-sub">Próximas actividades y OT vinculadas.</p>
                                    </div>
                                </header>

                                <%-- El calendario se arma en el servidor con los
                                     dias que TIENEN algo: pintar un mes vacio
                                     es pedirle a alguien que recorra treinta
                                     casillas para descubrir que no hay nada. --%>
                                <asp:Literal ID="litAgenda" runat="server" />

                                <div class="sg-mant-dia" id="sgMantDia"></div>
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-target"></i></span>
                                    <div><h3>Cómo se lee</h3></div>
                                </header>
                                <p class="sg-ot-texto">Una <strong>ocurrencia programada</strong> es una cita del plan: existe aunque nadie la haya tomado todavía. La <strong>orden de trabajo</strong> es el trabajo real, y aparece cuando alguien la genera desde esa cita.</p>
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     2. FICHA  ·  el activo se edita aca, sin salir del centro
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-ficha" data-panel="ficha">
                    <header class="sg-a3-ficha-cab">
                        <h2>Ficha del activo</h2>
                        <asp:Literal ID="litFichaModo" runat="server" />
                    </header>

                    <%-- Es el MISMO formulario del modal de alta: un control, no
                         una copia. Lo unico que cambia es donde van Guardar y
                         Cancelar. --%>
                    <wuc:ActivoForm runat="server" ID="frmFicha" EnCentro="true" OnGuardado="frmFicha_Guardado" />
                </section>

                <%-- ================================================================
                     6. COMPONENTES
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-comp" data-panel="componentes">
                    <div class="sg-comp-cols">

                        <%-- La estructura a la izquierda: de que esta hecho el
                             equipo. Es lo primero que alguien busca cuando le
                             dicen "fallo el reductor". --%>
                        <aside class="sg-ot-card sg-comp-arbol">
                            <header class="sg-ot-card-cab">
                                <span class="sg-ot-card-ico"><i class="mdi mdi-file-tree-outline"></i></span>
                                <div><h3>Estructura del equipo</h3></div>
                            </header>
                            <asp:Literal ID="litArbol" runat="server" />
                        </aside>

                        <div class="sg-comp-centro">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-puzzle-outline"></i></span>
                                    <div>
                                        <h3><asp:Literal ID="litCompTitulo" runat="server" Text="Componentes del equipo" /></h3>
                                        <p class="sg-ot-card-sub">Componentes instalados, retirados y su historial de reemplazos.</p>
                                    </div>
                                    <asp:LinkButton ID="lnkNuevoComponente" runat="server" CssClass="sg-ot-btn es-accion sg-ot-card-acc"
                                        OnClientClick="return abrirComponente(queryNuevoComponente);"><i class="mdi mdi-plus"></i>Asociar componente</asp:LinkButton>
                                </header>

                                <div class="sg-ot-ev-filtros">
                                    <div class="sg-ot-ev-tipos" id="sgCompTipos">
                                        <a href="#" class="sg-a3-chip es-activa" data-comp-estado="instalados">Instalados <b><asp:Literal ID="litCompInstalados" runat="server" Text="0" /></b></a>
                                        <a href="#" class="sg-a3-chip" data-comp-estado="retirados">Retirados <b><asp:Literal ID="litCompRetirados" runat="server" Text="0" /></b></a>
                                    </div>
                                    <div class="sg-ot-ev-buscar">
                                        <i class="mdi mdi-magnify"></i>
                                        <input type="search" id="sgCompBuscar" placeholder="Buscar por código o descripción..." autocomplete="off" />
                                    </div>
                                </div>

                                <asp:Literal ID="litComponentes" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-history"></i></span>
                                    <div>
                                        <h3>Historial de reemplazos</h3>
                                        <p class="sg-ot-card-sub">Repuestos que se cambiaron en este equipo, con la orden que los consumió.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litReemplazos" runat="server" />
                            </div>
                        </div>

                        <%-- El detalle se llena en el navegador con lo que ya
                             viene en la fila: pedir el componente al servidor
                             para mostrar lo que ya esta en pantalla es un viaje
                             de mas. --%>
                        <aside class="sg-ot-card sg-comp-detalle" id="sgCompDetalle">
                            <header class="sg-ot-card-cab">
                                <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                                <div><h3>Detalles del componente</h3></div>
                            </header>
                            <div class="sg-comp-detalle-cuerpo">
                                <p class="sg-ot-vacio-txt">Elija un componente de la lista para ver su detalle.</p>
                            </div>
                        </aside>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Los componentes retirados conservan su fecha de instalación: es lo que permite saber cuánto duró la pieza anterior.</span>
                    </div>
                </section>

                <%-- ================================================================
                     7. FALLAS E INDISPONIBILIDAD
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-fallas" data-panel="fallas">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande es-rojo"><i class="mdi mdi-alert-outline"></i></span>
                            <div>
                                <h3>Fallas e indisponibilidad</h3>
                                <p class="sg-ot-card-sub">Lo que se reportó del equipo y los períodos en que estuvo detenido.</p>
                            </div>
                            <asp:Literal ID="litEstadoAhora" runat="server" />
                        </header>

                        <%-- Una falla es lo que le pasa al equipo; una detencion
                             es el tiempo que costo. Se cuentan distinto y se
                             miran en momentos distintos. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgFallaVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-falla-vista="fallas"><i class="mdi mdi-alert-outline"></i>Fallas <b><asp:Literal ID="litFallasN" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-falla-vista="detenciones"><i class="mdi mdi-clock-alert-outline"></i>Detenciones <b><asp:Literal ID="litDetencionesN" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-cond-vista" data-falla-vista="fallas">
                            <div class="sg-ot-ev-filtros">
                                <div class="sg-ot-ev-tipos" id="sgFallaEstados">
                                    <a href="#" class="sg-a3-chip es-activa" data-falla-estado="todas">Todas</a>
                                    <a href="#" class="sg-a3-chip" data-falla-estado="abierta">Abiertas <b><asp:Literal ID="litFallasAbiertas" runat="server" Text="0" /></b></a>
                                    <a href="#" class="sg-a3-chip" data-falla-estado="resuelta">Resueltas</a>
                                </div>
                                <div class="sg-ot-ev-buscar">
                                    <i class="mdi mdi-magnify"></i>
                                    <input type="search" id="sgFallaBuscar" placeholder="Buscar falla por descripción o síntoma..." autocomplete="off" />
                                </div>
                            </div>

                            <asp:Literal ID="litFallas" runat="server" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-falla-vista="detenciones">
                            <div class="sg-falla-total">
                                <asp:Literal ID="litDetencionTotal" runat="server" />
                            </div>

                            <asp:Literal ID="litIndisponibilidad" runat="server" />

                            <div class="sg-ot-nota es-chica">
                                <i class="mdi mdi-information-outline"></i>
                                <span>Una detención planificada es tiempo que se decidió gastar; una no planificada es tiempo que se perdió. El indicador de disponibilidad los cuenta distinto.</span>
                            </div>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     8. CONDICIÓN Y MEDIDORES
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-cond-panel" data-panel="condicion">
                    <div class="sg-ot-card">

                        <%-- La cabecera trae las cuatro cosas que se hacen aca:
                             buscar, filtrar por estado, configurar que se mide
                             y registrar una lectura. --%>
                        <header class="sg-ot-card-cab sg-cond-top">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-pulse"></i></span>
                            <div>
                                <h3>Condición y medidores</h3>
                                <p class="sg-ot-card-sub"><asp:Literal ID="litCondActivo" runat="server" /></p>
                            </div>

                            <div class="sg-cond-acciones">
                                <div class="sg-ot-ev-buscar sg-cond-buscar">
                                    <i class="mdi mdi-magnify"></i>
                                    <input type="search" id="sgCondBuscar" placeholder="Buscar variable o contador..." autocomplete="off" />
                                </div>

                                <select id="sgCondEstado" class="sg-ot-select">
                                    <option value="">Estado: Todos</option>
                                    <option value="es-critico">Fuera de límite</option>
                                    <option value="es-aviso">Revisar</option>
                                    <option value="es-normal">En rango</option>
                                    <option value="es-sin">Sin lectura</option>
                                </select>

                                <asp:LinkButton ID="lnkNuevaVariable" runat="server" CssClass="sg-ot-btn es-plano"
                                    OnClientClick="return abrirVariable(queryNuevaVariable);"><i class="mdi mdi-cog-outline"></i>Configurar</asp:LinkButton>
                                <asp:LinkButton ID="lnkNuevoMedidor" runat="server" CssClass="sg-ot-btn es-plano"
                                    OnClientClick="return abrirMedidor(queryNuevoMedidor);"><i class="mdi mdi-counter"></i>Nuevo contador</asp:LinkButton>
                                <asp:LinkButton ID="lnkRegistrarLectura" runat="server" CssClass="sg-ot-btn es-primario"
                                    OnClientClick="return abrirLectura('');"><i class="mdi mdi-plus"></i>Registrar lectura</asp:LinkButton>
                            </div>
                        </header>

                        <%-- La banda dice cuantas piden atencion ANTES de la
                             grilla: con doce tarjetas, la que esta fuera de
                             limite se pierde entre las que estan bien. --%>
                        <asp:Literal ID="litCondAviso" runat="server" />

                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgCondVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-cond-vista="todas">Todas <b><asp:Literal ID="litCondTodas" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-cond-vista="variables"><i class="mdi mdi-pulse"></i>Variables <b><asp:Literal ID="litCondVariables" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-cond-vista="medidores"><i class="mdi mdi-counter"></i>Contadores <b><asp:Literal ID="litCondMedidores" runat="server" Text="0" /></b></a>
                        </div>

                        <section class="sg-cond-seccion" data-cond-grupo="variables">
                            <h4>Variables de condición <b><asp:Literal ID="litCondVariables2" runat="server" Text="0" /></b></h4>
                            <p>Cómo está el equipo según la última lectura.</p>
                            <div class="sg-cond-grid"><asp:Literal ID="litCondicion" runat="server" /></div>
                        </section>

                        <section class="sg-cond-seccion" data-cond-grupo="medidores">
                            <h4>Contadores acumulativos <b><asp:Literal ID="litCondMedidores2" runat="server" Text="0" /></b></h4>
                            <p>Cuánto ha trabajado o consumido el equipo.</p>
                            <div class="sg-cond-grid"><asp:Literal ID="litMedidores" runat="server" /></div>
                        </section>

                        <p class="sg-cond-nada" id="sgCondNada" style="display:none">Ninguna variable o contador coincide con la búsqueda.</p>

                        <%-- El historial y las acciones de la tarjeta elegida se
                             despliegan DEBAJO de su fila, no en una columna al
                             costado: asi la tarjeta no se mueve al abrirse. --%>
                        <div class="sg-cond-detalle" id="sgCondDetalle" style="display:none"></div>

                        <%-- Las lecturas viajan escondidas y el navegador las
                             mueve al detalle: pedirlas de a una obligaria a un
                             postback por tarjeta. --%>
                        <div class="sg-cond-fuente" id="sgCondFuente" style="display:none"><asp:Literal ID="litCondLecturas" runat="server" /></div>

                        <div class="sg-a3-umbrales">
                            <i class="mdi mdi-information-outline"></i>
                            Los rangos se configuran por equipo en su variable. No son límites de operación: valídelos con mantención antes de usarlos para decidir.
                        </div>
                    </div>
                </section>

<%-- ================================================================
                     9. DOCUMENTOS Y GALERÍA
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-docs" data-panel="documentos">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-image-multiple-outline"></i></span>
                            <div>
                                <h3>Documentos y galería</h3>
                                <p class="sg-ot-card-sub">Documentos técnicos, fotografías y lo que el terreno adjuntó.</p>
                            </div>
                            <asp:Literal ID="litDocConteos" runat="server" />
                        </header>

                        <%-- Tres vistas por lo que SON, no por su extension: un
                             manual y la foto de una correa rota son dos cosas
                             distintas aunque las dos sean archivos. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgDocChips">
                            <a href="#" class="sg-a3-chip es-activa" data-doc="todos">Todos <b><asp:Literal ID="litEvTodas" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-doc="documento"><i class="mdi mdi-file-document-outline"></i>Documentos <b><asp:Literal ID="litEvDocs" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-doc="fotografia"><i class="mdi mdi-camera-outline"></i>Fotografías <b><asp:Literal ID="litEvFotos" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-doc="evidencia"><i class="mdi mdi-cellphone-link"></i>Evidencias <b><asp:Literal ID="litEvEvidencias" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-ot-ev-filtros">
                            <div class="sg-ot-ev-buscar">
                                <i class="mdi mdi-magnify"></i>
                                <input type="search" id="sgDocBuscar" placeholder="Buscar archivo, origen o persona..." autocomplete="off" />
                            </div>
                            <select id="sgDocOrigen" class="sg-ot-select"><option value="">Todos los orígenes</option></select>
                        </div>

                        <div class="sg-ot-ev-cols">
                            <div class="sg-ot-ev-grid" id="sgOtEvGrid">
                                <asp:Literal ID="litArchivos" runat="server" />
                            </div>

                            <%-- El detalle del archivo elegido. Se llena en el
                                 navegador con lo que ya trae la tarjeta. --%>
                            <aside class="sg-ot-ev-detalle" id="sgOtEvDetalle"></aside>
                        </div>

                        <asp:Panel ID="pnlSinArchivos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                            <i class="mdi mdi-image-off-outline"></i>
                            <p>Sin documentos ni fotografías</p>
                            <span>Se adjuntan desde la ficha del activo o llegan con las evidencias de la app.</span>
                        </asp:Panel>

                        <div class="sg-cond-bloque">
                            <h4><i class="mdi mdi-format-list-bulleted"></i>Lista de archivos</h4>
                            <asp:Literal ID="litDocTabla" runat="server" />
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     10. INSPECCIONES Y TAREAS
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="inspecciones">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-clipboard-check-outline"></i></span>
                            <div>
                                <h3>Inspecciones y tareas</h3>
                                <p class="sg-ot-card-sub">Lo que se pasó a revisar en este equipo: pautas de inspección y tareas.</p>
                            </div>
                            <asp:Literal ID="litRevConteos" runat="server" />
                        </header>

                        <div class="sg-ot-ev-filtros">
                            <div class="sg-ot-ev-tipos" id="sgA3RevTipos">
                                <a href="#" class="sg-a3-chip es-activa" data-rev-tipo="todas">Todas <b><asp:Literal ID="litRevTodas" runat="server" Text="0" /></b></a>
                                <a href="#" class="sg-a3-chip" data-rev-tipo="INSPECCION"><i class="mdi mdi-clipboard-text-outline"></i>Inspecciones <b><asp:Literal ID="litRevInsp" runat="server" Text="0" /></b></a>
                                <a href="#" class="sg-a3-chip" data-rev-tipo="TAREA"><i class="mdi mdi-checkbox-marked-circle-outline"></i>Tareas <b><asp:Literal ID="litRevTareas" runat="server" Text="0" /></b></a>
                            </div>
                            <div class="sg-ot-ev-buscar">
                                <i class="mdi mdi-magnify"></i>
                                <input type="search" id="sgA3RevBuscar" placeholder="Buscar inspección o tarea..." autocomplete="off" />
                            </div>
                            <select id="sgA3RevResultado" class="sg-ot-select">
                                <option value="">Todos los resultados</option>
                                <option value="CONFORME">Sin observaciones</option>
                                <option value="CON_OBSERVACION">Con observación</option>
                                <option value="SIN_EVALUAR">Sin evaluar</option>
                            </select>
                        </div>

                        <asp:Literal ID="litRevisiones" runat="server" />

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>El <strong>estado</strong> dice el avance de la inspección o tarea. El <strong>resultado</strong> refleja la evaluación del técnico: una revisión puede estar completada y con hallazgos.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     11. REPUESTOS Y COSTOS
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="repuestos">
                    <asp:Literal ID="litCostoKpis" runat="server" />

                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-package-variant-closed"></i></span>
                            <div>
                                <h3>Materiales consumidos en el equipo</h3>
                                <p class="sg-ot-card-sub">Repuestos e insumos usados en las intervenciones de este activo.</p>
                            </div>
                            <asp:Literal ID="litConsumoConteos" runat="server" />
                        </header>

                        <asp:Literal ID="litConsumos" runat="server" />
                    </div>

                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico"><i class="mdi mdi-shape-outline"></i></span>
                            <div>
                                <h3>Repuestos compatibles</h3>
                                <p class="sg-ot-card-sub">Lo que este equipo puede llevar, aunque todavía no se le haya puesto.</p>
                            </div>
                        </header>

                        <asp:Literal ID="litCompatibles" runat="server" />
                    </div>
                </section>

                <%-- ================================================================
                     12. SIGMA AI
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="ia">
                    <asp:Literal ID="litIaPanel" runat="server" />
                </section>

                <%-- ================================================================
                     13. BITÁCORA Y TRAZABILIDAD
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="bitacora">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-notebook-outline"></i></span>
                                    <div>
                                        <h3>Bitácora del activo</h3>
                                        <p class="sg-ot-card-sub">Lo que la gente anotó del equipo, del registro más nuevo al más viejo.</p>
                                    </div>
                                    <asp:Literal ID="litBitConteos" runat="server" />
                                </header>

                                <asp:Literal ID="litBitacora" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-comment-text-outline"></i></span>
                                    <div>
                                        <h3>Agregar observación</h3>
                                        <p class="sg-ot-card-sub">Queda registrada a tu nombre y con la hora del servidor.</p>
                                    </div>
                                </header>

                                <div class="sg-a3-obs">
                                    <asp:TextBox ID="txtObservacion" runat="server" TextMode="MultiLine" Rows="3"
                                        CssClass="sg-ot-textarea" placeholder="Escribe una observación sobre el activo..." />
                                    <div class="sg-a3-obs-acc">
                                        <asp:LinkButton ID="lnkPublicar" runat="server" CssClass="sg-ot-btn es-primario"
                                            OnClick="lnkPublicar_Click"><i class="mdi mdi-send-outline"></i>Publicar</asp:LinkButton>
                                    </div>
                                </div>

                                <asp:Literal ID="litObsAviso" runat="server" />
                            </div>
                        </div>

                        <div class="sg-a3-col es-angosta">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-shield-check-outline"></i></span>
                                    <div>
                                        <h3>Trazabilidad de estado</h3>
                                        <p class="sg-ot-card-sub">Cada cambio de estado del equipo, con quién y por qué.</p>
                                    </div>
                                </header>

                                <asp:Literal ID="litTrazabilidad" runat="server" />
                            </div>
                        </div>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Los registros de bitácora no se editan. Una corrección entra como un registro nuevo: la trazabilidad se pierde el día que alguien puede arreglar lo que escribió ayer.</span>
                    </div>
                </section>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
