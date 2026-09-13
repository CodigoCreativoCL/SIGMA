<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PlanMantenimiento.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanMantenimiento" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La ficha usa el mismo vocabulario que los modales (secciones, grilla
         de campos, codigo con prefijo); Default.master no lo trae. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <style>
        /* En pagina completa la ficha usa todo el ancho y las pestañas
           respiran un poco mas que dentro de un modal. */
        .sigma-centro-plan .sigma-modal { padding: 0; }
        .sigma-centro-plan .RadMultiPage { padding-top: 14px; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* EL CENTRO ABRE SUS FICHAS EN MODAL Y RECUERDA CUAL GRILLA REFRESCAR

           Los modales cierran llamando a refresh() de esta ventana. Como hay
           dos grillas -hitos y equipos-, se anota cual se abrio para
           refrescar esa y no las dos. */
        var gridPendiente = null;

        /* Los ids nunca viajan a la vista: el plan va DENTRO del querystring
           cifrado, junto con el id del hito o del vinculo. Para «nuevo», el
           servidor ya dejo cifrado «Id=0&Plan=<este>». */
        var queryNuevoHito = '<%=QueryNuevoHito %>';
        var queryNuevoActivo = '<%=QueryNuevoActivo %>';

        function abrirPlanHito(query) {
            gridPendiente = "<%=GridHitos.ClientID %>";
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanHito.aspx") %>?query=' + query,
                title: query === queryNuevoHito ? 'Nuevo hito' : 'Editar hito',
                width: 960,
                initialHeight: 680
            });
        }

        function abrirPlanActivo(query) {
            gridPendiente = "<%=GridActivos.ClientID %>";
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanActivo.aspx") %>?query=' + query,
                title: query === queryNuevoActivo ? 'Asociar equipo' : 'Equipo del plan',
                width: 900,
                initialHeight: 520
            });
        }

        function refresh() {
            if (gridPendiente) __doPostBack(gridPendiente, '');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento · Planes
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    <asp:Literal ID="litTitulo" runat="server">Plan de mantenimiento</asp:Literal>
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-centro-plan"><div class="sigma-modal" style="max-width:none;">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <%-- EL PLAN ES EL CENTRO DE OPERACIONES

         Una sola pantalla con todo lo que cuelga del plan: que es, que se le
         hace y a que equipos. Tres pantallas sueltas obligaban a ir al menu
         tres veces para armar un plan, y a elegir el mismo plan tres veces. --%>
    <rad:RadTabStrip2 ID="tabPlan" runat="server" MultiPageID="mpPlan" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabFicha" Text="Ficha" runat="server" PageViewID="pvFicha" />
            <rad:RadTab ID="tabHitos" Text="Hitos" runat="server" PageViewID="pvHitos" />
            <rad:RadTab ID="tabEquipos" Text="Equipos" runat="server" PageViewID="pvEquipos" />
            <rad:RadTab ID="tabCalendario" Text="Calendario" runat="server" PageViewID="pvCalendario" />
            <rad:RadTab ID="tabVersiones" Text="Versiones" runat="server" PageViewID="pvVersiones" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpPlan" runat="server" SelectedIndex="0" Width="100%">

        <%-- ================================ FICHA ================================ --%>
        <rad:RadPageView ID="pvFicha" runat="server">

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
        </rad:RadPageView>

        <%-- ================================ HITOS ================================ --%>
        <rad:RadPageView ID="pvHitos" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-information-outline"></i>
                <div>
                    <strong>Qué se le hace y cada cuánto.</strong> Cada hito apunta a una programación
                    —un calendario, un intervalo o un medidor— y define la orden de trabajo que genera.
                    Solo se editan los hitos de una versión en <strong>borrador</strong>.
                </div>
            </div>
            <rad:RadGrid2 ID="GridHitos" runat="server" OnItemDataBound="GridHitos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="pmh_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevoHito" runat="server" Text="Nuevo hito" CssClass="icono_guardar" OnClientClick="return abrirPlanHito(queryNuevoHito);" />
                            <asp:LinkButton ID="lnkEliminarHito" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminarHito_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los hitos seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </rad:RadPageView>

        <%-- ================================ EQUIPOS ================================ --%>
        <rad:RadPageView ID="pvEquipos" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-information-outline"></i>
                <div>
                    <strong>A qué equipos se aplica.</strong> Tienen que caber en el alcance del plan
                    —su planta, su tipo y su modelo, si el plan los acota—. Un plan sin equipos
                    no se puede publicar: no tendría para qué máquina generar.
                </div>
            </div>
            <rad:RadGrid2 ID="GridActivos" runat="server" OnItemDataBound="GridActivos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="pac_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevoActivo" runat="server" Text="Asociar equipo" CssClass="icono_guardar" OnClientClick="return abrirPlanActivo(queryNuevoActivo);" />
                            <asp:LinkButton ID="lnkEliminarActivo" runat="server" Text="Quitar" CssClass="icono_eliminar" OnClick="lnkEliminarActivo_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Quitar los equipos seleccionados del plan?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </rad:RadPageView>

        <%-- ============================== CALENDARIO ============================== --%>
        <rad:RadPageView ID="pvCalendario" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-calendar-month-outline"></i>
                <div>
                    <strong>Cuándo le toca a cada equipo.</strong> Cada fila es un hito sobre un equipo en
                    una fecha. La <em>situación</em> se calcula contra hoy: vencida, atrasada, disponible o
                    futura. Solo lectura: las genera la versión publicada y las cierra la orden de trabajo.
                </div>
            </div>

            <div class="sigma-modal-grid" style="margin-bottom:10px;">
                <div class="sigma-modal-field is-mini">
                    <label>Año</label>
                    <rad:RadComboBox2 ID="cboAnio" runat="server" Width="100%" />
                </div>
                <div class="sigma-modal-field is-chico">
                    <label>Mes</label>
                    <rad:RadComboBox2 ID="cboMes" runat="server" Width="100%" />
                </div>
                <div class="sigma-modal-field is-medio">
                    <label>Equipo</label>
                    <rad:RadComboBox2 ID="cboActivoCal" runat="server" Filter="Contains" Width="100%" />
                </div>
                <div class="sigma-modal-field is-chico">
                    <label>Estado</label>
                    <rad:RadComboBox2 ID="cboEstadoCal" runat="server" Width="100%" />
                </div>
                <div class="sigma-modal-field is-chico" style="align-self:flex-end;">
                    <WebControls:PushButton ID="btnFiltrarCal" runat="server" Text="Aplicar" OnClick="btnFiltrarCal_Click" CausesValidation="false" />
                </div>
            </div>

            <div style="margin:0 0 10px;">
                <asp:Literal ID="litResumenCal" runat="server" />
            </div>

            <rad:RadGrid2 ID="GridCalendario" runat="server" OnItemDataBound="GridCalendario_ItemDataBound" AllowPaging="true" PageSize="50">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="pmo_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkDescargarCal" runat="server" Text="Descargar Excel" CssClass="icono_excel" OnClick="lnkDescargarCal_Click" CausesValidation="false" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </rad:RadPageView>

        <%-- =============================== VERSIONES =============================== --%>
        <rad:RadPageView ID="pvVersiones" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-source-branch"></i>
                <div>
                    <strong>Lo que se edita es siempre un borrador.</strong> Publicar congela los hitos y equipos
                    de esa versión y retira la publicada anterior. Para cambiar un plan publicado se abre una
                    versión nueva: nace como copia de la vigente y se edita desde las pestañas Hitos y Equipos.
                </div>
            </div>

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
        </rad:RadPageView>

    </rad:RadMultiPage>

        </ContentTemplate>
    </asp:UpdatePanel>
</div></div>
</asp:Content>
