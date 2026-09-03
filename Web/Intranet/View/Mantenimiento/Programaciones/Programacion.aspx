<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Programacion.aspx.cs" Inherits="View_Mantenimiento_Programaciones_Programacion" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">

    <%-- Esta hoja se enlaza SOLO aca. Es de esta ficha y de ninguna otra
         pantalla, asi que no tiene por que vivir en el Master. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-programacion.css?vrs=9") %>' rel="stylesheet" />

    <script type="text/javascript" src='<%=ResolveUrl("~/Js/gsap/gsap.min.js") %>'></script>
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-programacion.js?vrs=6") %>'></script>

    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }

        /* Confirmar antes de borrar.

           Una exclusion borrada por error no avisa: la programacion vuelve a
           generar trabajo el feriado y nadie se entera hasta que alguien
           llega a la planta un 18 de septiembre. */
        function confirmarBorrado(texto) {
            return window.confirm(texto || '¿Eliminar este registro?');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal sg-prog-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <%-- ============================================================
         UNA FICHA Y NO CINCO

         El backlog proponia una pantalla por tipo —ProgramacionCalendario,
         ProgramacionMedidor…—. Pero los cinco tipos comparten vigencia,
         tolerancias, zona horaria y politica: cinco pantallas serian las
         mismas cuatro secciones copiadas, y el dia que cambie una regla
         comun hay que acordarse de las cinco.

         Aca el combo de tipo intercambia UN panel. Lo demas es igual
         siempre, porque es igual siempre.
         ============================================================ --%>

    <%-- ---------------------------------------------------------------
         ENCABEZADO
         --------------------------------------------------------------- --%>
    <%-- EL ESTADO QUE SOBREVIVE AL GUARDADO

         En qué paso está, a quién se asigna y qué frecuencia se eligió los
         mueve el navegador sin ir al servidor. Guardar SÍ es un postback, y
         sin estos tres campos el servidor no tendría cómo saber nada de eso:
         devolvería la página en el paso 1 y con la frecuencia vieja.

         ClientIDMode="Static" para que el JS los encuentre por un id fijo en
         vez de adivinar el que le pone el Master. --%>
    <asp:HiddenField ID="hfPaso" runat="server" ClientIDMode="Static" Value="1" />
    <asp:HiddenField ID="hfModo" runat="server" ClientIDMode="Static" Value="nadie" />
    <asp:HiddenField ID="hfFrecuencia" runat="server" ClientIDMode="Static" Value="" />

    <div class="sg-prog-cab">
        <div class="sg-prog-cab-txt">
            <span class="sg-prog-eyebrow"><asp:Literal ID="litModo" runat="server" Text="Nueva programación" /></span>

            <h1 class="sg-prog-titulo">
                <asp:Literal ID="litTitulo" runat="server" Text="Programación" />
                <span class="sg-prog-id">ID <asp:Label ID="lblId" runat="server" /></span>
                <asp:Literal ID="litEstado" runat="server" />
            </h1>

            <p class="sg-prog-bajada">
                Define cuándo, dónde y para quién se generarán las actividades de mantenimiento.
            </p>
        </div>

        <div class="sg-prog-cab-acciones">
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar programación"
                CssClass="sg-btn-principal" OnClick="btnGuardar_Click" ValidationGroup="Programacion" />
        </div>
    </div>

    <%-- ---------------------------------------------------------------
         EL STEPPER

         Seis botones de servidor, no seis divs con javascript. Cada paso
         hace postback y el servidor decide cual esta activo, cual quedo
         completo y cual tiene algo pendiente. Un stepper que solo se pinta
         en el cliente no puede saber si al paso 4 le falta la hora.
         --------------------------------------------------------------- --%>
    <div class="sg-pasos" role="tablist">
        <asp:Repeater ID="rptPasos" runat="server" OnItemCommand="rptPasos_ItemCommand">
            <ItemTemplate>
                <asp:LinkButton runat="server" CssClass='<%# Eval("Clase") %>'
                    CommandName="ir" CommandArgument='<%# Eval("Numero") %>'
                    CausesValidation="false" ToolTip='<%# Eval("Ayuda") %>'>
                    <span class="sg-paso-bolita"><%# Eval("Bolita") %></span>
                    <span class="sg-paso-rotulo"><%# Eval("Titulo") %></span>
                </asp:LinkButton>
            </ItemTemplate>
            <SeparatorTemplate><span class="sg-paso-linea"></span></SeparatorTemplate>
        </asp:Repeater>
    </div>

    <%-- ---------------------------------------------------------------
         CUERPO: formulario a la izquierda, resumen a la derecha
         --------------------------------------------------------------- --%>
    <div class="sg-prog">

    <div class="sg-prog-form">

        <%-- ==========================================================
             PASO 1 — INFORMACION GENERAL

             OJO: los seis pasos se renderizan SIEMPRE y se ocultan con
             CSS, nunca con Visible="false". Un control que no se
             renderiza no postea, y cambiar de paso borraria lo escrito
             en los otros cinco. Es un requisito explicito: no se pierde
             informacion al moverse entre pasos.
             ========================================================== --%>
        <asp:Panel ID="pnlPaso1" runat="server" CssClass="sg-paso-panel">
            <div class="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra">A</span>
                    <div>
                        <div class="sg-tarjeta-titulo">Qué se programa</div>
                        <div class="sg-tarjeta-bajada">Información base de la programación.</div>
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mitad">
                        <label for="<%=txtNombre.ClientID %>">Nombre de la programación (*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Programacion" />
                        <span class="sigma-modal-ayuda">Cómo se la reconoce: "Inspección semanal de bombas".</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=cboTipo.ClientID %>">Tipo (*)</label>
                        <rad:RadComboBox2 ID="cboTipo" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="cboTipo_SelectedIndexChanged" />
                        <span class="sigma-modal-ayuda sg-candado">
                            <i class="mdi mdi-lock-outline"></i>
                            El tipo no puede cambiarse después de guardar.
                        </span>
                    </div>

                    <div class="sigma-modal-field is-chico">
                        <label>Vigente desde (*)</label>
                        <div class="sigma-modal-fecha"><WebControls:Calendar ID="calInicio" runat="server" /></div>
                    </div>

                    <div class="sigma-modal-field is-chico">
                        <label>Vigente hasta</label>
                        <div class="sigma-modal-fecha"><WebControls:Calendar ID="calFin" runat="server" /></div>
                        <span class="sigma-modal-ayuda">Vacío indica sin término.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=cboZonaHoraria.ClientID %>">Zona horaria</label>
                        <rad:RadComboBox2 ID="cboZonaHoraria" runat="server" />
                        <span class="sigma-modal-ayuda">
                            La hora se guarda en UTC y se muestra en esta zona. Sin ella el horario de
                            verano corre las ocurrencias una hora dos veces al año.
                        </span>
                    </div>
                </div>
            </div>
        </asp:Panel>

        <%-- ==========================================================
             PASO 2 — ALCANCE

             Estas columnas no existian: la tabla decia cuando y cada
             cuanto, pero no donde. Se agregaron en el bloque 118 porque
             una regla que genera trabajo sin decir en que instalacion se
             hace no es una programacion, es un recordatorio.
             ========================================================== --%>
        <asp:Panel ID="pnlPaso2" runat="server" CssClass="sg-paso-panel">
            <div class="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra">B</span>
                    <div>
                        <div class="sg-tarjeta-titulo">Dónde se realiza</div>
                        <div class="sg-tarjeta-bajada">De lo general a lo particular: planta, área y equipo.</div>
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label for="<%=cboInstalacion.ClientID %>">Instalación</label>
                        <rad:RadComboBox2 ID="cboInstalacion" runat="server" AutoPostBack="true"
                            Filter="Contains" MarkFirstMatch="true"
                            OnSelectedIndexChanged="cboInstalacion_SelectedIndexChanged" />
                        <span class="sigma-modal-ayuda">Al elegirla se cargan sus áreas y sus equipos.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=cboArea.ClientID %>">Área</label>
                        <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" MarkFirstMatch="true" />
                        <span class="sigma-modal-ayuda">Opcional. Sin área, el alcance es toda la instalación.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=cboActivo.ClientID %>">Activo</label>
                        <rad:RadComboBox2 ID="cboActivo" runat="server" Filter="Contains" MarkFirstMatch="true" />
                        <span class="sigma-modal-ayuda">Opcional. Un equipo concreto en vez de todo el área.</span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <div class="sigma-modal-note">
                            <i class="mdi mdi-information-outline"></i>
                            <div>
                                El activo tiene que pertenecer a la instalación elegida. Sin esa regla se
                                podría programar el mantenimiento de un motor de una planta diciendo que
                                se hace en otra, y la orden saldría con la cuadrilla equivocada.
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </asp:Panel>

        <%-- ==========================================================
             PASO 3 — ASIGNACION
             ========================================================== --%>
        <asp:Panel ID="pnlPaso3" runat="server" CssClass="sg-paso-panel">
            <div class="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra">C</span>
                    <div>
                        <div class="sg-tarjeta-titulo">Quién responde</div>
                        <div class="sg-tarjeta-bajada">Una persona o un grupo. Nunca los dos.</div>
                    </div>
                </div>

                <%-- Las dos opciones son UNA decision, no dos casillas
                     sueltas: por eso van como tarjetas que se eligen y no
                     como radios dispersos. --%>
                <div class="sg-opciones" role="radiogroup" aria-label="A quién se asigna">
                    <asp:LinkButton ID="btnModoPersona" runat="server" CssClass="sg-opcion"
                        CommandName="persona" OnClick="ModoAsignacion_Click" CausesValidation="false" data-modo="persona">
                        <span class="sg-opcion-marca"><i class="mdi mdi-check"></i></span>
                        <span class="sg-opcion-txt">
                            <span class="sg-opcion-t"><i class="mdi mdi-account-outline"></i> Personas</span>
                            <span class="sg-opcion-d">Una o varias personas concretas. No hace falta crear un grupo.</span>
                        </span>
                    </asp:LinkButton>

                    <asp:LinkButton ID="btnModoGrupo" runat="server" CssClass="sg-opcion"
                        CommandName="grupo" OnClick="ModoAsignacion_Click" CausesValidation="false" data-modo="grupo">
                        <span class="sg-opcion-marca"><i class="mdi mdi-check"></i></span>
                        <span class="sg-opcion-txt">
                            <span class="sg-opcion-t"><i class="mdi mdi-account-group-outline"></i> Un grupo</span>
                            <span class="sg-opcion-d">Responde una cuadrilla: personas concretas con su especialidad.</span>
                        </span>
                    </asp:LinkButton>

                    <asp:LinkButton ID="btnModoNadie" runat="server" CssClass="sg-opcion"
                        CommandName="nadie" OnClick="ModoAsignacion_Click" CausesValidation="false" data-modo="nadie">
                        <span class="sg-opcion-marca"><i class="mdi mdi-check"></i></span>
                        <span class="sg-opcion-txt">
                            <span class="sg-opcion-t"><i class="mdi mdi-account-question-outline"></i> Sin asignar</span>
                            <span class="sg-opcion-d">Se decide al generar cada actividad.</span>
                        </span>
                    </asp:LinkButton>
                </div>

                <div class="sigma-modal-grid">
                    <asp:Panel ID="pnlPersona" runat="server" CssClass="sigma-modal-field is-medio sg-campo-persona">
                        <label for="<%=cboResponsable.ClientID %>">Responsables</label>
                        <%-- CheckBoxes: se eligen varias sin salir del combo. Antes era una
                             sola, y para asignarle el trabajo a tres tecnicos habia
                             que inventarles una cuadrilla permanente. --%>
                        <rad:RadComboBox2 ID="cboResponsable" runat="server" CheckBoxes="true"
                            Filter="Contains" MarkFirstMatch="true"
                            EmptyMessage="Seleccione una o más personas"
                            OnClientItemChecked="sgResponsablesCambio"
                            OnClientLoad="sgResponsablesCargado" />

                        <%-- Los elegidos, con su cara. "2 seleccionados" no dice
                             QUIENES, que es justo lo que hay que poder revisar
                             antes de guardar. --%>
                        <div id="sgResponsablesChips" class="sg-personas"></div>

                        <span class="sigma-modal-ayuda">Se pueden marcar varias personas.</span>
                    </asp:Panel>

                    <asp:Panel ID="pnlGrupo" runat="server" CssClass="sigma-modal-field is-medio sg-campo-grupo">
                        <label for="<%=cboGrupo.ClientID %>">Grupo de trabajo</label>
                        <rad:RadComboBox2 ID="cboGrupo" runat="server" Filter="Contains" MarkFirstMatch="true" />
                    </asp:Panel>

                    <div class="sigma-modal-field is-ancho">
                        <div class="sigma-modal-note">
                            <i class="mdi mdi-information-outline"></i>
                            <div>
                                Asignar a una persona <strong>y</strong> a un grupo a la vez es la forma más
                                común de que al final no responda nadie: cada parte supone que contestaba
                                la otra. Por eso es una sola decisión.
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </asp:Panel>

        <%-- ==========================================================
             PASO 4 — FRECUENCIA Y CALENDARIO
             ========================================================== --%>
        <asp:Panel ID="pnlPaso4" runat="server" CssClass="sg-paso-panel">

            <asp:Panel ID="pnlRegla" runat="server" CssClass="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra">D</span>
                    <div>
                        <div class="sg-tarjeta-titulo">Frecuencia y calendario</div>
                        <div class="sg-tarjeta-bajada">Define la recurrencia y cuándo debe ejecutarse.</div>
                    </div>
                </div>

                <%-- ---------- FECHA ÚNICA (HU-070) ---------- --%>
                <asp:Panel ID="pnlFechaUnica" runat="server" Visible="false">
                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico sg-nueva-fecha">
                            <label>Agregar fecha</label>
                            <div class="sigma-modal-fecha"><WebControls:Calendar ID="calNuevaFecha" runat="server" /></div>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label for="<%=cboNuevaHora.ClientID %>">Hora</label>
                            <rad:RadComboBox2 ID="cboNuevaHora" runat="server" Filter="Contains" MarkFirstMatch="true" />
                        </div>

                        <div class="sigma-modal-field is-mini">
                            <label>&nbsp;</label>
                            <%-- El OnClick de servidor se conserva: si el JS no
                                 corre, el botón sigue funcionando por postback.
                                 Con JS, se intercepta y va por el web service. --%>
                            <WebControls:PushButton ID="btnAgregarFecha" runat="server" Text="Agregar"
                                CssClass="sg-btn-secundario sg-agregar-fecha"
                                OnClick="btnAgregarFecha_Click" CausesValidation="false" />
                        </div>
                        <div class="sigma-modal-field is-ancho">
                            <span class="sigma-modal-ayuda">
                                Cada fecha genera una ocurrencia independiente, con su propia ejecución,
                                estado y evidencias. Una fecha anterior a hoy se acepta: sirve para
                                registrar trabajo ya realizado.
                            </span>
                        </div>
                        <%-- LA TABLA DE FECHAS

                             Se dibuja en el navegador desde WsProgramacion.asmx.
                             Agregar, corregir y quitar una fecha son acciones
                             sobre UNA fila: devolver la ficha entera al servidor
                             y volver a pintar los seis pasos por cada una es
                             justamente lo que el patron llama una microaccion.

                             La grilla original queda viva y oculta: sus eventos
                             siguen registrados y es el camino de vuelta si algun
                             dia hace falta exportar o paginar. --%>
                        <div class="sigma-modal-field is-ancho">
                            <div id="sgFechas" class="sg-tabla-fechas"
                                 data-prog='<%=IdCifrado() %>'
                                 data-url='<%=ResolveUrl("~/WebService/WsProgramacion.asmx") %>'></div>

                            <div class="sg-oculto-accesible">
                                <rad:RadGrid2 ID="grdFechas" runat="server" OnItemDataBound="grdFechas_ItemDataBound"
                                    OnItemCommand="grdFechas_ItemCommand">
                                    <MasterTableView CommandItemDisplay="None" DataKeyNames="pfe_id" />
                                </rad:RadGrid2>
                            </div>
                        </div>
                    </div>
                </asp:Panel>

                <%-- ---------- CALENDARIO (HU-071) ---------- --%>
                <asp:Panel ID="pnlCalendario" runat="server" Visible="false">

                    <%-- La frecuencia como pestañas y no como combo: son
                         cinco opciones excluyentes y cual esta elegida
                         cambia TODO lo que se pide abajo. Un combo esconde
                         esa consecuencia detras de un clic. --%>
                    <div class="sg-segmentado" role="tablist" aria-label="Frecuencia">
                        <asp:Repeater ID="rptFrecuencias" runat="server" OnItemCommand="rptFrecuencias_ItemCommand">
                            <ItemTemplate>
                                <asp:LinkButton runat="server" CssClass='<%# Eval("Clase") %>'
                                    CommandName="frec" CommandArgument='<%# Eval("Id") %>'
                                    data-id='<%# Eval("Id") %>'
                                    CausesValidation="false" Text='<%# Eval("Nombre") %>' />
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>

                    <%-- El combo real sigue existiendo y sigue siendo la
                         fuente de verdad: las pestañas lo mueven. Asi el
                         code-behind, la validacion y el guardado no cambian.
                         Queda oculto, no eliminado. --%>
                    <div class="sg-oculto-accesible">
                        <rad:RadComboBox2 ID="cboFrecuencia" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="cboFrecuencia_SelectedIndexChanged" />
                    </div>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-mini">
                            <label>Repetir cada</label>
                            <div class="sg-conunidad">
                                <rad:RadNumericBox2 ID="txtIntervalo" runat="server">
                                    <NumberFormat DecimalDigits="0" />
                                </rad:RadNumericBox2>
                                <span class="sg-unidad sg-unidad-frecuencia"><asp:Literal ID="litUnidadFrecuencia" runat="server" /></span>
                            </div>
                        </div>

                        <asp:Panel ID="pnlDiaMes" runat="server" CssClass="sigma-modal-field is-chico sg-campo-diames">
                            <label for="<%=cboDiaMes.ClientID %>">Ejecutar el</label>
                            <rad:RadComboBox2 ID="cboDiaMes" runat="server" />
                            <span class="sigma-modal-ayuda">"Último día" resuelve febrero solo: 28 o 29 según el año.</span>
                        </asp:Panel>

                        <asp:Panel ID="pnlOrdinal" runat="server" CssClass="sigma-modal-field is-chico sg-campo-ordinal">
                            <label for="<%=cboOrdinal.ClientID %>">Semana del mes</label>
                            <rad:RadComboBox2 ID="cboOrdinal" runat="server" />
                            <span class="sigma-modal-ayuda">Combinado con el día: "último viernes de cada mes".</span>
                        </asp:Panel>

                        <asp:Panel ID="pnlMes" runat="server" CssClass="sigma-modal-field is-chico sg-campo-mes">
                            <label for="<%=cboMes.ClientID %>">Mes (*)</label>
                            <rad:RadComboBox2 ID="cboMes" runat="server" />
                        </asp:Panel>

                        <%-- HORA: selector, no texto libre.

                             El input libre usaba TimeSpan.TryParse, que
                             convierte "8" en OCHO DIAS. Aceptaba un valor
                             imposible como hora del dia y lo guardaba. --%>
                        <div class="sigma-modal-field is-mini">
                            <label for="<%=cboHora.ClientID %>">a las (*)</label>
                            <rad:RadComboBox2 ID="cboHora" runat="server" Filter="Contains" MarkFirstMatch="true" />
                        </div>
                    </div>

                    <%-- Los dias como chips: son una eleccion multiple donde
                         importa VER de un golpe cuales quedaron marcados. --%>
                    <asp:Panel ID="pnlDias" runat="server" CssClass="sigma-modal-field is-ancho sg-campo-dias">
                        <label>Días de la semana</label>

                        <div class="sg-chips" role="group" aria-label="Días de la semana">
                            <asp:Repeater ID="rptDias" runat="server" OnItemCommand="rptDias_ItemCommand">
                                <ItemTemplate>
                                    <asp:LinkButton runat="server" CssClass='<%# Eval("Clase") %>'
                                        CommandName="dia" CommandArgument='<%# Eval("Valor") %>'
                                        CausesValidation="false"
                                        aria-pressed='<%# Eval("Marcado") %>' Text='<%# Eval("Texto") %>' />
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>

                        <%-- La lista real sigue mandando; los chips la
                             mueven. Oculta para el ojo, viva para el
                             code-behind y para el lector de pantalla. --%>
                        <div class="sg-oculto-accesible">
                            <asp:CheckBoxList ID="chkDias" runat="server" RepeatDirection="Horizontal"
                                RepeatLayout="Flow" CssClass="sigma-checkbox-inline" />
                        </div>

                        <asp:Literal ID="litDiasAyuda" runat="server" />
                    </asp:Panel>

                    <div class="sg-resumen-linea">
                        <i class="mdi mdi-calendar-check"></i>
                        <asp:Literal ID="litReglaFrase" runat="server" />
                    </div>
                </asp:Panel>

                <%-- ---------- INTERVALO DE TIEMPO (HU-072) ---------- --%>
                <asp:Panel ID="pnlIntervalo" runat="server" Visible="false">
                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-mini">
                            <label>Cada (*)</label>
                            <rad:RadNumericBox2 ID="txtCantidad" runat="server">
                                <NumberFormat DecimalDigits="0" />
                            </rad:RadNumericBox2>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label for="<%=cboUnidadTiempo.ClientID %>">Unidad (*)</label>
                            <rad:RadComboBox2 ID="cboUnidadTiempo" runat="server" />
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Contado desde</label>
                            <div class="sigma-modal-fecha"><WebControls:Calendar ID="calAncla" runat="server" /></div>
                            <span class="sigma-modal-ayuda">Vacío usa el inicio de vigencia.</span>
                        </div>
                    </div>

                    <label class="sigma-modal-rotulo">Cómo se cuenta el intervalo</label>
                    <div class="sg-opciones">
                        <label class="sg-opcion sg-opcion-radio">
                            <asp:RadioButton ID="rdbDesdeProgramada" runat="server" GroupName="ModoIntervalo" Checked="true" />
                            <span class="sg-opcion-txt">
                                <span class="sg-opcion-t">Desde la fecha programada</span>
                                <span class="sg-opcion-d">Un atraso no desplaza las siguientes: el calendario del año se mantiene.</span>
                            </span>
                        </label>

                        <label class="sg-opcion sg-opcion-radio">
                            <asp:RadioButton ID="rdbDesdeEjecucion" runat="server" GroupName="ModoIntervalo" />
                            <span class="sg-opcion-txt">
                                <span class="sg-opcion-t">Desde la última ejecución</span>
                                <span class="sg-opcion-d">El intervalo se cuenta desde que se hizo de verdad, así que un atraso corre todo lo que viene.</span>
                            </span>
                        </label>
                    </div>
                </asp:Panel>

                <%-- ---------- MEDIDOR (HU-073) ---------- --%>
                <asp:Panel ID="pnlMedidor" runat="server" Visible="false">
                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-medio">
                            <label for="<%=cboMedidor.ClientID %>">Medidor (*)</label>
                            <rad:RadComboBox2 ID="cboMedidor" runat="server" Filter="Contains" MarkFirstMatch="true" />
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Valor inicial</label>
                            <rad:RadNumericBox2 ID="txtValorInicial" runat="server">
                                <NumberFormat DecimalDigits="2" />
                            </rad:RadNumericBox2>
                            <span class="sigma-modal-ayuda">Vacío toma la lectura actual del equipo.</span>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Cada (*)</label>
                            <rad:RadNumericBox2 ID="txtCadaCantidad" runat="server">
                                <NumberFormat DecimalDigits="2" />
                            </rad:RadNumericBox2>
                            <span class="sigma-modal-ayuda">Por ejemplo 500 horas.</span>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Avisar antes de</label>
                            <rad:RadNumericBox2 ID="txtAviso" runat="server">
                                <NumberFormat DecimalDigits="2" />
                            </rad:RadNumericBox2>
                            <span class="sigma-modal-ayuda">
                                Genera una alerta al acercarse. La alerta por sí sola no crea una orden.
                            </span>
                        </div>

                        <asp:Panel ID="pnlMedidorEstado" runat="server" Visible="false" CssClass="sigma-modal-field is-ancho">
                            <div class="sigma-modal-note">
                                <i class="mdi mdi-gauge"></i>
                                <div><asp:Literal ID="litMedidorEstado" runat="server" /></div>
                            </div>
                        </asp:Panel>
                    </div>
                </asp:Panel>

                <%-- ---------- CONDICIÓN (HU-074) ---------- --%>
                <asp:Panel ID="pnlCondicion" runat="server" Visible="false">
                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-medio">
                            <label for="<%=cboVariable.ClientID %>">Variable</label>
                            <rad:RadComboBox2 ID="cboVariable" runat="server" Filter="Contains" MarkFirstMatch="true" />
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label for="<%=cboOperador.ClientID %>">Operador</label>
                            <rad:RadComboBox2 ID="cboOperador" runat="server" />
                        </div>
                        <div class="sigma-modal-field is-mini">
                            <label>Umbral</label>
                            <rad:RadNumericBox2 ID="txtUmbral" runat="server">
                                <NumberFormat DecimalDigits="2" />
                            </rad:RadNumericBox2>
                        </div>
                        <div class="sigma-modal-field is-mini">
                            <label>Hasta</label>
                            <rad:RadNumericBox2 ID="txtUmbralHasta" runat="server">
                                <NumberFormat DecimalDigits="2" />
                            </rad:RadNumericBox2>
                            <span class="sigma-modal-ayuda">Solo para "Entre".</span>
                        </div>
                        <div class="sigma-modal-field is-mini">
                            <label>Durante (min)</label>
                            <rad:RadNumericBox2 ID="txtDuracionMinima" runat="server">
                                <NumberFormat DecimalDigits="0" />
                            </rad:RadNumericBox2>
                            <span class="sigma-modal-ayuda">Evita el pico aislado.</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label for="<%=cboSeveridad.ClientID %>">Severidad</label>
                            <rad:RadComboBox2 ID="cboSeveridad" runat="server" />
                        </div>
                        <div class="sigma-modal-field is-mini">
                            <label>&nbsp;</label>
                            <WebControls:PushButton ID="btnAgregarCondicion" runat="server" Text="Agregar"
                                CssClass="sg-btn-secundario" OnClick="btnAgregarCondicion_Click" CausesValidation="false" />
                        </div>
                        <div class="sigma-modal-field is-ancho">
                            <rad:RadGrid2 ID="grdCondiciones" runat="server"
                                OnItemDataBound="grdCondiciones_ItemDataBound"
                                OnItemCommand="grdCondiciones_ItemCommand">
                                <MasterTableView CommandItemDisplay="None" DataKeyNames="pco_id" />
                            </rad:RadGrid2>
                        </div>
                    </div>
                </asp:Panel>

                <asp:Panel ID="pnlGuardarPrimero" runat="server" Visible="false" CssClass="sigma-modal-note is-alerta">
                    <i class="mdi mdi-information-outline"></i>
                    <div>
                        Guarde primero la programación. La regla, las exclusiones y las próximas fechas
                        se definen sobre una programación que ya existe.
                    </div>
                </asp:Panel>
            </asp:Panel>

            <%-- ---------- VENTANA DE CUMPLIMIENTO (HU-075 #1) ---------- --%>
            <div class="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra is-tenue"><i class="mdi mdi-clock-check-outline"></i></span>
                    <div>
                        <div class="sg-tarjeta-titulo">Ventana de cumplimiento</div>
                        <div class="sg-tarjeta-bajada">Cuánto antes o después se acepta como hecha en fecha.</div>
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>Tolerancia antes</label>
                        <div class="sg-conunidad">
                            <rad:RadNumericBox2 ID="txtToleranciaAntes" runat="server">
                                <NumberFormat DecimalDigits="0" />
                            </rad:RadNumericBox2>
                            <span class="sg-unidad">min</span>
                        </div>
                        <span class="sigma-modal-ayuda">2880 son 2 días.</span>
                    </div>

                    <div class="sigma-modal-field is-mini">
                        <label>Tolerancia después</label>
                        <div class="sg-conunidad">
                            <rad:RadNumericBox2 ID="txtToleranciaDespues" runat="server">
                                <NumberFormat DecimalDigits="0" />
                            </rad:RadNumericBox2>
                            <span class="sg-unidad">min</span>
                        </div>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <div class="sg-interruptores">
                            <label class="sg-check">
                                <asp:CheckBox ID="chkPermiteAnticipada" runat="server" />
                                <span class="sg-check-txt">
                                    <span class="sg-check-t">Permitir antes de la fecha</span>
                                    <span class="sg-check-d">Permite ejecutar hasta la tolerancia antes.</span>
                                </span>
                            </label>

                            <label class="sg-check">
                                <asp:CheckBox ID="chkPermiteAtrasada" runat="server" />
                                <span class="sg-check-txt">
                                    <span class="sg-check-t">Permitir después de la fecha</span>
                                    <span class="sg-check-d">Permite ejecutar hasta la tolerancia después.</span>
                                </span>
                            </label>
                        </div>
                    </div>

                    <asp:Panel ID="pnlPolitica" runat="server" CssClass="sigma-modal-field is-chico">
                        <label for="<%=cboPolitica.ClientID %>">Política (*)</label>
                        <rad:RadComboBox2 ID="cboPolitica" runat="server" />
                        <span class="sigma-modal-ayuda">
                            Con varias condiciones: si basta una o si tienen que cumplirse todas.
                        </span>
                    </asp:Panel>
                </div>

                <div class="sg-interruptores is-fila">
                    <%-- DOS RADIOS SIN ETIQUETA NO SE ENTIENDEN

                         Un par Si/No renderiza como dos puntos identicos uno
                         al lado del otro: no hay forma de saber cual es cual
                         sin adivinar. Y es una sola decision binaria, que es
                         justo lo que un interruptor comunica de un vistazo.

                         Los radios siguen ahi —son los que postean y los que
                         el code-behind lee— pero recortados fuera de vista.
                         El interruptor los mueve. --%>
                    <div class="sg-check sg-conmutador" data-si="rdbGeneraSi" data-no="rdbGeneraNo">
                        <span class="sg-switch" role="switch" tabindex="0"
                              aria-label="Generación automática"><span class="sg-switch-bola"></span></span>

                        <div class="sg-oculto-accesible">
                            <asp:RadioButton ID="rdbGeneraSi" runat="server" GroupName="Genera" Text="Sí" Checked="true" />
                            <asp:RadioButton ID="rdbGeneraNo" runat="server" GroupName="Genera" Text="No" />
                        </div>

                        <span class="sg-check-txt">
                            <span class="sg-check-t">Generación automática</span>
                            <span class="sg-check-d">El sistema generará actividades automáticamente.</span>
                        </span>
                    </div>

                    <div class="sg-check sg-conmutador" data-si="rdbSi" data-no="rdbNo">
                        <span class="sg-switch" role="switch" tabindex="0"
                              aria-label="Programación habilitada"><span class="sg-switch-bola"></span></span>

                        <div class="sg-oculto-accesible">
                            <asp:RadioButton ID="rdbSi" runat="server" GroupName="Habilitado" Text="Sí" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" GroupName="Habilitado" Text="No" />
                        </div>

                        <span class="sg-check-txt">
                            <span class="sg-check-t">Programación habilitada</span>
                            <span class="sg-check-d">Deshabilitada deja de generar y conserva lo ya generado.</span>
                        </span>
                    </div>
                </div>
            </div>
        </asp:Panel>

        <%-- ==========================================================
             PASO 5 — EXCLUSIONES
             ========================================================== --%>
        <asp:Panel ID="pnlPaso5" runat="server" CssClass="sg-paso-panel">
            <asp:Panel ID="pnlExclusiones" runat="server" Visible="false" CssClass="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra">E</span>
                    <div>
                        <div class="sg-tarjeta-titulo">Exclusiones</div>
                        <div class="sg-tarjeta-bajada">Fechas en las que la programación no debe generar actividades.</div>
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>Desde</label>
                        <div class="sigma-modal-fecha"><WebControls:Calendar ID="calExclusionDesde" runat="server" /></div>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Hasta</label>
                        <div class="sigma-modal-fecha"><WebControls:Calendar ID="calExclusionHasta" runat="server" /></div>
                    </div>
                    <%-- Motivo ocupa la media fila que queda: es texto libre
                         y en tres columnas no cabe nada legible. --%>
                    <div class="sigma-modal-field is-mitad">
                        <label for="<%=txtExclusionMotivo.ClientID %>">Motivo</label>
                        <WebControls:TextBox2 ID="txtExclusionMotivo" runat="server" MaxLength="400" />
                    </div>

                    <%-- El efecto va en su PROPIA fila. Son dos tarjetas con
                         explicacion —no dos radios— y apretadas contra el
                         boton quedaban de tres lineas cada una. --%>
                    <div class="sigma-modal-field is-ancho">
                        <label>Efecto</label>
                        <div class="sg-opciones is-compacta">
                            <label class="sg-opcion sg-opcion-radio">
                                <asp:RadioButton ID="rdbExcluye" runat="server" GroupName="Efecto" Checked="true" />
                                <span class="sg-opcion-txt">
                                    <span class="sg-opcion-t">No generar nada</span>
                                    <span class="sg-opcion-d">La parada de planta: en ese período no hay trabajo programado.</span>
                                </span>
                            </label>

                            <label class="sg-opcion sg-opcion-radio">
                                <asp:RadioButton ID="rdbDesplaza" runat="server" GroupName="Efecto" />
                                <span class="sg-opcion-txt">
                                    <span class="sg-opcion-t">Correr al siguiente hábil</span>
                                    <span class="sg-opcion-d">El feriado: la fecha se desplaza y la original queda registrada.</span>
                                </span>
                            </label>
                        </div>
                    </div>

                    <%-- A la derecha y solo: es la accion de la seccion, no
                         un campo mas de la fila. --%>
                    <div class="sigma-modal-field is-ancho sg-fila-accion">
                        <WebControls:PushButton ID="btnAgregarExclusion" runat="server" Text="Agregar exclusión"
                            CssClass="sg-btn-secundario" OnClick="btnAgregarExclusion_Click" CausesValidation="false" />
                    </div>
                </div>

                <%-- La tabla como Repeater y no como grilla.

                     Mismos comandos, mismo evento y mismo permiso que la
                     RadGrid que habia antes: lo que cambia es que ahora se
                     puede leer. Cuatro exclusiones no necesitan paginacion
                     ni ordenamiento; necesitan verse. --%>
                <asp:Repeater ID="rptExclusiones" runat="server"
                    OnItemCommand="rptExclusiones_ItemCommand" OnItemDataBound="rptExclusiones_ItemDataBound">
                    <HeaderTemplate>
                        <table class="sg-tabla" role="table">
                            <thead>
                                <tr>
                                    <th scope="col">Desde</th>
                                    <th scope="col">Hasta</th>
                                    <th scope="col">Motivo</th>
                                    <th scope="col">Efecto</th>
                                    <th scope="col" class="sg-tabla-acciones">Acciones</th>
                                </tr>
                            </thead>
                            <tbody>
                    </HeaderTemplate>

                    <ItemTemplate>
                        <tr>
                            <td data-rotulo="Desde"><%# Eval("Desde") %></td>
                            <td data-rotulo="Hasta"><%# Eval("Hasta") %></td>
                            <td data-rotulo="Motivo"><%# Eval("Motivo") %></td>
                            <td data-rotulo="Efecto">
                                <span class='sg-etiqueta <%# Eval("EfectoClase") %>'><%# Eval("Efecto") %></span>
                            </td>
                            <td class="sg-tabla-acciones">
                                <asp:LinkButton ID="btnEliminar" runat="server" CssClass="sg-icono-btn is-borrar"
                                    CommandName="Eliminar" CommandArgument='<%# Eval("Id") %>'
                                    CausesValidation="false" ToolTip="Eliminar exclusión">
                                    <i class="mdi mdi-trash-can-outline"></i>
                                </asp:LinkButton>
                            </td>
                        </tr>
                    </ItemTemplate>

                    <FooterTemplate>
                            </tbody>
                        </table>
                    </FooterTemplate>
                </asp:Repeater>

                <asp:Panel ID="pnlSinExclusiones" runat="server" Visible="false" CssClass="sg-vacio">
                    <i class="mdi mdi-calendar-blank-outline"></i>
                    <div>
                        <strong>Sin exclusiones.</strong>
                        La programación generará actividades en todas las fechas que le corresponden,
                        feriados incluidos.
                    </div>
                </asp:Panel>

                <%-- La grilla original queda viva y oculta: sus eventos
                     siguen registrados y el dia que se necesite exportar o
                     paginar, esta ahi. --%>
                <div class="sg-oculto-accesible">
                    <rad:RadGrid2 ID="grdExclusiones" runat="server"
                        OnItemDataBound="grdExclusiones_ItemDataBound"
                        OnItemCommand="grdExclusiones_ItemCommand">
                        <MasterTableView CommandItemDisplay="None" DataKeyNames="pxc_id" />
                    </rad:RadGrid2>
                </div>
            </asp:Panel>

            <asp:Panel ID="pnlExclusionesBloqueadas" runat="server" Visible="false" CssClass="sigma-modal-note is-alerta">
                <i class="mdi mdi-information-outline"></i>
                <div>Guarde primero la programación: las exclusiones se definen sobre una que ya existe.</div>
            </asp:Panel>
        </asp:Panel>

        <%-- ==========================================================
             PASO 6 — REVISAR
             ========================================================== --%>
        <asp:Panel ID="pnlPaso6" runat="server" CssClass="sg-paso-panel">
            <div class="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra">F</span>
                    <div>
                        <div class="sg-tarjeta-titulo">Revisar y confirmar</div>
                        <div class="sg-tarjeta-bajada">Esto es lo que se guardará.</div>
                    </div>
                </div>

                <asp:Literal ID="litRevision" runat="server" />
            </div>

            <%-- ---------- PRÓXIMAS FECHAS ----------

                 No son ocurrencias: es el calculo de FNC_PROGRAMACION_FECHAS.
                 Sirve para ver si la regla dice lo que uno cree que dice
                 ANTES de que empiece a generar trabajo de verdad. --%>
            <asp:Panel ID="pnlProyeccion" runat="server" Visible="false" CssClass="sg-tarjeta">
                <div class="sg-tarjeta-cab">
                    <span class="sg-letra is-tenue"><i class="mdi mdi-calendar-search"></i></span>
                    <div>
                        <div class="sg-tarjeta-titulo">Próximas fechas</div>
                        <div class="sg-tarjeta-bajada">Cálculo de la regla, no actividades ya generadas.</div>
                    </div>
                </div>
                <asp:Literal ID="litProyeccion" runat="server" />
            </asp:Panel>

            <wuc:Auditoria runat="server" ID="wucAuditoria" />
        </asp:Panel>

        <%-- Navegación entre pasos. --%>
        <div class="sg-prog-nav">
            <asp:LinkButton ID="btnAnterior" runat="server" CssClass="sg-btn-plano"
                OnClick="btnAnterior_Click" CausesValidation="false">
                <i class="mdi mdi-chevron-left"></i> Anterior
            </asp:LinkButton>

            <asp:LinkButton ID="btnSiguiente" runat="server" CssClass="sg-btn-secundario"
                OnClick="btnSiguiente_Click" CausesValidation="false">
                Siguiente <i class="mdi mdi-chevron-right"></i>
            </asp:LinkButton>
        </div>
    </div>

    <%-- ---------------------------------------------------------------
         EL RESUMEN

         Se queda a la vista mientras se recorren los pasos: sin el, en el
         paso 5 ya nadie recuerda que puso en el 1. Todo lo que muestra sale
         de lo que hay cargado en el formulario; ninguna linea esta escrita
         a mano.
         --------------------------------------------------------------- --%>
    <aside class="sg-prog-resumen">
        <div class="sg-resumen-caja">
            <div class="sg-resumen-titulo">Resumen de la programación</div>

            <div class="sg-resumen-frase"><asp:Literal ID="litResumenFrase" runat="server" /></div>

            <asp:Literal ID="litResumenDatos" runat="server" />

            <asp:Panel ID="pnlResumenProximas" runat="server" Visible="false">
                <div class="sg-resumen-sub">Próximas ejecuciones</div>
                <asp:Literal ID="litResumenProximas" runat="server" />
            </asp:Panel>

            <asp:Literal ID="litResumenEstado" runat="server" />

            <div class="sg-resumen-acciones">
                <asp:LinkButton ID="btnRevisar" runat="server" CssClass="sg-btn-plano is-bloque"
                    OnClick="btnRevisar_Click" CausesValidation="false" Text="Revisar programación" />
            </div>
        </div>
    </aside>

    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
