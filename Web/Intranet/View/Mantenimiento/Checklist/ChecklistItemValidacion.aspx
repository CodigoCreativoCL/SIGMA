<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistItemValidacion.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistItemValidacion" %>
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

    <h1 class="sigma-modal-title">Umbrales y acciones del ítem</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-format-list-checks"></i>Ítem</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <asp:Panel ID="pnlItemNuevo" runat="server" CssClass="sigma-modal-field is-grande">
                <label>Ítem(*)</label>
                <rad:RadComboBox2 ID="cboItem" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvItem" runat="server" ControlToValidate="cboItem"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Val" />
                <span class="sigma-modal-ayuda">La pauta, la sección y el ítem al que se aplican los umbrales. Cada ítem tiene una sola validación.</span>
            </asp:Panel>
            <asp:Panel ID="pnlItemEdita" runat="server" Visible="false" CssClass="sigma-modal-field is-grande">
                <label>Ítem</label>
                <asp:Literal ID="litItem" runat="server" />
            </asp:Panel>
        </div>
    </div>

    <%-- ============ UMBRALES NUMÉRICOS ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-gauge"></i>Umbrales numéricos</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>Mínimo</label>
                <WebControls:TextBox2 ID="txtMinimo" runat="server" MaxLength="20" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Advertencia</label>
                <WebControls:TextBox2 ID="txtAdvertencia" runat="server" MaxLength="20" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Crítico</label>
                <WebControls:TextBox2 ID="txtCritico" runat="server" MaxLength="20" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Máximo</label>
                <WebControls:TextBox2 ID="txtMaximo" runat="server" MaxLength="20" />
            </div>
            <div class="sigma-modal-field is-grande">
                <span class="sigma-modal-ayuda">Fuera de [mínimo, máximo] es crítico. Dentro, ≥ crítico es crítico y ≥ advertencia es advertencia. Deje en blanco lo que no aplique.</span>
            </div>
        </div>
    </div>

    <%-- ============ VALIDACIÓN DE TEXTO (opcional) ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-format-text"></i>Texto (opcional)</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>Largo mínimo</label>
                <WebControls:TextBox2 ID="txtLargoMin" runat="server" MaxLength="6" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Largo máximo</label>
                <WebControls:TextBox2 ID="txtLargoMax" runat="server" MaxLength="6" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Expresión regular</label>
                <WebControls:TextBox2 ID="txtExpresion" runat="server" MaxLength="400" />
            </div>
        </div>
    </div>

    <%-- ============ ACCIONES FUERA DE RANGO ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-alert-decagram"></i>Acciones cuando sale de rango</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label class="sg-ta-toggle"><asp:CheckBox ID="chkComentario" runat="server" /><span>Exigir comentario</span></label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label class="sg-ta-toggle"><asp:CheckBox ID="chkEvidencia" runat="server" /><span>Exigir fotografía</span></label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label class="sg-ta-toggle"><asp:CheckBox ID="chkAlerta" runat="server" /><span>Generar alerta</span></label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label class="sg-ta-toggle"><asp:CheckBox ID="chkHallazgo" runat="server" /><span>Generar hallazgo</span></label>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Mensaje</label>
                <WebControls:TextBox2 ID="txtMensaje" runat="server" MaxLength="400" />
                <span class="sigma-modal-ayuda">El texto que ve el técnico cuando la respuesta sale de rango.</span>
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

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Val" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
