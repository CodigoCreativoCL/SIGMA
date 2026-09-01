<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Escanear.aspx.cs" Inherits="View_Comun_Impresion_Escanear" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-escaneo.css?vrs=2" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src="<%=ResolveUrl("~/Js/sigma-escaneo.js") %>?vrs=2"></script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Escanear
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Lea la etiqueta de una bodega, un estante o un repuesto y vea qué hay ahí.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">

    <%-- El visor vive FUERA del UpdatePanel del resultado: si estuviera
         dentro, cada lectura lo destruiría y habría que volver a pedir permiso
         de cámara en cada escaneo. --%>
    <div class="esc-camara" id="escCamara" style="display: none;">
        <video id="escVideo" playsinline muted></video>
        <div class="esc-mira"></div>
        <button type="button" class="esc-cerrar" onclick="sigmaEscaneo.detener(); return false;"
                title="Cerrar la cámara">
            <i class="mdi mdi-close"></i>
        </button>
        <div class="esc-camara-pista">Encuadre el QR dentro del marco</div>
    </div>

    <%-- LOS DOS CAMINOS, LADO A LADO

         Antes la pantalla ofrecía un botón de cámara que en el computador casi
         siempre responde "no puedo", y debajo un desplegable cerrado. Quedaba
         vacía y sin decir qué hacer.

         Ahora dice las dos formas de llegar y cuál corresponde a cada aparato:
         con el teléfono se escanea, en el computador se escribe. --%>
    <div class="esc-caminos" id="escCaminos">

        <div class="esc-camino" id="escCaminoCamara">
            <div class="cabecera">
                <span class="paso">Con el teléfono</span>
                <h3>Escanee la etiqueta</h3>
            </div>

            <p class="ayuda">
                Apunte la cámara al código QR de la etiqueta. Se abre lo que hay en
                ese lugar, sin escribir nada.
            </p>

            <button type="button" id="escBtnCamara" class="esc-boton-camara"
                    onclick="sigmaEscaneo.iniciar(); return false;">
                <i class="mdi mdi-qrcode-scan"></i>
                <span>Escanear con la cámara</span>
            </button>

            <%-- En el computador no hay cámara útil, pero sí se puede mostrar un
                 código que el teléfono lea: se escanea esto y la misma pantalla
                 sigue en el bolsillo, que es donde sirve. --%>
            <asp:Panel ID="pnlPuente" runat="server" Visible="false" CssClass="esc-puente">
                <div class="qr"><asp:Literal ID="litQrPuente" runat="server" /></div>
                <div class="texto">
                    <strong>Siga en su teléfono</strong>
                    <span>
                        Escanee este código con la cámara de su teléfono: esta misma
                        pantalla se abre ahí, donde la cámara sí sirve para leer
                        etiquetas.
                    </span>
                </div>
            </asp:Panel>

            <div class="esc-aviso" id="escAviso" style="display: none;"></div>
        </div>

        <div class="esc-camino">
            <div class="cabecera">
                <span class="paso">A mano</span>
                <h3>Escriba el código</h3>
            </div>

            <p class="ayuda">
                Sirve cuando la etiqueta está rayada, mojada o despegada. El código va
                impreso en grande justamente para poder teclearlo.
            </p>

            <asp:UpdatePanel runat="server" ID="udLectura" UpdateMode="Conditional">
                <ContentTemplate>
                    <div class="esc-manual-fila">
                        <WebControls:TextBox2 ID="txtLectura" runat="server" MaxLength="300"
                            AutoPostBack="true" OnTextChanged="txtLectura_Changed" />
                        <WebControls:PushButton ID="btnBuscar" runat="server" Text="Buscar"
                            OnClick="btnBuscar_Click" />
                    </div>
                </ContentTemplate>
            </asp:UpdatePanel>

            <%-- Los prefijos, porque nadie los adivina. --%>
            <div class="esc-prefijos">
                <span><b>BOD-</b> bodega</span>
                <span><b>UBI-</b> estante</span>
                <span><b>REP-</b> repuesto</span>
                <span><b>ACT-</b> equipo</span>
            </div>
        </div>

    </div>

    <%-- Lo que deja la cámara, y el disparador del postback. --%>
    <asp:HiddenField ID="hdnLeido" runat="server" />
    <asp:Button ID="btnLeido" runat="server" OnClick="btnLeido_Click" style="display: none;" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlNada" runat="server" Visible="false" CssClass="esc-vacio">
                <i class="mdi mdi-alert-circle-outline"></i>
                <div><asp:Literal ID="litNada" runat="server" /></div>
            </asp:Panel>

            <asp:Panel ID="pnlResultado" runat="server" Visible="false" CssClass="esc-resultado">

                <div class="esc-cabecera">
                    <div class="esc-cabecera-texto">
                        <div class="tipo"><asp:Literal ID="litTipo" runat="server" /></div>
                        <div class="codigo"><asp:Literal ID="litCodigo" runat="server" /></div>
                        <div class="nombre"><asp:Literal ID="litNombre" runat="server" /></div>
                        <div class="contexto"><asp:Literal ID="litContexto" runat="server" /></div>
                    </div>

                    <asp:Panel ID="pnlTotal" runat="server" Visible="false" CssClass="total">
                        <span class="rotulo">Total en bodegas</span>
                        <span class="valor"><asp:Literal ID="litTotal" runat="server" /></span>
                    </asp:Panel>
                </div>

                <div class="esc-resumen-fila">
                    <span class="esc-resumen"><asp:Literal ID="litResumen" runat="server" /></span>

                    <%-- Escanear otra sin salir: quien está frente a la estantería
                         lee varias seguidas. --%>
                    <button type="button" class="esc-otra" onclick="sigmaEscaneo.iniciar(); return false;">
                        <i class="mdi mdi-qrcode-scan"></i><span>Escanear otra</span>
                    </button>
                </div>

                <asp:Repeater ID="rptDetalle" runat="server" OnItemDataBound="rptDetalle_ItemDataBound">
                    <ItemTemplate>
                        <div class="esc-tarjeta">
                            <div class="fila-1">
                                <div class="quien">
                                    <asp:Literal ID="litLugar" runat="server" />
                                    <div class="rep-codigo"><%# Server.HtmlEncode(Eval("RepuestoCodigo").ToString()) %></div>
                                    <div class="rep-nombre"><%# Server.HtmlEncode(Eval("RepuestoNombre").ToString()) %></div>
                                </div>
                                <div class="cuanto">
                                    <asp:Literal ID="litCantidad" runat="server" />
                                </div>
                            </div>
                            <div class="fila-2">
                                <asp:Literal ID="litLote" runat="server" />
                                <asp:Literal ID="litUltimo" runat="server" />
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>

            </asp:Panel>

        </ContentTemplate>

        <%-- El botón que dispara la cámara vive FUERA de este panel, junto al
             visor. Como disparador asíncrono, el escaneo actualiza solo el
             resultado: un postback completo recargaría la página entera en un
             teléfono, con la lentitud y el salto de scroll que eso implica. --%>
        <Triggers>
            <asp:AsyncPostBackTrigger ControlID="btnLeido" EventName="Click" />
        </Triggers>
    </asp:UpdatePanel>

</asp:Content>
