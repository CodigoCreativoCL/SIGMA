<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Bodega.aspx.cs" Inherits="View_Inventario_Bodegas_Bodega" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        /* Ventana emergente, no RadWindow y no pestaña.

           RadWindow no sirve: la ventana modal del proyecto vive dentro de un
           iframe, y al imprimir desde un iframe el navegador manda la PAGINA
           CONTENEDORA. Saldría impresa la ficha de la bodega en vez de las
           etiquetas.

           Un popup es una ventana de verdad, así que imprime lo suyo, y deja
           la ficha visible detrás: al cerrarlo se sigue donde se estaba.

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

        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Bodega</h1>

    <%-- Pestañas y no secciones apiladas: cada bloque se ve entero y la
         ventana no crece. --%>
    <rad:RadTabStrip2 ID="tabFicha" runat="server" MultiPageID="mpFicha" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabDatos" Text="Datos" runat="server" PageViewID="pvDatos" />
            <rad:RadTab ID="tabUbicaciones" Text="Ubicaciones" runat="server" PageViewID="pvUbicaciones" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFicha" runat="server" SelectedIndex="0" Width="100%">

        <rad:RadPageView ID="pvDatos" runat="server">

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-warehouse"></i>Identificación</div>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-mini">
                    <label>ID</label>
                    <asp:Label ID="lblId" runat="server"></asp:Label>
                </div>
                <div class="sigma-modal-field is-chico">
                    <label>Código</label>
                    <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                        <span class="sigma-modal-ayuda">Se genera solo al guardar: <strong>BOD-</strong>más el número del registro.</span>
                    <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Bodega" />
                    <span class="sigma-modal-ayuda">Único dentro del cliente. No se puede cambiar después.</span>
                </div>
                <div class="sigma-modal-field is-medio">
                    <label>Nombre(*)</label>
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Bodega" />
                </div>
                <div class="sigma-modal-field is-chico">
                    <label>Planta(*)</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <asp:CustomValidator ID="cvPlanta" runat="server" ControlToValidate="cboPlanta"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Bodega" />
                </div>
                <div class="sigma-modal-field is-grande">
                    <label>Descripción</label>
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
                </div>
                <div class="sigma-modal-field is-medio">
                    <label>Habilitada(*)</label>
                    <div class="sigma-modal-opciones">
                        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                    </div>
                    <span class="sigma-modal-ayuda">Una bodega con existencia no se puede deshabilitar.</span>
                </div>
            </div>
            </div>
        </rad:RadPageView>

        <rad:RadPageView ID="pvUbicaciones" runat="server">
            <%-- ============ UBICACIONES · HU-052 criterio 2 ============
                 Aparecen con la bodega ya creada: una ubicación sin bodega no
                 existe, y ofrecer el formulario antes de guardar promete algo
                 que no se puede cumplir. --%>
            <asp:Panel ID="pnlUbicaciones" runat="server" Visible="false" CssClass="sigma-modal-section">

                <div class="sigma-modal-section-title">
                    <i class="mdi mdi-view-grid-outline"></i>
                    <span>Ubicaciones</span>
                </div>

                <div class="sigma-modal-note">
                    <i class="mdi mdi-information-outline"></i>
                    <div>
                        El código se genera solo —<strong>UBI-</strong>más el número— y es
                        el que va impreso en la etiqueta del estante. Póngale un
                        <strong>nombre</strong> que diga dónde queda, como "Pasillo A · Estante 3 ·
                        Nivel 2": es lo que se lee al consultar un repuesto.
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-grande">
                        <label>Nombre</label>
                        <WebControls:TextBox2 ID="txtUbiNombre" runat="server" MaxLength="400" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>&nbsp;</label>
                        <WebControls:PushButton ID="btnAgregarUbicacion" runat="server"
                            Text="Agregar ubicación" OnClick="btnAgregarUbicacion_Click" />
                    </div>
                </div>

                <%-- REPEATER Y NO RadGrid

                     Una bodega tiene entre cinco y treinta estantes: no hay
                     nada que paginar, ordenar ni filtrar. RadGrid traía todo
                     ese aparato y, al editar en línea, sus botones salían como
                     texto plano en inglés -"Edit", "Update Cancel"- con un
                     input sin estilo, porque el modo InPlace dibuja lo suyo y
                     no lo que el proyecto usa en el resto.

                     Se edita EN LA FILA. Cargar la fila en el formulario de
                     arriba, a media pantalla de distancia, dejaba dudando si
                     se estaba editando esa fila o creando otra. --%>
                <div class="sigma-lista">

                    <div class="sigma-lista-cabecera">
                        <span class="col-codigo">Código</span>
                        <span class="col-nombre">Nombre</span>
                        <span class="col-acciones"></span>
                    </div>

                    <asp:Repeater ID="rptUbicaciones" runat="server"
                        OnItemDataBound="rptUbicaciones_ItemDataBound"
                        OnItemCommand="rptUbicaciones_ItemCommand">
                        <ItemTemplate>
                            <div class="sigma-lista-fila">

                                <span class="col-codigo">
                                    <span class="sigma-lista-codigo"><%# Eval("bub_codigo") %></span>
                                </span>

                                <asp:Panel ID="pnlVista" runat="server" CssClass="col-nombre">
                                    <asp:Literal ID="litNombre" runat="server" />
                                </asp:Panel>

                                <asp:Panel ID="pnlEdicion" runat="server" Visible="false" CssClass="col-nombre">
                                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                                </asp:Panel>

                                <span class="col-acciones">
                                    <asp:LinkButton ID="lnkEditar" runat="server" CommandName="Editar"
                                        CssClass="sigma-lista-accion" ToolTip="Editar esta ubicación">
                                        <i class="mdi mdi-pencil-outline"></i>
                                    </asp:LinkButton>

                                    <asp:LinkButton ID="lnkGuardar" runat="server" CommandName="Guardar"
                                        Visible="false" CssClass="sigma-lista-accion is-guardar"
                                        ToolTip="Guardar el cambio">
                                        <i class="mdi mdi-check"></i>
                                    </asp:LinkButton>

                                    <asp:LinkButton ID="lnkCancelar" runat="server" CommandName="Cancelar"
                                        Visible="false" CssClass="sigma-lista-accion" ToolTip="Descartar el cambio">
                                        <i class="mdi mdi-close"></i>
                                    </asp:LinkButton>
                                </span>

                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                    <asp:Panel ID="pnlSinUbicaciones" runat="server" Visible="false" CssClass="sigma-lista-vacia">
                        Todavía no hay ubicaciones. Agregue la primera arriba.
                    </asp:Panel>

                </div>

                <%-- ============ IMPRESION DE ETIQUETAS ============
                     Se rotula la estantería completa de una vez: entrar y
                     salir de la pantalla por cada estante no lo hace nadie con
                     veinte estantes por delante. --%>
                <asp:Panel ID="pnlEtiquetas" runat="server" Visible="false" CssClass="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-printer-outline"></i>Imprimir etiquetas</div>
                    <div class="ayuda">
                        Cada etiqueta lleva su código impreso y el mismo dato en un QR.
                        Al escanearla con la cámara del teléfono se abre en SIGMA lo que
                        hay en ese lugar, así que sirve tanto para rotular como para
                        consultar de pie frente al estante.
                    </div>

                    <div class="sigma-opciones">

                        <button type="button" runat="server" id="btnEtiquetaBodega" class="sigma-opcion">
                            <span class="icono"><i class="mdi mdi-warehouse"></i></span>
                            <span class="cuerpo">
                                <span class="titulo">Etiqueta de la bodega</span>
                                <span class="nota">Una sola, para la puerta o el acceso.</span>
                            </span>
                        </button>

                        <button type="button" runat="server" id="btnEtiquetaUbicaciones" class="sigma-opcion">
                            <span class="icono"><i class="mdi mdi-view-grid-outline"></i></span>
                            <span class="cuerpo">
                                <span class="titulo">Etiquetas de las ubicaciones</span>
                                <span class="nota">Una por estante. No cambian aunque cambie lo guardado.</span>
                            </span>
                        </button>

                        <button type="button" runat="server" id="btnEtiquetaConRepuesto" class="sigma-opcion">
                            <span class="icono"><i class="mdi mdi-package-variant-closed"></i></span>
                            <span class="cuerpo">
                                <span class="titulo">Ubicación con su repuesto</span>
                                <span class="nota"><asp:Literal ID="litNotaConRepuesto" runat="server"
                                    Text="Rotula el casillero con lo que hay hoy." /></span>
                            </span>
                        </button>

                    </div>
                </asp:Panel>

            </asp:Panel>
        </rad:RadPageView>

    </rad:RadMultiPage>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Bodega" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
