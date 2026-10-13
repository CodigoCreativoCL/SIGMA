<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Accesibilidad.aspx.cs" Inherits="View_Comun_Accesibilidad_Accesibilidad" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Opciones de accesibilidad de la persona (HU-162). Cada quien configura
         las suyas; el intranet las respeta en todas las pantallas. Diseño
         estándar de SIGMA: cards blancas, un primario morado para guardar. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-accesibilidad.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mi cuenta
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Accesibilidad
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Ajusta cómo se ve y se escucha SIGMA. Tus opciones se guardan y se aplican en todas las pantallas.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:Literal ID="litAviso" runat="server" />

            <%-- ---- Ver ---- --%>
            <div class="card-box sg-acc-grupo">
                <h3 class="sg-acc-grupo-tit"><i class="mdi mdi-eye-outline"></i> Ver</h3>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Texto más grande</strong>
                        <small>Aumenta el tamaño de la letra en toda la interfaz, sin cortar el contenido.</small>
                    </div>
                    <asp:CheckBox ID="chkTextoGrande" runat="server" CssClass="sg-acc-switch" />
                </div>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Alto contraste</strong>
                        <small>Aplica una paleta de mayor contraste para leer mejor.</small>
                    </div>
                    <asp:CheckBox ID="chkAltoContraste" runat="server" CssClass="sg-acc-switch" />
                </div>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Iconos grandes</strong>
                        <small>Agranda los iconos para encontrarlos y tocarlos más fácil.</small>
                    </div>
                    <asp:CheckBox ID="chkIconosGrandes" runat="server" CssClass="sg-acc-switch" />
                </div>
            </div>

            <%-- ---- Voz ---- --%>
            <div class="card-box sg-acc-grupo">
                <h3 class="sg-acc-grupo-tit"><i class="mdi mdi-microphone-outline"></i> Voz</h3>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Entrada por voz</strong>
                        <small>Permite dictar en vez de teclear donde esté disponible.</small>
                    </div>
                    <asp:CheckBox ID="chkEntradaVoz" runat="server" CssClass="sg-acc-switch" />
                </div>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Lectura por voz</strong>
                        <small>Lee en voz alta los textos y mensajes.</small>
                    </div>
                    <asp:CheckBox ID="chkLecturaVoz" runat="server" CssClass="sg-acc-switch" />
                </div>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Confirmación hablada</strong>
                        <small>Confirma en voz alta las acciones importantes.</small>
                    </div>
                    <asp:CheckBox ID="chkConfirmacionHablada" runat="server" CssClass="sg-acc-switch" />
                </div>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Velocidad de la voz</strong>
                        <small>Qué tan rápido lee SIGMA.</small>
                    </div>
                    <rad:RadComboBox2 ID="cboVelocidad" runat="server" Width="140px">
                        <Items>
                            <rad:RadComboBoxItem Text="Lenta (0,5×)" Value="0.50" />
                            <rad:RadComboBoxItem Text="Pausada (0,75×)" Value="0.75" />
                            <rad:RadComboBoxItem Text="Normal (1×)" Value="1.00" />
                            <rad:RadComboBoxItem Text="Rápida (1,25×)" Value="1.25" />
                            <rad:RadComboBoxItem Text="Muy rápida (1,5×)" Value="1.50" />
                            <rad:RadComboBoxItem Text="Máxima (2×)" Value="2.00" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>

            <%-- ---- Sonido ---- --%>
            <div class="card-box sg-acc-grupo">
                <h3 class="sg-acc-grupo-tit"><i class="mdi mdi-volume-high"></i> Sonido</h3>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Silenciar las alertas sonoras</strong>
                        <small>No suenan las alertas. Su aviso visual se muestra siempre, igual.</small>
                    </div>
                    <asp:CheckBox ID="chkSilenciar" runat="server" CssClass="sg-acc-switch" />
                </div>

                <div class="sg-acc-opcion">
                    <div class="sg-acc-op-txt">
                        <strong>Volumen de las alertas</strong>
                        <small>Qué tan fuerte suenan cuando no están silenciadas.</small>
                    </div>
                    <rad:RadComboBox2 ID="cboVolumen" runat="server" Width="140px">
                        <Items>
                            <rad:RadComboBoxItem Text="0 % (mudo)" Value="0.00" />
                            <rad:RadComboBoxItem Text="25 %" Value="0.25" />
                            <rad:RadComboBoxItem Text="50 %" Value="0.50" />
                            <rad:RadComboBoxItem Text="75 %" Value="0.75" />
                            <rad:RadComboBoxItem Text="100 %" Value="1.00" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="btnGuardar" runat="server" CssClass="sigma-accion is-primaria" OnClick="btnGuardar_Click">
                    <i class="mdi mdi-content-save-outline"></i><span>Guardar</span>
                </asp:LinkButton>
            </div>

            <div class="sg-acc-nota card-box">
                <i class="mdi mdi-information-outline"></i>
                <span>El <strong>movimiento reducido</strong> lo toma SIGMA de tu sistema operativo: si lo activas ahí,
                    acá las animaciones se reemplazan por transiciones simples, sin que tengas que configurar nada.</span>
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
