<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Tarea.aspx.cs" Inherits="View_Mantenimiento_Tareas_Tarea" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />

    <%-- La cascara -cabecera, pestañas, tarjetas, chips, tablas- es la misma
         del centro de la orden de trabajo y se reusa tal cual, con sus clases
         sg-ot-*. Copiarla con otro nombre serian doscientas lineas que se
         separan a la primera correccion que se haga en una sola de las dos. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-orden.css?vrs=1") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-tarea.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <%-- El cambio de pestaña y los filtros del navegador tambien son los
         mismos: sigma-orden.js busca por clase, asi que funciona igual aca. --%>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-orden.js") %>?vrs=1'></script>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-tarea.js") %>?vrs=1'></script>

    <script type="text/javascript">
        var queryNuevaProgramacion = '<%=QueryNuevaProgramacion %>';

        function abrirTareaProgramacion(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Tareas/TareaProgramacion.aspx") %>?query=' + query,
                title: query === queryNuevaProgramacion ? 'Programar tarea' : 'Programación de la tarea',
                width: 860,
                initialHeight: 520
            });
        }

        /* El modal avisa que guardo llamando a refresh(): se repinta el panel
           sin recargar la pagina. */
        function refresh() { __doPostBack('<%=lnkRefrescar.UniqueID %>', ''); }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server"><asp:Literal ID="litTitulo" runat="server" Text="Tareas recurrentes" /></asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server"><asp:Literal ID="litSubtitulo" runat="server" /></asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sg-ot sg-ta">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <asp:HiddenField ID="hdnTab" runat="server" Value="configuracion" ClientIDMode="Static" />
    <asp:HiddenField ID="hdnNueva" runat="server" Value="0" ClientIDMode="Static" />

    <%-- El modal de programacion vuelve por aca: un LinkButton escondido que
         solo sirve para repintar. --%>
    <asp:LinkButton ID="lnkRefrescar" runat="server" style="display:none" OnClick="lnkRefrescar_Click" CausesValidation="false" />

    <%-- =====================================================================
         CABECERA
         ===================================================================== --%>
    <header class="sg-ot-cab">
        <span class="sg-ot-icono"><i class="mdi mdi-checkbox-marked-circle-outline"></i></span>

        <div class="sg-ot-cab-txt">
            <span class="sg-ot-num"><asp:Literal ID="litCodigo" runat="server" Text="Nueva" /></span>
            <h2 class="sg-ot-cab-titulo"><asp:Literal ID="litCabTitulo" runat="server" Text="Tarea recurrente" /></h2>
            <div class="sg-ot-cab-sub"><asp:Literal ID="litCabSub" runat="server" /></div>
        </div>

        <div class="sg-ot-chips"><asp:Literal ID="litChips" runat="server" /></div>

        <div class="sg-ot-cab-acc">
            <WebControls:PushButton ID="btnVolver" runat="server" Text="Volver a tareas" CssClass="sg-ot-btn es-plano"
                OnClick="btnVolver_Click" CausesValidation="false" />
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar cambios" CssClass="sg-ot-btn es-primario"
                OnClick="btnGuardar_Click" ValidationGroup="Tarea" />
        </div>
    </header>

    <nav class="sg-ot-tabs" role="tablist">
        <a href="#" class="sg-ot-tab" data-tab="configuracion"><i class="mdi mdi-cog-outline"></i>Configuración</a>
        <a href="#" class="sg-ot-tab" data-tab="ocurrencias"><i class="mdi mdi-calendar-month-outline"></i>Ocurrencias</a>
        <a href="#" class="sg-ot-tab" data-tab="evidencias"><i class="mdi mdi-image-multiple-outline"></i>Evidencias</a>
        <a href="#" class="sg-ot-tab" data-tab="comentarios"><i class="mdi mdi-comment-text-outline"></i>Comentarios</a>
    </nav>

    <%-- =====================================================================
         1. CONFIGURACIÓN
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="configuracion">
        <div class="sg-ot-cols">
            <div class="sg-ot-col">

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-clipboard-text-outline"></i></span>
                        <div>
                            <h3>Qué se debe hacer</h3>
                            <p class="sg-ot-card-sub">La actividad, su prioridad y las instrucciones para el técnico.</p>
                        </div>
                        <span class="sg-ot-obligatorios"><b class="sg-req">*</b> Campos obligatorios</span>
                    </header>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico">
                            <label>Código <b class="sg-req">*</b></label>
                            <div class="sg-codigo">
                                <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="90" UpperCase="true" />
                            </div>
                            <span class="sigma-modal-ayuda">Vacío: se numera solo. Único dentro del cliente.</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Título de la tarea <b class="sg-req">*</b></label>
                            <WebControls:TextBox2 ID="txtTitulo" runat="server" MaxLength="400" />
                            <asp:CustomValidator ID="cvTitulo" runat="server" ControlToValidate="txtTitulo"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Tarea" />
                            <span class="sigma-modal-ayuda">Lo que se hace, en imperativo: «Revisar nivel de aceite del reductor».</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Prioridad <b class="sg-req">*</b></label>
                            <rad:RadComboBox2 ID="cboPrioridad" runat="server" Width="100%" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Duración estimada (min) <b class="sg-req">*</b></label>
                            <div class="sg-ta-min">
                                <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="6" />
                                <span class="sg-ta-min-suf">min</span>
                            </div>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>¿Requiere evidencia?</label>
                            <label class="sg-ta-toggle">
                                <asp:CheckBox ID="chkEvidencia" runat="server" />
                                <span class="sg-ta-toggle-txt"><asp:Literal ID="litEvidencia" runat="server" Text="No" /></span>
                            </label>
                            <span class="sigma-modal-ayuda">Con Sí, el técnico debe adjuntar una foto al ejecutarla.</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Estado de la tarea</label>
                            <label class="sg-ta-toggle">
                                <asp:CheckBox ID="chkHabilitada" runat="server" Checked="true" />
                                <span class="sg-ta-toggle-txt"><asp:Literal ID="litHabilitada" runat="server" Text="Activa" /></span>
                            </label>
                            <span class="sigma-modal-ayuda">Una tarea apagada deja de generar ocurrencias nuevas.</span>
                        </div>
                        <div class="sigma-modal-field is-ancho">
                            <label>Descripción / Instrucciones</label>
                            <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="2000" />
                            <span class="sigma-modal-ayuda">Lo que se hace, en imperativo. Es lo que lee el técnico en el teléfono.</span>
                        </div>
                    </div>
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-map-marker-outline"></i></span>
                        <div>
                            <h3>Dónde se realiza</h3>
                            <p class="sg-ot-card-sub">La planta, el área y el equipo donde se ejecuta la tarea.</p>
                        </div>
                    </header>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico">
                            <label>Planta</label>
                            <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                                OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">Acota el área y el equipo. Vacío: cualquier planta.</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Área</label>
                            <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="100%" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Equipo (opcional)</label>
                            <rad:RadComboBox2 ID="cboActivo" runat="server" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">La tarea puede ser de un lugar y no de una máquina.</span>
                        </div>
                    </div>
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-clock"></i></span>
                        <div>
                            <h3>Cuándo y quién</h3>
                            <p class="sg-ot-card-sub">Las programaciones que generan las ocurrencias, sin salir de la tarea.</p>
                        </div>
                        <asp:LinkButton ID="lnkNuevaProgramacion" runat="server" CssClass="sg-ot-btn es-primario sg-ot-card-acc"
                            OnClientClick="return abrirTareaProgramacion(queryNuevaProgramacion);">
                            <i class="mdi mdi-plus"></i>Agregar programación
                        </asp:LinkButton>
                    </header>

                    <asp:Repeater ID="rptProgramaciones" runat="server" OnItemCommand="rptProgramaciones_ItemCommand">
                        <HeaderTemplate>
                            <div class="sg-ta-prog-cab">
                                <span>Frecuencia</span><span>Responsable</span><span>Grupo</span>
                                <span>Inicio</span><span>Estado</span><span></span>
                            </div>
                        </HeaderTemplate>
                        <ItemTemplate>
                            <div class="sg-ta-prog">
                                <span class="c-frec">
                                    <i class="mdi mdi-calendar-sync-outline"></i>
                                    <span><strong><%# Server.HtmlEncode(Convert.ToString(Eval("nombre"))) %></strong>
                                        <em><%# Server.HtmlEncode(Convert.ToString(Eval("tipo"))) %></em></span>
                                </span>
                                <span class="c-resp"><%# Eval("responsable") %></span>
                                <span class="c-grupo"><%# Eval("grupo") %></span>
                                <span class="c-inicio"><%# Eval("inicio") %></span>
                                <span class="c-estado"><%# Eval("estado") %></span>
                                <span class="c-acc">
                                    <asp:LinkButton ID="lnkEditarProg" runat="server" CssClass="sg-ot-link" CommandName="editar" CommandArgument='<%# Eval("id") %>'>
                                        <i class="mdi mdi-pencil-outline"></i>
                                    </asp:LinkButton>
                                    <asp:LinkButton ID="lnkQuitarProg" runat="server" CssClass="sg-ot-link es-quita" CommandName="quitar" CommandArgument='<%# Eval("id") %>'
                                        OnClientClick="return confirm('¿Quitar esta programación? La tarea deja de generar ocurrencias por ella.');">
                                        <i class="mdi mdi-trash-can-outline"></i>
                                    </asp:LinkButton>
                                </span>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                    <asp:Panel ID="pnlSinProgramaciones" runat="server" Visible="false" CssClass="sg-ot-vacio es-chico">
                        <i class="mdi mdi-calendar-blank-outline"></i>
                        <p>Sin programaciones</p>
                        <span>Mientras no haya una, la tarea no genera ocurrencias.</span>
                    </asp:Panel>

                    <div class="sg-ta-prog-pie">
                        <asp:LinkButton ID="lnkGenerarOcurrencias" runat="server" CssClass="sg-ot-link" OnClick="lnkGenerarOcurrencias_Click"
                            OnClientClick="return confirm('¿Generar las ocurrencias que falten para los próximos 90 días? Las que ya existen no se duplican.');">
                            <i class="mdi mdi-clock-outline"></i>Vista previa de ocurrencias · 90 días
                        </asp:LinkButton>
                    </div>
                </div>

                <wuc:Auditoria runat="server" ID="wucAuditoria" />
            </div>

            <%-- ---------------- columna derecha ---------------- --%>
            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-file-document-outline"></i></span>
                        <h3>Resumen de la tarea</h3>
                    </header>
                    <asp:Literal ID="litResumen" runat="server" />
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                        <h3>Información de la tarea</h3>
                    </header>
                    <asp:Literal ID="litInformacion" runat="server" />
                </div>
            </aside>
        </div>
    </section>

    <%-- =====================================================================
         2. OCURRENCIAS
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="ocurrencias">
        <div class="sg-ot-cols">
            <div class="sg-ot-col">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-month-outline"></i></span>
                        <div>
                            <h3>Historial y próximas ejecuciones</h3>
                            <p class="sg-ot-card-sub">Lo que la programación generó, lo que se hizo y lo que viene.</p>
                        </div>
                        <WebControls:PushButton ID="btnExportar" runat="server" Text="Exportar" CssClass="sg-ot-btn es-plano sg-ot-card-acc"
                            OnClick="btnExportar_Click" CausesValidation="false" />
                    </header>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico">
                            <label>Período</label>
                            <rad:RadComboBox2 ID="cboPeriodo" runat="server" Width="100%" AutoPostBack="true"
                                OnSelectedIndexChanged="Filtro_Changed" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Estado</label>
                            <rad:RadComboBox2 ID="cboEstado" runat="server" Width="100%" AutoPostBack="true"
                                OnSelectedIndexChanged="Filtro_Changed" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Responsable</label>
                            <rad:RadComboBox2 ID="cboResponsable" runat="server" Width="100%" AutoPostBack="true"
                                OnSelectedIndexChanged="Filtro_Changed" />
                        </div>
                    </div>

                    <%-- Los contadores son anclas: filtran en el navegador, que
                         para doce filas ya cargadas es instantaneo. --%>
                    <div class="sg-ta-conteos">
                        <a href="#" class="sg-ot-ev-chip es-activa" data-estado="todas">Todas <b><asp:Literal ID="litConteoTodas" runat="server" Text="0" /></b></a>
                        <a href="#" class="sg-ot-ev-chip" data-estado="completada"><span class="sg-ta-punto es-ok"></span>Completadas <b><asp:Literal ID="litConteoCompletadas" runat="server" Text="0" /></b></a>
                        <a href="#" class="sg-ot-ev-chip" data-estado="pendiente"><span class="sg-ta-punto es-pendiente"></span>Pendientes <b><asp:Literal ID="litConteoPendientes" runat="server" Text="0" /></b></a>
                        <a href="#" class="sg-ot-ev-chip" data-estado="futura"><span class="sg-ta-punto es-futura"></span>Futuras <b><asp:Literal ID="litConteoFuturas" runat="server" Text="0" /></b></a>
                    </div>

                    <div class="sg-ta-tabla" id="sgTaOcurrencias">
                        <div class="sg-ta-oc-cab">
                            <span>Fecha prevista</span><span>Responsable</span><span>Estado</span>
                            <span>Ejecución</span><span></span>
                        </div>

                        <asp:Repeater ID="rptOcurrencias" runat="server" OnItemCommand="rptOcurrencias_ItemCommand">
                            <ItemTemplate>
                                <div class='<%# "sg-ta-oc" + ((bool)Eval("elegida") ? " es-elegida" : "") %>' data-grupo='<%# Eval("grupo") %>'>
                                    <span class="c-fecha"><%# Eval("fecha") %></span>
                                    <span class="c-resp"><i class="mdi mdi-account-outline"></i><%# Server.HtmlEncode(Convert.ToString(Eval("responsable"))) %></span>
                                    <span class="c-estado"><%# Eval("estado") %></span>
                                    <span class="c-ejec"><%# Eval("ejecucion") %></span>
                                    <span class="c-acc">
                                        <asp:LinkButton ID="lnkVerOcurrencia" runat="server" CssClass="sg-ot-btn es-plano sg-ta-ver"
                                            CommandName="sel" CommandArgument='<%# Eval("id") %>'>
                                            <i class="mdi mdi-file-document-outline"></i>Ver detalle
                                        </asp:LinkButton>
                                    </span>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>

                        <asp:Panel ID="pnlSinOcurrencias" runat="server" Visible="false" CssClass="sg-ot-vacio">
                            <i class="mdi mdi-calendar-blank-outline"></i>
                            <p>Sin ocurrencias en el período</p>
                            <span>Cambie el período o genere las de los próximos 90 días.</span>
                        </asp:Panel>
                    </div>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Las ocurrencias se generan desde la programación de la tarea.</span>
                    </div>
                </div>
            </div>

            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <asp:Literal ID="litOcurrencia" runat="server" />
                </div>
            </aside>
        </div>
    </section>

    <%-- =====================================================================
         3. EVIDENCIAS

         La misma galeria de la orden de trabajo, con sus mismas clases e ids:
         asi el filtrado por tipo, la busqueda, el filtro por ocurrencia y el
         panel de detalle los resuelve sigma-orden.js sin una linea nueva.

         Los archivos vienen del Blob Storage: aca solo viajan la ruta y los
         datos; la imagen la pide el navegador a VerArchivo.aspx.
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="evidencias">
        <div class="sg-ot-card">
            <header class="sg-ot-card-cab">
                <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-image-multiple-outline"></i></span>
                <div>
                    <h3>Evidencias de la tarea</h3>
                    <p class="sg-ot-card-sub">Fotografías y archivos que el técnico envió desde la app al ejecutarla.</p>
                </div>
            </header>

            <div class="sg-ot-ev-filtros">
                <div class="sg-ot-ev-tipos">
                    <a href="#" class="sg-ot-ev-chip es-activa" data-tipo="todas">Todas <b><asp:Literal ID="litEvTodas" runat="server" Text="0" /></b></a>
                    <a href="#" class="sg-ot-ev-chip" data-tipo="imagen"><i class="mdi mdi-camera-outline"></i>Fotografías <b><asp:Literal ID="litEvFotos" runat="server" Text="0" /></b></a>
                    <a href="#" class="sg-ot-ev-chip" data-tipo="video"><i class="mdi mdi-video-outline"></i>Videos <b><asp:Literal ID="litEvVideos" runat="server" Text="0" /></b></a>
                    <a href="#" class="sg-ot-ev-chip" data-tipo="documento"><i class="mdi mdi-file-outline"></i>Archivos <b><asp:Literal ID="litEvArchivos" runat="server" Text="0" /></b></a>
                </div>
                <div class="sg-ot-ev-buscar">
                    <i class="mdi mdi-magnify"></i>
                    <input type="search" id="sgOtEvBuscar" placeholder="Buscar evidencia o descripción..." autocomplete="off" />
                </div>
                <select id="sgOtEvPaso" class="sg-ot-select"><option value="">Todas las ocurrencias</option></select>
            </div>

            <div class="sg-ot-ev-cols">
                <div class="sg-ot-ev-grid" id="sgOtEvGrid">
                    <asp:Literal ID="litEvidencias" runat="server" />
                </div>
                <aside class="sg-ot-ev-detalle" id="sgOtEvDetalle"></aside>
            </div>

            <asp:Panel ID="pnlSinEvidencias" runat="server" Visible="false" CssClass="sg-ot-vacio">
                <i class="mdi mdi-image-off-outline"></i>
                <p>Todavía no hay evidencias</p>
                <span>Aparecen acá en cuanto el técnico las envía desde la app.</span>
            </asp:Panel>
        </div>
    </section>

    <%-- =====================================================================
         3. COMENTARIOS
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="comentarios">
        <div class="sg-ot-cols">
            <div class="sg-ot-col">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-comment-text-multiple-outline"></i></span>
                        <div>
                            <h3>Conversaciones de la tarea</h3>
                            <p class="sg-ot-card-sub">Lo que se dijo en cada ejecución. Un comentario no se edita ni se borra: se responde.</p>
                        </div>
                    </header>

                    <div class="sg-ta-com-filtros">
                        <div class="sigma-modal-field is-chico">
                            <label>Ocurrencia</label>
                            <rad:RadComboBox2 ID="cboOcurrenciaComentario" runat="server" Width="100%" AutoPostBack="true"
                                OnSelectedIndexChanged="Filtro_Changed" />
                        </div>
                        <div class="sg-ot-ev-buscar">
                            <i class="mdi mdi-magnify"></i>
                            <input type="search" id="sgTaBuscarComentario" placeholder="Buscar en comentarios..." autocomplete="off" />
                        </div>
                    </div>

                    <div id="sgTaHilos"><asp:Literal ID="litHilos" runat="server" /></div>

                    <asp:Panel ID="pnlSinComentarios" runat="server" Visible="false" CssClass="sg-ot-vacio">
                        <i class="mdi mdi-comment-off-outline"></i>
                        <p>Todavía no hay comentarios</p>
                        <span>El técnico comenta desde el teléfono al ejecutar la tarea.</span>
                    </asp:Panel>

                    <asp:Panel ID="pnlResponder" runat="server" CssClass="sg-ta-responder">
                        <asp:HiddenField ID="hidOcurrencia" runat="server" ClientIDMode="Static" />
                        <asp:HiddenField ID="hidPadre" runat="server" ClientIDMode="Static" />

                        <div class="sg-ta-responder-cab">
                            <span id="sgTaRespondiendo"><asp:Literal ID="litRespondiendo" runat="server" /></span>
                            <a href="#" class="sg-ot-link" id="sgTaCancelarRespuesta"><i class="mdi mdi-close"></i>Cancelar respuesta</a>
                        </div>

                        <WebControls:TextArea2 ID="txtComentario" runat="server" MaxLength="4000" ClientIDMode="Static" />

                        <div class="sg-ta-responder-pie">
                            <%-- Dictar escribe en la caja con el reconocimiento de voz del
                                 navegador. Lo que se guarda es el texto, igual que si se
                                 hubiera escrito: no hay campo donde anotar que vino dictado
                                 -el SP de la web no lo recibe- y no se finge que lo hay. --%>
                            <a href="#" class="sg-ot-btn es-plano" id="sgTaDictar"><i class="mdi mdi-microphone-outline"></i>Dictar</a>
                            <WebControls:PushButton ID="btnComentar" runat="server" Text="Publicar respuesta" CssClass="sg-ot-btn es-primario"
                                OnClick="btnComentar_Click" CausesValidation="false" />
                        </div>
                    </asp:Panel>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>Los comentarios se conservan como registro. Para aclarar información, agregue una respuesta.</span>
                    </div>
                </div>
            </div>

            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <asp:Literal ID="litContextoComentario" runat="server" />
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-clipboard-text-outline"></i></span>
                        <h3>Instrucción de la tarea</h3>
                    </header>
                    <asp:Literal ID="litInstruccion" runat="server" />
                </div>
            </aside>
        </div>
    </section>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
