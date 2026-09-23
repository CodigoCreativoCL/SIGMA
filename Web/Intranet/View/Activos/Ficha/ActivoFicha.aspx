<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoFicha.aspx.cs" Inherits="View_Activos_Ficha_ActivoFicha" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

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

        var seccionPendiente = null;

        /* Los ids nunca viajan a la vista: el activo va DENTRO del
           querystring cifrado que arma el servidor. */
        var queryNuevoComponente = '<%=QueryNuevoComponente %>';

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
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Centro del activo</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Toda la vida de un equipo en una sola pantalla: lo que se le hizo, lo que se le va a hacer y lo que se midió.
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

            <%-- ====== LISTA DE RESULTADOS (clic para abrir el centro) ====== --%>
            <asp:Panel ID="pnlLista" runat="server" Visible="false" CssClass="sigma-af-lista" style="margin-top:14px;">
                <%-- La clase sg-ot trae las variables de color de la hoja del centro:
                     fuera de ella el boton queda con texto blanco sobre nada. --%>
                <div class="sg-ot sg-a3-lista-acc">
                    <asp:LinkButton ID="lnkNuevoActivo" runat="server" CssClass="sg-ot-btn es-primario"
                        OnClientClick="return abrirActivo(0);"><i class="mdi mdi-plus"></i>Nuevo activo</asp:LinkButton>
                </div>
                <rad:RadGrid2 ID="gridResultados" runat="server" OnItemDataBound="gridResultados_ItemDataBound">
                    <MasterTableView DataKeyNames="act_id" />
                </rad:RadGrid2>
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
                        <asp:HyperLink ID="hlEscanear" runat="server" CssClass="sg-ot-btn es-plano">
                            <i class="mdi mdi-qrcode-scan"></i>Escanear QR
                        </asp:HyperLink>
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
                    <a href="#" class="sg-a3-tab" data-sec="historial"><i class="mdi mdi-clock-outline"></i>Historial</a>
                    <a href="#" class="sg-a3-tab" data-sec="ordenes"><i class="mdi mdi-clipboard-text-outline"></i>Órdenes de trabajo</a>
                    <a href="#" class="sg-a3-tab" data-sec="mantenimiento"><i class="mdi mdi-wrench-outline"></i>Mantenimiento</a>
                    <a href="#" class="sg-a3-tab" data-sec="inspecciones"><i class="mdi mdi-clipboard-check-outline"></i>Inspecciones y tareas</a>

                    <div class="sg-a3-mas">
                        <a href="#" class="sg-a3-tab sg-a3-mas-btn"><i class="mdi mdi-dots-horizontal"></i>Más<span class="sg-a3-mas-nombre" id="sgA3MasNombre"></span><i class="mdi mdi-chevron-down"></i></a>

                        <div class="sg-a3-mas-menu">
                            <a href="#" class="sg-a3-mas-op" data-sec="ficha"><i class="mdi mdi-file-document-outline"></i>Ficha técnica</a>
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
                    <a href="#" class="sg-a3-tab es-ia" data-sec="ia"><i class="mdi mdi-star-four-points-outline"></i>SIGMA AI</a>
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
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-star-four-points-outline"></i></span>
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
                <section class="sg-a3-panel" data-panel="mantenimiento">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
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
                                        <h3>Próximas mantenciones</h3>
                                        <p class="sg-ot-card-sub">Lo que el plan tiene programado para este equipo.</p>
                                    </div>
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

                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                                    <h3>Cómo se lee</h3>
                                </header>
                                <p class="sg-ot-texto">Una <strong>ocurrencia programada</strong> es una cita del plan: existe aunque nadie la haya tomado todavía. La <strong>orden de trabajo</strong> es el trabajo real, y aparece cuando alguien la genera desde esa cita.</p>
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     5. FICHA TÉCNICA
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="ficha">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-file-document-outline"></i></span>
                                    <div>
                                        <h3>Ficha técnica</h3>
                                        <p class="sg-ot-card-sub">Identificación, ubicación y gestión del equipo.</p>
                                    </div>
                                    <asp:HyperLink ID="hlEditarFicha" runat="server" CssClass="sg-ot-btn es-plano sg-ot-card-acc" NavigateUrl="javascript:void(0)">
                                        <i class="mdi mdi-pencil-outline"></i>Editar ficha
                                    </asp:HyperLink>
                                </header>
                                <asp:Literal ID="litFichaTecnica" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-tune-variant"></i></span>
                                    <div>
                                        <h3>Atributos técnicos</h3>
                                        <p class="sg-ot-card-sub">Los campos que definen su tipo de equipo.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litAtributos" runat="server" />
                            </div>
                        </div>

                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <asp:Literal ID="litFotoFicha" runat="server" />
                                <asp:Literal ID="litQr" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     6. COMPONENTES
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="componentes">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-puzzle-outline"></i></span>
                            <div>
                                <h3>Componentes del equipo</h3>
                                <p class="sg-ot-card-sub">Las partes instaladas, su estado y desde cuándo están.</p>
                            </div>
                            <asp:LinkButton ID="lnkNuevoComponente" runat="server" CssClass="sg-ot-btn es-primario sg-ot-card-acc"
                                OnClientClick="return abrirComponente(queryNuevoComponente);"><i class="mdi mdi-plus"></i>Nuevo componente</asp:LinkButton>
                        </header>
                        <asp:Literal ID="litComponentes" runat="server" />
                    </div>
                </section>

                <%-- ================================================================
                     7. FALLAS E INDISPONIBILIDAD
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="fallas">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-alerta"><i class="mdi mdi-alert-outline"></i></span>
                                    <div>
                                        <h3>Fallas</h3>
                                        <p class="sg-ot-card-sub">Lo que se reportó del equipo y en qué quedó.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litFallas" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-power-plug-off-outline"></i></span>
                                    <div>
                                        <h3>Indisponibilidad</h3>
                                        <p class="sg-ot-card-sub">Los períodos en que el equipo estuvo detenido.</p>
                                    </div>
                                    <asp:Literal ID="litDetencionTotal" runat="server" />
                                </header>
                                <asp:Literal ID="litIndisponibilidad" runat="server" />
                            </div>
                        </div>

                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                                    <h3>Estado ahora</h3>
                                </header>
                                <asp:Literal ID="litEstadoAhora" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     8. CONDICIÓN Y MEDIDORES
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="condicion">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-gauge"></i></span>
                            <div>
                                <h3>Variables de condición</h3>
                                <p class="sg-ot-card-sub">Lo que se mide del equipo: valor, cuándo se tomó y contra qué se compara.</p>
                            </div>
                        </header>

                        <asp:Literal ID="litCondicion" runat="server" />

                        <div class="sg-a3-umbrales">
                            <i class="mdi mdi-information-outline"></i>
                            Los rangos se configuran por equipo en su variable. No son límites de operación: valídelos con mantención antes de usarlos para decidir.
                        </div>
                    </div>

                    <div class="sg-ot-card" style="margin-top:16px;">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico"><i class="mdi mdi-counter"></i></span>
                            <div>
                                <h3>Contadores acumulativos</h3>
                                <p class="sg-ot-card-sub">Horómetros y cuentakilómetros: no bajan, se acumulan.</p>
                            </div>
                            <asp:HyperLink ID="hlMedidores" runat="server" CssClass="sg-ot-btn es-plano sg-ot-card-acc">
                                <i class="mdi mdi-cog-outline"></i>Gestionar
                            </asp:HyperLink>
                        </header>
                        <asp:Literal ID="litMedidores" runat="server" />
                    </div>
                </section>

                <%-- ================================================================
                     9. DOCUMENTOS Y GALERÍA
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="documentos">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-image-multiple-outline"></i></span>
                            <div>
                                <h3>Documentos y galería</h3>
                                <p class="sg-ot-card-sub">Manuales, certificados y fotografías del equipo.</p>
                            </div>
                            <asp:Literal ID="litDocConteos" runat="server" />
                        </header>

                        <div class="sg-ot-ev-filtros">
                            <div class="sg-ot-ev-tipos">
                                <a href="#" class="sg-ot-ev-chip es-activa" data-tipo="todas">Todas <b><asp:Literal ID="litEvTodas" runat="server" Text="0" /></b></a>
                                <a href="#" class="sg-ot-ev-chip" data-tipo="imagen"><i class="mdi mdi-camera-outline"></i>Fotografías <b><asp:Literal ID="litEvFotos" runat="server" Text="0" /></b></a>
                                <a href="#" class="sg-ot-ev-chip" data-tipo="documento"><i class="mdi mdi-file-outline"></i>Documentos <b><asp:Literal ID="litEvDocs" runat="server" Text="0" /></b></a>
                            </div>
                            <div class="sg-ot-ev-buscar">
                                <i class="mdi mdi-magnify"></i>
                                <input type="search" id="sgOtEvBuscar" placeholder="Buscar archivo..." autocomplete="off" />
                            </div>
                            <select id="sgOtEvPaso" class="sg-ot-select"><option value="">Todos los orígenes</option></select>
                        </div>

                        <div class="sg-ot-ev-cols">
                            <div class="sg-ot-ev-grid" id="sgOtEvGrid">
                                <asp:Literal ID="litArchivos" runat="server" />
                            </div>
                            <aside class="sg-ot-ev-detalle" id="sgOtEvDetalle"></aside>
                        </div>

                        <asp:Panel ID="pnlSinArchivos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                            <i class="mdi mdi-image-off-outline"></i>
                            <p>Sin documentos ni fotografías</p>
                            <span>Se adjuntan desde la ficha del activo o llegan con las evidencias de la app.</span>
                        </asp:Panel>
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
