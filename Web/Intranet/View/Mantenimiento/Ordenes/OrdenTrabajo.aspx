<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="OrdenTrabajo.aspx.cs" Inherits="View_Mantenimiento_Ordenes_OrdenTrabajo" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <style>
        .sigma-centro-ot .sigma-modal { padding: 0; }
        .sigma-centro-ot .RadMultiPage { padding-top: 14px; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        var gridPendiente = null;
        var queryNuevaAsignacion = '<%=QueryNuevaAsignacion %>';
        var queryNuevaIndisponibilidad = '<%=QueryNuevaIndisponibilidad %>';

        function abrirAsignacion(query) {
            gridPendiente = "<%=GridAsignaciones.ClientID %>";
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajoAsignacion.aspx") %>?query=' + query,
                title: 'Asignar la orden', width: 860, initialHeight: 560
            });
        }
        function abrirIndisponibilidad(query) {
            gridPendiente = "<%=GridIndisponibilidad.ClientID %>";
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Fallas/ActivoIndisponibilidad.aspx") %>?query=' + query,
                title: query === queryNuevaIndisponibilidad ? 'Registrar indisponibilidad' : 'Indisponibilidad', width: 860, initialHeight: 560
            });
        }
        function refresh() { if (gridPendiente) __doPostBack(gridPendiente, ''); }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento · Órdenes de trabajo
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    <asp:Literal ID="litTitulo" runat="server">Orden de trabajo</asp:Literal>
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-centro-ot"><div class="sigma-modal" style="max-width:none;">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <rad:RadTabStrip2 ID="tabOT" runat="server" MultiPageID="mpOT" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabFicha" Text="Ficha" runat="server" PageViewID="pvFicha" />
            <rad:RadTab ID="tabAsignacion" Text="Asignación" runat="server" PageViewID="pvAsignacion" />
            <rad:RadTab ID="tabPasos" Text="Pasos" runat="server" PageViewID="pvPasos" />
            <rad:RadTab ID="tabIndisponibilidad" Text="Indisponibilidad" runat="server" PageViewID="pvIndisponibilidad" />
            <rad:RadTab ID="tabCierre" Text="Cierre" runat="server" PageViewID="pvCierre" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpOT" runat="server" SelectedIndex="0" Width="100%">

        <%-- ================================ FICHA ================================ --%>
        <rad:RadPageView ID="pvFicha" runat="server">
            <asp:Panel ID="pnlCerrada" runat="server" Visible="false" CssClass="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-lock-outline"></i>
                <div><asp:Literal ID="litCerrada" runat="server" /></div>
            </asp:Panel>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-clipboard-text-outline"></i>Qué hay que hacer</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>OT</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>
                    <div class="sigma-modal-field is-grande">
                        <label>Título(*)</label>
                        <WebControls:TextBox2 ID="txtTitulo" runat="server" MaxLength="400" />
                        <asp:CustomValidator ID="cvTitulo" runat="server" ControlToValidate="txtTitulo" ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="OT" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Tipo(*)</label>
                        <rad:RadComboBox2 ID="cboTipo" runat="server" Width="100%">
                            <Items>
                                <rad:RadComboBoxItem Text="Correctiva" Value="2" Selected="true" />
                                <rad:RadComboBoxItem Text="Preventiva" Value="1" />
                                <rad:RadComboBoxItem Text="Predictiva" Value="3" />
                            </Items>
                        </rad:RadComboBox2>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Estrategia(*)</label>
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
                        <label>Prioridad(*)</label>
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
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="4000" />
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Dónde</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Planta</label>
                        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" AutoPostBack="true" OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" Filter="Contains" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Equipo</label>
                        <rad:RadComboBox2 ID="cboActivo" runat="server" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Opcional: una orden sobre un área sin equipo no cuenta en los indicadores por máquina.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Área</label>
                        <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Obligatoria si no hay equipo.</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-calendar-clock"></i>Cuándo</div>
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
                        <label>Requiere permiso de trabajo</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbPermisoSi" runat="server" Text="SI" GroupName="Permiso" />
                            <asp:RadioButton ID="rdbPermisoNo" runat="server" Text="NO" GroupName="Permiso" Checked="true" />
                        </div>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Registro posterior</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbPosteriorSi" runat="server" Text="SI" GroupName="Posterior" />
                            <asp:RadioButton ID="rdbPosteriorNo" runat="server" Text="NO" GroupName="Posterior" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">El trabajo ya ocurrió y se anota después: se guardan las dos fechas.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Cuándo ocurrió</label>
                        <WebControls:TextBox2 ID="txtFechaOcurrencia" runat="server" MaxLength="16" />
                        <span class="sigma-modal-ayuda">dd-mm-aaaa hh:mm · solo registro posterior</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-note-text-outline"></i>Notas</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-ancho">
                        <WebControls:TextArea2 ID="txtNotas" runat="server" MaxLength="4000" />
                    </div>
                </div>
            </div>

            <wuc:Auditoria runat="server" ID="wucAuditoria" />

            <div class="sigma-modal-actions">
                <WebControls:PushButton ID="btnVolver" runat="server" Text="Volver al listado" CssClass="ButtonCerrar" OnClick="btnVolver_Click" CausesValidation="false" />
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="OT" />
            </div>
        </rad:RadPageView>

        <%-- ============================= ASIGNACIÓN ============================= --%>
        <rad:RadPageView ID="pvAsignacion" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-account-hard-hat"></i>
                <div><strong>Quién la ejecuta.</strong> Un técnico o una empresa externa; puede haber apoyos, pero un único responsable: al nombrar otro, el anterior pasa a apoyo. Si la orden pide una especialidad que el técnico no tiene, se advierte y se deja continuar.</div>
            </div>
            <rad:RadGrid2 ID="GridAsignaciones" runat="server" OnItemDataBound="GridAsignaciones_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="ota_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkAsignar" runat="server" Text="Asignar" CssClass="icono_guardar" OnClientClick="return abrirAsignacion(queryNuevaAsignacion);" />
                            <asp:LinkButton ID="lnkQuitarAsignacion" runat="server" Text="Quitar" CssClass="icono_eliminar" OnClick="lnkQuitarAsignacion_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Quitar las asignaciones seleccionadas?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </rad:RadPageView>

        <%-- ================================ PASOS ================================ --%>
        <rad:RadPageView ID="pvPasos" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-format-list-checks"></i>
                <div><strong>Lo que el técnico marca en terreno.</strong> Solo lectura aquí: los pasos nacen del plan (una actividad, un paso) o los agrega el técnico desde el teléfono.</div>
            </div>
            <asp:Literal ID="litPasos" runat="server" />
        </rad:RadPageView>

        <%-- ========================= INDISPONIBILIDAD ========================= --%>
        <rad:RadPageView ID="pvIndisponibilidad" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-power-plug-off-outline"></i>
                <div><strong>Cuánto estuvo detenido el equipo por esta orden.</strong> Los minutos se calculan de inicio a término. Planificada no penaliza el indicador de disponibilidad; no planificada sí.</div>
            </div>
            <rad:RadGrid2 ID="GridIndisponibilidad" runat="server" OnItemDataBound="GridIndisponibilidad_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="ain_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevaIndisponibilidad" runat="server" Text="Registrar indisponibilidad" CssClass="icono_guardar" OnClientClick="return abrirIndisponibilidad(queryNuevaIndisponibilidad);" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </rad:RadPageView>

        <%-- ================================ CIERRE ================================ --%>
        <rad:RadPageView ID="pvCierre" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-check-decagram-outline"></i>
                <div><strong>Cerrar es de quien tiene la facultad</strong> (planificador, supervisor, jefe). Con «Trabajo realizado» la orden tiene que estar en espera de cierre y hay que describir lo hecho; anular, duplicada o no aplica cierran desde cualquier estado y conservan el correlativo.</div>
            </div>
            <asp:Literal ID="litEstadoCierre" runat="server" />
            <asp:Panel ID="pnlFormCierre" runat="server" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-lock-check-outline"></i>Cerrar la orden</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Motivo(*)</label>
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
                        <label>Trabajo realizado</label>
                        <WebControls:TextArea2 ID="txtResultadoCierre" runat="server" MaxLength="4000" />
                    </div>
                </div>
                <div class="sigma-modal-actions">
                    <asp:LinkButton ID="btnCerrarOT" runat="server" Text="Cerrar la orden" CssClass="icono_guardar" OnClick="btnCerrarOT_Click" CausesValidation="false"
                        OnClientClick="return ConfirSweetAlert(this, '', '¿Cerrar la orden? Una orden cerrada no se edita: se consulta.');" />
                </div>
            </asp:Panel>
        </rad:RadPageView>

    </rad:RadMultiPage>

        </ContentTemplate>
    </asp:UpdatePanel>
</div></div>
</asp:Content>
