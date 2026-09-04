<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CentroCosto.aspx.cs" Inherits="View_Organizacion_CentrosCosto_CentroCosto" %>

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
    <h1 class="sigma-modal-title">Centro de costo</h1>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>ID</label>
        <asp:Label ID="lblId" runat="server"></asp:Label>
    </div>
    <div class="sigma-modal-field">
        <label>Código</label>
        <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
             lo escribe quien crea el registro. Van juntos en una sola
             caja para que se lea como UN codigo y no como dos campos. --%>
        <div class="sg-codigo">
            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
        </div>
                        <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="CentroCosto" />
        <span class="sigma-modal-ayuda">Único dentro del cliente.</span>
    </div>
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="CentroCosto" />
    </div>
    <div class="sigma-modal-field">
        <label>Depende de</label>
        <rad:RadComboBox2 ID="cboPadre" runat="server" OnLoad="LoadControls" Filter="Contains" Width="80%" />
        <span class="sigma-modal-ayuda">
        Vacío indica que es de primer nivel. El costo de un centro suma al de su superior.
        </span>
    </div>
    <div class="sigma-modal-field">
        <label>Habilitado(*)</label>
        <div class="sigma-modal-opciones">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="CentroCosto" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="CentroCosto" />
        </div>
    </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="CentroCosto" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
