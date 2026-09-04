<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="UnidadMedida.aspx.cs" Inherits="View_Sistema_UnidadesMedida_UnidadMedida" %>
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

    <h1 class="sigma-modal-title">Unidad de medida</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-ruler"></i>Identificación</div>

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
                    <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="20" ReadOnly="true" />
                </div>
                <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="100" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Unidad" />
            </div>
            <div class="sigma-modal-field is-mini">
                <label>Símbolo(*)</label>
                <WebControls:TextBox2 ID="txtSimbolo" runat="server" MaxLength="20" />
                <asp:CustomValidator ID="cvSimbolo" runat="server" ControlToValidate="txtSimbolo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Unidad" />
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Magnitud(*)</label>
                <rad:RadComboBox2 ID="cboMagnitud" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvMagnitud" runat="server" ControlToValidate="cboMagnitud"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Unidad" />
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitada(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-swap-horizontal"></i>Conversión</div>

        <div class="sigma-modal-note">
            <i class="mdi mdi-information-outline"></i>
            <div>
                La <strong>unidad base</strong> es la de referencia de la magnitud (cada magnitud tiene una sola).
                Deje vacío para que <strong>esta</strong> sea la base. El <strong>factor</strong> y el <strong>offset</strong>
                convierten a la base: 1&nbsp;km = <strong>1000</strong> m (factor); 0&nbsp;°C = 273,15 K (offset).
            </div>
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Unidad base</label>
                <rad:RadComboBox2 ID="cboBase" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">De la misma magnitud. Vacío = esta es la base.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Factor</label>
                <WebControls:TextBox2 ID="txtFactor" runat="server" MaxLength="20" />
                <span class="sigma-modal-ayuda">Cuánto vale 1 de esta unidad en la base. Por defecto 1.</span>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Offset</label>
                <WebControls:TextBox2 ID="txtOffset" runat="server" MaxLength="20" />
                <span class="sigma-modal-ayuda">Desfase respecto a la base. Por defecto 0.</span>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Unidad" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
