<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CargaMasivaRepuestos.aspx.cs" Inherits="View_Inventario_Repuestos_CargaMasivaRepuestos" %>

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

        /* La carga es un postback completo que con cientos de filas tarda: sin
           aviso parece colgada y se vuelve a pulsar. Sin archivo no se muestra,
           que el servidor diga qué falta. */
        function mostrarCargando() {
            var f = document.getElementById('<%=fldArchivo.ClientID %>');
            if (!f || !f.value) return true;
            var c = document.getElementById('cmCargando');
            if (c.classList.contains('es-visible')) return false;
            c.classList.add('es-visible');
            return true;
        }
    </script>
    <style>
        .cm-cargando { position: fixed; inset: 0; z-index: 9999; display: none;
            align-items: center; justify-content: center; background: rgba(23, 34, 59, .45); }
        .cm-cargando.es-visible { display: flex; }
        .cm-cargando-caja { background: #FFFFFF; border: 1px solid #E2E7F0; border-radius: 14px;
            box-shadow: 0 10px 30px rgba(23, 34, 59, .18); padding: 26px 34px; text-align: center; color: #17223B; }
        .cm-cargando-caja strong { display: block; font-size: 14px; margin-top: 12px; }
        .cm-cargando-caja span { font-size: 12px; color: #68738A; }
        .cm-spinner { width: 38px; height: 38px; margin: 0 auto; border-radius: 50%;
            border: 4px solid #F2EFFF; border-top-color: #6732F4; animation: cm-giro .8s linear infinite; }
        @keyframes cm-giro { to { transform: rotate(360deg); } }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Carga masiva de repuestos</h1>

    <%-- El orden de la pantalla es el orden del trabajo: primero se baja la
         plantilla, después se sube. Ponerlos al revés obliga a leer para
         entender por dónde se empieza. --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-numeric-1-circle-outline"></i>Baje la plantilla</div>
        <div class="ayuda">
            Trae una fila de ejemplo con el formato de cada columna, una segunda
            hoja con las <strong>unidades válidas</strong> y una tercera con los
            <strong>tipos de repuesto válidos</strong>: sin ellas se escribe
            "unidades", "un", "u." y cada una falla sin que se entienda por qué.
            La fila de ejemplo se ignora al cargar, así que da lo mismo si se
            olvida borrarla.
        </div>

        <div class="sigma-modal-actions" style="justify-content: flex-start;">
            <WebControls:PushButton ID="btnPlantilla" runat="server" Text="Descargar plantilla"
                CssClass="ButtonCerrar" OnClick="btnPlantilla_Click" />
        </div>
    </div>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-numeric-2-circle-outline"></i>Suba la planilla</div>
        <div class="ayuda">
            El <strong>código puede ir vacío</strong>: se genera solo como
            <strong>REP-</strong>más el número, igual que al crear un repuesto a mano.
            La columna <strong>TIPO</strong> también es opcional: escriba el
            código del tipo (hoja TIPOS VALIDOS) o su nombre; vacía, el repuesto
            queda sin clasificar.
            Una fila con error no detiene el resto — se cargan las demás y abajo se
            dice cuál falló y por qué.
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
        <WebControls:PushButton ID="btnCargar" runat="server" Text="Cargar repuestos"
            OnClick="btnCargar_Click" OnClientClick="return mostrarCargando();" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
<div id="cmCargando" class="cm-cargando" role="status" aria-live="polite">
    <div class="cm-cargando-caja">
        <div class="cm-spinner"></div>
        <strong>Cargando planilla…</strong>
        <span>Validando y creando los repuestos, no cierre esta ventana.</span>
    </div>
</div>
</asp:Content>
