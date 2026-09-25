<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="RegistrarLectura.aspx.cs" Inherits="View_Activos_Ficha_RegistrarLectura" %>

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

    <h1 class="sigma-modal-title">Registrar lectura</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-gauge"></i>Qué se midió</div>
        <div class="sigma-modal-grid">

            <div class="sigma-modal-field is-medio">
                <label>Equipo</label>
                <asp:Label ID="lblActivo" runat="server" CssClass="sigma-modal-lectura" />
            </div>

            <%-- Variables y contadores en un solo desplegable: quien anota un
                 numero sabe QUE midio, no si el sistema lo guarda en una tabla
                 o en la otra. El prefijo del valor dice cual es cual. --%>
            <div class="sigma-modal-field is-medio">
                <label>Variable o contador(*)</label>
                <rad:RadComboBox2 ID="cboQue" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="cboQue_SelectedIndexChanged" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvQue" runat="server" ControlToValidate="cboQue"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Lectura" />
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Valor(*)</label>
                <WebControls:TextBox2 ID="txtValor" runat="server" MaxLength="18" />
                <asp:CustomValidator ID="cvValor" runat="server" ControlToValidate="txtValor"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Lectura" />
                <span class="sigma-modal-ayuda"><asp:Literal ID="litUnidad" runat="server" /></span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Fecha(*)</label>
                <div class="sigma-modal-fecha"><WebControls:Calendar ID="calFecha" runat="server" /></div>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Hora</label>
                <rad:RadComboBox2 ID="cboHora" runat="server" OnLoad="LoadControls" AllowCustomText="true"
                    MarkFirstMatch="true" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Vacío: la medianoche de ese día.</span>
            </div>

            <%-- Un contador no baja. Cuando de verdad se reinicio -se cambio el
                 motor, se reseteo el tablero- hay que declararlo, o el SP
                 rechaza el valor por ser menor al anterior. --%>
            <div class="sigma-modal-field is-chico" id="pnlReinicio" runat="server" visible="false">
                <label>¿Es un reinicio del contador?</label>
                <asp:RadioButton ID="rdbReinicioSi" runat="server" GroupName="Reinicio" Text="Sí" />
                <asp:RadioButton ID="rdbReinicioNo" runat="server" GroupName="Reinicio" Text="No" Checked="true" />
            </div>

            <div class="sigma-modal-field is-grande">
                <label>Observación</label>
                <WebControls:TextBox2 ID="txtObservacion" runat="server" MaxLength="500" TextMode="MultiLine" Rows="2" />
                <span class="sigma-modal-ayuda">De dónde salió el dato: quién lo reportó, con qué instrumento.</span>
            </div>
        </div>

        <asp:Literal ID="litContexto" runat="server" />
    </div>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Registrar" OnClick="btnGuardar_Click" ValidationGroup="Lectura" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
