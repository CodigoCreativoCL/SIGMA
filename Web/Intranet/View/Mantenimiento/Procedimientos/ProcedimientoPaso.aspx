<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ProcedimientoPaso.aspx.cs" Inherits="View_Mantenimiento_Procedimientos_ProcedimientoPaso" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-procedimiento.css?vrs=2") %>' rel="stylesheet" />
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
<div class="sigma-modal sg-proc-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <%-- ENCABEZADO --%>
    <div class="sg-proc-cab">
        <div>
            <span class="sg-proc-eyebrow"><asp:Literal ID="litModo" runat="server" Text="Nuevo paso" /></span>
            <h1 class="sg-proc-titulo">
                <asp:Literal ID="litTitulo" runat="server" Text="Paso del procedimiento" />
                <span class="sg-proc-id">ID <asp:Label ID="lblId" runat="server" /></span>
                <asp:Literal ID="litEstado" runat="server" />
            </h1>
            <p class="sg-proc-bajada">
                Un paso de la receta: qué hacer y en qué orden. Los pasos se ejecutan en el orden indicado.
            </p>
        </div>
    </div>

    <asp:Panel ID="pnlGlobal" runat="server" Visible="false" CssClass="sg-proc-aviso">
        <i class="mdi mdi-information-outline"></i>
        <span>Este paso pertenece a un procedimiento <strong>global del sistema</strong>: se puede ver pero no se edita desde aquí.</span>
    </asp:Panel>

    <div class="sg-proc">
        <div class="sg-proc-form">

            <%-- ====== A — UBICACION DEL PASO ====== --%>
            <div class="sg-proc-card">
                <div class="sg-proc-card-cab">
                    <span class="sg-proc-letra">A</span>
                    <div>
                        <div class="sg-proc-card-titulo">Ubicación del paso</div>
                        <div class="sg-proc-card-bajada">A qué procedimiento pertenece, su orden y su nombre.</div>
                    </div>
                </div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-grande">
                        <label>Procedimiento(*)</label>
                        <rad:RadComboBox2 ID="cboProcedimiento" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">La receta a la que pertenece este paso.</span>
                    </div>
                    <div class="sigma-modal-field is-mini">
                        <label>Orden</label>
                        <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="4" />
                        <span class="sigma-modal-ayuda">Vacío = al final.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Nombre del paso(*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Paso" />
                    </div>
                </div>
            </div>

            <%-- ====== B — INSTRUCCION ====== --%>
            <div class="sg-proc-card">
                <div class="sg-proc-card-cab">
                    <span class="sg-proc-letra">B</span>
                    <div>
                        <div class="sg-proc-card-titulo">Instrucción</div>
                        <div class="sg-proc-card-bajada">Qué debe hacer el técnico en este paso.</div>
                    </div>
                </div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-grande">
                        <label>Detalle</label>
                        <WebControls:TextArea2 ID="txtInstruccion" runat="server" MaxLength="4000" />
                    </div>
                </div>
            </div>

            <%-- ====== C — CONTROLES ====== --%>
            <div class="sg-proc-card">
                <div class="sg-proc-card-cab">
                    <span class="sg-proc-letra">C</span>
                    <div>
                        <div class="sg-proc-card-titulo">Controles del paso</div>
                        <div class="sg-proc-card-bajada">Punto de control, evidencia y medición.</div>
                    </div>
                </div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>¿Es punto de control?(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbPcSi" runat="server" Text="SI" GroupName="Pc" />
                            <asp:RadioButton ID="rdbPcNo" runat="server" Text="NO" GroupName="Pc" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">No se avanza hasta resolverlo.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>¿Requiere evidencia?(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbEvSi" runat="server" Text="SI" GroupName="Ev" />
                            <asp:RadioButton ID="rdbEvNo" runat="server" Text="NO" GroupName="Ev" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Ej. foto o firma al ejecutarlo.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>¿Requiere medición?(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbMedSi" runat="server" Text="SI" GroupName="Med" AutoPostBack="true" OnCheckedChanged="rdbMed_CheckedChanged" />
                            <asp:RadioButton ID="rdbMedNo" runat="server" Text="NO" GroupName="Med" Checked="true" AutoPostBack="true" OnCheckedChanged="rdbMed_CheckedChanged" />
                        </div>
                        <span class="sigma-modal-ayuda">Pide un valor que queda en la serie del activo.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Variable a medir</label>
                        <rad:RadComboBox2 ID="cboVariable" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Obligatoria si el paso requiere medición.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Duración estimada (min)</label>
                        <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="5" />
                        <span class="sigma-modal-ayuda">Cuánto suele tomar. Opcional.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Habilitado(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                    </div>
                </div>
            </div>

            <wuc:Auditoria runat="server" ID="wucAuditoria" />
        </div>

        <%-- ====== RESUMEN LATERAL ====== --%>
        <aside class="sg-proc-resumen">
            <h3><i class="mdi mdi-lightbulb-on-outline"></i>Cómo funciona</h3>
            <p>Cada paso se ejecuta en el orden indicado. Al generar una orden desde el procedimiento se crea un paso por cada uno.</p>
            <ul class="sg-proc-tips">
                <li><i class="mdi mdi-sort-numeric-variant"></i><span>El <strong>orden</strong> es único dentro del procedimiento.</span></li>
                <li><i class="mdi mdi-check-decagram-outline"></i><span>Un <strong>punto de control</strong> obliga a resolverlo antes de seguir.</span></li>
                <li><i class="mdi mdi-gauge"></i><span>Si <strong>requiere medición</strong>, elija la variable: su valor queda en la serie histórica del activo.</span></li>
            </ul>
        </aside>
    </div>

    <%-- PIE: acciones al final --%>
    <div class="sg-proc-footer">
        <div class="sg-proc-cab-acciones">
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar paso" OnClick="btnGuardar_Click" ValidationGroup="Paso" />
        </div>
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
