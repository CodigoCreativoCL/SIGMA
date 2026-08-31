<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Organizacion_Grupos_Grupo, App_Web_h1ntucqv" %>

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
    <h1 class="sigma-modal-title">Grupo de trabajo</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>ID</label>
        <asp:Label ID="lblId" runat="server"></asp:Label>
    </div>
    <div class="sigma-modal-field">
        <label>Código(*)</label>
        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Grupo" />
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Grupo" />
        <span class="sigma-modal-ayuda">Por ejemplo: Turno noche mecánicos.</span>
    </div>
    <div class="sigma-modal-field">
        <label>Planta</label>
        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="80%" />
        <span class="sigma-modal-ayuda">
        Vacío indica un grupo transversal, asignable en todas las plantas del cliente.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Especialidad predominante</label>
        <rad:RadComboBox2 ID="cboEspecialidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="80%" />
    </div>
    <div class="sigma-modal-field is-ancho">
        <label>Descripción</label>
        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado(*)</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Grupo" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Grupo" />
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Grupo" />
</div>

            <%-- ---------- Integrantes ----------
                 Solo aparecen cuando el grupo ya existe: un integrante
                 necesita un grupo al que pertenecer. --%>
            <asp:Panel ID="pnlIntegrantes" runat="server" Visible="false">

                <div class="sigma-modal-seccion">Integrantes</div>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field is-ancho">
        <label>Persona</label>
        <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="100%" />
    </div>
    <div class="sigma-modal-field">
        <label>Desde</label>
        <WebControls:Calendar ID="calDesde" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Hasta</label>
        <WebControls:Calendar ID="calHasta" runat="server" />
    </div>
    <div class="sigma-modal-field">
        <label>Rol</label>
        <div class="sigma-modal-opciones">
            <asp:CheckBox ID="chkEsLider" runat="server" Text=" Es líder" />
        </div>
    </div>
    <div class="sigma-modal-field">
        <label>&nbsp;</label>
        <WebControls:PushButton ID="btnAgregar" runat="server" Text="Agregar" OnClick="btnAgregar_Click" />
    </div>
                </div>

                <rad:RadGrid2 ID="GridIntegrantes" runat="server"
                    OnItemCreated="GridIntegrantes_ItemCreated"
                    OnItemDataBound="GridIntegrantes_ItemDataBound">
                    <MasterTableView CommandItemDisplay="None" DataKeyNames="gtu_id">
                    </MasterTableView>
                </rad:RadGrid2>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
