<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Root_Mantenedores_Menu, App_Web_cfzyid50" %>

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
    <h1 class="sigma-modal-title">Menú</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>ID</label>
        <asp:Label ID="lblId" runat="server"></asp:Label>
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="100" />
        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Menu" />
    </div>
    <div class="sigma-modal-field">
        <label>Descripción</label>
        <WebControls:TextBox2 ID="txtDescripcion" runat="server" MaxLength="200" />
    </div>
    <div class="sigma-modal-field">
        <label>Depende de</label>
        <rad:RadComboBox2 ID="cboPadre" runat="server" Width="60%" />
    </div>
    </div>
    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Nivel(*)</label>
        <WebControls:TextBox2 ID="txtNivel" runat="server" MaxLength="2" />
    </div>
    <div class="sigma-modal-field">
        <label>Orden(*)</label>
        <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="3" />
    </div>
    <div class="sigma-modal-field">
        <label>Página</label>
        <WebControls:TextBox2 ID="txtLink" runat="server" MaxLength="200" />
        <span class="sigma-modal-ayuda">
        Ruta tal cual, por ejemplo ~/View/Sistema/Mantenedores/Paises/Paises.aspx.
        Dejar en # si es una carpeta que solo agrupa otros menús.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Permiso</label>
        <rad:RadComboBox2 ID="cboPermiso" runat="server" Width="60%" />
        <span class="sigma-modal-ayuda">
        Obligatorio cuando hay página. Es lo que se exige al abrirla.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Ícono</label>
        <WebControls:TextBox2 ID="txtIcon" runat="server" MaxLength="100" />
        <span class="sigma-modal-ayuda">
        Clase de Material Design Icons, por ejemplo
        <b>mdi mdi-account-group-outline</b>. Todo el sitio usa MDI;
        no mezclar con Font Awesome.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Visible(*)</label>
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Visible" Checked="true" ValidationGroup="Menu" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Visible" ValidationGroup="Menu" />
        <span class="sigma-modal-ayuda">
        NO es una página que existe pero no aparece en el menú lateral,
        como las ventanas de detalle.
        </span>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Menu" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
