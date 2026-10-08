<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="CargaMasivaPlanes.aspx.cs" Inherits="View_Mantenimiento_Planes_CargaMasivaPlanes" %>

<%-- Carga masiva de planes (se abre desde el Centro de Planificación).

     Mismo diseño que el Centro de carga de datos de los otros centros
     (sigma-carga-datos.css): cabecera con ícono, tres pasos numerados, KPI
     del resultado y tabla de filas con error. La lógica no cambia: sigue
     siendo PlanMantenimientoCargaController (plan + intervenciones +
     activos, por el mismo camino que las fichas). --%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href="<%=ResolveUrl("~/Css/Comun/sigma-carga-datos.css") %>?vrs=3" rel="stylesheet" />
    <style>.cd-zona{overflow:hidden;text-align:center}.cd-zona input[type=file]{max-width:100%;font-size:12px;margin-top:8px}</style>
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement && window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            try {
                if (window.parent && window.parent.SigmaModal) { window.parent.SigmaModal.close(); return; }
            } catch (e) { }
            var w = getRadWindow();
            if (w) { if (w.BrowserWindow && w.BrowserWindow.refresh) w.BrowserWindow.refresh(); w.close(); }
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="cd es-fijo">
                <section class="cd-card cd-asistente">
                    <div class="cd-asistente-cab">
                        <span class="cd-modulo-ico" style="background:#007F8A1A;color:#007F8A"><i class="mdi mdi-calendar-check"></i></span>
                        <div>
                            <h3>Cargar planes de mantenimiento</h3>
                            <p>Planes con sus intervenciones y los activos a los que se aplican. Todo entra en borrador: nada se activa solo.</p>
                        </div>
                    </div>

                    <div class="cd-pasos">
                        <div class="cd-paso">
                            <div class="cd-paso-tit"><b>1</b>Descarga la plantilla</div>
                            <p>Un libro con tres hojas que se cruzan por el <strong>código del plan</strong>: <strong>PLANES</strong> (qué es), <strong>HITOS</strong> (qué se le hace y cada cuánto) y <strong>EQUIPOS</strong> (a qué activos). Las demás hojas son de ayuda, con los valores válidos de tu empresa. La fila de ejemplo se ignora al cargar.</p>
                            <div class="cd-hojas">
                                <details class="cd-hoja" open>
                                    <summary><i class="mdi mdi-clipboard-text-outline ico"></i>PLANES</summary>
                                    <div class="cd-hoja-cuerpo">Código, nombre, planta, tipo y modelo, planificador.</div>
                                </details>
                                <details class="cd-hoja">
                                    <summary><i class="mdi mdi-wrench-outline ico"></i>HITOS</summary>
                                    <div class="cd-hoja-cuerpo">Cada intervención del plan y su programación.</div>
                                </details>
                                <details class="cd-hoja">
                                    <summary><i class="mdi mdi-cog-outline ico"></i>EQUIPOS</summary>
                                    <div class="cd-hoja-cuerpo">Los activos de cada plan, con su alcance.</div>
                                </details>
                            </div>
                            <div class="cd-acciones">
                                <asp:LinkButton ID="btnPlantilla" runat="server" CssClass="cd-btn es-contorno" OnClick="btnPlantilla_Click" CausesValidation="false"><i class="mdi mdi-file-excel-outline"></i>Descargar plantilla</asp:LinkButton>
                            </div>
                        </div>

                        <div class="cd-paso">
                            <div class="cd-paso-tit"><b>2</b>Sube tu planilla</div>
                            <p>Se cargan primero los planes, después sus hitos y al final sus activos, con las mismas reglas de las fichas: código único, alcance del activo y solo sobre un borrador. Una fila con error no detiene el resto: abajo se dice en qué hoja y fila falló.</p>
                            <div class="cd-zona tiene-archivo" style="cursor:default">
                                <i class="mdi mdi-cloud-upload-outline"></i>
                                <b>Archivo (.xlsx)</b>
                                <asp:FileUpload ID="fldArchivo" runat="server" accept=".xlsx" />
                            </div>
                        </div>

                        <div class="cd-paso">
                            <div class="cd-paso-tit"><b>3</b>Revisa y carga</div>
                            <p>Al cargar, SIGMA crea cada plan en borrador. Los hitos y activos pueden apuntar a un plan que ya exista, si está en borrador.</p>
                            <div class="cd-acciones">
                                <asp:LinkButton ID="btnCargar" runat="server" CssClass="cd-btn es-primario" OnClick="btnCargar_Click" CausesValidation="false"><i class="mdi mdi-database-import-outline"></i>Cargar planes</asp:LinkButton>
                                <a href="#" class="cd-btn es-ghost" onclick="closeWindow(); return false;"><i class="mdi mdi-close"></i>Cerrar</a>
                            </div>
                        </div>
                    </div>
                </section>

                <asp:Panel ID="pnlResultado" runat="server" Visible="false" CssClass="cd-card cd-resultado">
                    <div class="cd-card-cab">
                        <h3><i class="mdi mdi-clipboard-check-outline"></i>Resultado</h3>
                    </div>
                    <div class="cd-kpis">
                        <div class="cd-kpi"><span class="cd-kpi-ico" style="background:#16855B1A;color:#16855B"><i class="mdi mdi-check-circle-outline"></i></span><div><b><asp:Literal ID="litCargados" runat="server" /></b><span>Cargados</span></div></div>
                        <div class="cd-kpi"><span class="cd-kpi-ico" style="background:#C7352B1A;color:#C7352B"><i class="mdi mdi-alert-circle-outline"></i></span><div><b><asp:Literal ID="litFallidos" runat="server" /></b><span>Con error</span></div></div>
                        <div class="cd-kpi"><span class="cd-kpi-ico" style="background:#6732F41A;color:#6732F4"><i class="mdi mdi-timer-outline"></i></span><div><b><asp:Literal ID="litDuracion" runat="server" /></b><span>Duración</span></div></div>
                    </div>

                    <%-- Las filas que fallaron, con su número: sin él hay que adivinar
                         cuál de las doscientas es. --%>
                    <asp:Panel ID="pnlErrores" runat="server" Visible="false">
                        <div class="cd-tabla-scroll">
                            <table class="cd-tabla">
                                <thead><tr><th style="width:90px">Fila</th><th>Qué pasó</th></tr></thead>
                                <tbody>
                                    <asp:Repeater ID="rptErrores" runat="server">
                                        <ItemTemplate>
                                            <tr>
                                                <td><span class="cd-chip es-danger"><%# Eval("FILA") %></span></td>
                                                <td><strong><%# Server.HtmlEncode(Eval("CODIGO").ToString()) %></strong> — <%# Server.HtmlEncode(Eval("MOTIVO").ToString()) %></td>
                                            </tr>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </tbody>
                            </table>
                        </div>
                    </asp:Panel>
                </asp:Panel>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
