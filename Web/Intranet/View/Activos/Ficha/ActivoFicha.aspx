<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoFicha.aspx.cs" Inherits="View_Activos_Ficha_ActivoFicha" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-activo-ficha.css?vrs=2") %>' rel="stylesheet" />
    <script type="text/javascript">
        // Pestañas: delegación a nivel documento para que sigan funcionando
        // después de cada refresco del UpdatePanel, sin volver a enlazar nada.
        document.addEventListener('click', function (e) {
            var tab = e.target.closest ? e.target.closest('.sigma-af-tab') : null;
            if (!tab) return;
            var scope = tab.closest('.sigma-af');
            if (!scope) return;
            scope.querySelectorAll('.sigma-af-tab').forEach(function (x) { x.classList.remove('is-activa'); });
            scope.querySelectorAll('.sigma-af-pane').forEach(function (x) { x.classList.remove('is-activa'); });
            tab.classList.add('is-activa');
            var pane = scope.querySelector('.sigma-af-pane[data-pane="' + tab.getAttribute('data-tab') + '"]');
            if (pane) pane.classList.add('is-activa');
        });
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Activos</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Ficha e historial</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Toda la vida de un equipo en una sola pantalla.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para consultar sus activos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- ====== SELECTOR DE ACTIVO (integrado, autocarga) ====== --%>
            <div class="sigma-af-selector">
                <span class="sigma-af-selector-ico"><i class="mdi mdi-cog-outline"></i></span>
                <div class="sigma-af-selector-campo">
                    <label>Activo</label>
                    <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%"
                        EmptyMessage="Escriba o elija un activo…" />
                </div>
            </div>

            <asp:Panel ID="pnlSinActivo" runat="server" Visible="true" CssClass="sigma-af-inicial">
                <i class="mdi mdi-gesture-tap"></i>
                <p>Elija un activo arriba para ver su ficha completa y su historial.</p>
            </asp:Panel>

            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sigma-af">

                <%-- ====== ENCABEZADO ====== --%>
                <div class="sigma-af-hero">
                    <div>
                        <h1>
                            <asp:Literal ID="litHeroCodigo" runat="server" />
                            <span class="sep">·</span>
                            <asp:Literal ID="litHeroNombre" runat="server" />
                            <asp:Literal ID="litBadges" runat="server" />
                        </h1>
                        <p class="sigma-af-bajada">Vista 360° del activo, su configuración y trazabilidad operacional.</p>
                    </div>
                    <div class="sigma-af-hero-acc">
                        <asp:HyperLink ID="hlEditar" runat="server" CssClass="sigma-af-btn is-plano" NavigateUrl="javascript:void(0)">
                            <i class="mdi mdi-pencil-outline"></i> Editar activo
                        </asp:HyperLink>
                        <asp:HyperLink ID="hlGenerarOT" runat="server" CssClass="sigma-af-btn is-primario">
                            <i class="mdi mdi-plus-circle-outline"></i> Generar OT
                        </asp:HyperLink>
                    </div>
                </div>

                <%-- ====== TARJETA RESUMEN: IMAGEN + IDENTIDAD + MÉTRICAS ====== --%>
                <div class="sigma-af-resumen">
                    <div class="sigma-af-foto"><asp:Literal ID="litImagen" runat="server" /></div>
                    <div>
                        <div class="sigma-af-ident">
                            <h2><asp:Literal ID="litIdentCodigo" runat="server" /></h2>
                            <div class="sigma-af-ident-filas">
                                <div class="fila"><i class="mdi mdi-cog-outline"></i><asp:Literal ID="litTipo" runat="server" /></div>
                                <div class="fila"><i class="mdi mdi-factory"></i><asp:Literal ID="litPlanta" runat="server" /></div>
                                <div class="fila"><i class="mdi mdi-map-marker-outline"></i><asp:Literal ID="litArea" runat="server" /></div>
                            </div>
                        </div>
                        <div class="sigma-af-tiles">
                            <div class="sigma-af-tile">
                                <div class="ico"><i class="mdi mdi-pulse"></i></div>
                                <div class="rot">Estado</div>
                                <div class="val"><asp:Literal ID="litTileEstado" runat="server" /></div>
                            </div>
                            <div class="sigma-af-tile">
                                <div class="ico"><i class="mdi mdi-shield-alert-outline"></i></div>
                                <div class="rot">Criticidad</div>
                                <div class="val"><asp:Literal ID="litTileCriticidad" runat="server" /></div>
                            </div>
                            <div class="sigma-af-tile">
                                <div class="ico"><i class="mdi mdi-file-document-outline"></i></div>
                                <div class="rot">Eventos registrados</div>
                                <div class="val"><asp:Literal ID="litEventos" runat="server" /></div>
                            </div>
                            <div class="sigma-af-tile">
                                <div class="ico"><i class="mdi mdi-calendar-clock"></i></div>
                                <div class="rot">Último evento</div>
                                <div class="val"><asp:Literal ID="litUltimoEvento" runat="server" /></div>
                            </div>
                        </div>
                    </div>
                </div>

                <%-- ====== CUERPO: PESTAÑAS + PANEL LATERAL ====== --%>
                <div class="sigma-af-cuerpo">
                    <div>
                        <div class="sigma-af-tabs">
                            <button type="button" class="sigma-af-tab" data-tab="resumen">Resumen</button>
                            <button type="button" class="sigma-af-tab is-activa" data-tab="historial">Historial</button>
                            <button type="button" class="sigma-af-tab" data-tab="componentes">Componentes</button>
                            <button type="button" class="sigma-af-tab" data-tab="medidores">Medidores</button>
                            <button type="button" class="sigma-af-tab" data-tab="atributos">Atributos técnicos</button>
                            <button type="button" class="sigma-af-tab" data-tab="documentos">Documentos</button>
                        </div>

                        <%-- RESUMEN --%>
                        <div class="sigma-af-pane" data-pane="resumen">
                            <div class="sigma-af-card">
                                <h3>Resumen del activo</h3>
                                <asp:Literal ID="litResumen" runat="server" />
                            </div>
                        </div>

                        <%-- HISTORIAL --%>
                        <div class="sigma-af-pane is-activa" data-pane="historial">
                            <div class="sigma-af-card">
                                <div class="sigma-af-tools">
                                    <h3 style="margin:0;">Historial del activo</h3>
                                    <div class="sigma-af-tools-filtros">
                                        <rad:RadComboBox2 ID="cboTipo" runat="server" Width="150px" AutoPostBack="true" OnSelectedIndexChanged="btnBuscar_Click">
                                            <Items>
                                                <rad:RadComboBoxItem Text="Todos los tipos" Value="" />
                                                <rad:RadComboBoxItem Text="Cambios de estado" Value="ESTADO" />
                                                <rad:RadComboBoxItem Text="Cambios de posición" Value="POSICION" />
                                                <rad:RadComboBoxItem Text="Mediciones" Value="MEDICION" />
                                            </Items>
                                        </rad:RadComboBox2>
                                        <div class="sigma-af-fecha"><WebControls:Calendar ID="calDesde" runat="server" /></div>
                                        <div class="sigma-af-fecha"><WebControls:Calendar ID="calHasta" runat="server" /></div>
                                        <WebControls:PushButton ID="btnBuscar" runat="server" Text="Filtrar" OnClick="btnBuscar_Click" CssClass="sigma-af-btn is-plano" />
                                        <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sigma-af-btn is-plano" OnClick="lnkExportar_Click">
                                            <i class="mdi mdi-download"></i> Exportar
                                        </asp:LinkButton>
                                    </div>
                                </div>

                                <asp:Panel ID="pnlSinEventos" runat="server" Visible="false" CssClass="sigma-af-vacio">
                                    <i class="mdi mdi-timeline-text-outline"></i>
                                    Este activo todavía no tiene eventos registrados.
                                </asp:Panel>

                                <ul class="sigma-af-timeline">
                                    <asp:Repeater ID="rptHistorial" runat="server">
                                        <ItemTemplate>
                                            <li class='sigma-af-ev <%# TipoClase(Eval("tipo_evento")) %>'>
                                                <div class="ev-cab">
                                                    <span class="ev-fecha"><%# FechaLarga(Eval("fecha")) %></span>
                                                    <span class="ev-chip"><%# TipoEtiqueta(Eval("tipo_evento")) %></span>
                                                </div>
                                                <div class="ev-titulo"><%# Server.HtmlEncode(Convert.ToString(Eval("titulo"))) %></div>
                                                <div class="ev-detalle"><%# Server.HtmlEncode(Convert.ToString(Eval("detalle"))) %></div>
                                                <div class="ev-usuario"><i class="mdi mdi-account-circle-outline"></i><%# Server.HtmlEncode(Convert.ToString(Eval("usuario_nombre"))) %></div>
                                            </li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul>
                            </div>
                        </div>

                        <%-- COMPONENTES --%>
                        <div class="sigma-af-pane" data-pane="componentes">
                            <div class="sigma-af-card">
                                <div class="sigma-af-tools">
                                    <h3 style="margin:0;">Componentes del activo</h3>
                                    <asp:HyperLink ID="hlComponentes" runat="server" CssClass="sigma-af-btn is-primario"><i class="mdi mdi-cog-outline"></i> Gestionar</asp:HyperLink>
                                </div>
                                <asp:Panel ID="pnlSinComponentes" runat="server" Visible="false" CssClass="sigma-af-vacio">
                                    <i class="mdi mdi-puzzle-outline"></i> Este activo aún no tiene componentes registrados.
                                </asp:Panel>
                                <div class="sigma-af-tabla">
                                    <asp:Repeater ID="rptComponentes" runat="server">
                                        <HeaderTemplate><div class="fila cab"><span>Código</span><span>Componente</span><span>Tipo</span><span>Estado</span></div></HeaderTemplate>
                                        <ItemTemplate>
                                            <div class="fila">
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("aco_codigo"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("aco_nombre"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("tipo_nombre"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("estado_nombre"))) %></span>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>

                        <%-- MEDIDORES --%>
                        <div class="sigma-af-pane" data-pane="medidores">
                            <div class="sigma-af-card">
                                <div class="sigma-af-tools">
                                    <h3 style="margin:0;">Medidores del activo</h3>
                                    <asp:HyperLink ID="hlMedidores" runat="server" CssClass="sigma-af-btn is-primario"><i class="mdi mdi-cog-outline"></i> Gestionar</asp:HyperLink>
                                </div>
                                <asp:Panel ID="pnlSinMedidores" runat="server" Visible="false" CssClass="sigma-af-vacio">
                                    <i class="mdi mdi-gauge"></i> Este activo aún no tiene medidores configurados.
                                </asp:Panel>
                                <div class="sigma-af-tabla">
                                    <asp:Repeater ID="rptMedidores" runat="server">
                                        <HeaderTemplate><div class="fila cab"><span>Código</span><span>Medidor</span><span>Valor actual</span><span>Unidad</span></div></HeaderTemplate>
                                        <ItemTemplate>
                                            <div class="fila">
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("ame_codigo"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("ame_nombre"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("ame_valor_actual"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("unidad_nombre"))) %></span>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>

                        <%-- ATRIBUTOS --%>
                        <div class="sigma-af-pane" data-pane="atributos">
                            <div class="sigma-af-card">
                                <div class="sigma-af-tools">
                                    <h3 style="margin:0;">Atributos técnicos del tipo</h3>
                                    <asp:HyperLink ID="hlAtributos" runat="server" CssClass="sigma-af-btn is-primario"><i class="mdi mdi-cog-outline"></i> Gestionar</asp:HyperLink>
                                </div>
                                <asp:Panel ID="pnlSinAtributos" runat="server" Visible="false" CssClass="sigma-af-vacio">
                                    <i class="mdi mdi-format-list-bulleted-type"></i> El tipo de este activo aún no tiene atributos técnicos definidos.
                                </asp:Panel>
                                <div class="sigma-af-tabla">
                                    <asp:Repeater ID="rptAtributos" runat="server">
                                        <HeaderTemplate><div class="fila cab"><span>Código</span><span>Atributo</span><span>Tipo de dato</span><span>Unidad</span></div></HeaderTemplate>
                                        <ItemTemplate>
                                            <div class="fila">
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("ate_codigo"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("ate_nombre"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("tipo_dato_nombre"))) %></span>
                                                <span><%# Server.HtmlEncode(Convert.ToString(Eval("unidad_nombre"))) %></span>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>

                        <%-- DOCUMENTOS --%>
                        <div class="sigma-af-pane" data-pane="documentos">
                            <div class="sigma-af-card sigma-af-vacio">
                                <i class="mdi mdi-folder-outline"></i>
                                Aún no hay documentos adjuntos a este activo.
                            </div>
                        </div>
                    </div>

                    <%-- ====== PANEL LATERAL ====== --%>
                    <aside class="sigma-af-panel">
                        <div class="caja">
                            <h3>Ficha técnica</h3>
                            <div class="sigma-af-ft">
                                <div class="fila"><span class="k"><i class="mdi mdi-barcode"></i>Código</span><span class="v"><asp:Literal ID="litFtCodigo" runat="server" /></span></div>
                                <div class="fila"><span class="k"><i class="mdi mdi-cog-outline"></i>Tipo</span><span class="v"><asp:Literal ID="litFtTipo" runat="server" /></span></div>
                                <div class="fila"><span class="k"><i class="mdi mdi-factory"></i>Planta</span><span class="v"><asp:Literal ID="litFtPlanta" runat="server" /></span></div>
                                <div class="fila"><span class="k"><i class="mdi mdi-map-marker-outline"></i>Área</span><span class="v"><asp:Literal ID="litFtArea" runat="server" /></span></div>
                                <div class="fila"><span class="k"><i class="mdi mdi-pulse"></i>Estado</span><span class="v"><asp:Literal ID="litFtEstado" runat="server" /></span></div>
                                <div class="fila"><span class="k"><i class="mdi mdi-shield-alert-outline"></i>Criticidad</span><span class="v"><asp:Literal ID="litFtCriticidad" runat="server" /></span></div>
                            </div>
                        </div>

                        <div class="caja">
                            <h3>Acciones rápidas</h3>
                            <div class="sigma-af-acc">
                                <asp:HyperLink ID="hlAccEditar" runat="server" NavigateUrl="javascript:void(0)"><i class="mdi mdi-pencil-outline"></i>Editar ficha<span class="chev"><i class="mdi mdi-chevron-right"></i></span></asp:HyperLink>
                                <asp:HyperLink ID="hlAccComponentes" runat="server"><i class="mdi mdi-puzzle-outline"></i>Ver componentes<span class="chev"><i class="mdi mdi-chevron-right"></i></span></asp:HyperLink>
                                <asp:HyperLink ID="hlAccCambiar" runat="server"><i class="mdi mdi-swap-horizontal"></i>Cambiar estado<span class="chev"><i class="mdi mdi-chevron-right"></i></span></asp:HyperLink>
                                <asp:HyperLink ID="hlAccOT" runat="server" CssClass="is-primario"><i class="mdi mdi-plus-circle-outline"></i>Generar OT<span class="chev"><i class="mdi mdi-chevron-right"></i></span></asp:HyperLink>
                            </div>
                        </div>
                    </aside>
                </div>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
