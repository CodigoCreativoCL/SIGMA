<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Proveedor.aspx.cs" Inherits="View_Terceros_Proveedores_Proveedor" %>
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

    <h1 class="sigma-modal-title">Proveedor</h1>

    <%-- ============================================================
         DOS SECCIONES Y NO TRES, Y LAS FILAS COMPLETAS

         La rejilla es de 12 columnas y la ficha las estaba gastando:
         "Razón social" ocupaba 6 —media pantalla— para el nombre de una
         empresa, y "Qué hace para nosotros" era una sección entera para
         dos casillas y un sí/no.

         Ahora cada fila suma 12 justas y los tipos viajan con el giro,
         que es lo mismo que están diciendo: a qué se dedica esta empresa
         y qué nos hace a nosotros. Seis filas pasaron a cuatro.
         ============================================================ --%>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-domain"></i>Identificación</div>

        <div class="sigma-modal-grid">

            <%-- Fila 1: 2 + 3 + 4 + 3 = 12 --%>
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>

            <div class="sigma-modal-field is-chico">
                <%-- La etiqueta la pone el país del cliente: "RUT" en Chile,
                     "RUC" en Perú, "CUIT" en Argentina. Escribirla fija en el
                     markup sería correcta en un país de los cinco. --%>
                <label><asp:Literal ID="litRotuloRut" runat="server" Text="RUT" />(*)</label>
                <WebControls:TextBox2 ID="txtRut" runat="server" MaxLength="40" UpperCase="true" />
                <asp:CustomValidator ID="cvRut" runat="server" ControlToValidate="txtRut"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Proveedor" />
                <span class="sigma-modal-ayuda">Único en su empresa. No se le genera un código aparte.</span>
            </div>

            <div class="sigma-modal-field is-medio">
                <label>Razón social(*)</label>
                <WebControls:TextBox2 ID="txtRazonSocial" runat="server" MaxLength="400" />
                <asp:CustomValidator ID="cvRazonSocial" runat="server" ControlToValidate="txtRazonSocial"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Proveedor" />
                <span class="sigma-modal-ayuda">Como aparece en la factura.</span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Nombre de fantasía</label>
                <WebControls:TextBox2 ID="txtNombreFantasia" runat="server" MaxLength="400" />
                <span class="sigma-modal-ayuda">Como lo llaman en la planta. Es lo que se ve en las listas.</span>
            </div>

            <%-- Fila 2: 4 + 5 + 3 = 12 --%>
            <div class="sigma-modal-field is-medio">
                <label>Giro</label>
                <WebControls:TextBox2 ID="txtGiro" runat="server" MaxLength="400" />
            </div>

            <div class="sigma-modal-field is-cinco">
                <label>Qué hace para nosotros(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:CheckBox ID="chkContratista" runat="server" Text=" Contratista" />
                    <asp:CheckBox ID="chkProveedorRepuesto" runat="server" Text=" Proveedor de repuestos" />
                </div>
                <span class="sigma-modal-ayuda">
                    <strong>Al menos una.</strong> No son excluyentes: hay empresas que hacen el
                    montaje y además venden el material.
                </span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Proveedor" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Proveedor" />
                </div>
                <span class="sigma-modal-ayuda">Deshabilitado deja de ofrecerse y conserva su historial.</span>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-card-account-phone-outline"></i>Con quién se habla</div>

        <div class="sigma-modal-grid">

            <%-- Fila 1: 3 + 3 + 2 + 4 = 12 --%>
            <div class="sigma-modal-field is-chico">
                <label>Contacto</label>
                <WebControls:TextBox2 ID="txtContacto" runat="server" MaxLength="400" />
                <span class="sigma-modal-ayuda">La persona, no la empresa.</span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Correo</label>
                <WebControls:TextBox2 ID="txtEmail" runat="server" MaxLength="400" />
            </div>

            <div class="sigma-modal-field is-mini">
                <label>Teléfono</label>
                <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="100" />
            </div>

            <div class="sigma-modal-field is-medio">
                <label>Dirección</label>
                <WebControls:TextBox2 ID="txtDireccion" runat="server" MaxLength="600" />
            </div>

            <%-- La observación sí ocupa el ancho: es texto libre y en tres
                 columnas se escribe en una rendija. --%>
            <div class="sigma-modal-field is-ancho">
                <label>Observación</label>
                <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="1000" />
            </div>
        </div>
    </div>

    <%-- Lo que ya se le compró. Solo cuando existe: en un proveedor nuevo
         sería una sección vacía diciendo "0 lotes, 0 servicios". --%>
    <asp:Panel ID="pnlUso" runat="server" Visible="false" CssClass="sigma-modal-note">
        <i class="mdi mdi-history"></i>
        <div><asp:Literal ID="litUso" runat="server" /></div>
    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Proveedor" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
