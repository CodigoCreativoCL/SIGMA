<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="AlertaDetalle.aspx.cs" Inherits="View_Comun_Notificaciones_AlertaDetalle" %>

<%--
    LA FICHA DE UNA ALERTA

    Hasta acá, tocar una notificación llevaba a la ficha del registro
    relacionado —el repuesto, el permiso, el medidor— y de los quince tipos
    de alerta solo unos pocos tenían esa ficha configurada: el resto no
    llevaba a ninguna parte y terminaba en un aviso de "no tiene registro
    relacionado configurado".

    Y aunque la tuviera, la ficha del repuesto no cuenta LA ALERTA: dice
    cuántas unidades hay, no que el sistema la detectó hace tres días, cuántas
    veces se repitió, quién la tomó ni qué se decidió.

    Esta pantalla es esa historia, y desde acá se actúa sin salir: tomarla,
    ponerla en gestión, resolverla, descartarla, generar la orden de trabajo
    si salió de una predicción, y recién entonces —si hace falta— abrir el
    registro de origen.
--%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-notificaciones.css?vrs=26" rel="stylesheet" />

    <script type="text/javascript">
        /* CERRAR LA VENTANA DESDE ADENTRO

           La ficha vive dentro de un iframe y el botón «Cerrar» es suyo, no
           del marco. Cada ficha del sitio declara su propio closeWindow() y
           esta no lo tenía: el botón no hacía nada.

           Se piden las dos puertas porque conviven dos marcos: el RadWindow
           de siempre y el SigmaModal nuevo, que es el que abre la campana. */
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement && window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }

        function closeWindow() {
            var w = getRadWindow();

            if (w) {
                if (w.BrowserWindow && w.BrowserWindow.refresh) w.BrowserWindow.refresh();
                w.close();
                return;
            }

            try {
                if (window.parent && window.parent.SigmaModal) window.parent.SigmaModal.close();
            } catch (e) { }
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal sg-ald">

    <asp:UpdatePanel ID="udPanel" runat="server" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlNoExiste" runat="server" Visible="false" CssClass="sg-ald-vacio">
                <i class="mdi mdi-bell-off-outline" aria-hidden="true"></i>
                <div class="sg-ald-vacio-titulo">Esta notificación ya no está</div>
                <div class="sg-ald-vacio-texto">
                    Puede que la hayan resuelto o descartado desde otra pantalla.
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlFicha" runat="server">

                <%-- Encabezado: qué pasó, dónde y desde cuándo --%>
                <div class="sg-ald-head">
                    <span class="sg-ald-icono"><asp:Literal ID="litIcono" runat="server" /></span>
                    <div class="sg-ald-head-texto">
                        <div class="sg-ald-chips"><asp:Literal ID="litChips" runat="server" /></div>
                        <h2 class="sg-ald-titulo"><asp:Literal ID="litTitulo" runat="server" /></h2>
                        <div class="sg-ald-contexto"><asp:Literal ID="litContexto" runat="server" /></div>
                    </div>
                </div>

                <p class="sg-ald-descripcion"><asp:Literal ID="litDescripcion" runat="server" /></p>

                <%-- Los números de la alerta: lo medido contra el umbral, cuándo
                     se detectó y cuántas veces se repitió. --%>
                <div class="sg-ald-datos"><asp:Literal ID="litDatos" runat="server" /></div>

                <%-- Solo cuando salió de un modelo. --%>
                <asp:Panel ID="pnlPrediccion" runat="server" Visible="false" CssClass="sg-ald-ai">
                    <div class="sg-ald-ai-marca"><i class="mdi mdi-robot-outline"></i> SIGMA AI</div>
                    <asp:Literal ID="litPrediccion" runat="server" />
                </asp:Panel>

                <%-- Fotos del equipo, si las hay. La alerta habla de una
                     máquina y verla ahorra ir a terreno para saber cuál es. --%>
                <asp:Panel ID="pnlImagenes" runat="server" Visible="false">
                    <div class="sg-ald-seccion">Imágenes del equipo</div>
                    <div class="sg-ald-galeria"><asp:Literal ID="litImagenes" runat="server" /></div>
                </asp:Panel>

                <%-- Qué se ha hecho con ella. --%>
                <asp:Panel ID="pnlHistorial" runat="server" Visible="false">
                    <div class="sg-ald-seccion">Línea de tiempo</div>
                    <div class="sg-ald-linea"><asp:Literal ID="litHistorial" runat="server" /></div>
                </asp:Panel>

                <%-- El motivo se pide antes de cerrar: una alerta resuelta sin
                     explicación no le sirve a quien la lea el mes que viene. --%>
                <asp:Panel ID="pnlMotivo" runat="server" Visible="false" CssClass="sg-ald-motivo">
                    <label for="<%= txtMotivo.ClientID %>"><asp:Literal ID="litMotivoRotulo" runat="server" /></label>
                    <WebControls:TextArea2 ID="txtMotivo" runat="server" MaxLength="500" />
                    <div class="sg-ald-motivo-acciones">
                        <asp:Button ID="btnConfirmar" runat="server" CssClass="sg-btn sg-btn-primario"
                            Text="Confirmar" OnClick="btnConfirmar_Click" />
                        <asp:Button ID="btnCancelarMotivo" runat="server" CssClass="sg-btn"
                            Text="Cancelar" OnClick="btnCancelarMotivo_Click" CausesValidation="false" />
                    </div>
                </asp:Panel>

                <div class="sg-ald-acciones">
                    <asp:Button ID="btnTomar" runat="server" CssClass="sg-btn sg-btn-primario"
                        Text="Tomar alerta" OnClick="btnTomar_Click" Visible="false" />
                    <asp:Button ID="btnGestionar" runat="server" CssClass="sg-btn"
                        Text="Iniciar gestión" OnClick="btnGestionar_Click" Visible="false" />
                    <asp:Button ID="btnGenerarOt" runat="server" CssClass="sg-btn"
                        Text="Generar orden de trabajo" OnClick="btnGenerarOt_Click" Visible="false" />
                    <asp:Button ID="btnResolver" runat="server" CssClass="sg-btn"
                        Text="Resolver" OnClick="btnResolver_Click" Visible="false" />
                    <asp:Button ID="btnDescartar" runat="server" CssClass="sg-btn"
                        Text="Descartar" OnClick="btnDescartar_Click" Visible="false" />
                    <asp:HyperLink ID="lnkOrigen" runat="server" CssClass="sg-btn" Visible="false"
                        Target="_top">Abrir el registro</asp:HyperLink>
                </div>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar"
            OnClientClick="closeWindow(); return false;" />
    </div>
</div>
</asp:Content>
