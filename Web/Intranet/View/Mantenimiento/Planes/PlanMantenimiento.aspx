<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PlanMantenimiento.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanMantenimiento" %>
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

    <h1 class="sigma-modal-title">Plan de mantenimiento</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-check-outline"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código</label>
                <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                     lo escribe quien crea el registro. Van juntos en una sola
                     caja para que se lea como UN codigo y no como dos campos. --%>
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
                <%-- Se lee, no se edita: la version se gestiona con sus propias
                     acciones (publicar, retirar) y nunca desde esta ficha. --%>
                <asp:Literal ID="litVersion" runat="server" />
            </div>
            <div class="sigma-modal-field is-ancho">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="2000" />
                <span class="sigma-modal-ayuda">Para qué existe el plan y qué cubre. Lo lee quien lo hereda dentro de dos años.</span>
            </div>
        </div>
    </div>

    <%-- ============ ALCANCE ============ --%>
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
                <span class="sigma-modal-ayuda">La familia de equipos a la que aplica. Vacío indica cualquiera.</span>
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
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="PlanMantenimiento" />
    </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
