<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Etiquetas.aspx.cs" Inherits="View_Comun_Impresion_Etiquetas" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-impresion.css?vrs=1" rel="stylesheet" />

    <%-- El tamaño de página depende del formato elegido, y @page no se puede
         condicionar por clase: se emite desde el servidor. --%>
    <asp:Literal ID="litPagina" runat="server" />

    <script type="text/javascript">
        function imprimir() {
            window.print();
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
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

        <span class="cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
    </div>

    <div class="etq-ayuda no-imprimir">
        Cada etiqueta lleva su código impreso en grande y el mismo dato en el QR.
        Al escanearla —con la cámara del teléfono— se abre en SIGMA lo que hay en
        ese lugar. <strong>El código no se puede cambiar después</strong>: si se
        corrige, las etiquetas ya pegadas dejan de servir.
    </div>

    <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="etq-vacio no-imprimir">
        <asp:Literal ID="litVacio" runat="server" />
    </asp:Panel>

    <div id="divHoja" runat="server" class="etq-hoja">
        <asp:Repeater ID="rptEtiquetas" runat="server" OnItemDataBound="rptEtiquetas_ItemDataBound">
            <ItemTemplate>
                <div class="etq">
                    <asp:Literal ID="litQr" runat="server" />
                    <div class="texto">
                        <asp:Literal ID="litCodigo" runat="server" />
                        <div class="titulo"><%# Server.HtmlEncode(Eval("Titulo").ToString()) %></div>
                        <div class="sub"><%# Server.HtmlEncode(Eval("Subtitulo").ToString()) %></div>
                        <div class="detalle"><%# Server.HtmlEncode(Eval("Detalle").ToString()) %></div>
                        <div class="pie"><%# Server.HtmlEncode(Eval("Pie").ToString()) %></div>
                    </div>
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
