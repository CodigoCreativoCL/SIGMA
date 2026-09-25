<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PlanMantenimiento.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanMantenimiento" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La configuracion sigue siendo un formulario y usa el vocabulario de
         los modales; la cascara del centro -tarjetas, chips, tablas, vacios-
         es la misma de la orden de trabajo y del activo, y se reusa tal cual. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-orden.css?vrs=1") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-activo360.css?vrs=1") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-plan360.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <%-- La navegacion por secciones es la misma del centro del activo: las
         pestañas son del navegador, no del servidor. Cambiar de pestaña no
         puede costar un viaje. --%>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-activo360.js") %>?vrs=1'></script>

    <script type="text/javascript">
        /* EL CENTRO ABRE SUS FICHAS EN MODAL Y RECUERDA CUAL REFRESCAR

           Los modales cierran llamando a refresh() de esta ventana. Como hay
           dos listas -hitos y equipos-, se anota cual se abrio. */
        var seccionPendiente = null;

        /* Los ids nunca viajan a la vista: el plan va DENTRO del querystring
           cifrado, junto con el id del hito o del vinculo. */
        var queryNuevoHito = '<%=QueryNuevoHito %>';
        var queryNuevoActivo = '<%=QueryNuevoActivo %>';

        function abrirPlanHito(query) {
            seccionPendiente = 'hitos';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanHito.aspx") %>?query=' + query,
                title: query === queryNuevoHito ? 'Nuevo hito' : 'Editar hito',
                width: 960,
                initialHeight: 680
            });
        }

        function abrirPlanActivo(query) {
            seccionPendiente = 'equipos';
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanActivo.aspx") %>?query=' + query,
                title: query === queryNuevoActivo ? 'Asociar equipo' : 'Equipo del plan',
                width: 900,
                initialHeight: 520
            });
        }

        function refresh() {
            var h = document.getElementById('hdnSeccion');
            if (h && seccionPendiente) h.value = seccionPendiente;
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento · Planes</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Centro del plan</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Qué se le hace a la planta, a qué equipos y cuándo le toca a cada uno.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- La seccion abierta viaja en un campo oculto: un postback
                 asincrono repinta el bloque entero y sin esto siempre
                 volveria al Resumen. --%>
            <asp:HiddenField ID="hdnSeccion" runat="server" Value="resumen" ClientIDMode="Static" />
            <asp:LinkButton ID="lnkRecargar" runat="server" style="display:none" OnClick="lnkRecargar_Click" CausesValidation="false" />

            <asp:Panel ID="pnlPlan" runat="server" CssClass="sg-a3 sg-ot">

                <div class="sg-a3-miga">
                    <a href='<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanMantenimientos.aspx") %>'>Planes</a>
                    <span>/</span><span>Centro del plan</span>
                </div>

                <header class="sg-a3-hero">
                    <div class="sg-a3-hero-txt">
                        <span class="sg-plan-codigo"><asp:Literal ID="litHeroCodigo" runat="server" /></span>
                        <h1><asp:Literal ID="litHeroNombre" runat="server" /></h1>
                        <asp:Literal ID="litBadges" runat="server" />
                        <p class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></p>
                    </div>

                    <div class="sg-a3-hero-acc">
                        <asp:HyperLink ID="hlVolver" runat="server" CssClass="sg-ot-btn es-plano">
                            <i class="mdi mdi-arrow-left"></i>Volver a planes</asp:HyperLink>
                        <a href="#" class="sg-ot-btn es-accion" data-ir-sec="calendario">
                            <i class="mdi mdi-calendar-month-outline"></i>Ver calendario</a>
                    </div>
                </header>

                <asp:Literal ID="litKpis" runat="server" />

                <%-- ---------------- navegacion ---------------- --%>
                <asp:Panel ID="pnlNav" runat="server" CssClass="sg-a3-nav">
                    <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-home-outline"></i>Resumen</a>
                    <a href="#" class="sg-a3-tab" data-sec="hitos"><i class="mdi mdi-format-list-checks"></i>Hitos<asp:Literal ID="litTabHitos" runat="server" /></a>
                    <a href="#" class="sg-a3-tab" data-sec="equipos"><i class="mdi mdi-account-group-outline"></i>Equipos<asp:Literal ID="litTabEquipos" runat="server" /></a>
                    <a href="#" class="sg-a3-tab" data-sec="calendario"><i class="mdi mdi-calendar-month-outline"></i>Calendario</a>
                    <a href="#" class="sg-a3-tab" data-sec="configuracion"><i class="mdi mdi-cog-outline"></i>Configuración</a>
                </asp:Panel>

                <%-- ================================================================
                     1. RESUMEN
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="resumen">
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-grande es-rojo"><i class="mdi mdi-alert-outline"></i></span>
                                    <div>
                                        <h3>Requiere atención</h3>
                                        <p class="sg-ot-card-sub">Lo vencido y lo atrasado del plan, con acceso a su equipo.</p>
                                    </div>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="calendario">Ver calendario</a>
                                </header>

                                <asp:Literal ID="litAtencion" runat="server" />
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-format-list-checks"></i></span>
                                    <div>
                                        <h3>Hitos del plan</h3>
                                        <p class="sg-ot-card-sub">Qué se realiza y con qué frecuencia.</p>
                                    </div>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="hitos">Ver los hitos</a>
                                </header>

                                <asp:Literal ID="litHitosResumen" runat="server" />
                            </div>
                        </div>

                        <div class="sg-a3-col es-angosta">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-target"></i></span>
                                    <div><h3>Alcance del plan</h3></div>
                                </header>

                                <dl class="sg-a3-ident"><asp:Literal ID="litAlcance" runat="server" /></dl>
                            </div>

                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-account-group-outline"></i></span>
                                    <div><h3>Equipos asociados</h3></div>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="equipos">Ver todos</a>
                                </header>

                                <asp:Literal ID="litEquiposResumen" runat="server" />
                                <asp:Literal ID="litNotaVersion" runat="server" />
                            </div>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     2. HITOS
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="hitos">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-format-list-checks"></i></span>
                            <div>
                                <h3>Hitos del plan</h3>
                                <p class="sg-ot-card-sub">Qué se realiza y con qué frecuencia.</p>
                            </div>
                            <asp:Literal ID="litHitosEstado" runat="server" />
                            <asp:LinkButton ID="lnkNuevoHito" runat="server" CssClass="sg-ot-btn es-accion"
                                OnClientClick="return abrirPlanHito(queryNuevoHito);"><i class="mdi mdi-plus"></i>Nuevo hito</asp:LinkButton>
                        </header>

                        <asp:Literal ID="litHitos" runat="server" />

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>Cada hito apunta a una programación —un calendario, un intervalo o un medidor— y define la orden que genera. Solo se editan los hitos de una versión en <strong>borrador</strong>.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     3. EQUIPOS
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="equipos">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-account-group-outline"></i></span>
                            <div>
                                <h3>Equipos asociados</h3>
                                <p class="sg-ot-card-sub">Equipos incluidos en el alcance de esta versión.</p>
                            </div>
                            <asp:Literal ID="litEquiposEstado" runat="server" />
                            <asp:LinkButton ID="lnkNuevoActivo" runat="server" CssClass="sg-ot-btn es-accion"
                                OnClientClick="return abrirPlanActivo(queryNuevoActivo);"><i class="mdi mdi-plus"></i>Asociar equipo</asp:LinkButton>
                        </header>

                        <asp:Literal ID="litAlcanceChips" runat="server" />
                        <asp:Literal ID="litEquipos" runat="server" />

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>Los equipos tienen que caber en el alcance: su planta, su tipo y su modelo, si el plan los acota. Un plan sin equipos no se publica: no tendría para qué máquina generar.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     4. CALENDARIO
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="calendario">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-calendar-month-outline"></i></span>
                            <div>
                                <h3>Calendario de mantenimiento</h3>
                                <p class="sg-ot-card-sub">Ocurrencias generadas por la versión publicada.</p>
                            </div>
                        </header>

                        <div class="sg-plan-filtros">
                            <div class="sg-plan-filtro">
                                <label>Año</label>
                                <rad:RadComboBox2 ID="cboAnio" runat="server" Width="100%" />
                            </div>
                            <div class="sg-plan-filtro">
                                <label>Mes</label>
                                <rad:RadComboBox2 ID="cboMes" runat="server" Width="100%" />
                            </div>
                            <div class="sg-plan-filtro es-ancho">
                                <label>Equipo</label>
                                <rad:RadComboBox2 ID="cboActivoCal" runat="server" Filter="Contains" Width="100%" />
                            </div>
                            <div class="sg-plan-filtro">
                                <label>Estado</label>
                                <rad:RadComboBox2 ID="cboEstadoCal" runat="server" Width="100%" />
                            </div>
                            <div class="sg-plan-filtro">
                                <label>Solo con parada</label>
                                <asp:CheckBox ID="chkSoloParada" runat="server" Text="Sí" />
                            </div>
                            <div class="sg-plan-filtro">
                                <label>Generar hacia adelante</label>
                                <rad:RadComboBox2 ID="cboHorizonte" runat="server" Width="100%">
                                    <Items>
                                        <rad:RadComboBoxItem Text="30 días" Value="30" />
                                        <rad:RadComboBoxItem Text="90 días" Value="90" Selected="true" />
                                        <rad:RadComboBoxItem Text="180 días" Value="180" />
                                        <rad:RadComboBoxItem Text="1 año" Value="365" />
                                    </Items>
                                </rad:RadComboBox2>
                            </div>
                            <div class="sg-plan-filtro es-boton">
                                <WebControls:PushButton ID="btnFiltrarCal" runat="server" Text="Aplicar" OnClick="btnFiltrarCal_Click" CausesValidation="false" />
                            </div>
                        </div>

                        <asp:Literal ID="litResumenCal" runat="server" />
                        <asp:Literal ID="litSemanas" runat="server" />

                        <asp:Panel ID="pnlResultadoOT" runat="server" Visible="false" CssClass="sg-ot-nota">
                            <i class="mdi mdi-clipboard-check-outline"></i>
                            <span><asp:Literal ID="litResultadoOT" runat="server" /></span>
                        </asp:Panel>

                        <%-- La grilla se queda: generar ordenes trabaja sobre lo
                             SELECCIONADO, y esa seleccion es suya. --%>
                        <rad:RadGrid2 ID="GridCalendario" runat="server" OnItemDataBound="GridCalendario_ItemDataBound" AllowPaging="true" PageSize="50">
                            <MasterTableView CommandItemDisplay="Top" DataKeyNames="pmo_id">
                                <CommandItemTemplate>
                                    <div style="margin-bottom: 5px;">
                                        <asp:LinkButton ID="btnGenerarOcurrencias" runat="server" Text="Generar ocurrencias" CssClass="icono_excel" OnClick="btnGenerarOcurrencias_Click" CausesValidation="false"
                                            OnClientClick="return ConfirSweetAlert(this, '', '¿Generar las ocurrencias que faltan de la versión publicada en el horizonte elegido? Las que ya existen no se duplican.');" />
                                        <asp:LinkButton ID="lnkGenerarOT" runat="server" Text="Generar órdenes de trabajo" CssClass="icono_guardar" OnClick="lnkGenerarOT_Click" CausesValidation="false"
                                            OnClientClick="return ConfirSweetAlert(this, '', '¿Generar una orden de trabajo por cada ocurrencia seleccionada? Las que ya tienen orden se informan y no se duplican.');" />
                                        <asp:LinkButton ID="lnkDescargarCal" runat="server" Text="Descargar Excel" CssClass="icono_excel" OnClick="lnkDescargarCal_Click" CausesValidation="false" />
                                    </div>
                                </CommandItemTemplate>
                            </MasterTableView>
                        </rad:RadGrid2>

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>Solo lectura: las ocurrencias las genera la versión publicada y las cierra la orden de trabajo. La <em>situación</em> se calcula contra hoy.</span>
                        </div>
                    </div>
                </section>

                <%-- ================================================================
                     5. CONFIGURACION
                     ================================================================ --%>
                <section class="sg-a3-panel" data-panel="configuracion">
                    <div class="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico es-grande"><i class="mdi mdi-cog-outline"></i></span>
                            <div>
                                <h3>Ficha del plan</h3>
                                <p class="sg-ot-card-sub">Qué es el plan y a qué alcanza.</p>
                            </div>
                        </header>

                        <div class="sigma-modal" style="max-width:none;padding:0;">
                            <div class="sigma-form-seccion">
                                <div class="titulo"><i class="mdi mdi-calendar-check-outline"></i>Identificación</div>

                                <div class="sigma-modal-grid">
                                    <div class="sigma-modal-field is-mini">
                                        <label>ID</label>
                                        <asp:Label ID="lblId" runat="server"></asp:Label>
                                    </div>
                                    <div class="sigma-modal-field is-chico">
                                        <label>Código</label>
                                        <div class="sg-codigo">
                                            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="90" UpperCase="true" />
                                        </div>
                                        <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>HORNOS-L1</em>). Si lo deja vacío, se numera solo. Único dentro del cliente.</span>
                                    </div>
                                    <div class="sigma-modal-field is-medio">
                                        <label>Nombre(*)</label>
                                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanMantenimiento" />
                                    </div>
                                    <div class="sigma-modal-field is-medio">
                                        <label>Versión</label>
                                        <asp:Literal ID="litVersion" runat="server" />
                                    </div>
                                    <div class="sigma-modal-field is-ancho">
                                        <label>Descripción</label>
                                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="2000" />
                                        <span class="sigma-modal-ayuda">Para qué existe el plan y qué cubre. Lo lee quien lo hereda dentro de dos años.</span>
                                    </div>
                                </div>
                            </div>

                            <div class="sigma-form-seccion">
                                <div class="titulo"><i class="mdi mdi-target"></i>Alcance</div>

                                <div class="sigma-modal-grid">
                                    <div class="sigma-modal-field is-medio">
                                        <label>Planta</label>
                                        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                                        <span class="sigma-modal-ayuda">Vacío indica que aplica a cualquier planta del cliente.</span>
                                    </div>
                                    <div class="sigma-modal-field is-medio">
                                        <label>Planificador</label>
                                        <rad:RadComboBox2 ID="cboPlanificador" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                                        <span class="sigma-modal-ayuda">Quien responde por el plan. Opcional.</span>
                                    </div>
                                    <div class="sigma-modal-field is-medio">
                                        <label>Tipo de activo</label>
                                        <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                                            OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                                        <span class="sigma-modal-ayuda">La familia de equipos a la que aplica. Vacío indica cualquiera. Los equipos que se asocien tienen que ser de este tipo.</span>
                                    </div>
                                    <div class="sigma-modal-field is-medio">
                                        <label>Modelo</label>
                                        <rad:RadComboBox2 ID="cboModelo" runat="server" Filter="Contains" Width="100%" />
                                        <span class="sigma-modal-ayuda">Elija primero el tipo. Acota el plan a un modelo concreto.</span>
                                    </div>
                                    <div class="sigma-modal-field is-chico">
                                        <label>Habilitado(*)</label>
                                        <div class="sigma-modal-opciones">
                                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="PlanMantenimiento" />
                                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="PlanMantenimiento" />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <wuc:Auditoria runat="server" ID="wucAuditoria" />

                            <div class="sigma-modal-actions">
                                <WebControls:PushButton ID="btnVolver" runat="server" Text="Volver al listado" CssClass="ButtonCerrar" OnClick="btnVolver_Click" CausesValidation="false" />
                                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="PlanMantenimiento" />
                            </div>
                        </div>
                    </div>

                    <asp:Panel ID="pnlVersiones" runat="server" CssClass="sg-ot-card">
                        <header class="sg-ot-card-cab">
                            <span class="sg-ot-card-ico"><i class="mdi mdi-source-branch"></i></span>
                            <div>
                                <h3>Versiones</h3>
                                <p class="sg-ot-card-sub">Lo que se edita es siempre un borrador; publicar lo congela.</p>
                            </div>
                        </header>

                        <div class="sigma-modal-grid" style="margin-bottom:10px;">
                            <div class="sigma-modal-field is-ancho">
                                <label>Observación (qué cambia en esta versión)</label>
                                <WebControls:TextBox2 ID="txtObservacionVersion" runat="server" MaxLength="1000" />
                            </div>
                        </div>

                        <rad:RadGrid2 ID="GridVersiones" runat="server" OnItemDataBound="GridVersiones_ItemDataBound">
                            <MasterTableView CommandItemDisplay="Top" DataKeyNames="pmv_id">
                                <CommandItemTemplate>
                                    <div style="margin-bottom: 5px;">
                                        <asp:LinkButton ID="lnkNuevaVersion" runat="server" Text="Abrir versión nueva" CssClass="icono_guardar" OnClick="lnkNuevaVersion_Click"
                                            OnClientClick="return ConfirSweetAlert(this, '', '¿Abrir una versión nueva en borrador, copiando los hitos y equipos de la vigente?');" />
                                        <asp:LinkButton ID="lnkPublicar" runat="server" Text="Publicar el borrador" CssClass="icono_excel" OnClick="lnkPublicar_Click"
                                            OnClientClick="return ConfirSweetAlert(this, '', '¿Publicar el borrador? Sus hitos y equipos quedan congelados y la versión publicada anterior se retira.');" />
                                    </div>
                                </CommandItemTemplate>
                            </MasterTableView>
                        </rad:RadGrid2>

                        <div class="sg-ot-nota es-chica">
                            <i class="mdi mdi-information-outline"></i>
                            <span>Para cambiar un plan publicado se abre una versión nueva: nace como copia de la vigente y se edita desde Hitos y Equipos.</span>
                        </div>
                    </asp:Panel>
                </section>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
