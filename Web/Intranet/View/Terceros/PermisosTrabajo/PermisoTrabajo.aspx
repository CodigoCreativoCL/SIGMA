<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="PermisoTrabajo.aspx.cs" Inherits="View_Terceros_PermisosTrabajo_PermisoTrabajo" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>
<%@ Register TagPrefix="wuc" TagName="Adjunto" Src="~/View/Comun/Controls/Adjunto.ascx" %>

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

    <h1 class="sigma-modal-title">Permiso de trabajo</h1>

    <%-- La situación arriba del todo cuando el permiso ya existe: es lo
         primero que alguien necesita saber al abrirlo. --%>
    <asp:Panel ID="pnlSituacion" runat="server" Visible="false" CssClass="sigma-modal-hero">
        <div class="sigma-modal-hero-icon"><i class="mdi mdi-shield-check-outline"></i></div>
        <div class="sigma-modal-hero-text">
            <div class="sigma-modal-hero-title"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
            <div class="sigma-modal-hero-detail"><asp:Literal ID="litHeroDetalle" runat="server" /></div>
        </div>
        <div class="sigma-modal-hero-chip"><asp:Literal ID="litHeroChip" runat="server" /></div>
    </asp:Panel>

    <div class="sigma-form-seccion">
        <div class="titulo">
            <span class="paso">1</span><i class="mdi mdi-shield-alert-outline"></i>Qué faena habilita
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>

            <div class="sigma-modal-field is-mitad">
                <label>Tipo de permiso(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Permiso" />
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Folio del formulario</label>
                <WebControls:TextBox2 ID="txtNumero" runat="server" MaxLength="100" UpperCase="true" />
                <span class="sigma-modal-ayuda">
                    El número que trae el papel de prevención. Opcional: hay plantas que no numeran.
                </span>
            </div>

            <div class="sigma-modal-field is-mitad">
                <label>Solicitante</label>
                <rad:RadComboBox2 ID="cboSolicitante" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">Quién pidió el permiso. Por omisión, usted.</span>
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo">
            <span class="paso">2</span><i class="mdi mdi-calendar-range"></i>Desde cuándo y hasta cuándo
        </div>

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
                <span class="sigma-modal-ayuda">
                    Es la fecha con la que se avisa antes de que caduque. Sin ella no hay aviso.
                </span>
            </div>

            <div class="sigma-modal-field is-chico">
                <label>Estado(*)</label>
                <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Width="100%"
                    AutoPostBack="true" OnSelectedIndexChanged="cboEstado_Changed" />
                <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaEstado" runat="server" /></span>
            </div>
        </div>
    </div>

    <%-- ============================================================
         PASO 3 — EL DOCUMENTO FIRMADO

         Es el corazón de la historia: "adjuntar el permiso firmado que
         habilita el trabajo". Y es lo único que hoy no se puede hacer.

         El hueco queda conectado de punta a punta —ptr_archivo apunta a
         Archivo, el SEL_ devuelve nombre y peso— y la pantalla pregunta
         por Almacenamiento.Disponible antes de ofrecer nada. El día que
         la API exista se cambia el Web.config y funciona.
         ============================================================ --%>
    <div class="sigma-form-seccion">
        <div class="titulo">
            <span class="paso">3</span><i class="mdi mdi-file-document-outline"></i>El documento firmado
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-ancho">
                <%-- El control resuelve los cuatro estados —lo tiene, se puede
                     subir, no se puede, no hay— y los enlaces de ver y
                     descargar. Escrito una vez para todos los módulos que
                     adjuntan algo. --%>
                <wuc:Adjunto runat="server" ID="wucAdjunto"
                    Modulo="permisos-trabajo"
                    Categoria="13"
                    Ayuda="El permiso firmado, en PDF o como foto. Se guarda junto al registro y queda como constancia." />
            </div>
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo">
            <span class="paso">4</span><i class="mdi mdi-text-box-outline"></i>Detalle
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mitad">
                <label>Orden de trabajo</label>
                <rad:RadComboBox2 ID="cboOrden" runat="server" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda"><asp:Literal ID="litAyudaOrden" runat="server" /></span>
            </div>

            <div class="sigma-modal-field is-ancho">
                <label>Observación</label>
                <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="1000" />
                <span class="sigma-modal-ayuda">
                    Qué se va a hacer y con qué resguardos. Es lo que lee quien revisa la faena.
                </span>
            </div>
        </div>
    </div>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Permiso" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
