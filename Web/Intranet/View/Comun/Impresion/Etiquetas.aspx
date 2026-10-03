<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Etiquetas.aspx.cs" Inherits="View_Comun_Impresion_Etiquetas" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-impresion.css?vrs=4" rel="stylesheet" />

    <script type="text/javascript">
        function imprimir() {
            window.print();
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<%-- El tamaño de página depende del formato elegido, y @page no se puede
     condicionar por clase: se emite desde el servidor. Va DENTRO del cuerpo
     (que es lo que refresca el UpdatePanel del master) y no en el head: si
     no, cambiar el combo dejaba la clase del rollo térmico con la regla de
     A4 y la impresión salía en hoja grande. --%>
<asp:Literal ID="litPagina" runat="server" />
<div class="sigma-modal">

    <h1 class="sigma-modal-title no-imprimir"><asp:Literal ID="litTitulo" runat="server" /></h1>

    <div class="etq-barra no-imprimir">
        <div class="campo">
            <label for="cboFormato">Formato:</label>
            <rad:RadComboBox2 ID="cboFormato" runat="server" AutoPostBack="true"
                OnSelectedIndexChanged="cboFormato_Changed" Width="280px">
                <Items>
                    <rad:RadComboBoxItem Text="Rollo térmico · 50 × 25 mm" Value="termica" />
                    <rad:RadComboBoxItem Text="Hoja A4 · 24 etiquetas (70 × 37 mm)" Value="a4-24" Selected="true" />
                    <rad:RadComboBoxItem Text="Hoja A4 · 10 etiquetas (99 × 57 mm)" Value="a4-10" />
                </Items>
            </rad:RadComboBox2>
        </div>

        <%-- QR o barras: lo elegido queda como predeterminado de la empresa
             (bloque 331), y el mapa 3D dibuja las etiquetas igual. --%>
        <div class="campo">
            <label for="cboSimbolo">Código:</label>
            <rad:RadComboBox2 ID="cboSimbolo" runat="server" AutoPostBack="true"
                OnSelectedIndexChanged="cboSimbolo_Changed" Width="270px">
                <Items>
                    <rad:RadComboBoxItem Text="QR · cámara del teléfono" Value="QR" />
                    <rad:RadComboBoxItem Text="Código de barras · Code 128" Value="BARRAS" />
                </Items>
            </rad:RadComboBox2>
        </div>

        <span class="cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
    </div>

    <div class="etq-ayuda no-imprimir">
        <asp:Literal ID="litAyuda" runat="server" />
        <strong>El código no se puede cambiar después</strong>: si se
        corrige, las etiquetas ya pegadas dejan de servir.
        <asp:Literal ID="litSimboloAviso" runat="server" />
    </div>

    <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="etq-vacio no-imprimir">
        <asp:Literal ID="litVacio" runat="server" />
    </asp:Panel>

    <div id="divHoja" runat="server" class="etq-hoja">
        <asp:Repeater ID="rptEtiquetas" runat="server" OnItemDataBound="rptEtiquetas_ItemDataBound">
            <ItemTemplate>
                <div class="<%# ClaseEtiqueta %>">
                    <asp:Literal ID="litQr" runat="server" />
                    <div class="texto">
                        <asp:Literal ID="litCodigo" runat="server" />
                        <div class="titulo"><%# Server.HtmlEncode(Eval("Titulo").ToString()) %></div>
                        <div class="sub"><%# Server.HtmlEncode(Eval("Subtitulo").ToString()) %></div>
                        <div class="detalle"><%# Server.HtmlEncode(Eval("Detalle").ToString()) %></div>
                        <div class="pie"><%# Server.HtmlEncode(Eval("Pie").ToString()) %></div>
                    </div>
                    <asp:Literal ID="litBarras" runat="server" />
                </div>
            </ItemTemplate>
        </asp:Repeater>
    </div>

    <div class="sigma-modal-actions no-imprimir">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar"
            OnClientClick="window.close(); return false;" ToolTip="Cierra esta ventana y vuelve a la ficha" />
        <WebControls:PushButton ID="btnImprimir" runat="server" Text="Imprimir"
            OnClientClick="return imprimir();" />
    </div>

</div>
</asp:Content>
