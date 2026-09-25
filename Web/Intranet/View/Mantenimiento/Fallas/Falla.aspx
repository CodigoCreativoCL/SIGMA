<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Falla.aspx.cs" Inherits="View_Mantenimiento_Fallas_Falla" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <style>
        .sigma-centro-falla .sigma-modal { padding: 0; }
        .sigma-centro-falla .RadMultiPage { padding-top: 14px; }
        .sigma-hilo-item { padding: 10px 0; border-bottom: 1px solid #eee; }
        .sigma-hilo-item .meta { color: #7a8391; font-size: 12px; margin-top: 3px; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        var queryNuevaIndisponibilidad = '<%=QueryNuevaIndisponibilidad %>';
        function abrirIndisponibilidad(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Fallas/ActivoIndisponibilidad.aspx") %>?query=' + query,
                title: query === queryNuevaIndisponibilidad ? 'Registrar indisponibilidad' : 'Indisponibilidad', width: 860, initialHeight: 560
            });
        }
        function refresh() { __doPostBack("<%=GridIndisponibilidad.ClientID %>", ''); }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento · Fallas
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    <asp:Literal ID="litTitulo" runat="server">Falla</asp:Literal>
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-centro-falla"><div class="sigma-modal" style="max-width:none;">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <rad:RadTabStrip2 ID="tabFalla" runat="server" MultiPageID="mpFalla" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabFicha" Text="Ficha" runat="server" PageViewID="pvFicha" />
            <rad:RadTab ID="tabDiagnosticos" Text="Diagnósticos" runat="server" PageViewID="pvDiagnosticos" />
            <rad:RadTab ID="tabAcciones" Text="Acciones" runat="server" PageViewID="pvAcciones" />
            <rad:RadTab ID="tabIndisponibilidad" Text="Indisponibilidad" runat="server" PageViewID="pvIndisponibilidad" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFalla" runat="server" SelectedIndex="0" Width="100%">

        <%-- ================================ FICHA ================================ --%>
        <rad:RadPageView ID="pvFicha" runat="server">
            <asp:Panel ID="pnlResuelta" runat="server" Visible="false" CssClass="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-check-circle-outline"></i>
                <div><asp:Literal ID="litResuelta" runat="server" /></div>
            </asp:Panel>
            <asp:Panel ID="pnlHistorial" runat="server" Visible="false" CssClass="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-repeat"></i>
                <div><asp:Literal ID="litHistorial" runat="server" /></div>
            </asp:Panel>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-alert-circle-outline"></i>Qué falló</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>Falla</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>
                    <div class="sigma-modal-field is-grande">
                        <label>Título(*)</label>
                        <WebControls:TextBox2 ID="txtTitulo" runat="server" MaxLength="400" />
                        <asp:CustomValidator ID="cvTitulo" runat="server" ControlToValidate="txtTitulo" ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="FALLA" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Planta</label>
                        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" AutoPostBack="true" OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" Filter="Contains" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Equipo(*)</label>
                        <rad:RadComboBox2 ID="cboActivo" runat="server" AutoPostBack="true" OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                        <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo" ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="FALLA" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Componente</label>
                        <rad:RadComboBox2 ID="cboComponente" runat="server" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Opcional: la parte del equipo que falló.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Criticidad(*)</label>
                        <rad:RadComboBox2 ID="cboCriticidad" runat="server" Width="100%">
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
                        <span class="sigma-modal-ayuda">Qué se vio, qué ruido hacía, qué dejó de hacer.</span>
                    </div>
                    <div class="sigma-modal-field is-ancho">
                        <label>Consecuencia</label>
                        <WebControls:TextArea2 ID="txtConsecuencia" runat="server" MaxLength="4000" />
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-factory"></i>Impacto</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>Detectada el</label>
                        <WebControls:TextBox2 ID="txtFechaDeteccion" runat="server" MaxLength="16" />
                        <span class="sigma-modal-ayuda">dd-mm-aaaa hh:mm · vacío = ahora</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Detuvo producción</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbProdSi" runat="server" Text="SI" GroupName="Prod" />
                            <asp:RadioButton ID="rdbProdNo" runat="server" Text="NO" GroupName="Prod" Checked="true" />
                        </div>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Estado del equipo tras la falla</label>
                        <rad:RadComboBox2 ID="cboEstadoPosterior" runat="server" Width="100%">
                            <Items>
                                <rad:RadComboBoxItem Text="No cambia" Value="" Selected="true" />
                                <rad:RadComboBoxItem Text="Operativo con observación" Value="2" />
                                <rad:RadComboBoxItem Text="Detenido" Value="3" />
                                <rad:RadComboBoxItem Text="Fuera de servicio" Value="5" />
                            </Items>
                        </rad:RadComboBox2>
                        <span class="sigma-modal-ayuda">Al guardar, el equipo cambia a este estado y queda en su historial.</span>
                    </div>
                </div>
            </div>

            <wuc:Auditoria runat="server" ID="wucAuditoria" />

            <div class="sigma-modal-actions">
                <WebControls:PushButton ID="btnVolver" runat="server" Text="Volver al listado" CssClass="ButtonCerrar" OnClick="btnVolver_Click" CausesValidation="false" />
                <asp:LinkButton ID="btnGenerarOT" runat="server" Text="Generar orden correctiva" CssClass="icono_guardar" OnClick="btnGenerarOT_Click" CausesValidation="false"
                    OnClientClick="return ConfirSweetAlert(this, '', '¿Crear una orden correctiva de emergencia para esta falla? Se abrirá la orden para asignarla.');" />
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="FALLA" />
            </div>
        </rad:RadPageView>

        <%-- ============================ DIAGNÓSTICOS ============================ --%>
        <rad:RadPageView ID="pvDiagnosticos" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-stethoscope"></i>
                <div><strong>Qué se encontró al revisar.</strong> Se anotan todos los diagnósticos; uno solo puede ser el definitivo y al marcarlo los anteriores dejan de serlo. Se conservan como historia.</div>
            </div>
            <asp:Literal ID="litDiagnosticos" runat="server" />
            <asp:Panel ID="pnlNuevoDiagnostico" runat="server" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-plus-circle-outline"></i>Agregar diagnóstico</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Método</label>
                        <rad:RadComboBox2 ID="cboMetodo" runat="server" Width="100%">
                            <Items>
                                <rad:RadComboBoxItem Text="Sin indicar" Value="" Selected="true" />
                                <rad:RadComboBoxItem Text="Inspección visual" Value="1" />
                                <rad:RadComboBoxItem Text="Medición" Value="2" />
                                <rad:RadComboBoxItem Text="Análisis de vibración" Value="3" />
                                <rad:RadComboBoxItem Text="Termografía" Value="4" />
                                <rad:RadComboBoxItem Text="Análisis de aceite" Value="5" />
                                <rad:RadComboBoxItem Text="Ultrasonido" Value="6" />
                                <rad:RadComboBoxItem Text="Desarme" Value="7" />
                                <rad:RadComboBoxItem Text="Historial" Value="8" />
                                <rad:RadComboBoxItem Text="Análisis con IA" Value="9" />
                            </Items>
                        </rad:RadComboBox2>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Confianza (%)</label>
                        <WebControls:TextBox2 ID="txtConfianza" runat="server" MaxLength="3" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Es el definitivo</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbDefSi" runat="server" Text="SI" GroupName="Def" />
                            <asp:RadioButton ID="rdbDefNo" runat="server" Text="NO" GroupName="Def" Checked="true" />
                        </div>
                    </div>
                    <div class="sigma-modal-field is-ancho">
                        <label>Diagnóstico(*)</label>
                        <WebControls:TextArea2 ID="txtDiagnostico" runat="server" MaxLength="4000" />
                    </div>
                </div>
                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnDiagnostico" runat="server" Text="Registrar diagnóstico" OnClick="btnDiagnostico_Click" CausesValidation="false" />
                </div>
            </asp:Panel>
        </rad:RadPageView>

        <%-- ============================== ACCIONES ============================== --%>
        <rad:RadPageView ID="pvAcciones" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-wrench-outline"></i>
                <div><strong>Cómo se reparó.</strong> Una acción <em>provisoria</em> mantiene la falla abierta; la <em>definitiva</em> la resuelve y fija la fecha de solución. Varias provisorias sobre el mismo equipo son la señal de que hay que ir más a fondo.</div>
            </div>
            <asp:Literal ID="litAcciones" runat="server" />
            <asp:Panel ID="pnlNuevaAccion" runat="server" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-plus-circle-outline"></i>Agregar acción</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Sobre el diagnóstico</label>
                        <rad:RadComboBox2 ID="cboDiagnosticoAccion" runat="server" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Orden de trabajo</label>
                        <rad:RadComboBox2 ID="cboOrdenAccion" runat="server" Width="100%" />
                        <span class="sigma-modal-ayuda">Solo las órdenes generadas desde esta falla.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Tipo(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbAccProvisoria" runat="server" Text="Provisoria" GroupName="Acc" Checked="true" />
                            <asp:RadioButton ID="rdbAccDefinitiva" runat="server" Text="Definitiva" GroupName="Acc" />
                        </div>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Cuándo</label>
                        <WebControls:TextBox2 ID="txtFechaAccion" runat="server" MaxLength="16" />
                        <span class="sigma-modal-ayuda">dd-mm-aaaa hh:mm · vacío = ahora</span>
                    </div>
                    <div class="sigma-modal-field is-ancho">
                        <label>Qué se hizo(*)</label>
                        <WebControls:TextArea2 ID="txtAccion" runat="server" MaxLength="4000" />
                    </div>
                </div>
                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnAccion" runat="server" Text="Registrar acción" OnClick="btnAccion_Click" CausesValidation="false" />
                </div>
            </asp:Panel>
        </rad:RadPageView>

        <%-- ========================= INDISPONIBILIDAD ========================= --%>
        <rad:RadPageView ID="pvIndisponibilidad" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-power-plug-off-outline"></i>
                <div><strong>Cuánto estuvo detenido el equipo por esta falla.</strong> Los minutos se calculan de inicio a término; una falla es siempre indisponibilidad no planificada.</div>
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

    </rad:RadMultiPage>

        </ContentTemplate>
    </asp:UpdatePanel>
</div></div>
</asp:Content>
