<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Escanear.aspx.cs" Inherits="View_Comun_Impresion_Escanear" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-escaneo.css?vrs=1" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src="<%=ResolveUrl("~/Js/sigma-escaneo.js") %>?vrs=1"></script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Escanear
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Apunte la cámara a la etiqueta y vea qué hay ahí.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">

    <%-- El visor vive FUERA del UpdatePanel del resultado: si estuviera
         dentro, cada lectura lo destruiría y habría que volver a pedir
         permiso de cámara en cada escaneo. --%>
    <div class="esc-lector">

        <div class="esc-camara" id="escCamara" style="display: none;">
            <video id="escVideo" playsinline muted></video>
            <div class="esc-mira"></div>
            <button type="button" class="esc-cerrar" onclick="sigmaEscaneo.detener(); return false;">
                <i class="mdi mdi-close"></i>
            </button>
        </div>

        <div class="esc-acciones">
            <button type="button" id="escBtnCamara" class="esc-boton-camara"
                    onclick="sigmaEscaneo.iniciar(); return false;">
                <i class="mdi mdi-qrcode-scan"></i>
                <span>Escanear con la cámara</span>
            </button>
        </div>

        <div class="esc-aviso" id="escAviso" style="display: none;"></div>

        <%-- La entrada a mano no es el camino principal, pero tiene que
             existir: una etiqueta rayada, mojada o despegada no se lee, y el
             código va impreso en grande justamente para poder teclearlo. --%>
        <details class="esc-manual">
            <summary>Escribir el código a mano</summary>
            <div class="esc-manual-cuerpo">
                <asp:UpdatePanel runat="server" ID="udLectura" UpdateMode="Conditional">
                    <ContentTemplate>
                        <WebControls:TextBox2 ID="txtLectura" runat="server" MaxLength="300"
                            AutoPostBack="true" OnTextChanged="txtLectura_Changed" />
                        <WebControls:PushButton ID="btnBuscar" runat="server" Text="Buscar"
                            OnClick="btnBuscar_Click" />
                    </ContentTemplate>
                </asp:UpdatePanel>
                <span class="esc-pista">Por ejemplo <strong>UBI-17</strong> o <strong>BOD-9</strong>.</span>
            </div>
        </details>

        <%-- Lo que deja la cámara, y el disparador del postback. --%>
        <asp:HiddenField ID="hdnLeido" runat="server" />
        <asp:Button ID="btnLeido" runat="server" OnClick="btnLeido_Click" style="display: none;" />
    </div>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Panel ID="pnlNada" runat="server" Visible="false" CssClass="esc-vacio">
                <i class="mdi mdi-alert-circle-outline"></i>
                <div><asp:Literal ID="litNada" runat="server" /></div>
            </asp:Panel>

            <asp:Panel ID="pnlResultado" runat="server" Visible="false">

                <div class="esc-cabecera">
                    <div class="tipo"><asp:Literal ID="litTipo" runat="server" /></div>
                    <div class="codigo"><asp:Literal ID="litCodigo" runat="server" /></div>
                    <div class="nombre"><asp:Literal ID="litNombre" runat="server" /></div>
                    <div class="contexto"><asp:Literal ID="litContexto" runat="server" /></div>

                    <asp:Panel ID="pnlTotal" runat="server" Visible="false" CssClass="total">
                        <span class="rotulo">Total en bodegas</span>
                        <span class="valor"><asp:Literal ID="litTotal" runat="server" /></span>
                    </asp:Panel>
                </div>

                <div class="esc-resumen"><asp:Literal ID="litResumen" runat="server" /></div>

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
