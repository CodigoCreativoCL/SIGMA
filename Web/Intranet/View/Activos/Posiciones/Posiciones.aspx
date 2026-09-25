<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Posiciones.aspx.cs" Inherits="View_Activos_Posiciones_Posiciones" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPosicion(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Posiciones/Posicion.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva posición' : 'Posición',
                width: 960,
                initialHeight: 620
            });
        }

        /* Las etiquetas se imprimen en una ventana aparte, igual que en
           Bodega.aspx: es una hoja para la impresora, no una ficha. */
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

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Activos
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Posiciones
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Los lugares fijos de cada área. El QR se pega en la sala y sigue sirviendo aunque cambie la máquina.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboArea" style="display:block; margin:0 0 4px;">Área:</label>
                    <rad:RadComboBox2 ID="cboArea" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboOcupacion" style="display:block; margin:0 0 4px;">Ocupación:</label>
                    <rad:RadComboBox2 ID="cboOcupacion" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas" Value="" />
                            <rad:RadComboBoxItem Text="Con equipo" Value="0" />
                            <rad:RadComboBoxItem Text="Libres" Value="1" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-3 col-md-3 col-xs-12">
                    <label for="cboHabilitado" style="display:block; margin:0 0 4px;">Habilitada:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus posiciones.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrPosiciones_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="apo_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nueva posición" CssClass="icono_guardar" OnClientClick="return abrirPosicion(0);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Eliminar las posiciones seleccionadas? Las que ya tuvieron un equipo no se borran: se deshabilitan desde su ficha.');" />
                            <%-- HU-034 #2: varias posiciones de un area en una sola hoja.
                                 Se seleccionan en la grilla (o se filtra por area y se
                                 marcan todas) y sale un documento con una etiqueta por
                                 posicion. --%>
                            <asp:LinkButton ID="lnkEtiquetas" runat="server" Text="Imprimir etiquetas" CssClass="icono_imprimir" OnClick="lnkEtiquetas_Click" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
