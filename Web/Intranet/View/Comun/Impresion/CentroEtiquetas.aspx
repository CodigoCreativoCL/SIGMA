<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="CentroEtiquetas.aspx.cs" Inherits="View_Comun_Impresion_CentroEtiquetas" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-escaneo.css?vrs=1" rel="stylesheet" />
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

            <div class="etq-ayuda">
                Cada etiqueta lleva su código impreso en grande y el mismo dato en un QR.
                Al escanearla con la cámara del teléfono se abre en SIGMA lo que hay en
                ese lugar, así que sirve tanto para rotular como para consultar de pie
                frente al estante.
            </div>

            <%-- El filtro por bodega solo aparece si algún origen visible lo
                 admite: un combo que no afecta a nada de lo que se ve es una
                 pregunta sin consecuencia. --%>
            <asp:Panel ID="pnlBodega" runat="server" Visible="false" CssClass="etq-barra">
                <div class="campo">
                    <label for="cboBodega">Bodega:</label>
                    <rad:RadComboBox2 ID="cboBodega" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="cboBodega_Changed" Filter="Contains" Width="320px" />
                </div>
                <span class="cuenta">Acota las etiquetas de ubicación a una sola bodega.</span>
            </asp:Panel>

            <div class="sigma-opciones">
                <asp:Repeater ID="rptOrigenes" runat="server" OnItemDataBound="rptOrigenes_ItemDataBound">
                    <ItemTemplate>
                        <asp:Literal ID="litTarjeta" runat="server" />
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <asp:Panel ID="pnlSinOrigenes" runat="server" Visible="false" CssClass="esc-vacio">
                <i class="mdi mdi-alert-circle-outline"></i>
                <div>No hay módulos que usted pueda etiquetar con sus permisos actuales.</div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

</asp:Content>
