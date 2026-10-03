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

        /* Vista previa de los codigos que se van a crear, con la misma regla
           que el mapa 3D (sugerirRack): <prefijo>-<pasillo>-R<numero>, desde el
           siguiente numero libre del pasillo. Los datos los deja el servidor
           en #bodRacksDatos en cada render, asi que sirve tambien despues de
           un postback parcial. */
        function bodPreview() {
            var datos = document.getElementById('bodRacksDatos'),
                pas = document.querySelector('.bod-in-pasillo input, input.bod-in-pasillo'),
                can = document.querySelector('.bod-in-cantidad input, input.bod-in-cantidad'),
                out = document.getElementById('bodRacksPrevia');
            if (!datos || !pas || !can || !out) return;
            var p = (pas.value || '').trim().toUpperCase(), n = parseInt(can.value, 10) || 1;
            if (!/^[A-Z]{1,3}$/.test(p)) { out.innerHTML = 'El pasillo es de 1 a 3 letras (A, B, AB…).'; return; }
            if (n < 1 || n > 30) { out.innerHTML = 'Se crean de 1 a 30 racks por vez.'; return; }
            var max = JSON.parse(datos.getAttribute('data-max') || '{}'), desde = (max[p] || 0) + 1, hasta = desde + n - 1;
            var cod = function (k) { return datos.getAttribute('data-prefijo') + '-' + p + '-R' + (k < 10 ? '0' + k : k); };
            out.innerHTML = (max[p] ? 'Sigue el pasillo ' + p + ': ' : 'Abre el pasillo ' + p + ': ') +
                '<b>' + cod(desde) + '</b>' + (n > 1 ? ' a <b>' + cod(hasta) + '</b>' : '');
        }

        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
    <style type="text/css">
        /* Racks como los ve el mapa 3D: agrupados por pasillo, con lo que
           guardan, la carga por nivel y el ultimo conteo. */
        .bod-racks .sigma-lista-cabecera,
        .bod-racks .sigma-lista-fila { grid-template-columns: 118px minmax(140px, 1fr) 110px 120px 112px 104px; }
        .bod-pasillo {
            display: flex; align-items: center; gap: 10px;
            padding: 8px 16px; background: #F4F6FA; border-top: 1px solid #E2E7F0;
            font-size: 11px; font-weight: 800; letter-spacing: .4px; text-transform: uppercase; color: #4A556D;
        }
        .bod-pasillo:first-child { border-top: 0; }
        .bod-pasillo .chip { margin-left: auto; text-transform: none; letter-spacing: 0; }
        .bod-chip {
            display: inline-flex; align-items: center; gap: 4px; padding: 2px 9px; border-radius: 999px;
            font-size: 11px; font-weight: 800; white-space: nowrap;
        }
        .bod-chip.es-cyan { background: #E8FBFB; color: #007F8A; }
        .bod-chip.es-purple { background: #F2EFFF; color: #6732F4; }
        .bod-chip.es-blue { background: #EAF4FF; color: #087BEA; }
        .bod-chip.es-warning { background: #FFF4E5; color: #B65C00; }
        .bod-chip.es-muted { background: #F4F6FA; color: #68738A; }
        .bod-dato { font-size: 12px; color: #68738A; }
        .bod-dato b { color: #17223B; }
        .bod-previa { font-size: 12px; color: #4A556D; margin-top: 6px; }
        .bod-previa b { color: #6732F4; }
        .bod-mapa {
            display: inline-flex; align-items: center; gap: 6px; height: 38px; padding: 0 14px;
            border: 1px solid #087BEA; border-radius: 10px; color: #087BEA; background: #fff;
            font-size: 13px; font-weight: 700; text-decoration: none;
        }
        .bod-mapa:hover, .bod-mapa:focus { background: #EAF4FF; color: #0565C2; text-decoration: none; }
        @media (max-width: 760px) {
            .bod-racks .sigma-lista-fila { grid-template-columns: 1fr auto; }
        }
    </style>
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
                    <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                         lo escribe quien crea el registro. Van juntos en una sola
                         caja para que se lea como UN codigo y no como dos campos. --%>
                    <div class="sg-codigo">
                        <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                    </div>
                        <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
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

            <%-- Bloque 328: de que caja se descuenta al consumir. Es lo mismo que
                 se cambia en el mapa 3D (bodega > Datos de la bodega). --%>
            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-swap-vertical"></i>Almacenamiento</div>
                <div class="ayuda">
                    El <strong>método de salida</strong> decide de qué caja sale el repuesto al consumir:
                    <strong>FEFO</strong> la que vence primero, <strong>FIFO</strong> la que entró primero,
                    <strong>LIFO</strong> la última que entró. Un repuesto puede tener el suyo propio
                    (en su ficha); los demás siguen el de la bodega.
                </div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Método de salida</label>
                        <asp:DropDownList ID="ddlMetodo" runat="server" CssClass="form-control">
                            <asp:ListItem Value="FEFO">FEFO · vence primero</asp:ListItem>
                            <asp:ListItem Value="FIFO">FIFO · entró primero</asp:ListItem>
                            <asp:ListItem Value="LIFO">LIFO · entró último</asp:ListItem>
                        </asp:DropDownList>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>En el mapa 3D</label>
                        <asp:Literal ID="litResumenMapa" runat="server" />
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
                        Cada rack se crea con el código que lee el <strong>mapa 3D</strong>:
                        <strong><asp:Literal ID="litConvencion" runat="server" /></strong> es
                        pasillo A, rack 01 (impares a la izquierda, pares a la derecha). Es el que va
                        impreso en la etiqueta y <strong>no cambia después</strong>; el nombre sí.
                    </div>
                </div>

                <asp:Literal ID="litRacksDatos" runat="server" />
                <asp:Panel ID="pnlAltaRacks" runat="server" CssClass="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>Pasillo</label>
                        <WebControls:TextBox2 ID="txtPasillo" runat="server" MaxLength="3" UpperCase="true"
                            CssClass="bod-in-pasillo" onkeyup="bodPreview()" onchange="bodPreview()" />
                    </div>
                    <div class="sigma-modal-field is-mini">
                        <label>Racks</label>
                        <WebControls:TextBox2 ID="txtCantidad" runat="server" MaxLength="2" Text="1"
                            CssClass="bod-in-cantidad" onkeyup="bodPreview()" onchange="bodPreview()" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Nombre (opcional)</label>
                        <WebControls:TextBox2 ID="txtUbiNombre" runat="server" MaxLength="400" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>&nbsp;</label>
                        <WebControls:PushButton ID="btnAgregarUbicacion" runat="server"
                            Text="Agregar racks" OnClick="btnAgregarUbicacion_Click" />
                    </div>
                    <div class="sigma-modal-field is-grande" style="margin-top:-6px">
                        <div class="bod-previa" id="bodRacksPrevia"></div>
                        <span class="sigma-modal-ayuda">Vacío, el nombre es «Pasillo A · Rack 04». Varios racks numeran el nombre que escriba.</span>
                    </div>
                </asp:Panel>

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
                <div class="sigma-lista bod-racks">

                    <div class="sigma-lista-cabecera">
                        <span class="col-codigo">Código</span>
                        <span class="col-nombre">Nombre</span>
                        <span>Guarda</span>
                        <span>Carga / nivel</span>
                        <span>Último conteo</span>
                        <span class="col-acciones"></span>
                    </div>

                    <asp:Repeater ID="rptUbicaciones" runat="server"
                        OnItemDataBound="rptUbicaciones_ItemDataBound"
                        OnItemCommand="rptUbicaciones_ItemCommand">
                        <ItemTemplate>
                            <asp:Literal ID="litPasillo" runat="server" />
                            <div class="sigma-lista-fila">

                                <span class="col-codigo">
                                    <span class="sigma-lista-codigo"><%# Server.HtmlEncode(Convert.ToString(Eval("CODIGO"))) %></span>
                                </span>

                                <asp:Panel ID="pnlVista" runat="server" CssClass="col-nombre">
                                    <asp:Literal ID="litNombre" runat="server" />
                                </asp:Panel>

                                <asp:Panel ID="pnlEdicion" runat="server" Visible="false" CssClass="col-nombre">
                                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                                </asp:Panel>

                                <span class="bod-dato"><asp:Literal ID="litGuarda" runat="server" /></span>

                                <span class="bod-dato">
                                    <asp:Literal ID="litCarga" runat="server" />
                                    <asp:Panel ID="pnlCarga" runat="server" Visible="false">
                                        <WebControls:TextBox2 ID="txtCarga" runat="server" MaxLength="10" placeholder="1000" />
                                    </asp:Panel>
                                </span>

                                <span class="bod-dato"><asp:Literal ID="litConteo" runat="server" /></span>

                                <span class="col-acciones">
                                    <asp:HyperLink ID="hlMapaRack" runat="server" CssClass="sigma-lista-accion" Target="_blank"
                                        ToolTip="Ver este rack en el mapa 3D"><i class="mdi mdi-cube-scan"></i></asp:HyperLink>
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
                        Todavía no hay racks. Indique el pasillo y cuántos racks tiene, arriba.
                    </asp:Panel>

                </div>

                <%-- ============ IMPRESION DE ETIQUETAS ============
                     Se rotula la estantería completa de una vez: entrar y
                     salir de la pantalla por cada estante no lo hace nadie con
                     veinte estantes por delante. --%>
                <asp:Panel ID="pnlEtiquetas" runat="server" Visible="false" CssClass="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-printer-outline"></i>Imprimir etiquetas</div>
                    <div class="ayuda">
                        Cada etiqueta lleva su código impreso y el mismo dato en QR o en
                        código de barras (se elige en la hoja de impresión). Al escanearla
                        se abre en SIGMA lo que hay en ese lugar, así que sirve tanto para
                        rotular como para consultar de pie frente al estante.
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
        <asp:HyperLink ID="hlMapa" runat="server" CssClass="bod-mapa" Target="_blank" Visible="false"
            ToolTip="Abre la bodega en el mapa 3D, en otra pestaña"><i class="mdi mdi-cube-scan"></i>Abrir en el mapa 3D</asp:HyperLink>
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Bodega" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
