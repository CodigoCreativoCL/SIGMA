<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Notificaciones.aspx.cs" Inherits="View_Comun_Notificaciones_Notificaciones" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La hoja de estilos NO se enlaza aca.

         El Master ya la carga para el panel de la campana, que existe en
         todas las pantallas. Enlazarla tambien aca la descargaba y parseaba
         dos veces, y cada regla aparecia duplicada en el inspector.

         Peor que eso: este placeholder se dibuja ANTES del link del Master,
         asi que en cada empate ganaba la copia del Master. Con una version
         distinta en la query, el navegador las trata como dos archivos y
         podia quedarse aplicando una copia vieja en cache por encima de la
         nueva. De ahi que los cambios de estilo solo se vieran despues de un
         Ctrl+F5. --%>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Operación
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Centro de Acción Operacional
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Prioriza, gestiona y resuelve situaciones críticas desde un solo lugar.
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">

    <%-- GSAP va LOCAL, no por CDN.

         El proyecto ya vendoriza jQuery y Highcharts en /Js, y una intranet
         de planta no tiene por qué tener salida a internet: un <script> a un
         CDN deja la pantalla sin animaciones y la consola con errores, justo
         en el turno de noche en que nadie puede arreglarlo.

         Este placeholder se dibuja al final del body, así que cuando esto
         corre el ScriptManager ya publicó PageRequestManager, que es de lo
         que dependen las animaciones para volver a correr tras cada
         refresco parcial. --%>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/gsap/gsap.min.js") %>'></script>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-animaciones.js?vrs=1") %>'></script>

    <script type="text/javascript">
        /* Se abre el registro relacionado en la misma ventana modal del
           sitio. Abrirlo marca la alerta LEIDA y nada mas: leer no es
           reconocer, y ninguna de las dos resuelve. */
        function abrirFicha(url, query, id, menu) {
            if (id && window.sigmaAlertas) sigmaAlertas.leer(id, menu);

            /* El modal de SIGMA. La comprobacion de existencia ya no hace
               falta: el componente se crea al primer uso, no es un control
               que pueda no haberse renderizado. */
            SigmaModal.open({
                url: query ? url + "?query=" + query : url,
                title: 'Detalle de la alerta',
                width: 1000,
                initialHeight: 680
            });

            return false;
        }

        /* La ventana modal llama a refresh() al cerrarse: el registro pudo
           cambiar y la bandeja tiene que enterarse. */
        function refresh() { __doPostBack("<%=lnkRevisar.UniqueID %>", ""); }

        /* El icono de SIGMA AI para los avisos del modelo. Se resuelve en el
           servidor y se publica acá para que sigma-alertas.js —que es global y
           no conoce esta ruta— pueda usarlo sin que haya que tocar el Master. */
        window.sigmaToastIconoAi = '<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-toast-dark.svg") %>';

        /* El toast. Se dibuja DENTRO del contenido, nunca sobre la topbar. */
        (function () {
            var ultimoAviso = null;

            function cerrar(caja) {
                if (!caja) return;
                caja.className = caja.className.replace(' is-visible', '');
                window.setTimeout(function () {
                    if (caja.parentNode) caja.parentNode.removeChild(caja);
                }, 220);
            }

            window.sigmaToast = function (titulo, texto, icono, esCritico, clave) {
                /* Una alerta ya avisada no vuelve a sonar: el sondeo pasa
                   cada minuto y repetirlo convierte el aviso en ruido que la
                   gente aprende a ignorar. */
                if (clave && clave === ultimoAviso) return;
                ultimoAviso = clave || null;

                var host = document.getElementById('sgToastHost');
                if (!host) return;

                var caja = document.createElement('div');
                caja.className = 'sg-toast' + (esCritico ? ' is-critico' : '');
                caja.setAttribute('role', 'status');
                caja.setAttribute('aria-live', 'polite');
                caja.setAttribute('tabindex', '0');

                var html = '';
                if (icono) html += '<img class="sg-toast-icono" src="' + icono + '" alt="" />';
                html += '<div class="sg-toast-cuerpo">';
                html += '<div class="sg-toast-titulo"></div>';
                html += '<div class="sg-toast-texto"></div>';
                html += '</div>';
                html += '<button type="button" class="sg-toast-cerrar" aria-label="Cerrar aviso">&times;</button>';
                caja.innerHTML = html;

                /* textContent y no innerHTML: el titulo y la descripcion los
                   escribe el detector a partir de datos del cliente. */
                caja.querySelector('.sg-toast-titulo').textContent = titulo;
                caja.querySelector('.sg-toast-texto').textContent = texto;

                caja.querySelector('.sg-toast-cerrar').onclick = function () { cerrar(caja); };
                caja.onkeydown = function (e) { if (e.keyCode === 27) cerrar(caja); };

                host.appendChild(caja);
                window.setTimeout(function () { caja.className += ' is-visible'; }, 20);
                window.setTimeout(function () { cerrar(caja); }, 9000);
            };
        })();
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">


    <%-- El toast vive DENTRO del contenido: sobre la topbar taparia el
         selector de cliente y la campana, que es justo lo que la persona
         necesita mirar cuando entra un aviso. --%>
    <div id="sgToastHost" class="sg-toast-host" aria-live="polite"></div>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- ============================================================
                 ESTADO EN TIEMPO REAL
                 ============================================================ --%>
            <div class="sg-cao-estado">
                <span class="sg-cao-vivo">
                    <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-realtime.svg") %>'
                         alt="" class="sg-cao-vivo-icono" />
                    <span>Monitoreo en tiempo real</span>
                </span>

                <asp:LinkButton ID="lnkRevisar" runat="server" CssClass="sg-cao-revisar"
                    OnClick="lnkRevisar_Click" ToolTip="Vuelve a revisar los umbrales ahora">
                    <i class="mdi mdi-refresh"></i><span>Revisar ahora</span>
                </asp:LinkButton>
            </div>

            <%-- ============================================================
                 LOS CINCO INDICADORES

                 Todos salen de SEL_ALERTA_RESUMEN. Ninguno esta escrito a
                 mano: un numero inventado en un tablero de operacion es peor
                 que no tener el tablero.
                 ============================================================ --%>
            <div class="sg-kpis">
                <asp:Repeater ID="rptKpis" runat="server">
                    <ItemTemplate>
                        <div class='sg-kpi <%# Eval("Clase") %>'>
                            <%-- Icono a la izquierda, cifra y rotulo apilados al
                                 lado: la cifra queda a la altura del ojo y el
                                 rotulo la explica sin robarle sitio. --%>
                            <div class="sg-kpi-fila">
                                <span class="sg-kpi-icono"><%# Eval("IconoHtml") %></span>
                                <span class="sg-kpi-texto">
                                    <span class="sg-kpi-valor"><%# Eval("Valor") %></span>
                                    <span class="sg-kpi-rotulo"><%# Eval("Rotulo") %></span>
                                </span>
                            </div>

                            <%-- El pie solo aparece si hay con que compararse.
                                 Una tarjeta sin historia no dibuja un cero: deja
                                 el espacio y ya. --%>
                            <div class="sg-kpi-pie">
                                <span class='sg-kpi-var <%# Eval("TendenciaClase") %>'><%# Eval("TendenciaTexto") %></span>
                                <%# Eval("Sparkline") %>
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <%-- ============================================================
                 MAESTRO — DETALLE
                 ============================================================ --%>
            <div class="sg-cao">

                <%-- ---------- COLA DE ALERTAS ---------- --%>
                <div class="sg-cola">
                    <div class="sg-cola-cab">
                        <h2 class="sg-cola-titulo">Cola de alertas</h2>

                        <div class="sg-cola-buscar">
                            <i class="mdi mdi-magnify"></i>
                            <asp:TextBox ID="txtBuscar" runat="server" CssClass="sg-input"
                                placeholder="Buscar alertas..." AutoPostBack="true"
                                OnTextChanged="Filtro_Changed" />
                        </div>

                        <%-- Filter="Contains" para poder escribir y acotar: con
                             doce tipos de alerta, desplegar y buscar con la vista
                             es mas lento que teclear tres letras. --%>
                        <rad:RadComboBox2 ID="cboSeveridad" runat="server" CssClass="sg-select"
                            Filter="Contains" MarkFirstMatch="true" Width="46%"
                            AutoPostBack="true" OnSelectedIndexChanged="Combo_Changed">
                            <Items>
                                <rad:RadComboBoxItem Text="Toda gravedad" Value="" Selected="true" />
                                <rad:RadComboBoxItem Text="Crítica" Value="CRITICA" />
                                <rad:RadComboBoxItem Text="Alta" Value="ALTA" />
                                <rad:RadComboBoxItem Text="Advertencia" Value="ADVERTENCIA" />
                                <rad:RadComboBoxItem Text="Baja" Value="BAJA" />
                            </Items>
                        </rad:RadComboBox2>

                        <rad:RadComboBox2 ID="cboTipo" runat="server" CssClass="sg-select"
                            Filter="Contains" MarkFirstMatch="true" Width="46%"
                            AutoPostBack="true" OnSelectedIndexChanged="Combo_Changed" />
                    </div>

                    <%-- Las pestañas.

                         EL ROTULO VA EN Text, NO ANIDADO DENTRO DEL LINKBUTTON.

                         Estaban escritas con el texto y un <span> como hijos del
                         LinkButton. En la primera carga se veian; en cuanto
                         habia un postback asincrono el UpdatePanel volvia a
                         dibujar su contenido y esos hijos estaticos no se
                         reconstruian: las pestanas desaparecian.

                         Con el rotulo en la propiedad Text —que el ViewState si
                         conserva— el control se dibuja igual la primera vez y
                         todas las siguientes. --%>
                    <div class="sg-tabs" role="tablist">
                        <asp:LinkButton ID="tabActivas" runat="server" CssClass="sg-tab"
                            CommandArgument="ACTIVAS" OnCommand="Tab_Command" CausesValidation="false" />

                        <asp:LinkButton ID="tabGestion" runat="server" CssClass="sg-tab"
                            CommandArgument="GESTION" OnCommand="Tab_Command" CausesValidation="false" />

                        <asp:LinkButton ID="tabResueltas" runat="server" CssClass="sg-tab"
                            CommandArgument="RESUELTAS" OnCommand="Tab_Command" CausesValidation="false" />
                    </div>

                    <div class="sg-cola-lista">
                        <asp:Repeater ID="rptAlertas" runat="server" OnItemDataBound="rptAlertas_ItemDataBound"
                            OnItemCommand="rptAlertas_ItemCommand">
                            <ItemTemplate>
                                <asp:LinkButton ID="lnkItem" runat="server" CommandName="Seleccionar"
                                    CommandArgument='<%# Eval("ale_id") %>' CssClass="sg-alerta">
                                    <asp:Literal ID="litItem" runat="server" />
                                </asp:LinkButton>
                            </ItemTemplate>
                        </asp:Repeater>

                        <asp:Panel ID="pnlColaVacia" runat="server" Visible="false" CssClass="sg-vacio">
                            <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-symbol-gradient.svg") %>'
                                 alt="" class="sg-vacio-marca" />
                            <div class="sg-vacio-titulo">Nada pendiente acá</div>
                            <div class="sg-vacio-texto">
                                <asp:Literal ID="litColaVacia" runat="server"
                                    Text="No hay alertas con estos filtros." />
                            </div>
                        </asp:Panel>
                    </div>
                </div>

                <%-- ---------- DETALLE ACCIONABLE ---------- --%>
                <div class="sg-detalle">

                    <asp:Panel ID="pnlSinSeleccion" runat="server" CssClass="sg-vacio sg-vacio-alto">
                        <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-symbol-gradient.svg") %>'
                             alt="" class="sg-vacio-marca" />
                        <div class="sg-vacio-titulo">Elija una alerta</div>
                        <div class="sg-vacio-texto">
                            El detalle, el análisis y las acciones aparecen acá.
                        </div>
                    </asp:Panel>

                    <asp:Panel ID="pnlDetalle" runat="server" Visible="false">

                        <%-- ============================================================
                             LAS ACCIONES VAN DECLARADAS, NO CREADAS A MANO

                             Estaban construidas en el code-behind dentro de un
                             PlaceHolder, y desde PreRender. Un control creado
                             tan tarde se DIBUJA bien pero en el postback
                             todavia no existe cuando ASP.NET reparte los
                             eventos: los botones se veian y no hacian nada.

                             Declarados aca existen desde el inicio del ciclo,
                             el evento siempre encuentra su control, y lo unico
                             que decide el code-behind es cuales se ven.
                             ============================================================ --%>
                        <div class="sg-det-cab">
                            <div class="sg-det-chips"><asp:Literal ID="litChips" runat="server" /></div>

                            <div class="sg-det-acciones">
                                <asp:LinkButton ID="btnTomar" runat="server" CssClass="sg-btn sg-btn-primario"
                                    OnClick="Tomar_Click" CausesValidation="false" Visible="false"
                                    Text="&lt;i class='mdi mdi-hand-back-right-outline'&gt;&lt;/i&gt;&lt;span&gt;Tomar alerta&lt;/span&gt;" />

                                <asp:LinkButton ID="btnGestionar" runat="server" CssClass="sg-btn"
                                    OnClick="Gestionar_Click" CausesValidation="false" Visible="false"
                                    Text="&lt;i class='mdi mdi-progress-wrench'&gt;&lt;/i&gt;&lt;span&gt;Iniciar gestión&lt;/span&gt;" />

                                <asp:LinkButton ID="btnAsignar" runat="server" CssClass="sg-btn"
                                    OnClick="Asignar_Click" CausesValidation="false" Visible="false"
                                    Text="&lt;i class='mdi mdi-account-arrow-right-outline'&gt;&lt;/i&gt;&lt;span&gt;Asignar responsable&lt;/span&gt;" />

                                <asp:LinkButton ID="btnResolver" runat="server" CssClass="sg-btn"
                                    OnClick="Resolver_Click" CausesValidation="false" Visible="false"
                                    Text="&lt;i class='mdi mdi-check-circle-outline'&gt;&lt;/i&gt;&lt;span&gt;Resolver&lt;/span&gt;" />

                                <asp:LinkButton ID="btnDescartar" runat="server" CssClass="sg-btn"
                                    OnClick="Descartar_Click" CausesValidation="false" Visible="false"
                                    Text="&lt;i class='mdi mdi-close-circle-outline'&gt;&lt;/i&gt;&lt;span&gt;Descartar&lt;/span&gt;" />

                                <asp:HyperLink ID="lnkOrigen" runat="server" CssClass="sg-btn" Visible="false"
                                    NavigateUrl="javascript:void(0);"
                                    Text="&lt;i class='mdi mdi-open-in-new'&gt;&lt;/i&gt;&lt;span&gt;Abrir origen&lt;/span&gt;" />
                            </div>
                        </div>

                        <%-- Asignar responsable. Aparece al pedirlo, no siempre:
                             un combo permanente con veinte nombres compite con
                             lo que de verdad hay que mirar. --%>
                        <asp:Panel ID="pnlAsignar" runat="server" Visible="false" CssClass="sg-cierre">
                            <label for="<%=cboResponsable.ClientID %>" class="sg-cierre-rotulo">
                                ¿Quién se hace cargo?
                            </label>
                            <rad:RadComboBox2 ID="cboResponsable" runat="server" CssClass="sg-select"
                                Filter="Contains" MarkFirstMatch="true" Width="100%"
                                EmptyMessage="Escriba para buscar…" />
                            <div class="sg-cierre-botones">
                                <asp:LinkButton ID="btnAsignarConfirmar" runat="server" CssClass="sg-btn sg-btn-primario"
                                    OnClick="btnAsignarConfirmar_Click" CausesValidation="false">Asignar</asp:LinkButton>
                                <asp:LinkButton ID="btnAsignarCancelar" runat="server" CssClass="sg-btn"
                                    OnClick="btnAsignarCancelar_Click" CausesValidation="false">Cancelar</asp:LinkButton>
                            </div>
                        </asp:Panel>

                        <h2 class="sg-det-titulo"><asp:Literal ID="litTitulo" runat="server" /></h2>
                        <div class="sg-det-meta"><asp:Literal ID="litMeta" runat="server" /></div>

                        <div class="sg-det-descripcion"><asp:Literal ID="litDescripcion" runat="server" /></div>

                        <%-- ---- PANEL DE SIGMA AI ----
                             Solo cuando la alerta salio del modelo. En una de
                             stock no aparece: decir "probabilidad de falla: no
                             disponible" ahi sugiere que el modelo opino y no
                             lo hizo. --%>
                        <asp:Panel ID="pnlPrediccion" runat="server" Visible="false" CssClass="sg-ai">
                            <div class="sg-ai-cab">
                                <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-logo-horizontal-light.svg") %>'
                                     alt="SIGMA AI" class="sg-ai-logo" />
                                <span class="sg-ai-cuando"><asp:Literal ID="litAiCuando" runat="server" /></span>
                            </div>

                            <div class="sg-ai-grid">
                                <%-- La tarjeta de riesgo: el titulo a la izquierda y
                                     la marca del modelo a la derecha, porque lo que
                                     manda es el dato y no de donde salio. --%>
                                <div class="sg-ai-tarjeta sg-ai-riesgo-card">
                                    <div class="sg-ai-tarjeta-cab">
                                        <span>Análisis predictivo de riesgo</span>
                                        <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-symbol-gradient.svg") %>'
                                             alt="SIGMA AI" class="sg-ai-icono" />
                                    </div>

                                    <div class="sg-ai-riesgo"><asp:Literal ID="litRiesgo" runat="server" /></div>

                                    <%-- La curva solo aparece si el modelo puntuo mas
                                         de una vez. Con un punto no hay historia que
                                         contar y se esconde entera. --%>
                                    <asp:Literal ID="litCurva" runat="server" />
                                </div>

                                <div class="sg-ai-tarjeta">
                                    <div class="sg-ai-tarjeta-cab">
                                        <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-prediction.svg") %>'
                                             alt="" class="sg-ai-icono" />
                                        <span>Qué detectó SIGMA AI</span>
                                    </div>
                                    <div class="sg-ai-texto"><asp:Literal ID="litHallazgo" runat="server" /></div>
                                </div>

                                <div class="sg-ai-tarjeta">
                                    <div class="sg-ai-tarjeta-cab"><span>Factores principales</span></div>
                                    <div class="sg-ai-factores"><asp:Literal ID="litFactores" runat="server" /></div>
                                </div>
                            </div>

                            <%-- ---- DE LA PREDICCION AL ENCARGO ----

                                 Sin esto el panel termina en un dato: "este motor
                                 falla en 9 dias". El boton es lo que lo convierte
                                 en trabajo asignado.

                                 Aparece solo si la persona tiene la funcion, y se
                                 cambia por el enlace a la OT cuando ya existe: no
                                 se ofrece generar dos veces lo mismo. --%>
                            <div class="sg-ai-pie">
                                <asp:LinkButton ID="btnGenerarOt" runat="server" Visible="false"
                                    CssClass="sg-ai-ot" OnClick="btnGenerarOt_Click"
                                    Text="Generar orden de trabajo" />

                                <asp:Literal ID="litOrdenTrabajo" runat="server" />
                            </div>
                        </asp:Panel>

                        <%-- SIGMA AI todavia calculando. Solo para la evidencia
                             concreta que se esta analizando, no como loader de
                             la pagina entera. --%>
                        <asp:Panel ID="pnlAnalizando" runat="server" Visible="false" CssClass="sg-ai-analizando">
                            <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-analyzing.svg") %>'
                                 alt="" class="sg-ai-icono" />
                            <span>SIGMA AI está analizando la información…</span>
                        </asp:Panel>

                        <%-- ---- ACCION RECOMENDADA ---- --%>
                        <asp:Panel ID="pnlRecomendacion" runat="server" Visible="false" CssClass="sg-reco">
                            <img src='<%=ResolveUrl("~/Imagen/sigma-ai/sigma-ai-status-recommendation.svg") %>'
                                 alt="" class="sg-reco-icono" />
                            <div class="sg-reco-cuerpo">
                                <div class="sg-reco-titulo">Acción recomendada</div>
                                <div class="sg-reco-texto"><asp:Literal ID="litRecomendacion" runat="server" /></div>
                            </div>
                        </asp:Panel>

                        <%-- ---- LINEA DE TIEMPO ---- --%>
                        <div class="sg-linea">
                            <div class="sg-linea-titulo">Línea de tiempo</div>
                            <asp:Literal ID="litLinea" runat="server" />
                        </div>

                        <%-- ---- CERRAR CON MOTIVO ---- --%>
                        <asp:Panel ID="pnlCierre" runat="server" Visible="false" CssClass="sg-cierre">
                            <label for="<%=txtMotivo.ClientID %>" class="sg-cierre-rotulo">
                                <asp:Literal ID="litCierreRotulo" runat="server" />
                            </label>
                            <asp:TextBox ID="txtMotivo" runat="server" CssClass="sg-input sg-input-area"
                                TextMode="MultiLine" Rows="2" MaxLength="1000" />
                            <div class="sg-cierre-botones">
                                <asp:LinkButton ID="lnkCierreConfirmar" runat="server" CssClass="sg-btn sg-btn-primario"
                                    OnClick="lnkCierreConfirmar_Click">Confirmar</asp:LinkButton>
                                <asp:LinkButton ID="lnkCierreCancelar" runat="server" CssClass="sg-btn"
                                    OnClick="lnkCierreCancelar_Click" CausesValidation="false">Cancelar</asp:LinkButton>
                            </div>
                        </asp:Panel>

                    </asp:Panel>
                </div>
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>

</asp:Content>
