<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoFicha.aspx.cs" Inherits="View_Activos_Ficha_ActivoFicha" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>
<%@ Register TagPrefix="wuc" TagName="ActivoForm" Src="~/View/Activos/Activos/ActivoForm.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />

    <%-- La cascara -tarjetas, chips, datos, vacios, botones- es la misma del
         centro de la orden de trabajo y se reusa tal cual. Aca va solo lo
         propio del centro del activo. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
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

        /* Retirar necesita saber CUAL pieza: la elegida en la lista. Sin una
           elegida, el boton no abre un modal vacio, lo dice. */
        function retirarComponente() {
            var fila = document.querySelector('.sg-comp.es-elegida[data-comp-query]')
                    || document.querySelector('.sg-comp[data-comp-query]');

            if (!fila) {
                alert('Primero elija el componente que va a retirar.');
                return false;
            }

            return abrirComponente(fila.getAttribute('data-comp-query'));
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

    <%-- La version sale de la fecha del archivo: con `?vrs=1` fijo, el
         navegador se quedaba con la copia vieja y las correcciones se
         publicaban sin llegar. --%>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-activo360.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-orden.js") %>'></script>
</asp:Content>

<%-- El rotulo dice el modulo, no la pantalla: el titulo ya dice cual es. --%>
<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Control de activos</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server"><asp:Literal ID="litTitulo" runat="server" Text="Centro de activos 360°" /></asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" Text="Historial, mantenimiento y condición de tus equipos." />
</asp:Content>

<%-- LA BUSQUEDA AVANZADA DEL SITIO NO SIRVE EN EL CENTRO

     El `wucFiltro` del encabezado trae un cuadro de texto que busca contra
     SEL_ACTIVO. Aca eso no hace nada visible: la lista ya se filtra en el
     navegador con su propio buscador, y una vez abierto un activo el centro
     no es una lista, asi que escribir "ot-20" arriba y apretar Buscar no
     cambiaba una sola fila.

     Los combos de planta, area y linea SI filtraban de verdad, y por eso no
     se borraron: bajaron a la barra de la lista, donde estan las cosas que
     afectan a lo que se ve. Siguen siendo de servidor -con postback- porque
     "Exportar" entrega lo que el filtro dejo, y para eso el servidor tiene
     que saber cual es. --%>

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

                    <%-- PLANTA, AREA Y LINEA NO HACEN FALTA

                         El buscador de la lista ya compara contra la
                         ubicacion -"Renca · Linea 1" viaja en el texto de
                         cada fila-, asi que escribir "renca" hace lo mismo
                         que la cascada de tres combos, sin tres postbacks ni
                         la regla de que el hijo se vacia cuando cambia el
                         padre.

                         Queda solo "Habilitado", que es el unico que muestra
                         algo que de otra forma no se puede ver: un activo
                         dado de baja no aparece escrito en ninguna parte. --%>
                    <div class="sg-a3-filtros">
                        <%-- El buscador de la lista.

                             No existia: lo que buscaba era el cuadro de la
                             busqueda avanzada del encabezado, que pegaba
                             contra el servidor. Al sacarlo, la lista se
                             quedaba sin ninguna forma de buscar, asi que
                             entra aca y compara contra el texto que cada fila
                             ya trae -codigo, nombre, tipo y ubicacion-. --%>
                        <span class="sg-a3-filtro-buscar">
                            <i class="mdi mdi-magnify"></i>
                            <input type="search" id="sgListaBuscar" autocomplete="off"
                                placeholder="Buscar por código, nombre, tipo o ubicación..." />
                        </span>

                        <label class="sg-a3-filtro"><i class="mdi mdi-check-circle-outline"></i>
                            <span>Estado del registro</span>
                            <rad:RadComboBox2 ID="cboHabilitado" runat="server" AutoPostBack="true" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Solo habilitados" Value="1" />
                                    <rad:RadComboBoxItem Text="Todos" Value="" />
                                    <rad:RadComboBoxItem Text="Solo dados de baja" Value="0" />
                                </Items>
                            </rad:RadComboBox2>
                        </label>
                    </div>

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

                <%-- La miga usa los nombres del menu: el modulo es "Control de
                     activos" y la pantalla de vuelta es "Activos". Dejarla con
                     los nombres viejos obliga a traducir mentalmente donde
                     esta uno. --%>
                <div class="sg-a3-miga">
                    <span>Control de activos</span>
                    <span class="sep">/</span>
                    <asp:LinkButton ID="lnkVolverLista" runat="server" OnClick="btnVolver_Click" CausesValidation="false">Activos</asp:LinkButton>
                    <span class="sep">/</span><asp:Literal ID="litMigaActivo" runat="server" />
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
                                    <%-- La tarjeta muestra los primeros: sin salida,
                                         el resto queda escondido sin decirlo. --%>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="ordenes">Ver todas <i class="mdi mdi-arrow-right"></i></a>
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

                            <%-- QUIEN RESPONDE POR EL EQUIPO Y CUANDO SE TOCO

                                 La ficha dice como es el equipo; esto dice de
                                 quien es y si el dato esta fresco. Una ficha
                                 sin fecha de actualizacion se lee como si
                                 estuviera al dia, y puede llevar dos años
                                 sin que nadie la mire. --%>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-account-group-outline"></i></span>
                                    <h3>Contexto del equipo</h3>
                                </header>
                                <asp:Literal ID="litContexto" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- ================================================================
                     2. HISTORIAL
                     ================================================================ --%>
                <section class="sg-a3-panel sg-a3-hist" data-panel="historial">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-timeline-text-outline"></i></span>
                                    <div>
                                        <h3>Todo lo que ha ocurrido en este activo</h3>
                                        <p class="sg-ot-card-sub">Órdenes, inspecciones, fallas, repuestos, lecturas y cambios, en una sola línea de tiempo.</p>
                                    </div>
                                    <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sg-ot-btn es-plano sg-ot-card-acc" OnClick="lnkExportar_Click">
                                        <i class="mdi mdi-download"></i>Exportar
                                    </asp:LinkButton>
                                </header>

                                <%-- La barra y la linea de tiempo las arma el
                                     servidor: los filtros salen de lo que hay,
                                     no de un catalogo fijo. --%>
                                <asp:Literal ID="litHistorial" runat="server" />

                                <asp:Panel ID="pnlSinEventos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                                    <i class="mdi mdi-timeline-text-outline"></i>
                                    <p>Sin eventos registrados</p>
                                    <span>Este equipo todavía no tiene historia que mostrar.</span>
                                </asp:Panel>
                            </div>
                        </div>

                        <%-- EL EVENTO ELEGIDO

                             La linea de tiempo responde "que paso y cuando";
                             este panel responde "que fue exactamente eso", sin
                             salir a la pantalla de origen y perder el lugar en
                             la linea. Se llena en el navegador con lo que ya
                             trae cada evento. --%>
                        <div class="sg-a3-col es-angosta">
                            <aside class="sg-hist-detalle" id="sgHistDetalle">
                                <div class="sg-ot-card">
                                    <header class="sg-ot-card-cab">
                                        <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                                        <div><h3>Evento seleccionado</h3></div>
                                    </header>
                                    <p class="sg-ot-vacio-txt">Toque un evento de la línea para ver su detalle.</p>
                                </div>
                            </aside>
                        </div>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Cada evento conserva el vínculo a su registro de origen.</span>
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

                            <%-- QUE CUBRE EL MANTENIMIENTO

                                 "Preventivo de hornos v1" no dice si entra el
                                 quemador. Quien firma una parada necesita
                                 saber que se va a tocar y que queda fuera. --%>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-target"></i></span>
                                    <div>
                                        <h3>Alcance del mantenimiento</h3>
                                        <p class="sg-ot-card-sub">Componentes y actividades que cubre el plan.</p>
                                    </div>
                                </header>
                                <asp:Literal ID="litAlcance" runat="server" />
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

                                    <%-- RETIRAR ES CAMBIAR SU ESTADO, NO BORRARLO

                                         La ficha del componente ya pide el motivo y
                                         deja la huella en su historial; este boton
                                         lleva ahi con la pieza elegida en vez de
                                         inventar un segundo camino para lo mismo. --%>
                                    <asp:LinkButton ID="lnkRetirarComponente" runat="server" CssClass="sg-ot-btn es-accion sg-ot-card-acc"
                                        OnClientClick="return retirarComponente();"><i class="mdi mdi-archive-arrow-down-outline"></i>Registrar retiro</asp:LinkButton>
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

                            <%-- Fecha y tipo: con cuarenta archivos, "el
                                 informe de la semana pasada" se encuentra por
                                 cuando llego, no leyendo cuarenta nombres. --%>
                            <select id="sgDocFecha" class="sg-ot-select">
                                <option value="">Cualquier fecha</option>
                                <option value="7">Últimos 7 días</option>
                                <option value="30">Últimos 30 días</option>
                                <option value="90">Últimos 90 días</option>
                                <option value="365">Último año</option>
                            </select>

                            <select id="sgDocTipo" class="sg-ot-select">
                                <option value="">Todos los tipos</option>
                                <option value="imagen">Imágenes</option>
                                <option value="video">Videos</option>
                                <option value="audio">Audios</option>
                                <option value="documento">Documentos</option>
                            </select>
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
                <section class="sg-a3-panel sg-a3-rep-panel" data-panel="repuestos">
                    <asp:Literal ID="litCostoKpis" runat="server" />

                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-package-variant-closed"></i></span>
                            <div>
                                <h3>Repuestos y costos</h3>
                                <p class="sg-ot-card-sub">Gestión de materiales, devoluciones y costos asociados al activo.</p>
                            </div>
                            <asp:Literal ID="litConsumoConteos" runat="server" />
                        </header>

                        <%-- CONSUMOS, DEVOLUCIONES Y COSTOS NO SON LA MISMA LISTA

                             Lo consumido dice que se gasto; lo devuelto dice
                             que se pidio de mas y volvio a bodega -que no es
                             gasto y no puede sumarse igual-; y los costos
                             agrupan por orden, que es como se aprueba el
                             presupuesto. Mezclarlas obliga a leer una columna
                             para saber que se esta mirando. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgRepVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-rep-vista="consumos"><i class="mdi mdi-package-variant-closed"></i>Consumos <b><asp:Literal ID="litRepConsumos" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-rep-vista="devoluciones"><i class="mdi mdi-undo-variant"></i>Devoluciones <b><asp:Literal ID="litRepDevoluciones" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-rep-vista="costos"><i class="mdi mdi-calculator-variant-outline"></i>Costos <b><asp:Literal ID="litRepOrdenes" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-cond-vista" data-rep-vista="consumos">
                            <asp:Literal ID="litConsumos" runat="server" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-rep-vista="devoluciones">
                            <asp:Literal ID="litDevoluciones" runat="server" />
                        </div>

                        <div class="sg-cond-vista es-oculta" data-rep-vista="costos">
                            <asp:Literal ID="litCostos" runat="server" />
                        </div>
                    </div>

                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico"><i class="mdi mdi-shape-outline"></i></span>
                            <div>
                                <h3>Repuestos compatibles</h3>
                                <p class="sg-ot-card-sub">Lo que este equipo puede llevar, con lo que hay en bodega ahora.</p>
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
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-notebook-outline"></i></span>
                            <div>
                                <h3>Bitácora y trazabilidad</h3>
                                <p class="sg-ot-card-sub">Registro cronológico de lo que se anotó del equipo y de cada cambio auditable.</p>
                            </div>
                            <asp:Literal ID="litBitConteos" runat="server" />
                        </header>

                        <%-- LA BITACORA Y LA AUDITORIA NO SON LO MISMO

                             La bitacora la escribe una persona: "el equipo
                             suena raro". La auditoria la escribe el sistema:
                             "la criticidad paso de media a alta". Una se
                             corrige agregando otra nota; la otra no se corrige
                             nunca, y por eso van separadas. --%>
                        <div class="sg-ot-ev-tipos sg-cond-vistas" id="sgBitVistas">
                            <a href="#" class="sg-a3-chip es-activa" data-bit-vista="bitacora"><i class="mdi mdi-note-text-outline"></i>Bitácora <b><asp:Literal ID="litBitRegistros" runat="server" Text="0" /></b></a>
                            <a href="#" class="sg-a3-chip" data-bit-vista="auditoria"><i class="mdi mdi-shield-check-outline"></i>Auditoría <b><asp:Literal ID="litBitCambios" runat="server" Text="0" /></b></a>
                        </div>

                        <div class="sg-cond-vista" data-bit-vista="bitacora">
                            <asp:Literal ID="litBitacora" runat="server" />

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

                        <div class="sg-cond-vista es-oculta" data-bit-vista="auditoria">
                            <asp:Literal ID="litTrazabilidad" runat="server" />
                        </div>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Los registros de auditoría no son editables. Las correcciones se registran como nuevos eventos en la bitácora.</span>
                    </div>
                </section>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
