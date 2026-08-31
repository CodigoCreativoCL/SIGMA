<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Comun_Clientes_CargaMasivaUsuarios, App_Web_gmrbtxiv" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
    <style>
        /* ── Layout principal ─────────────────────────────── */
        .cmu-layout {
            display: flex;
            gap: 18px;
            align-items: flex-start;
        }
        .cmu-left  { width: 320px; flex-shrink: 0; display: flex; flex-direction: column; gap: 14px; }
        .cmu-right { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px; }

        /* ── Card base ───────────────────────────────────── */
        .cmu-card {
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            box-shadow: 0 1px 3px rgba(0,0,0,.06);
            overflow: hidden;
        }
        .cmu-card-body { padding: 18px 20px; }
        .cmu-card-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px 20px;
            background: #f8fafc;
            border-bottom: 1px solid #e2e8f0;
        }
        .cmu-card-header-title { font-size: 15px; font-weight: 700; color: #0f172a; }

        /* ── Instrucciones ───────────────────────────────── */
        .cmu-card-title-row {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 12px;
        }
        .cmu-icon-circle {
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
            flex-shrink: 0;
        }
        .cmu-icon-blue { background: rgba(37,99,235,.12); color: #2563eb; }
        .cmu-section-title { font-size: 15px; font-weight: 700; color: #0f172a; margin: 0; }
        .cmu-intro-text { font-size: 13px; color: #475569; line-height: 1.55; margin-bottom: 14px; }
        .cmu-steps-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 10px; }
        .cmu-step-item { display: flex; gap: 10px; align-items: flex-start; }
        .cmu-step-num {
            width: 22px;
            height: 22px;
            border-radius: 50%;
            background: #e2e8f0;
            color: #475569;
            font-size: 11px;
            font-weight: 700;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            margin-top: 1px;
        }
        .cmu-step-text { font-size: 13px; color: #334155; line-height: 1.5; }
        .cmu-warning-box {
            margin-top: 14px;
            padding: 11px 13px;
            background: rgba(180,83,9,.05);
            border: 1px solid rgba(180,83,9,.2);
            border-radius: 8px;
        }
        .cmu-warning-title {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 11px;
            font-weight: 700;
            color: #b45309;
            text-transform: uppercase;
            letter-spacing: .04em;
            margin-bottom: 4px;
        }
        .cmu-warning-text { font-size: 12px; color: #475569; line-height: 1.5; margin: 0; }

        /* ── Perfiles ────────────────────────────────────── */
        .cmu-section-label {
            font-size: 11px;
            font-weight: 700;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: .05em;
            margin-bottom: 10px;
        }
        .cmu-perfil-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
        .cmu-perfil-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 6px 10px;
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
        }
        .cmu-perfil-nombre { font-size: 12px; color: #475569; }
        .cmu-perfil-id { font-size: 13px; font-weight: 700; color: #2563eb; }

        /* ── Badge campos requeridos ─────────────────────── */
        .cmu-badge-required {
            font-size: 10px;
            font-weight: 700;
            color: #475569;
            background: #e2e8f0;
            border-radius: 20px;
            padding: 3px 10px;
            letter-spacing: .03em;
        }

        /* ── Tabla de referencia ─────────────────────────── */
        .cmu-table-wrap { max-height: 100%; overflow-y: auto; }
        .cmu-table { width: 100%; border-collapse: collapse; }
        .cmu-table thead th {
            position: sticky;
            top: 0;
            background: #fff;
            font-size: 11px;
            font-weight: 700;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: .04em;
            padding: 10px 18px;
            border-bottom: 1px solid #e2e8f0;
            z-index: 1;
        }
        .cmu-table tbody tr + tr td { border-top: 1px solid #f1f5f9; }
        .cmu-table tbody td { padding: 4px 18px; font-size: 13px; }
        .cmu-table tbody td:first-child { font-weight: 700; color: #0f172a; white-space: nowrap; }
        .cmu-table tbody td:last-child  { color: #475569; }

        /* ── Acciones: descarga + subida ─────────────────── */
        .cmu-actions-row { display: flex; gap: 18px; }
        .cmu-action-col  { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 8px; }
        .cmu-action-label {
            font-size: 11px;
            font-weight: 700;
            color: #64748b;
            text-transform: uppercase;
            letter-spacing: .05em;
        }

        /* Caja de descarga */
        .cmu-download-box {
            flex: 1;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 4px;
            padding: 14px 12px;
            background: rgba(21,128,61,.04);
            border: 1px solid rgba(21,128,61,.18);
            border-radius: 10px;
            text-align: center;
        }
        .cmu-download-icon {
            width: 36px;
            height: 36px;
            border-radius: 50%;
            background: rgba(21,128,61,.12);
            color: #15803d;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            margin-bottom: 2px;
        }
        .cmu-download-title { font-size: 12px; font-weight: 700; color: #0f172a; margin: 0; }
        .cmu-download-sub   { font-size: 11px; color: #64748b; margin: 0; }
        .cmu-btn-download {
            display: inline-block;
            margin-top: 6px;
            padding: 6px 16px;
            background: #15803d;
            color: #fff !important;
            font-size: 12px;
            font-weight: 700;
            border-radius: 6px;
            border: none;
            cursor: pointer;
            text-decoration: none;
            transition: background .15s;
        }
        .cmu-btn-download:hover { background: #166534; color: #fff; text-decoration: none; }

        /* Caja de subida */
        .cmu-upload-box {
            flex: 1;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 4px;
            padding: 14px 12px;
            background: #f8fafc;
            border: 2px dashed #c6c6cd;
            border-radius: 10px;
            text-align: center;
            transition: border-color .15s, background .15s;
        }
        .cmu-upload-box:hover { border-color: #2563eb; background: rgba(37,99,235,.03); }
        .cmu-upload-icon {
            width: 36px;
            height: 36px;
            border-radius: 50%;
            background: rgba(37,99,235,.1);
            color: #2563eb;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            margin-bottom: 2px;
        }
        .cmu-upload-title { font-size: 12px; font-weight: 700; color: #0f172a; margin: 0; }
        .cmu-upload-sub   { font-size: 11px; color: #64748b; margin: 0; }
        .cmu-upload-box input[type="file"] {
            margin-top: 6px;
            font-size: 11px;
            max-width: 100%;
        }
        .cmu-filename-chip {
            margin-top: 4px;
            font-size: 11px;
            font-weight: 600;
            color: #2563eb;
            background: rgba(37,99,235,.08);
            border-radius: 20px;
            padding: 2px 10px;
        }

        /* ── Footer ──────────────────────────────────────── */
        .cmu-footer {
            display: flex;
            justify-content: flex-end;
            align-items: center;
            gap: 10px;
            padding-top: 12px;
            margin-top: 10px;
            border-top: 1px solid #f1f5f9;
        }

        /* ── Panel resultado ─────────────────────────────── */
        .cmu-result-card {
            margin-top: 18px;
            background: #fff;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            box-shadow: 0 1px 3px rgba(0,0,0,.06);
            overflow: hidden;
        }
        .cmu-result-header {
            padding: 12px 20px;
            background: #f0fdf4;
            border-bottom: 1px solid #bbf7d0;
            font-size: 14px;
            font-weight: 700;
            color: #166534;
        }
        .cmu-result-body { padding: 16px 20px; }
        .cmu-result-stats { display: flex; gap: 24px; margin-bottom: 14px; }
        .cmu-result-stat { display: flex; flex-direction: column; gap: 2px; }
        .cmu-result-stat-label { font-size: 11px; font-weight: 600; color: #64748b; text-transform: uppercase; }
        .cmu-result-stat-value { font-size: 22px; font-weight: 700; color: #0f172a; }
    </style>
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement && window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var oWin = getRadWindow();
            if (oWin) { if (oWin.BrowserWindow && oWin.BrowserWindow.refresh) oWin.BrowserWindow.refresh(); oWin.close(); }
        }

        function abrirTimer() {
            var fileUpload = $('#<%=fldDocumento.ClientID %>');
            if (fileUpload[0].files[0] != null) {
                var oWin = $find("<%=rwiProcesamiento.ClientID %>");
                oWin.setUrl('<%=ResolveUrl("~/View/Comun/Procesamiento.aspx") %>');
                oWin.show();
                bloqueaScroll(false);
            }
            return false;
        }

        function closeWindowProcesamiento() {
            var oWin = $find("<%=rwiProcesamiento.ClientID %>");
            if (oWin != null) oWin.close();
        }

        $(document).ready(function () {
            $('#<%=fldDocumento.ClientID %>').on('change', function () {
                var nombre = this.files.length > 0 ? this.files[0].name : '';
                var chip = document.getElementById('divFileName');
                if (nombre) {
                    chip.textContent = nombre;
                    chip.style.display = 'block';
                } else {
                    chip.style.display = 'none';
                }
            });
        });
    </script>
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-modal">
    <rad:RadWindow2 ID="rwiProcesamiento" runat="server" Width="1000" Height="500" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- Layout principal --%>
            <div class="cmu-layout">

                <%-- COLUMNA IZQUIERDA --%>
                <div class="cmu-left">

                    <%-- Card: Instrucciones --%>
                    <div class="cmu-card">
                        <div class="cmu-card-body">
                            <div class="cmu-card-title-row">
                                <span class="cmu-icon-circle cmu-icon-blue">
                                    <i class="mdi mdi-information-outline"></i>
                                </span>
                                <h3 class="cmu-section-title">Instrucciones</h3>
                            </div>
                            <p class="cmu-intro-text">
                                Siga estos pasos para asegurar que la informaci&#243;n se procese correctamente en el sistema:
                            </p>
                            <ul class="cmu-steps-list">
                                <li class="cmu-step-item">
                                    <span class="cmu-step-num">1</span>
                                    <p class="cmu-step-text">Descargue la plantilla oficial en formato <strong>.xlsx</strong>.</p>
                                </li>
                                <li class="cmu-step-item">
                                    <span class="cmu-step-num">2</span>
                                    <p class="cmu-step-text">Complete todos los campos obligatorios respetando los formatos indicados.</p>
                                </li>
                                <li class="cmu-step-item">
                                    <span class="cmu-step-num">3</span>
                                    <p class="cmu-step-text">Suba el archivo procesado en la zona de carga a continuaci&#243;n.</p>
                                </li>
                            </ul>
                            <div class="cmu-warning-box">
                                <div class="cmu-warning-title">
                                    <i class="mdi mdi-alert-outline"></i> Importante
                                </div>
                                <p class="cmu-warning-text">
                                    No modifique los encabezados de la plantilla ni cambie el formato de las celdas para evitar errores.
                                </p>
                            </div>
                        </div>
                    </div>

                    <%-- Card: Mapeo de Perfiles --%>
                    <div class="cmu-card">
                        <div class="cmu-card-body">
                            <p class="cmu-section-label">Mapeo de Perfiles (ID)</p>
                            <div class="cmu-perfil-grid">
                                <asp:Literal ID="litPerfiles" runat="server" />
                            </div>
                        </div>
                    </div>

                    <%-- lblPerfil oculto (requerido por code-behind) --%>
                    <asp:Label ID="lblPerfil" runat="server" Visible="false" />

                </div>

                <%-- COLUMNA DERECHA --%>
                <div class="cmu-right">

                    <%-- Card: Referencia de Campos --%>
                    <div class="cmu-card">
                        <div class="cmu-card-header">
                            <span class="cmu-card-header-title">Referencia de Campos</span>
                            <span class="cmu-badge-required">10 CAMPOS REQUERIDOS</span>
                        </div>
                        <div class="cmu-table-wrap">
                            <table class="cmu-table">
                                <thead>
                                    <tr>
                                        <th>Campo</th>
                                        <th>Descripci&#243;n / Regla</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td>Identificador</td>
                                        <td>ID &#250;nico del usuario en el sistema.</td>
                                    </tr>
                                    <tr>
                                        <td>Login</td>
                                        <td>Nombre de usuario asignado para el acceso.</td>
                                    </tr>
                                    <tr>
                                        <td>Clave</td>
                                        <td>Contrase&#241;a &#250;nica para plataformas web/m&#243;vil.</td>
                                    </tr>
                                    <tr>
                                        <td>Perfil</td>
                                        <td>ID num&#233;rico del perfil separado por coma (ver Mapeo de Perfiles).</td>
                                    </tr>
                                    <tr>
                                        <td>Nombre</td>
                                        <td>Nombres del usuario.</td>
                                    </tr>
                                    <tr>
                                        <td>Apellido Paterno</td>
                                        <td>Primer apellido del usuario.</td>
                                    </tr>
                                    <tr>
                                        <td>Apellido Materno</td>
                                        <td>Segundo apellido del usuario.</td>
                                    </tr>
                                    <tr>
                                        <td>Tel&#233;fono</td>
                                        <td>N&#250;mero de contacto directo.</td>
                                    </tr>
                                    <tr>
                                        <td>Correo</td>
                                        <td>Direcci&#243;n de e-mail institucional.</td>
                                    </tr>
                                    <tr>
                                        <td>Habilitado</td>
                                        <td><strong>1</strong> para Activo, <strong>0</strong> para Inactivo.</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <%-- Card: Acciones (descarga + subida) --%>
                    <div class="cmu-card">
                        <div class="cmu-card-body">

                            <div class="cmu-actions-row">

                                <%-- 1. Descarga --%>
                                <div class="cmu-action-col">
                                    <p class="cmu-action-label">1. Obtener Formato</p>
                                    <div class="cmu-download-box">
                                        <div class="cmu-download-icon">
                                            <i class="mdi mdi-file-excel-outline"></i>
                                        </div>
                                        <p class="cmu-download-title">Plantilla de Usuarios</p>
                                        <p class="cmu-download-sub">Formato Excel (.xlsx)</p>
                                        <asp:LinkButton ID="lnkDescargaPlanilla" runat="server"
                                            CssClass="cmu-btn-download"
                                            Text="Descargar Plantilla"
                                            OnClick="lnkDescargaPlanilla_Click" />
                                    </div>
                                </div>

                                <%-- 2. Subida --%>
                                <div class="cmu-action-col">
                                    <p class="cmu-action-label">2. Cargar Archivo</p>
                                    <div class="cmu-upload-box">
                                        <div class="cmu-upload-icon">
                                            <i class="mdi mdi-cloud-upload-outline"></i>
                                        </div>
                                        <p class="cmu-upload-title">Arrastre su archivo aqu&#237;</p>
                                        <p class="cmu-upload-sub">o haga clic para seleccionar desde su PC</p>
                                        <asp:FileUpload ID="fldDocumento" runat="server" />
                                        <div id="divFileName" class="cmu-filename-chip" style="display:none"></div>
                                    </div>
                                </div>

                            </div>

                            <%-- Footer con botones --%>
                            <div class="cmu-footer">
                                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                                    CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
                                <WebControls:PushButton ID="btnCargaMasiva" runat="server"
                                    Text="Iniciar Carga de Usuarios"
                                    OnClientClick="abrirTimer();"
                                    OnClick="btnCargaMasiva_Click" />
                            </div>

                        </div>
                    </div>

                </div>
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>

    <%-- Panel de Resultado --%>
    <asp:Panel ID="pnlResultado" runat="server" Visible="false">
        <div class="cmu-result-card">
            <div class="cmu-result-header">
                <i class="mdi mdi-check-circle-outline"></i> Resultado de la Carga
            </div>
            <div class="cmu-result-body">
                <div class="cmu-result-stats">
                    <div class="cmu-result-stat">
                        <span class="cmu-result-stat-label">Cargados</span>
                        <asp:Label ID="lblDocumentosCargados" runat="server" CssClass="cmu-result-stat-value" />
                    </div>
                    <div class="cmu-result-stat">
                        <span class="cmu-result-stat-label">No Cargados</span>
                        <asp:Label ID="lblDocumentosNoCargados" runat="server" CssClass="cmu-result-stat-value" />
                    </div>
                    <div class="cmu-result-stat">
                        <span class="cmu-result-stat-label">Tiempo Total</span>
                        <asp:Label ID="lblTiempoTotalProceso" runat="server" CssClass="cmu-result-stat-value" style="font-size:15px" />
                    </div>
                </div>
                <rad:RadGrid2 ID="Grid3" runat="server" AutoGenerateColumns="true" AllowPaging="false">
                    <ClientSettings>
                        <Scrolling AllowScroll="true" ScrollHeight="300px" />
                    </ClientSettings>
                </rad:RadGrid2>
            </div>
        </div>
    </asp:Panel>
</div>
</asp:Content>
