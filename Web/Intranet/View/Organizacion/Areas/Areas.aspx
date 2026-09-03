<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Areas.aspx.cs" Inherits="View_Organizacion_Areas_Areas" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="../../../Css/LookAndFeel/sigma-arbol.css?vrs=1" rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirArea(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Organizacion/Areas/Area.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva área' : 'Editar área',
                width: 960,
                initialHeight: 520
            });
        }

        function refresh() {
            __doPostBack("<%=lnkRefrescar.UniqueID %>", '');
        }

        /* PLEGAR Y DESPLEGAR

             El arbol se dibuja plano —una fila por area, con su nivel— y el
             parentesco viaja en data-padre. Plegar es esconder a todos los
             descendientes, no solo a los hijos: si se escondieran solo los
             hijos, los nietos quedarian colgando de una rama que ya no se ve.

             Se recorre hacia abajo desde la fila tocada mientras el nivel sea
             mayor que el suyo. Como las filas vienen en orden de recorrido,
             ese tramo contiguo ES el subarbol completo. */
        function sgArbolPlegar(boton) {
            var fila = boton.closest('.sg-arbol-fila');
            if (!fila) return false;

            var cerrado = fila.classList.toggle('is-plegado');
            var nivel = parseInt(fila.getAttribute('data-nivel'), 10);
            var actual = fila.nextElementSibling;

            while (actual && parseInt(actual.getAttribute('data-nivel'), 10) > nivel) {
                if (cerrado) {
                    actual.style.display = 'none';
                }
                else {
                    /* Al abrir NO se muestra todo el subarbol: solo lo que
                       cuelga de ramas que a su vez estan abiertas. Mostrarlo
                       todo perderia el estado que el usuario dejo adentro. */
                    var padre = document.querySelector(
                        '.sg-arbol-fila[data-id="' + actual.getAttribute('data-padre') + '"]');

                    actual.style.display =
                        (padre && (padre.classList.contains('is-plegado') ||
                                   padre.style.display === 'none')) ? 'none' : '';
                }
                actual = actual.nextElementSibling;
            }

            return false;
        }

        function sgArbolTodo(abrir) {
            var filas = document.querySelectorAll('.sg-arbol-fila');

            for (var i = 0; i < filas.length; i++) {
                filas[i].style.display = abrir ? '' : (filas[i].getAttribute('data-nivel') === '1' ? '' : 'none');
                if (abrir) filas[i].classList.remove('is-plegado');
                else if (filas[i].getAttribute('data-hijos') === '1') filas[i].classList.add('is-plegado');
            }

            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Organización
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Áreas
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cómo se divide cada planta por dentro.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboPlanta" style="margin: 0;">Planta:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="80%"
                        AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
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
        <p>Seleccione un cliente en el encabezado para trabajar con sus áreas.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:LinkButton ID="lnkRefrescar" runat="server" OnClick="lnkRefrescar_Click" style="display:none;" />

            <%-- ============================================================
                 UN ARBOL Y NO UNA GRILLA

                   Un area de planta CONTIENE otras areas. La grilla mostraba
                   esa jerarquia con una columna "Área superior" y un padding
                   izquierdo calculado: para saber qué cuelga de qué había que
                   leer fila por fila y comparar nombres.

                   Acá la estructura se ve, se pliega y se navega. Y cada rama
                   ofrece "nueva subárea" en su propio sitio, que es donde
                   alguien está mirando cuando decide crearla — antes había
                   que abrir "Nueva" y elegir el padre de un desplegable.
                 ============================================================ --%>

            <div class="sg-arbol-barra">
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion"
                    OnClientClick="return abrirArea(0);">
                    <i class="mdi mdi-plus"></i><span>Nueva área</span>
                </asp:LinkButton>

                <a href="javascript:void(0);" class="sigma-accion" onclick="return sgArbolTodo(true);">
                    <i class="mdi mdi-unfold-more-horizontal"></i><span>Desplegar todo</span>
                </a>

                <a href="javascript:void(0);" class="sigma-accion" onclick="return sgArbolTodo(false);">
                    <i class="mdi mdi-unfold-less-horizontal"></i><span>Plegar todo</span>
                </a>

                <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <div class="sg-arbol">
                <asp:Repeater ID="rptAreas" runat="server"
                    OnItemDataBound="rptAreas_ItemDataBound"
                    OnItemCommand="rptAreas_ItemCommand">
                    <ItemTemplate>
                        <div class="sg-arbol-fila" runat="server" id="fila">

                            <span class="sangria" runat="server" id="sangria"></span>

                            <asp:Literal ID="litToggle" runat="server" />

                            <span class="icono" runat="server" id="icono">
                                <i class="mdi mdi-shape-outline"></i>
                            </span>

                            <span class="texto">
                                <span class="nombre"><asp:Literal ID="litNombre" runat="server" /></span>
                                <span class="meta"><asp:Literal ID="litMeta" runat="server" /></span>
                            </span>

                            <span class="chips"><asp:Literal ID="litChips" runat="server" /></span>

                            <span class="acciones">
                                <asp:LinkButton ID="lnkEditar" runat="server" CssClass="sg-arbol-accion"
                                    ToolTip="Abrir el área">
                                    <i class="mdi mdi-pencil-outline"></i>
                                </asp:LinkButton>

                                <asp:LinkButton ID="lnkSub" runat="server" CssClass="sg-arbol-accion"
                                    ToolTip="Crear una subárea acá dentro">
                                    <i class="mdi mdi-subdirectory-arrow-right"></i>
                                </asp:LinkButton>

                                <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="sg-arbol-accion is-peligro"
                                    CommandName="Eliminar" ToolTip="Eliminar el área">
                                    <i class="mdi mdi-trash-can-outline"></i>
                                </asp:LinkButton>
                            </span>

                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-arbol-vacio">
                <i class="mdi mdi-file-tree-outline"></i>
                <div class="titulo">No hay áreas que mostrar</div>
                <div class="texto"><asp:Literal ID="litVacio" runat="server" /></div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
