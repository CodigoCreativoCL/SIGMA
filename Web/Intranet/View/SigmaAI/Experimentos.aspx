<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Experimentos.aspx.cs" Inherits="View_SigmaAI_Experimentos" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-notificaciones.css?vrs=2") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-programacion.css?vrs=2") %>' rel="stylesheet" />
    <style type="text/css">
        /* La pantalla es un cuaderno de laboratorio: cinco pasos, cada uno en
           su tarjeta, con lo que produjo debajo. El orden de las tarjetas ES
           el orden en que se ejecuta la investigacion. */
        .sg-ml-paso { margin-bottom: 16px; }
        .sg-ml-paso h4 { display: flex; align-items: center; gap: 10px; margin: 0 0 6px 0; font-size: 15px; font-weight: 800; color: #141c2e; }
        .sg-ml-paso h4 .n { display: inline-flex; align-items: center; justify-content: center; width: 26px; height: 26px; border-radius: 50%; background: #6C5CFF; color: #fff; font-size: 12.5px; font-weight: 800; }
        .sg-ml-paso h4 .n.is-listo { background: #16a34a; }
        .sg-ml-paso h4 .n.is-espera { background: #9ca3af; }
        .sg-ml-paso .txt { font-size: 12.5px; color: #4e5b72; line-height: 1.5; margin-bottom: 10px; }
        .sg-ml-paso .txt code, .sg-ml-cmd { font-family: Consolas, "Courier New", monospace; font-size: 12px; background: #f3f4f8; border: 1px solid #e3e6ef; border-radius: 6px; padding: 1px 6px; color: #2b2f3a; }
        .sg-ml-cmd { display: block; padding: 10px 12px; margin: 8px 0; white-space: pre-wrap; word-break: break-all; }
        .sg-ml-form { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin-bottom: 8px; }
        .sg-ml-form label { margin: 0; font-size: 12.5px; color: #374151; }
        .sg-ml-form input.form-control { width: 130px !important; display: inline-block; }
        .sg-ml-form input.form-control.is-corta { width: 70px !important; }
        .sg-tabla.is-compacta td, .sg-tabla.is-compacta th { padding: 6px 8px; font-size: 11.5px; white-space: nowrap; }
        .sg-tabla .num { text-align: right; font-variant-numeric: tabular-nums; }
        .sg-tabla .pos { color: #b91c1c; font-weight: 700; }
        .sg-tabla .neg { color: #6b7280; }
        .sg-ml-barra { display: inline-block; height: 8px; border-radius: 4px; background: linear-gradient(90deg, #16a34a, #f59e0b 50%, #dc2626); vertical-align: middle; }
        .sg-ml-pill { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 10.5px; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; }
        .sg-ml-pill.is-pub { background: #dcfce7; color: #166534; }
        .sg-ml-pill.is-bor { background: #fef3c7; color: #92400e; }
        .sg-ml-pill.is-ret { background: #f3f4f6; color: #6b7280; }
        .sg-ml-pill.is-err { background: #fee2e2; color: #991b1b; }
        .sg-ml-pill.is-ok { background: #dcfce7; color: #166534; }
        .sg-ml-plan { list-style: none; padding: 0; margin: 0; display: grid; gap: 6px; }
        .sg-ml-plan li { display: flex; gap: 10px; align-items: flex-start; font-size: 12.5px; color: #374151; line-height: 1.45; }
        .sg-ml-plan li i { font-size: 17px; flex: none; margin-top: -1px; }
        .sg-ml-plan li i.is-listo { color: #16a34a; }
        .sg-ml-plan li i.is-pend { color: #9ca3af; }
        .sg-ml-plan li i.is-bryan { color: #6C5CFF; }
        .sg-ml-aviso { border-left: 4px solid #f59e0b; background: #fffbeb; padding: 9px 12px; border-radius: 6px; font-size: 12.5px; color: #78350f; margin-bottom: 10px; }
        .sg-ml-aviso.is-ok { border-color: #16a34a; background: #f0fdf4; color: #14532d; }
        .sg-ml-aviso.is-mal { border-color: #dc2626; background: #fef2f2; color: #7f1d1d; }
        .sg-ml-exp { font-size: 11px; color: #4e5b72; white-space: normal !important; max-width: 520px; }
        .sg-ml-scroll { overflow-x: auto; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    SIGMA AI
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Experimentos · Investigación Azure Machine Learning
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    SIGMA FAILURE a 30 días, de punta a punta y sin costo: dataset desde la base, entrenamiento local, registro en Azure ML y puntuación dentro de la API.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Literal ID="litAviso" runat="server" />

            <%-- ESTADO: cinco números que dicen en qué paso va la investigación --%>
            <div class="sg-kpis">
                <asp:Literal ID="litKpis" runat="server" />
            </div>

            <%-- EL PLAN, con lo hecho y lo que falta --%>
            <div class="card-box sg-ml-paso">
                <h4><i class="mdi mdi-map-marker-path" style="color:#6C5CFF"></i> Cómo se ejecuta la investigación</h4>
                <div class="txt">
                    Todo lo que se factura en Azure ML es <strong>cómputo</strong> (instancias, clústeres, endpoints) y esta
                    investigación no crea ninguno. El área de trabajo, el registro de modelos y el seguimiento de MLflow no tienen
                    cargo; el entrenamiento corre en el computador de quien entrena y la puntuación dentro de la API de SIGMA.
                    Lo único que Azure guarda son unos KB de métricas y el archivo <code>.onnx</code> del modelo (unos pocos KB).
                </div>
                <ul class="sg-ml-plan">
                    <asp:Literal ID="litPlan" runat="server" />
                </ul>
            </div>

            <%-- PASO 1: EL DATASET --%>
            <div class="card-box sg-ml-paso">
                <h4><span class="n" id="n1" runat="server">1</span> Dataset: un equipo × una fecha de corte</h4>
                <div class="txt">
                    <code>FNC_ML_ACTIVO_HISTORICO_V1</code> calcula, para cada equipo y cada corte, 15 características con lo que
                    pasó <strong>antes</strong> del corte y el label <code>FALLO_EN_30D</code> con lo que pasó <strong>después</strong>
                    (una falla en los 30 días siguientes). Sin fechas toma desde el primer registro del cliente hasta hoy − 30, un corte
                    cada 7 días. Registrar el dataset guarda cuántas filas tiene, cuántas positivas y su huella SHA-256: la versión
                    que salga de él dirá exactamente con qué se entrenó.
                </div>
                <div class="sg-ml-form">
                    <label for="txtDesde">Desde</label>
                    <asp:TextBox ID="txtDesde" runat="server" CssClass="form-control" placeholder="aaaa-mm-dd" MaxLength="10" />
                    <label for="txtHasta">Hasta</label>
                    <asp:TextBox ID="txtHasta" runat="server" CssClass="form-control" placeholder="aaaa-mm-dd" MaxLength="10" />
                    <label for="txtPaso">Cada (días)</label>
                    <asp:TextBox ID="txtPaso" runat="server" CssClass="form-control is-corta" Text="7" MaxLength="3" />
                    <asp:LinkButton ID="btnMuestra" runat="server" CssClass="sigma-accion" OnClick="btnMuestra_Click">
                        <i class="mdi mdi-table-eye"></i><span>Ver muestra</span>
                    </asp:LinkButton>
                    <asp:LinkButton ID="btnRegistrar" runat="server" CssClass="sigma-accion is-primaria" OnClick="btnRegistrar_Click">
                        <i class="mdi mdi-database-plus-outline"></i><span>Registrar dataset</span>
                    </asp:LinkButton>
                </div>
                <div class="sg-ml-scroll"><asp:Literal ID="litMuestra" runat="server" /></div>
                <asp:Literal ID="litDatasets" runat="server" />
            </div>

            <%-- PASO 2: ENTRENAR (fuera de la web) --%>
            <div class="card-box sg-ml-paso">
                <h4><span class="n" id="n2" runat="server">2</span> Entrenar en tu computador y registrar en Azure ML</h4>
                <div class="txt">
                    <code>ML/entrenar_falla.py</code> baja el dataset por la API, entrena una regresión logística (scikit-learn),
                    la valida, la convierte a ONNX y comprueba que el ONNX y los pesos dan la misma probabilidad. Si
                    <code>MLFLOW_TRACKING_URI</code> apunta al área de trabajo, deja la corrida y registra el modelo en Azure ML
                    (gratis); si no, lo deja en <code>ML/mlruns</code>. Al terminar informa la corrida y la versión con
                    <code>POST /sigma-ai/entrenamientos</code>; la versión queda en <strong>borrador</strong>.
                </div>
                <asp:Literal ID="litComando" runat="server" />
                <asp:Literal ID="litCorridas" runat="server" />
            </div>

            <%-- PASO 3: PUBLICAR --%>
            <div class="card-box sg-ml-paso">
                <h4><span class="n" id="n3" runat="server">3</span> Versiones: publicar la que se va a usar</h4>
                <div class="txt">
                    Publicar deja una sola versión vigente y retira la anterior. Los pesos (<code>mpv_parametro</code>) son lo que
                    la API usa para puntuar; la ruta es el modelo registrado en Azure ML y el hash, el del <code>.onnx</code>.
                </div>
                <asp:Repeater ID="rptVersiones" runat="server" OnItemCommand="rptVersiones_ItemCommand">
                    <HeaderTemplate>
                        <div class="sg-ml-scroll"><table class="sg-tabla is-compacta">
                            <tr><th>#</th><th>Estado</th><th>Algoritmo</th><th>Dataset</th><th class="num">AUC</th><th class="num">Precisión</th><th class="num">Recall</th><th class="num">F1</th><th>Azure ML</th><th>Entrenada</th><th></th></tr>
                    </HeaderTemplate>
                    <ItemTemplate>
                        <tr>
                            <td><strong>v<%# Eval("numero") %></strong></td>
                            <td><%# Eval("estadoHtml") %></td>
                            <td><%# Eval("algoritmo") %></td>
                            <td><%# Eval("dataset") %></td>
                            <td class="num"><%# Eval("auc") %></td>
                            <td class="num"><%# Eval("precision") %></td>
                            <td class="num"><%# Eval("recall") %></td>
                            <td class="num"><%# Eval("f1") %></td>
                            <td style="white-space: normal; min-width: 190px;"><span class="sg-ml-exp" title='<%# Eval("ruta") %>'><%# Eval("registroHtml") %></span></td>
                            <td><%# Eval("entrenada") %></td>
                            <td class="sg-tabla-acciones" style="width: 250px; white-space: nowrap;">
                                <asp:LinkButton ID="lnkVerificar" runat="server" CssClass="sigma-accion" CommandName="verificar"
                                    CommandArgument='<%# Eval("id") %>' Visible='<%# (bool)Eval("tieneArtefacto") %>' ToolTip="Baja el .onnx del área de trabajo y compara su hash">
                                    <i class="mdi mdi-cloud-check-outline"></i><span>Verificar en Azure</span>
                                </asp:LinkButton>
                                <asp:LinkButton ID="lnkPublicar" runat="server" CssClass="sigma-accion is-primaria" CommandName="publicar"
                                    CommandArgument='<%# Eval("id") %>' Visible='<%# (bool)Eval("puedePublicar") %>'
                                    OnClientClick="return ConfirSweetAlert(this, '', '¿Publicar esta versión? La API pasará a puntuar con sus pesos y la versión vigente se retira.');">
                                    <i class="mdi mdi-rocket-launch-outline"></i><span>Publicar</span>
                                </asp:LinkButton>
                            </td>
                        </tr>
                    </ItemTemplate>
                    <FooterTemplate></table></div></FooterTemplate>
                </asp:Repeater>
                <asp:Literal ID="litVersionesVacio" runat="server" />
                <asp:Literal ID="litArtefacto" runat="server" />
                <asp:LinkButton ID="btnSincronizar" runat="server" OnClick="btnSincronizar_Click" style="display:none" />
            </div>

            <%-- PASO 4: PUNTUAR --%>
            <div class="card-box sg-ml-paso">
                <h4><span class="n" id="n4" runat="server">4</span> Puntuar hoy con la versión publicada</h4>
                <div class="txt">
                    <code>POST /sigma-ai/predecir</code> arma la fila de hoy de cada equipo, la puntúa dentro de la API
                    (<code>PuntuadorFalla</code>: estandarizar, multiplicar por los pesos, sigmoide) y guarda la predicción con las
                    características que usó, las tres razones que más pesaron y la alerta si supera el umbral del modelo.
                    Volver a puntuar el mismo día devuelve la misma predicción. Lo que sale se ve también en
                    <strong>Alertas</strong> y en la app (Análisis de SIGMA AI).
                </div>
                <div class="sg-ml-form">
                    <asp:LinkButton ID="btnPredecir" runat="server" CssClass="sigma-accion is-primaria" OnClick="btnPredecir_Click">
                        <i class="mdi mdi-brain"></i><span>Puntuar todos los equipos</span>
                    </asp:LinkButton>
                </div>
                <div class="sg-ml-scroll"><asp:Literal ID="litPredicciones" runat="server" /></div>
            </div>

            <%-- PASO 5: AZURE ML --%>
            <div class="card-box sg-ml-paso">
                <h4><span class="n" id="n5" runat="server">5</span> Lo que hay en Azure ML (área de trabajo SIGMA_AI)</h4>
                <div class="txt">
                    Dos canales, los dos gratis. <strong>El artefacto</strong>: el registro de modelos deja el <code>.onnx</code> y los pesos en el
                    almacenamiento del área de trabajo (contenedor <code>azureml</code>), la misma cuenta a la que la API ya accede con su SAS;
                    por ahí la API baja el modelo registrado, comprueba su hash y puede tomar los pesos desde Azure («Verificar en Azure» en la
                    tarjeta 3). <strong>El plano de control</strong> (experimentos, corridas, lista de modelos) exige una entidad de servicio en
                    Entra ID; mientras las claves <code>AzureML.ClientId/ClientSecret</code> digan PENDIENTE, esta tarjeta lo dice tal cual.
                </div>
                <div class="sg-ml-form">
                    <asp:LinkButton ID="btnAzure" runat="server" CssClass="sigma-accion" OnClick="btnAzure_Click">
                        <i class="mdi mdi-microsoft-azure"></i><span>Consultar Azure ML</span>
                    </asp:LinkButton>
                </div>
                <asp:Literal ID="litAzure" runat="server" />
            </div>

            <div class="card-box" style="font-size: 12px; color: #555;">
                <strong>Investigación, no producto.</strong> Esta pantalla existe para recorrer el camino completo de SIGMA AI con
                datos reales y dejar constancia de cada paso. Con el historial de hoy (pocas fallas registradas) el modelo que salga
                <strong>no sirve para decidir</strong>: el objetivo es que el camino esté probado para cuando el historial exista.
                El modelo de línea base (<em>Tendencia de variable medida</em>) sigue operando en paralelo.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
