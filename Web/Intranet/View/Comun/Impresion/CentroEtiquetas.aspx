<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="CentroEtiquetas.aspx.cs" Inherits="View_Comun_Impresion_CentroEtiquetas" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-escaneo.css?vrs=2" rel="stylesheet" />
    <link href="../../../Css/LookAndFeel/sigma-impresion.css?vrs=2" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* Ventana emergente y no pestaña ni RadWindow.

           RadWindow no sirve: la ventana modal del proyecto vive dentro de un
           iframe, y al imprimir desde un iframe el navegador manda la PAGINA
           CONTENEDORA. Saldría impreso este listado en vez de las etiquetas.

           Un popup es una ventana de verdad, así que imprime lo suyo, y deja
           el centro visible detrás: al cerrarlo se sigue donde se estaba.

           Lleva nombre para que dos clics seguidos reutilicen la misma
           ventana en vez de sembrar el escritorio de copias. */
        function abrirEtiquetas(query) {
            var w = 980, h = 760;
            var x = window.screenX + Math.max(0, (window.outerWidth - w) / 2);
            var y = window.screenY + Math.max(0, (window.outerHeight - h) / 2);

            var vent = window.open(
                '<%=ResolveUrl("~/View/Comun/Impresion/Etiquetas.aspx") %>?query=' + query,
                'sigmaEtiquetas',
                'width=' + w + ',height=' + h + ',left=' + Math.round(x) + ',top=' + Math.round(y) +
                ',resizable=yes,scrollbars=yes');

            if (!vent) {
                alert('El navegador bloqueó la ventana de impresión. ' +
                      'Permita las ventanas emergentes para este sitio y vuelva a intentarlo.');
                return false;
            }

            vent.focus();
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Etiquetas
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Todo lo que se puede identificar con una etiqueta y un código QR.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="etq-ayuda" style="max-width: 860px;">
                Cada etiqueta lleva su código impreso en grande y el mismo dato en un QR.
                Al escanearla con la cámara del teléfono se abre en SIGMA lo que hay en
                ese lugar, así que sirve tanto para rotular como para consultar de pie
                frente al estante.
            </div>

            <%-- DOS GRUPOS, PORQUE EL FILTRO SOLO APLICA A UNO

                 El combo de bodega estaba arriba, como si filtrara toda la
                 pantalla, y en realidad solo afecta a las etiquetas de
                 ubicación: un repuesto o un activo existen en el catálogo del
                 cliente, no dentro de una bodega.

                 Puesto como filtro global obligaba a preguntarse "¿esto también
                 acota los repuestos?". Dentro de su grupo, la pregunta no
                 aparece. --%>
            <asp:Panel ID="pnlGrupoBodega" runat="server" Visible="false" CssClass="etq-grupo">
                <div class="etq-grupo-cabecera">
                    <div class="titulo">
                        <i class="mdi mdi-warehouse"></i>
                        <span>De una bodega</span>
                    </div>

                    <div class="campo">
                        <label for="cboBodega">Bodega:</label>
                        <rad:RadComboBox2 ID="cboBodega" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="cboBodega_Changed" Filter="Contains" Width="280px" />
                    </div>
                </div>

                <div class="sigma-opciones">
                    <asp:Repeater ID="rptBodega" runat="server" OnItemDataBound="rptOrigenes_ItemDataBound">
                        <ItemTemplate>
                            <asp:Literal ID="litTarjeta" runat="server" />
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlGrupoCatalogo" runat="server" Visible="false" CssClass="etq-grupo">
                <div class="etq-grupo-cabecera">
                    <div class="titulo">
                        <i class="mdi mdi-format-list-bulleted"></i>
                        <span>Del catálogo</span>
                    </div>
                    <span class="nota">No dependen de una bodega.</span>
                </div>

                <div class="sigma-opciones">
                    <asp:Repeater ID="rptCatalogo" runat="server" OnItemDataBound="rptOrigenes_ItemDataBound">
                        <ItemTemplate>
                            <asp:Literal ID="litTarjeta" runat="server" />
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlSinOrigenes" runat="server" Visible="false" CssClass="esc-vacio">
                <i class="mdi mdi-alert-circle-outline"></i>
                <div>No hay módulos que usted pueda etiquetar con sus permisos actuales.</div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

</asp:Content>
