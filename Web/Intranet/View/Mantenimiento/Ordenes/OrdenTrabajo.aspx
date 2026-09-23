<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="OrdenTrabajo.aspx.cs" Inherits="View_Mantenimiento_Ordenes_OrdenTrabajo" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-orden.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-orden.js") %>?vrs=1'></script>
</asp:Content>

<%-- El master pinta el rubro, el titulo y la bajada de TODA pantalla. Esta
     tiene cabecera propia -numero, chips de estado y acciones-, asi que los
     tres van vacios en vez de repetir lo mismo dos veces. --%>
<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server"><asp:Literal ID="litTitulo" runat="server" Text="Orden de trabajo" /></asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server"><asp:Literal ID="litSubtitulo" runat="server" /></asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sg-ot">

    <%-- TODO el centro vive dentro de un UpdatePanel: guardar, asignar,
         registrar una detencion o cerrar la orden no recargan la pagina, y el
         cambio de pestaña ni siquiera llega al servidor (lo hace el JS). --%>
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <%-- La pestaña abierta viaja en un campo oculto: un postback asincrono
         repinta el bloque entero y sin esto siempre volveria al Resumen. --%>
    <%-- ClientIDMode estatico: sigma-orden.js es un archivo aparte y no
         puede saber el id largo que ASP.NET le pondria dentro del master. --%>
    <asp:HiddenField ID="hdnTab" runat="server" Value="resumen" ClientIDMode="Static" />
    <asp:HiddenField ID="hdnNueva" runat="server" Value="0" ClientIDMode="Static" />

    <%-- =====================================================================
         CABECERA
         ===================================================================== --%>
    <header class="sg-ot-cab">
        <span class="sg-ot-icono"><i class="mdi mdi-clipboard-text-outline"></i></span>

        <div class="sg-ot-cab-txt">
            <span class="sg-ot-num"><asp:Literal ID="litNumero" runat="server" Text="Nueva" /></span>
            <h2 class="sg-ot-cab-titulo"><asp:Literal ID="litCabTitulo" runat="server" Text="Orden de trabajo" /></h2>
            <div class="sg-ot-cab-sub"><asp:Literal ID="litCabSub" runat="server" /></div>
        </div>

        <div class="sg-ot-chips"><asp:Literal ID="litChips" runat="server" /></div>

        <div class="sg-ot-cab-acc">
            <WebControls:PushButton ID="btnVolver" runat="server" Text="Volver a órdenes" CssClass="sg-ot-btn es-plano"
                OnClick="btnVolver_Click" CausesValidation="false" />
            <a href="#" class="sg-ot-btn es-primario" data-ir="cierre"><i class="mdi mdi-check-decagram-outline"></i>Revisar cierre</a>
        </div>
    </header>

    <%-- =====================================================================
         PESTAÑAS. Son anclas y no LinkButtons a proposito: cambiar de
         pestaña es mirar otra parte de lo mismo, no pedirle nada al
         servidor. Todo el contenido ya esta en la pagina.
         ===================================================================== --%>
    <nav class="sg-ot-tabs" role="tablist">
        <a href="#" class="sg-ot-tab" data-tab="resumen"><i class="mdi mdi-view-dashboard-outline"></i>Resumen</a>
        <a href="#" class="sg-ot-tab" data-tab="ficha"><i class="mdi mdi-file-document-outline"></i>Ficha</a>
        <a href="#" class="sg-ot-tab" data-tab="asignacion"><i class="mdi mdi-account-group-outline"></i>Asignación</a>
        <a href="#" class="sg-ot-tab" data-tab="pasos"><i class="mdi mdi-format-list-numbered"></i>Pasos</a>
        <a href="#" class="sg-ot-tab" data-tab="evidencias"><i class="mdi mdi-image-multiple-outline"></i>Evidencias</a>
        <a href="#" class="sg-ot-tab" data-tab="indisponibilidad"><i class="mdi mdi-clock-outline"></i>Indisponibilidad</a>
        <a href="#" class="sg-ot-tab" data-tab="cierre"><i class="mdi mdi-shield-check-outline"></i>Cierre</a>
    </nav>

    <%-- =====================================================================
         1. RESUMEN — todo de lectura, asi que lo arma el servidor de una vez
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="resumen">
        <asp:Literal ID="litResumen" runat="server" />
    </section>

    <%-- =====================================================================
         2. FICHA
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="ficha">
        <div class="sg-ot-cols">
            <div class="sg-ot-col">

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-file-document-outline"></i></span>
                        <h3>Datos de la orden</h3>
                        <span class="sg-ot-obligatorios"><b>*</b> Campos obligatorios</span>
                    </header>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-ancho">
                            <label>Título <b class="sg-req">*</b></label>
                            <WebControls:TextBox2 ID="txtTitulo" runat="server" MaxLength="400" />
                            <asp:CustomValidator ID="cvTitulo" runat="server" ControlToValidate="txtTitulo" ValidateEmptyText="true"
                                ClientValidationFunction="validaControl" ValidationGroup="OT" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Tipo <b class="sg-req">*</b></label>
                            <rad:RadComboBox2 ID="cboTipo" runat="server" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Correctiva" Value="2" Selected="true" />
                                    <rad:RadComboBoxItem Text="Preventiva" Value="1" />
                                    <rad:RadComboBoxItem Text="Predictiva" Value="3" />
                                </Items>
                            </rad:RadComboBox2>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Estrategia <b class="sg-req">*</b></label>
                            <rad:RadComboBox2 ID="cboEstrategia" runat="server" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Rutinario" Value="1" Selected="true" />
                                    <rad:RadComboBoxItem Text="Programado" Value="2" />
                                    <rad:RadComboBoxItem Text="Emergencia" Value="3" />
                                    <rad:RadComboBoxItem Text="Inspección" Value="4" />
                                    <rad:RadComboBoxItem Text="Overhaul" Value="5" />
                                    <rad:RadComboBoxItem Text="Mejora" Value="6" />
                                </Items>
                            </rad:RadComboBox2>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Prioridad <b class="sg-req">*</b></label>
                            <rad:RadComboBox2 ID="cboPrioridad" runat="server" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Baja" Value="1" />
                                    <rad:RadComboBoxItem Text="Media" Value="2" Selected="true" />
                                    <rad:RadComboBoxItem Text="Alta" Value="3" />
                                    <rad:RadComboBoxItem Text="Crítica" Value="4" />
                                </Items>
                            </rad:RadComboBox2>
                        </div>
                        <div class="sigma-modal-field is-ancho">
                            <label>Descripción <b class="sg-req">*</b></label>
                            <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
                        </div>
                    </div>
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-map-marker-outline"></i></span>
                        <h3>Ubicación</h3>
                    </header>
                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico">
                            <label>Planta</label>
                            <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                                OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" Filter="Contains" Width="100%" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Equipo</label>
                            <rad:RadComboBox2 ID="cboActivo" runat="server" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">Una orden sobre un área sin equipo no cuenta en los indicadores por máquina.</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Área</label>
                            <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">Obligatoria si no hay equipo.</span>
                        </div>
                    </div>
                </div>

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-calendar-clock"></i></span>
                        <h3>Programación</h3>
                    </header>
                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico">
                            <label>Fecha programada</label>
                            <WebControls:TextBox2 ID="txtFechaProgramada" runat="server" MaxLength="16" />
                            <span class="sigma-modal-ayuda">dd-mm-aaaa hh:mm</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Duración estimada (min)</label>
                            <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="6" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Cuándo ocurrió</label>
                            <WebControls:TextBox2 ID="txtFechaOcurrencia" runat="server" MaxLength="16" />
                            <span class="sigma-modal-ayuda">Solo registro posterior.</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Requiere permiso</label>
                            <div class="sigma-modal-opciones sg-ot-si-no">
                                <asp:RadioButton ID="rdbPermisoSi" runat="server" Text="Sí" GroupName="Permiso" />
                                <asp:RadioButton ID="rdbPermisoNo" runat="server" Text="No" GroupName="Permiso" Checked="true" />
                            </div>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Registro posterior</label>
                            <div class="sigma-modal-opciones sg-ot-si-no">
                                <asp:RadioButton ID="rdbPosteriorSi" runat="server" Text="Sí" GroupName="Posterior" />
                                <asp:RadioButton ID="rdbPosteriorNo" runat="server" Text="No" GroupName="Posterior" Checked="true" />
                            </div>
                            <span class="sigma-modal-ayuda">El trabajo ya ocurrió y se anota después: se guardan las dos fechas.</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Notas</label>
                            <WebControls:TextArea2 ID="txtNotas" runat="server" MaxLength="4000" />
                            <span class="sigma-modal-ayuda">Información para el equipo técnico.</span>
                        </div>
                    </div>
                </div>

                <wuc:Auditoria runat="server" ID="wucAuditoria" />
            </div>

            <%-- ---- columna derecha: el contexto ---- --%>
            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                        <h3>Contexto</h3>
                    </header>
                    <asp:Literal ID="litContexto" runat="server" />
                </div>

                <div class="sg-ot-nota">
                    <i class="mdi mdi-information-outline"></i>
                    <span>Complete la información de la orden. Los campos marcados con <b class="sg-req">*</b> son obligatorios.</span>
                </div>

                <div class="sg-ot-lado-acc">
                    <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cancelar" CssClass="sg-ot-btn es-plano"
                        OnClick="btnCancelar_Click" CausesValidation="false" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar cambios" CssClass="sg-ot-btn es-primario"
                        OnClick="btnGuardar_Click" ValidationGroup="OT" />
                </div>
            </aside>
        </div>
    </section>

    <%-- =====================================================================
         3. ASIGNACIÓN
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="asignacion">
        <div class="sg-ot-cols">
            <div class="sg-ot-col">

                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-account-group-outline"></i></span>
                        <div>
                            <h3>Equipo de trabajo</h3>
                            <p class="sg-ot-card-sub">Un responsable principal y los apoyos que necesite la intervención.</p>
                        </div>
                        <a href="#" class="sg-ot-btn es-primario sg-ot-card-acc" data-foco="#sgOtNuevaAsignacion">
                            <i class="mdi mdi-account-plus-outline"></i>Asignar persona o empresa
                        </a>
                    </header>

                    <div class="sg-ot-sub-titulo">Responsable actual</div>
                    <asp:Literal ID="litResponsable" runat="server" />

                    <div class="sg-ot-sub-titulo">Apoyos</div>
                    <asp:Repeater ID="rptApoyos" runat="server" OnItemCommand="rptAsignaciones_ItemCommand">
                        <ItemTemplate>
                            <div class="sg-ot-persona">
                                <span class="sg-ot-avatar"><%# Eval("iniciales") %></span>
                                <div class="sg-ot-persona-txt">
                                    <span class="sg-ot-persona-nom"><%# Server.HtmlEncode(Convert.ToString(Eval("nombre"))) %></span>
                                    <span class="sg-ot-persona-meta"><%# Eval("meta") %></span>
                                </div>
                                <div class="sg-ot-persona-acc">
                                    <asp:LinkButton runat="server" CssClass="sg-ot-link" CommandName="responsable" CommandArgument='<%# Eval("id") %>'>
                                        <i class="mdi mdi-account-star-outline"></i>Hacer responsable
                                    </asp:LinkButton>
                                    <asp:LinkButton runat="server" CssClass="sg-ot-link es-quita" CommandName="quitar" CommandArgument='<%# Eval("id") %>'
                                        OnClientClick="return confirm('¿Quitar esta asignación?');">
                                        <i class="mdi mdi-trash-can-outline"></i>Quitar
                                    </asp:LinkButton>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                    <asp:Panel ID="pnlSinApoyos" runat="server" CssClass="sg-ot-vacio es-chico">
                        <i class="mdi mdi-account-group-outline"></i>
                        <p>Aún no hay apoyos asignados</p>
                        <span>Puede agregar técnicos para apoyar la intervención.</span>
                    </asp:Panel>
                </div>

                <asp:Panel ID="pnlNuevaAsignacion" runat="server" CssClass="sg-ot-card" ClientIDMode="Static">
                    <header class="sg-ot-card-cab" id="sgOtNuevaAsignacion">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-account-plus-outline"></i></span>
                        <h3>Nueva asignación</h3>
                        <div class="sigma-modal-opciones sg-ot-card-acc">
                            <asp:RadioButton ID="rdbQuienTecnico" runat="server" Text="Técnico" GroupName="Quien" Checked="true"
                                AutoPostBack="true" OnCheckedChanged="rdbQuien_CheckedChanged" />
                            <asp:RadioButton ID="rdbQuienEmpresa" runat="server" Text="Empresa externa" GroupName="Quien"
                                AutoPostBack="true" OnCheckedChanged="rdbQuien_CheckedChanged" />
                        </div>
                    </header>

                    <div class="sigma-modal-grid">
                        <asp:Panel ID="pnlTecnico" runat="server" CssClass="sigma-modal-field is-medio">
                            <label>Buscar técnico</label>
                            <rad:RadComboBox2 ID="cboUsuario" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">Arriba aparecen quienes tienen la especialidad que la orden exige.</span>
                        </asp:Panel>
                        <asp:Panel ID="pnlEmpresa" runat="server" CssClass="sigma-modal-field is-medio" Visible="false">
                            <label>Empresa externa</label>
                            <rad:RadComboBox2 ID="cboProveedor" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        </asp:Panel>
                        <div class="sigma-modal-field is-chico">
                            <label>Grupo</label>
                            <rad:RadComboBox2 ID="cboGrupo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Rol</label>
                            <rad:RadComboBox2 ID="cboRol" runat="server" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Apoyo" Value="0" Selected="true" />
                                    <rad:RadComboBoxItem Text="Responsable" Value="1" />
                                </Items>
                            </rad:RadComboBox2>
                            <span class="sigma-modal-ayuda">Solo puede haber un responsable: al nombrar otro, el anterior pasa a apoyo.</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Observación (opcional)</label>
                            <WebControls:TextBox2 ID="txtObservacion" runat="server" MaxLength="400" />
                        </div>
                    </div>

                    <div class="sg-ot-card-pie">
                        <WebControls:PushButton ID="btnAsignar" runat="server" Text="Asignar" CssClass="sg-ot-btn es-primario"
                            OnClick="btnAsignar_Click" CausesValidation="false" />
                    </div>
                </asp:Panel>
            </div>

            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-lightbulb-on-outline"></i></span>
                        <h3>Cómo se asigna</h3>
                    </header>
                    <p class="sg-ot-texto">Solo puede haber un responsable. Si elige otro, el anterior pasa a apoyo.</p>
                </div>
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span>
                        <h3>Información importante</h3>
                    </header>
                    <p class="sg-ot-texto">Si falta una especialidad, SIGMA lo advierte y permite continuar: quien asigna sabe lo que está haciendo, pero queda anotado.</p>
                </div>
            </aside>
        </div>
    </section>

    <%-- =====================================================================
         4. PASOS (lectura: se marcan desde la app)
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="pasos">
        <div class="sg-ot-card sg-ot-pasos-cab">
            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-format-list-numbered"></i></span>
            <div class="sg-ot-pasos-tit">
                <h3>Pasos de la intervención</h3>
                <p class="sg-ot-card-sub">Seguimiento del trabajo registrado en terreno.</p>
            </div>
            <span class="sg-ot-candado"><i class="mdi mdi-lock-outline"></i>Solo lectura · Se actualiza desde la app</span>
            <asp:Literal ID="litPasosAvance" runat="server" />
        </div>

        <div class="sg-ot-cols es-pasos">
            <div class="sg-ot-card sg-ot-pasos-lista">
                <asp:Repeater ID="rptPasos" runat="server" OnItemCommand="rptPasos_ItemCommand">
                    <ItemTemplate>
                        <asp:LinkButton runat="server" CssClass='<%# "sg-ot-paso" + ((bool)Eval("elegido") ? " es-elegido" : "") %>'
                            CommandName="sel" CommandArgument='<%# Eval("indice") %>'>
                            <span class='<%# "sg-ot-paso-num " + Eval("clase") %>'><%# Eval("numero") %></span>
                            <span class="sg-ot-paso-nom"><%# Server.HtmlEncode(Convert.ToString(Eval("nombre"))) %></span>
                            <span class='<%# "sg-ot-estado " + Eval("clase") %>'><i class='<%# "mdi " + Eval("icono") %>'></i><%# Eval("estado") %></span>
                            <i class="mdi mdi-chevron-right sg-ot-paso-flecha"></i>
                        </asp:LinkButton>
                    </ItemTemplate>
                </asp:Repeater>

                <asp:Panel ID="pnlSinPasos" runat="server" Visible="false" CssClass="sg-ot-vacio">
                    <i class="mdi mdi-format-list-numbered"></i>
                    <p>Esta orden todavía no tiene pasos</p>
                    <span>Nacen del plan o los agrega el técnico desde la app.</span>
                </asp:Panel>
            </div>

            <div class="sg-ot-card">
                <asp:Literal ID="litPasoDetalle" runat="server" />
            </div>
        </div>

        <div class="sg-ot-nota">
            <i class="mdi mdi-information-outline"></i>
            <span>Los pasos provienen del plan o son agregados por el técnico desde la app.</span>
        </div>
    </section>

    <%-- =====================================================================
         5. EVIDENCIAS

         Los filtros, la busqueda y el detalle son del navegador: las tarjetas
         ya estan en la pagina con lo suyo en atributos, asi que mirar otra
         evidencia no le cuesta nada al servidor.
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="evidencias">
        <div class="sg-ot-card">
            <header class="sg-ot-card-cab">
                <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-image-multiple-outline"></i></span>
                <div>
                    <h3>Evidencias de la intervención</h3>
                    <p class="sg-ot-card-sub">Fotografías, videos y archivos enviados desde la app.</p>
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
                <select id="sgOtEvPaso" class="sg-ot-select"><option value="">Todos los pasos</option></select>
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
         6. INDISPONIBILIDAD
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="indisponibilidad">
        <div class="sg-ot-cols es-tres">
            <div class="sg-ot-card">
                <header class="sg-ot-card-cab">
                    <span class="sg-ot-card-ico"><i class="mdi mdi-clock-outline"></i></span>
                    <div>
                        <h3>Indisponibilidad del equipo</h3>
                        <p class="sg-ot-card-sub">Los períodos de detención asociados a esta orden.</p>
                    </div>
                </header>
                <asp:Literal ID="litIndisponibilidad" runat="server" />
            </div>

            <asp:Panel ID="pnlFormIndisp" runat="server" CssClass="sg-ot-card">
                <header class="sg-ot-card-cab">
                    <span class="sg-ot-card-ico"><i class="mdi mdi-file-document-edit-outline"></i></span>
                    <div>
                        <h3>Registrar indisponibilidad</h3>
                        <p class="sg-ot-card-sub">El período en que el equipo estuvo detenido.</p>
                    </div>
                </header>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>Inicio <b class="sg-req">*</b></label>
                        <WebControls:TextBox2 ID="txtIndInicio" runat="server" MaxLength="16" />
                        <span class="sigma-modal-ayuda">dd-mm-aaaa hh:mm</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Término</label>
                        <WebControls:TextBox2 ID="txtIndFin" runat="server" MaxLength="16" />
                        <span class="sigma-modal-ayuda">Vacío = sigue detenido.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Tipo de indisponibilidad <b class="sg-req">*</b></label>
                        <div class="sigma-modal-opciones sg-ot-si-no">
                            <asp:RadioButton ID="rdbIndPlan" runat="server" Text="Planificada" GroupName="IndTipo" Checked="true" />
                            <asp:RadioButton ID="rdbIndNoPlan" runat="server" Text="No planificada" GroupName="IndTipo" />
                        </div>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Motivo <b class="sg-req">*</b></label>
                        <rad:RadComboBox2 ID="cboIndMotivo" runat="server" OnLoad="LoadControls" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Detalle</label>
                        <WebControls:TextArea2 ID="txtIndDetalle" runat="server" MaxLength="500" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>¿Detuvo la producción?</label>
                        <div class="sigma-modal-opciones sg-ot-si-no">
                            <asp:RadioButton ID="rdbIndProdSi" runat="server" Text="Sí" GroupName="IndProd" />
                            <asp:RadioButton ID="rdbIndProdNo" runat="server" Text="No" GroupName="IndProd" Checked="true" />
                        </div>
                    </div>
                </div>

                <div class="sg-ot-card-pie">
                    <WebControls:PushButton ID="btnIndLimpiar" runat="server" Text="Cancelar" CssClass="sg-ot-btn es-plano"
                        OnClick="btnIndLimpiar_Click" CausesValidation="false" />
                    <WebControls:PushButton ID="btnIndRegistrar" runat="server" Text="Registrar período" CssClass="sg-ot-btn es-primario"
                        OnClick="btnIndRegistrar_Click" CausesValidation="false" />
                </div>
            </asp:Panel>

            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-chart-bar"></i></span>
                        <h3>Impacto en disponibilidad</h3>
                    </header>
                    <p class="sg-ot-texto">Cómo se considera este período en los indicadores del equipo.</p>
                    <div class="sg-ot-impacto es-ok">
                        <i class="mdi mdi-calendar-check-outline"></i>
                        <div><strong>Planificada</strong><span>No penaliza el indicador.</span></div>
                    </div>
                    <div class="sg-ot-impacto es-alerta">
                        <i class="mdi mdi-flash-outline"></i>
                        <div><strong>No planificada</strong><span>Se considera en el indicador.</span></div>
                    </div>
                </div>
            </aside>
        </div>
    </section>

    <%-- =====================================================================
         7. CIERRE
         ===================================================================== --%>
    <section class="sg-ot-panel" data-panel="cierre">
        <div class="sg-ot-card sg-ot-cierre-cab">
            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-shield-check-outline"></i></span>
            <div>
                <h3>Revisar y firmar cierre</h3>
                <p class="sg-ot-card-sub">Valide el resultado del trabajo, revise las evidencias y complete la firma para cerrar la OT.</p>
            </div>
        </div>

        <div class="sg-ot-cols">
            <div class="sg-ot-col">
                <asp:Panel ID="pnlFormCierre" runat="server" CssClass="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-wrench-outline"></i></span>
                        <div>
                            <h3>Resultado del trabajo</h3>
                            <p class="sg-ot-card-sub">Indique el resultado final de la intervención.</p>
                        </div>
                    </header>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-medio">
                            <label>Motivo de cierre <b class="sg-req">*</b></label>
                            <rad:RadComboBox2 ID="cboMotivoCierre" runat="server" Width="100%">
                                <Items>
                                    <rad:RadComboBoxItem Text="Trabajo realizado" Value="1" Selected="true" />
                                    <rad:RadComboBoxItem Text="Sin hallazgo, no requirió intervención" Value="2" />
                                    <rad:RadComboBoxItem Text="Resuelta en otra orden" Value="3" />
                                    <rad:RadComboBoxItem Text="Duplicada" Value="4" />
                                    <rad:RadComboBoxItem Text="Anulada por error de registro" Value="5" />
                                    <rad:RadComboBoxItem Text="No aplica" Value="6" />
                                </Items>
                            </rad:RadComboBox2>
                        </div>
                        <div class="sigma-modal-field is-ancho">
                            <label>Trabajo realizado <b class="sg-req">*</b></label>
                            <WebControls:TextArea2 ID="txtResultadoCierre" runat="server" MaxLength="1000" />
                        </div>
                    </div>

                    <div class="sg-ot-sub-titulo">Evidencias del técnico</div>
                    <asp:Literal ID="litCierreEvidencias" runat="server" />
                </asp:Panel>
            </div>

            <aside class="sg-ot-lado">
                <div class="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-check-circle-outline"></i></span>
                        <div>
                            <h3>Validación de cierre</h3>
                            <p class="sg-ot-card-sub">Los requisitos para cerrar esta orden.</p>
                        </div>
                    </header>
                    <asp:Literal ID="litValidacion" runat="server" />
                </div>

                <asp:Panel ID="pnlFirma" runat="server" CssClass="sg-ot-card">
                    <header class="sg-ot-card-cab">
                        <span class="sg-ot-card-ico"><i class="mdi mdi-draw-pen"></i></span>
                        <div>
                            <h3>Firma de quien autoriza</h3>
                            <p class="sg-ot-card-sub">Dibuje su firma con el mouse o en la pantalla táctil.</p>
                        </div>
                    </header>

                    <div class="sigma-modal-field is-ancho">
                        <label>Usuario con permiso de cierre</label>
                        <div class="sg-ot-usuario"><i class="mdi mdi-account-outline"></i><asp:Literal ID="litUsuarioCierre" runat="server" /></div>
                    </div>

                    <%-- El trazo se dibuja en el canvas y viaja en el campo
                         oculto como PNG: un canvas no se postea solo. --%>
                    <div class="sg-ot-firma">
                        <canvas id="sgOtFirma" width="620" height="150"></canvas>
                        <span class="sg-ot-firma-guia"><i class="mdi mdi-pencil-outline"></i>Firme aquí</span>
                    </div>
                    <asp:HiddenField ID="hdnFirma" runat="server" ClientIDMode="Static" />

                    <div class="sg-ot-firma-acc">
                        <a href="#" class="sg-ot-link" id="sgOtFirmaLimpiar"><i class="mdi mdi-trash-can-outline"></i>Limpiar</a>
                    </div>

                    <label class="sg-ot-confirmo">
                        <asp:CheckBox ID="chkConfirmo" runat="server" />
                        <span>Confirmo que revisé el trabajo y sus evidencias.</span>
                    </label>

                    <div class="sg-ot-nota es-chica">
                        <i class="mdi mdi-information-outline"></i>
                        <span>La firma se vinculará a la OT, al usuario autenticado y a la fecha de cierre.</span>
                    </div>

                    <div class="sg-ot-card-pie">
                        <a href="#" class="sg-ot-btn es-plano" data-ir="resumen">Volver a revisión</a>
                        <WebControls:PushButton ID="btnCerrarOT" runat="server" Text="Firmar y cerrar OT" CssClass="sg-ot-btn es-primario"
                            OnClick="btnCerrarOT_Click" CausesValidation="false" />
                    </div>
                </asp:Panel>

                <asp:Literal ID="litCerrada" runat="server" />
            </aside>
        </div>
    </section>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
