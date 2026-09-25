<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CargaMasivaActivos.aspx.cs" Inherits="View_Activos_Ficha_CargaMasivaActivos" %>

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
        function sigmaNombreArchivo(input) {
            var n = document.getElementById('sigmaCargaNombre');
            if (n) n.textContent = input.files && input.files.length ? input.files[0].name : '';
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Carga masiva de activos</h1>

    <%-- PASO 1: la planilla ---------------------------------------------
         Primero la plantilla y despues el archivo. Al reves, el primer
         intento siempre es una planilla propia con otras columnas. --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-file-table-outline"></i>1. La planilla</div>

        <p class="sigma-modal-nota">
            <i class="mdi mdi-information-outline"></i>
            <span>Descarga la plantilla, complétala y súbela. Las columnas obligatorias son
            <strong>Código</strong>, <strong>Nombre</strong>, <strong>Planta</strong>, <strong>Tipo</strong>,
            <strong>Estado</strong> y <strong>Criticidad</strong>. Planta, área, tipo, estado y criticidad
            se escriben con su nombre tal como está en el sistema.</span>
        </p>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Plantilla</label>
                <asp:LinkButton ID="lnkPlantilla" runat="server" CssClass="sigma-img-btn"
                    CausesValidation="false" OnClick="lnkPlantilla_Click"><i class="mdi mdi-download-outline"></i> Descargar plantilla</asp:LinkButton>
                <span class="sigma-modal-ayuda">Trae una fila de ejemplo con los valores que este cliente tiene cargados.</span>
            </div>

            <div class="sigma-modal-field is-medio">
                <label>Archivo(*)</label>
                <label for="fuPlanilla" class="sigma-img-btn"><i class="mdi mdi-paperclip"></i> Elegir archivo</label>
                <asp:FileUpload ID="fuPlanilla" runat="server" accept=".csv,text/csv" ClientIDMode="Static"
                    onchange="sigmaNombreArchivo(this)" style="display:none;" />
                <span id="sigmaCargaNombre" class="sigma-img-name"></span>
                <span class="sigma-modal-ayuda">CSV separado por punto y coma, como lo exporta Excel en español.</span>
            </div>
        </div>

        <div class="sigma-modal-actions es-alineado">
            <asp:LinkButton ID="lnkRevisar" runat="server" CssClass="sigma-img-btn es-primario"
                CausesValidation="false" OnClick="lnkRevisar_Click"><i class="mdi mdi-magnify"></i>Revisar la planilla</asp:LinkButton>
        </div>
    </div>

    <%-- PASO 2: la vista previa -------------------------------------------
         Nada se escribe antes de mostrar QUE se va a escribir. Una carga
         masiva que falla a la mitad deja un catalogo incompleto y nadie sabe
         donde quedo. --%>
    <asp:Panel ID="pnlPrevia" runat="server" Visible="false" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-format-list-checks"></i>2. Qué se va a crear</div>

        <asp:Literal ID="litResumen" runat="server" />
        <asp:Literal ID="litPrevia" runat="server" />

        <div class="sigma-modal-actions es-alineado">
            <asp:LinkButton ID="lnkCargar" runat="server" CssClass="sigma-img-btn es-primario"
                CausesValidation="false" OnClick="lnkCargar_Click"><i class="mdi mdi-database-import-outline"></i>Crear los activos válidos</asp:LinkButton>
        </div>
    </asp:Panel>

    <%-- PASO 3: el resultado --%>
    <asp:Panel ID="pnlResultado" runat="server" Visible="false" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-check-circle-outline"></i>3. Resultado</div>
        <asp:Literal ID="litResultado" runat="server" />
    </asp:Panel>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
    </div>

        </ContentTemplate>
        <Triggers>
            <%-- La descarga entrega un archivo: no puede ir por AJAX. --%>
            <asp:PostBackTrigger ControlID="lnkPlantilla" />
            <asp:PostBackTrigger ControlID="lnkRevisar" />
        </Triggers>
    </asp:UpdatePanel>
</div>
</asp:Content>
