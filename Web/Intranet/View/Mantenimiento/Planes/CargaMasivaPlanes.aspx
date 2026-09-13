<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CargaMasivaPlanes.aspx.cs" Inherits="View_Mantenimiento_Planes_CargaMasivaPlanes" %>

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

    <h1 class="sigma-modal-title">Carga masiva de planes</h1>

    <%-- El orden de la pantalla es el orden del trabajo: primero se baja la
         plantilla, después se sube. Ponerlos al revés obliga a leer para
         entender por dónde se empieza. --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-numeric-1-circle-outline"></i>Baje la plantilla</div>
        <div class="ayuda">
            Un libro con tres hojas que se cruzan por el <strong>código del plan</strong>:
            <strong>PLANES</strong> (qué es), <strong>HITOS</strong> (qué se le hace y cada cuánto)
            y <strong>EQUIPOS</strong> (a qué máquinas). Las demás hojas son de ayuda: plantas,
            planificadores, tipos y modelos, programaciones, unidades y equipos, escritos
            tal como hay que ponerlos. La fila de ejemplo se ignora al cargar.
        </div>

        <div class="sigma-modal-actions" style="justify-content: flex-start;">
            <WebControls:PushButton ID="btnPlantilla" runat="server" Text="Descargar plantilla"
                CssClass="ButtonCerrar" OnClick="btnPlantilla_Click" />
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-numeric-2-circle-outline"></i>Suba la planilla</div>
        <div class="ayuda">
            Se cargan primero los planes, después sus hitos y al final sus equipos,
            por el mismo camino que las fichas: las mismas reglas —código único,
            alcance del equipo, solo sobre un borrador— y los mismos mensajes. Los
            hitos y equipos pueden apuntar a un plan que ya exista, si está en borrador.
            Una fila con error no detiene el resto: abajo se dice en qué hoja y fila falló y por qué.
        </div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-grande">
                <label>Archivo (.xlsx)</label>
                <asp:FileUpload ID="fldArchivo" runat="server" />
            </div>
        </div>
    </div>

    <asp:Panel ID="pnlResultado" runat="server" Visible="false" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-clipboard-check-outline"></i>Resultado</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-chico">
                <label>Cargados</label>
                <div class="sigma-modal-valor"><asp:Literal ID="litCargados" runat="server" /></div>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Con error</label>
                <div class="sigma-modal-valor"><asp:Literal ID="litFallidos" runat="server" /></div>
            </div>
            <div class="sigma-modal-field is-mitad">
                <label>Duración</label>
                <div class="sigma-modal-valor"><asp:Literal ID="litDuracion" runat="server" /></div>
            </div>
        </div>

        <%-- Las filas que fallaron, con su número: sin él hay que adivinar
             cuál de las doscientas es. --%>
        <asp:Panel ID="pnlErrores" runat="server" Visible="false">
            <div class="sigma-lista">
                <div class="sigma-lista-cabecera">
                    <span class="col-codigo">Fila</span>
                    <span class="col-nombre">Qué pasó</span>
                    <span class="col-acciones"></span>
                </div>

                <asp:Repeater ID="rptErrores" runat="server">
                    <ItemTemplate>
                        <div class="sigma-lista-fila">
                            <span class="col-codigo">
                                <span class="sigma-lista-codigo"><%# Eval("FILA") %></span>
                            </span>
                            <span class="col-nombre">
                                <strong><%# Server.HtmlEncode(Eval("CODIGO").ToString()) %></strong>
                                — <%# Server.HtmlEncode(Eval("MOTIVO").ToString()) %>
                            </span>
                            <span class="col-acciones"></span>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </asp:Panel>
    </asp:Panel>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar"
            OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnCargar" runat="server" Text="Cargar planes"
            OnClick="btnCargar_Click" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
