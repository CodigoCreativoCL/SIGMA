<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Programacion.aspx.cs" Inherits="View_Mantenimiento_Programaciones_Programacion" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Programación</h1>

    <%-- ============================================================
         UNA FICHA Y NO CINCO

         El backlog proponía una pantalla por tipo —ProgramacionCalendario,
         ProgramacionMedidor…—. Pero los cinco tipos comparten vigencia,
         tolerancias, zona horaria y política: cinco pantallas serían las
         mismas cuatro secciones copiadas, y el día que cambie una regla
         común hay que acordarse de las cinco.

         Acá el combo de tipo intercambia UN panel. Lo demás es igual
         siempre, porque es igual siempre.
         ============================================================ --%>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-clock"></i>Qué se programa</div>

        <div class="sigma-modal-grid">

            <%-- Fila 1: 2 + 6 + 4 = 12 --%>
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>

            <div class="sigma-modal-field is-largo">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Programacion" />
                <span class="sigma-modal-ayuda">Cómo se la reconoce: "Inspección semanal de bombas".</span>
            </div>

            <div class="sigma-modal-field is-medio">
                <label>Tipo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" />
                <span class="sigma-modal-ayuda">Determina qué regla se pide más abajo. No se cambia después de guardar.</span>
            </div>

            <%-- Fila 2: 3 + 3 + 6 = 12 --%>
            <div class="sigma-modal-field is-chico">
                <label>Vigente desde(*)</label>
                <WebControls:Calendar ID="calInicio" runat="server" />
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Vigente hasta</label>
                <WebControls:Calendar ID="calFin" runat="server" />
                <span class="sigma-modal-ayuda">Vacío indica sin término.</span>
            </div>

            <div class="sigma-modal-field is-largo">
                <label>Zona horaria</label>
                <rad:RadComboBox2 ID="cboZonaHoraria" runat="server" />
                <span class="sigma-modal-ayuda">
                    La hora se guarda en UTC y se muestra en esta zona. Sin ella el horario de
                    verano corre las ocurrencias una hora dos veces al año.
                </span>
            </div>
        </div>
    </div>

    <%-- ============================================================
         LA REGLA — un panel por tipo
         ============================================================ --%>

    <asp:Panel ID="pnlRegla" runat="server" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-repeat"></i>La regla</div>

        <%-- ---------- FECHA ÚNICA (HU-070) ---------- --%>
        <asp:Panel ID="pnlFechaUnica" runat="server" Visible="false">
            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-chico">
                    <label>Agregar fecha</label>
                    <WebControls:Calendar ID="calNuevaFecha" runat="server" />
                </div>
                <div class="sigma-modal-field is-mini">
                    <label>&nbsp;</label>
                    <WebControls:PushButton ID="btnAgregarFecha" runat="server" Text="Agregar"
                        OnClick="btnAgregarFecha_Click" CausesValidation="false" />
                </div>
                <div class="sigma-modal-field is-largo">
                    <span class="sigma-modal-ayuda">
                        Cada fecha genera una ocurrencia independiente, con su propia ejecución,
                        estado y evidencias. Una fecha anterior a hoy se acepta: sirve para
                        registrar trabajo ya realizado.
                    </span>
                </div>
                <div class="sigma-modal-field is-ancho">
                    <rad:RadGrid2 ID="grdFechas" runat="server" OnItemDataBound="grdFechas_ItemDataBound"
                        OnItemCommand="grdFechas_ItemCommand">
                        <MasterTableView CommandItemDisplay="None" DataKeyNames="pfe_id" />
                    </rad:RadGrid2>
                </div>
            </div>
        </asp:Panel>

        <%-- ---------- CALENDARIO (HU-071) ---------- --%>
        <asp:Panel ID="pnlCalendario" runat="server" Visible="false">
            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-chico">
                    <label>Frecuencia(*)</label>
                    <rad:RadComboBox2 ID="cboFrecuencia" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="cboFrecuencia_SelectedIndexChanged" />
                </div>

                <div class="sigma-modal-field is-mini">
                    <label>Cada</label>
                    <rad:RadNumericBox2 ID="txtIntervalo" runat="server">
                        <NumberFormat DecimalDigits="0" />
                    </rad:RadNumericBox2>
                </div>

                <div class="sigma-modal-field is-mini">
                    <label>Hora(*)</label>
                    <WebControls:TextBox2 ID="txtHoraLocal" runat="server" MaxLength="5" />
                    <span class="sigma-modal-ayuda">HH:MM</span>
                </div>

                <asp:Panel ID="pnlDias" runat="server" CssClass="sigma-modal-field is-medio">
                    <label>Días de la semana</label>
                    <asp:CheckBoxList ID="chkDias" runat="server" RepeatDirection="Horizontal"
                        RepeatLayout="Flow" CssClass="sigma-checkbox-inline" />
                </asp:Panel>

                <asp:Panel ID="pnlDiaMes" runat="server" CssClass="sigma-modal-field is-chico">
                    <label>Día del mes</label>
                    <rad:RadComboBox2 ID="cboDiaMes" runat="server" />
                    <span class="sigma-modal-ayuda">
                        "Último día" resuelve febrero solo: 28 o 29 según el año.
                    </span>
                </asp:Panel>

                <asp:Panel ID="pnlOrdinal" runat="server" CssClass="sigma-modal-field is-chico">
                    <label>Semana del mes</label>
                    <rad:RadComboBox2 ID="cboOrdinal" runat="server" />
                    <span class="sigma-modal-ayuda">
                        Combinado con el día: "último viernes de cada mes".
                    </span>
                </asp:Panel>

                <asp:Panel ID="pnlMes" runat="server" CssClass="sigma-modal-field is-chico">
                    <label>Mes(*)</label>
                    <rad:RadComboBox2 ID="cboMes" runat="server" />
                </asp:Panel>
            </div>
        </asp:Panel>

        <%-- ---------- INTERVALO DE TIEMPO (HU-072) ---------- --%>
        <asp:Panel ID="pnlIntervalo" runat="server" Visible="false">
            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-mini">
                    <label>Cada(*)</label>
                    <rad:RadNumericBox2 ID="txtCantidad" runat="server">
                        <NumberFormat DecimalDigits="0" />
                    </rad:RadNumericBox2>
                </div>

                <div class="sigma-modal-field is-chico">
                    <label>Unidad(*)</label>
                    <rad:RadComboBox2 ID="cboUnidadTiempo" runat="server" />
                </div>

                <div class="sigma-modal-field is-chico">
                    <label>Contado desde</label>
                    <WebControls:Calendar ID="calAncla" runat="server" />
                    <span class="sigma-modal-ayuda">Vacío usa el inicio de vigencia.</span>
                </div>

                <div class="sigma-modal-field is-medio">
                    <label>Modo</label>
                    <asp:RadioButton ID="rdbDesdeProgramada" runat="server" GroupName="ModoIntervalo"
                        Text="Desde la fecha programada" Checked="true" />
                    <asp:RadioButton ID="rdbDesdeEjecucion" runat="server" GroupName="ModoIntervalo"
                        Text="Desde la última ejecución" />
                    <span class="sigma-modal-ayuda">
                        <strong>Desde la programada:</strong> un atraso no desplaza las siguientes,
                        el calendario del año se mantiene.<br />
                        <strong>Desde la ejecución:</strong> el intervalo se cuenta desde que se
                        hizo de verdad, así que un atraso corre todo lo que viene.
                    </span>
                </div>
            </div>
        </asp:Panel>

        <%-- ---------- MEDIDOR (HU-073) ---------- --%>
        <asp:Panel ID="pnlMedidor" runat="server" Visible="false">
            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-medio">
                    <label>Medidor(*)</label>
                    <rad:RadComboBox2 ID="cboMedidor" runat="server" />
                </div>

                <div class="sigma-modal-field is-chico">
                    <label>Valor inicial</label>
                    <rad:RadNumericBox2 ID="txtValorInicial" runat="server">
                        <NumberFormat DecimalDigits="2" />
                    </rad:RadNumericBox2>
                    <span class="sigma-modal-ayuda">Vacío toma la lectura actual del equipo.</span>
                </div>

                <div class="sigma-modal-field is-chico">
                    <label>Cada(*)</label>
                    <rad:RadNumericBox2 ID="txtCadaCantidad" runat="server">
                        <NumberFormat DecimalDigits="2" />
                    </rad:RadNumericBox2>
                    <span class="sigma-modal-ayuda">Por ejemplo 500 horas.</span>
                </div>

                <div class="sigma-modal-field is-chico">
                    <label>Avisar antes de</label>
                    <rad:RadNumericBox2 ID="txtAviso" runat="server">
                        <NumberFormat DecimalDigits="2" />
                    </rad:RadNumericBox2>
                    <span class="sigma-modal-ayuda">
                        Genera una alerta al acercarse. La alerta por sí sola no crea una orden.
                    </span>
                </div>

                <asp:Panel ID="pnlMedidorEstado" runat="server" Visible="false" CssClass="sigma-modal-note">
                    <i class="mdi mdi-gauge"></i>
                    <div><asp:Literal ID="litMedidorEstado" runat="server" /></div>
                </asp:Panel>
            </div>
        </asp:Panel>

        <%-- ---------- CONDICIÓN (HU-074) ---------- --%>
        <asp:Panel ID="pnlCondicion" runat="server" Visible="false">
            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-medio">
                    <label>Variable</label>
                    <rad:RadComboBox2 ID="cboVariable" runat="server" />
                </div>
                <div class="sigma-modal-field is-chico">
                    <label>Operador</label>
                    <rad:RadComboBox2 ID="cboOperador" runat="server" />
                </div>
                <div class="sigma-modal-field is-mini">
                    <label>Umbral</label>
                    <rad:RadNumericBox2 ID="txtUmbral" runat="server">
                        <NumberFormat DecimalDigits="2" />
                    </rad:RadNumericBox2>
                </div>
                <div class="sigma-modal-field is-mini">
                    <label>Hasta</label>
                    <rad:RadNumericBox2 ID="txtUmbralHasta" runat="server">
                        <NumberFormat DecimalDigits="2" />
                    </rad:RadNumericBox2>
                    <span class="sigma-modal-ayuda">Solo para "Entre".</span>
                </div>
                <div class="sigma-modal-field is-mini">
                    <label>Durante (min)</label>
                    <rad:RadNumericBox2 ID="txtDuracionMinima" runat="server">
                        <NumberFormat DecimalDigits="0" />
                    </rad:RadNumericBox2>
                    <span class="sigma-modal-ayuda">Evita el pico aislado.</span>
                </div>
                <div class="sigma-modal-field is-chico">
                    <label>Severidad</label>
                    <rad:RadComboBox2 ID="cboSeveridad" runat="server" />
                </div>
                <div class="sigma-modal-field is-mini">
                    <label>&nbsp;</label>
                    <WebControls:PushButton ID="btnAgregarCondicion" runat="server" Text="Agregar"
                        OnClick="btnAgregarCondicion_Click" CausesValidation="false" />
                </div>
                <div class="sigma-modal-field is-ancho">
                    <rad:RadGrid2 ID="grdCondiciones" runat="server"
                        OnItemDataBound="grdCondiciones_ItemDataBound"
                        OnItemCommand="grdCondiciones_ItemCommand">
                        <MasterTableView CommandItemDisplay="None" DataKeyNames="pco_id" />
                    </rad:RadGrid2>
                </div>
            </div>
        </asp:Panel>

        <asp:Panel ID="pnlGuardarPrimero" runat="server" Visible="false" CssClass="sigma-modal-note">
            <i class="mdi mdi-information-outline"></i>
            <div>
                Guarde primero la programación. La regla, las exclusiones y las próximas fechas
                se definen sobre una programación que ya existe.
            </div>
        </asp:Panel>
    </asp:Panel>

    <%-- ============================================================
         VENTANA DE CUMPLIMIENTO (HU-075 #1)
         ============================================================ --%>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-clock-check-outline"></i>Ventana de cumplimiento</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Tolerancia antes</label>
                <rad:RadNumericBox2 ID="txtToleranciaAntes" runat="server">
                    <NumberFormat DecimalDigits="0" />
                </rad:RadNumericBox2>
                <span class="sigma-modal-ayuda">En minutos. 2880 son 2 días.</span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Tolerancia después</label>
                <rad:RadNumericBox2 ID="txtToleranciaDespues" runat="server">
                    <NumberFormat DecimalDigits="0" />
                </rad:RadNumericBox2>
                <span class="sigma-modal-ayuda">
                    Una ejecución dentro de la ventana se considera cumplida en fecha.
                </span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Se puede ejecutar</label>
                <asp:CheckBox ID="chkPermiteAnticipada" runat="server" Text="Antes de la fecha" />
                <asp:CheckBox ID="chkPermiteAtrasada" runat="server" Text="Después de la fecha" />
            </div>

            <asp:Panel ID="pnlPolitica" runat="server" CssClass="sigma-modal-field is-chico">
                <label>Política(*)</label>
                <rad:RadComboBox2 ID="cboPolitica" runat="server" />
                <span class="sigma-modal-ayuda">
                    Con varias condiciones: si basta una o si tienen que cumplirse todas.
                </span>
            </asp:Panel>
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Genera automáticamente</label>
                <asp:RadioButton ID="rdbGeneraSi" runat="server" GroupName="Genera" Text="Sí" Checked="true" />
                <asp:RadioButton ID="rdbGeneraNo" runat="server" GroupName="Genera" Text="No" />
                <span class="sigma-modal-ayuda">En No, solo genera cuando alguien lo pide.</span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Habilitada</label>
                <asp:RadioButton ID="rdbSi" runat="server" GroupName="Habilitado" Text="Sí" Checked="true" />
                <asp:RadioButton ID="rdbNo" runat="server" GroupName="Habilitado" Text="No" />
                <span class="sigma-modal-ayuda">
                    Deshabilitada deja de generar y conserva lo ya generado.
                </span>
            </div>
        </div>
    </div>

    <%-- ============================================================
         EXCLUSIONES (HU-075 #2 y #3)
         ============================================================ --%>

    <asp:Panel ID="pnlExclusiones" runat="server" Visible="false" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-remove"></i>Exclusiones</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Desde</label>
                <WebControls:Calendar ID="calExclusionDesde" runat="server" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Hasta</label>
                <WebControls:Calendar ID="calExclusionHasta" runat="server" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Motivo</label>
                <WebControls:TextBox2 ID="txtExclusionMotivo" runat="server" MaxLength="400" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Efecto</label>
                <asp:RadioButton ID="rdbExcluye" runat="server" GroupName="Efecto"
                    Text="No generar nada" Checked="true" />
                <asp:RadioButton ID="rdbDesplaza" runat="server" GroupName="Efecto"
                    Text="Correr al siguiente hábil" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>&nbsp;</label>
                <WebControls:PushButton ID="btnAgregarExclusion" runat="server" Text="Agregar"
                    OnClick="btnAgregarExclusion_Click" CausesValidation="false" />
            </div>

            <div class="sigma-modal-field is-ancho">
                <span class="sigma-modal-ayuda">
                    <strong>No generar nada</strong> es la parada de planta: en ese período
                    simplemente no hay trabajo programado.<br />
                    <strong>Correr al siguiente hábil</strong> es el feriado: la fecha se desplaza
                    y la original queda registrada, para que después se sepa por qué se movió.
                </span>
            </div>

            <div class="sigma-modal-field is-ancho">
                <rad:RadGrid2 ID="grdExclusiones" runat="server"
                    OnItemDataBound="grdExclusiones_ItemDataBound"
                    OnItemCommand="grdExclusiones_ItemCommand">
                    <MasterTableView CommandItemDisplay="None" DataKeyNames="pxc_id" />
                </rad:RadGrid2>
            </div>
        </div>
    </asp:Panel>

    <%-- ============================================================
         PRÓXIMAS FECHAS — la vista previa

         No son ocurrencias: es el cálculo de FNC_PROGRAMACION_FECHAS.
         Sirve para ver si la regla dice lo que uno cree que dice ANTES
         de que empiece a generar trabajo de verdad.
         ============================================================ --%>

    <asp:Panel ID="pnlProyeccion" runat="server" Visible="false" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-search"></i>Próximas fechas</div>
        <asp:Literal ID="litProyeccion" runat="server" />
    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Programacion" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
