<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PlanActividad.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanActividad" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
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

    <h1 class="sigma-modal-title">Actividad del hito</h1>

    <asp:Panel ID="pnlBloqueado" runat="server" Visible="false" CssClass="sigma-modal-ayuda" style="margin-bottom:12px;">
        <%-- La version de este hito ya no esta en borrador: se lee, no se
             edita. Se dice arriba y no al apretar Guardar, que es cuando ya
             se escribio todo. --%>
        <i class="mdi mdi-lock-outline"></i>
        Esta actividad pertenece a una versión <strong><asp:Literal ID="litEstadoVersion" runat="server" /></strong> y ya no se puede modificar. Para cambiarla, abra una versión nueva del plan.
    </asp:Panel>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-checkbox-marked-circle-outline"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Hito(*)</label>
                <rad:RadComboBox2 ID="cboHito" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvHito" runat="server" ControlToValidate="cboHito"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanActividad" />
                <span class="sigma-modal-ayuda">Solo los hitos de una versión en borrador. El hito dice cada cuánto; la actividad dice qué se hace.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código(*)</label>
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanActividad" />
                <span class="sigma-modal-ayuda">Único dentro del hito. Por ejemplo <em>ACT-010</em>.</span>
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Orden</label>
                <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="3" />
                <span class="sigma-modal-ayuda">Vacío: al final.</span>
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="PlanActividad" />
                <span class="sigma-modal-ayuda">Lo que hay que hacer, en la forma en que se le diría al técnico: <em>Revisar acople y alineación</em>.</span>
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
            </div>
        </div>
    </div>

    <%-- ============ CÓMO SE HACE ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-clipboard-list-outline"></i>Cómo se hace</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Procedimiento</label>
                <rad:RadComboBox2 ID="cboProcedimiento" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Sus pasos se copian dentro de la orden que genere el hito. Opcional: una actividad simple no necesita procedimiento.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Duración estimada (min)</label>
                <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="6" />
                <span class="sigma-modal-ayuda">Vacío: se usa la del procedimiento, si tiene.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Obligatoria(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbObligatoriaSi" runat="server" Text="SI" GroupName="Obligatoria" Checked="true" />
                    <asp:RadioButton ID="rdbObligatoriaNo" runat="server" Text="NO" GroupName="Obligatoria" />
                </div>
                <span class="sigma-modal-ayuda">Una actividad obligatoria no deja cerrar la orden sin resultado.</span>
            </div>
        </div>
    </div>

    <%-- ============ SEGURIDAD ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-shield-alert-outline"></i>Seguridad</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Requiere parada</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbParadaSi" runat="server" Text="SI" GroupName="Parada" />
                    <asp:RadioButton ID="rdbParadaNo" runat="server" Text="NO" GroupName="Parada" Checked="true" />
                </div>
                <span class="sigma-modal-ayuda">La actividad exige el equipo detenido, aunque el hito completo no.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Requiere permiso</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbPermisoSi" runat="server" Text="SI" GroupName="Permiso" />
                    <asp:RadioButton ID="rdbPermisoNo" runat="server" Text="NO" GroupName="Permiso" Checked="true" />
                </div>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Tipo de permiso</label>
                <rad:RadComboBox2 ID="cboPermisoTipo" runat="server" OnLoad="LoadControls" Width="100%" />
                <span class="sigma-modal-ayuda">Obligatorio si la actividad requiere permiso: «pide permiso» sin decir de qué no sirve para emitirlo.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="PlanActividad" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="PlanActividad" />
                </div>
            </div>
        </div>
    </div>

    <%-- ============ REPUESTOS PLANIFICADOS ============
         Solo al editar: los repuestos cuelgan de la actividad, y al crear
         todavia no tiene id del cual colgar. Se guarda primero y se agregan
         despues, que es el mismo orden que sigue la imagen del componente. --%>
    <asp:Panel ID="pnlRepuestos" runat="server" Visible="false" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-package-variant-closed"></i>Repuestos planificados</div>

        <span class="sigma-modal-ayuda" style="display:block; margin-bottom:8px;">
            Lo que la actividad va a consumir. Al generar la orden de trabajo del hito, estos repuestos entran como <strong>cantidad planificada</strong>, así que el técnico los tiene pedidos antes de llegar al pañol.
        </span>

        <asp:Panel ID="pnlAgregarRepuesto" runat="server" CssClass="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Repuesto</label>
                <rad:RadComboBox2 ID="cboRepuesto" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Cantidad</label>
                <WebControls:TextBox2 ID="txtCantidad" runat="server" MaxLength="10" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Obligatorio</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbRepObligatorioSi" runat="server" Text="SI" GroupName="RepObligatorio" Checked="true" />
                    <asp:RadioButton ID="rdbRepObligatorioNo" runat="server" Text="NO" GroupName="RepObligatorio" />
                </div>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Observación</label>
                <WebControls:TextBox2 ID="txtRepObservacion" runat="server" MaxLength="500" />
            </div>
            <div class="sigma-modal-field is-chico" style="align-self:flex-end;">
                <WebControls:PushButton ID="btnAgregarRepuesto" runat="server" Text="Agregar" OnClick="btnAgregarRepuesto_Click" CausesValidation="false" />
            </div>
        </asp:Panel>

        <asp:Literal ID="litRepuestos" runat="server" />

        <%-- El "Quitar" de cada fila postea aca con el id en el argumento: un
             LinkButton por fila dentro de un Literal no existe como control,
             y un boton por fila en un Repeater seria mas markup para lo
             mismo. --%>
        <asp:LinkButton ID="lnkQuitarRepuesto" runat="server" style="display:none"
            OnClick="lnkQuitarRepuesto_Click" CausesValidation="false" />
    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="PlanActividad" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
