<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PermisoUsuario.aspx.cs" Inherits="View_Root_Mantenedores_PermisosUsuario_PermisoUsuario" %>

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
    <h1 class="sigma-modal-title">Permiso puntual</h1>

    <%-- LAS DOS REJILLAS ESTABAN PARTIDAS POR EL MEDIO

         Entre el bloque de arriba y el de las fechas había dos paneles con
         la rejilla Bootstrap heredada —col-lg-3 para el rótulo, col-lg-9
         para el combo— que no es la del resto del sitio. Al aparecer, esas
         dos filas rompían la alineación de todo lo que venía después: los
         rótulos quedaban a la izquierda en vez de encima, y el ancho no
         coincidía con ninguna columna de las rejillas vecinas.

         Ahora los dos son campos como cualquier otro y viven DENTRO de la
         misma rejilla, así que aparecer o desaparecer no mueve nada más. --%>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-key-outline"></i>Qué se concede y a quién</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mitad">
                <label>Usuario(*)</label>
                <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvUsuario" runat="server" ControlToValidate="cboUsuario"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
                <span class="sigma-modal-ayuda">La lista muestra el perfil de cada persona.</span>
            </div>

            <div class="sigma-modal-field is-mitad">
                <label>Permiso(*)</label>
                <rad:RadComboBox2 ID="cboPermiso" runat="server" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvPermiso" runat="server" ControlToValidate="cboPermiso"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
                <span class="sigma-modal-ayuda">
                    Sólo aparecen los permisos que pueden concederse a una persona.
                </span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Efecto(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbConcede" runat="server" Text="Concede" GroupName="Efecto" Checked="true" />
                    <asp:RadioButton ID="rdbDeniega" runat="server" Text="Deniega" GroupName="Efecto" />
                </div>
                <span class="sigma-modal-ayuda">Denegar prevalece sobre el permiso del perfil.</span>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Hasta dónde alcanza</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Ámbito(*)</label>
                <rad:RadComboBox2 ID="cboAmbito" runat="server" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboAmbito_SelectedIndexChanged">
                    <Items>
                        <rad:RadComboBoxItem Text="Todo el cliente" Value="CLIENTE" Selected="true" />
                        <rad:RadComboBoxItem Text="Una planta" Value="PLANTA" />
                        <rad:RadComboBoxItem Text="Un área" Value="AREA" />
                    </Items>
                </rad:RadComboBox2>
            </div>

            <asp:Panel ID="pnlPlanta" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                <label>Planta(*)</label>
                <rad:RadComboBox2 ID="cboPlanta" runat="server" Filter="Contains" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" />
            </asp:Panel>

            <asp:Panel ID="pnlArea" runat="server" Visible="false" CssClass="sigma-modal-field is-mitad">
                <label>Área(*)</label>
                <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="100%" />
            </asp:Panel>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-calendar-range"></i>Desde cuándo y por qué</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Vigente desde</label>
                <div class="sigma-modal-fecha">
                    <WebControls:Calendar ID="calDesde" runat="server" />
                </div>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Vigente hasta</label>
                <div class="sigma-modal-fecha">
                    <WebControls:Calendar ID="calHasta" runat="server" />
                </div>
                <span class="sigma-modal-ayuda">Vacío indica sin vencimiento.</span>
            </div>

            <div class="sigma-modal-field is-ancho">
                <label>Motivo(*)</label>
                <WebControls:TextArea2 ID="txtMotivo" runat="server" MaxLength="500" />
                <asp:CustomValidator ID="cvMotivo" runat="server" ControlToValidate="txtMotivo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
                <span class="sigma-modal-ayuda">
                    Al menos 10 caracteres. Queda registrado junto a quién lo concedió y cuándo.
                </span>
            </div>
        </div>
    </div>
<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Permiso" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
