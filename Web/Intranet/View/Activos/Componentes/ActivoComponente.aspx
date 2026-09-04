<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoComponente.aspx.cs" Inherits="View_Activos_Componentes_ActivoComponente" %>
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

    <h1 class="sigma-modal-title">Componente del activo</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-puzzle-outline"></i>Identificación</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Activo(*)</label>
                <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                    OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Comp" />
                <span class="sigma-modal-ayuda">La máquina a la que pertenece. No se cambia después.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código</label>
                <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                     lo escribe quien crea el registro. Van juntos en una sola
                     caja para que se lea como UN codigo y no como dos campos. --%>
                <div class="sg-codigo">
                    <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                    <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" ReadOnly="true" />
                </div>
                <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Comp" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Tipo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Comp" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Estado(*)</label>
                <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Comp" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Criticidad(*)</label>
                <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Comp" />
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

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Detalle</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Posición</label>
                <rad:RadComboBox2 ID="cboPosicion" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Dónde va en el activo. Opcional.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Componente superior</label>
                <rad:RadComboBox2 ID="cboPadre" runat="server" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Solo los del mismo activo. Vacío = de primer nivel.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Fecha de instalación</label>
                <div class="sigma-modal-fecha"><WebControls:Calendar ID="calInstalacion" runat="server" /></div>
                <span class="sigma-modal-ayuda">Elija la fecha. Vacío indica sin dato.</span>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Comp" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
