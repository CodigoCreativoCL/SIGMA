<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Repuesto.aspx.cs" Inherits="View_Inventario_Repuestos_Repuesto" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
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
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Repuesto</h1>

    <%-- Pestañas y no secciones apiladas: la ficha tenía tres bloques uno
         debajo del otro y obligaba a desplazar para llegar a los lotes. Con
         pestañas cada cosa se ve entera y la ventana no crece.

         Las que no aplican se ocultan ENTERAS, no vacías: una pestaña
         "Lotes" que al abrirla no tiene nada es peor que no ofrecerla. --%>
    <rad:RadTabStrip2 ID="tabFicha" runat="server" MultiPageID="mpFicha" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabDatos" Text="Datos" runat="server" PageViewID="pvDatos" />
            <rad:RadTab ID="tabUmbrales" Text="Stock mín. y máx." runat="server" PageViewID="pvUmbrales" />
            <rad:RadTab ID="tabLotes" Text="Lotes" runat="server" PageViewID="pvLotes" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFicha" runat="server" SelectedIndex="0" Width="100%">

        <rad:RadPageView ID="pvDatos" runat="server">

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-tag-outline"></i>Identificación</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>ID</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Código</label>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                        <span class="sigma-modal-ayuda">Se genera solo al guardar: <strong>REP-</strong>más el número del registro.</span>
                        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Repuesto" />
                        <span class="sigma-modal-ayuda">Único dentro del cliente. No se puede cambiar después.</span>
                    </div>
                    <div class="sigma-modal-field is-mitad">
                        <label>Nombre(*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Repuesto" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Unidad de medida(*)</label>
                        <rad:RadComboBox2 ID="cboUnidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        <asp:CustomValidator ID="cvUnidad" runat="server" ControlToValidate="cboUnidad"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Repuesto" />
                        <span class="sigma-modal-ayuda">No se puede cambiar si el repuesto tiene existencia.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Habilitado(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                        <span class="sigma-modal-ayuda">No se puede dar de baja con existencia en bodega.</span>
                    </div>
                    <div class="sigma-modal-field is-mitad">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-factory"></i>Fabricante</div>
                <div class="ayuda">
                    El buscador del listado mira estos campos además del código y el nombre: el
                    técnico escribe el número grabado en la pieza y la encuentra igual.
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field">
                        <label>Fabricante</label>
                        <WebControls:TextBox2 ID="txtFabricante" runat="server" MaxLength="400" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Modelo o código del fabricante</label>
                        <WebControls:TextBox2 ID="txtModelo" runat="server" MaxLength="400" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Costo de referencia</label>
                        <WebControls:TextBox2 ID="txtCosto" runat="server" MaxLength="14" />
                        <span class="sigma-modal-ayuda">Referencial. El costo real sale de cada ingreso.</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-shape-outline"></i>Características</div>
                <div class="ayuda">
                    Cambian <strong>cómo se opera</strong> el repuesto, no cómo se describe.
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field">
                        <label>Controla lote(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbLoteSi" runat="server" Text="SI" GroupName="Lote" />
                            <asp:RadioButton ID="rdbLoteNo" runat="server" Text="NO" GroupName="Lote" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">
                            Con SI, cada ingreso exige el número de lote. Se usa en lo que vence o hay
                            que poder rastrear: aceites, filtros, sellos.
                        </span>
                    </div>
                    <div class="sigma-modal-field">
                        <label>Consumible(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbConsumibleSi" runat="server" Text="SI" GroupName="Consumible" />
                            <asp:RadioButton ID="rdbConsumibleNo" runat="server" Text="NO" GroupName="Consumible" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Se gasta al usarlo y no vuelve a bodega.</span>
                    </div>
                    <div class="sigma-modal-field">
                        <label>Reparable(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbReparableSi" runat="server" Text="SI" GroupName="Reparable" />
                            <asp:RadioButton ID="rdbReparableNo" runat="server" Text="NO" GroupName="Reparable" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Sale de servicio, se repara y vuelve.</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-timer-sand"></i>Vida útil esperada</div>
                <div class="ayuda">
                    La que declara el fabricante. Las tres pueden convivir: un aceite vence a las
                    2.000 horas <strong>o</strong> a los 365 días, lo que ocurra primero. Vacías si
                    no se conocen.<br />
                    La vida útil <strong>real</strong> —cuánto duró en esta planta— se calcula con los
                    horómetros de instalación y retiro, y se lleva aparte.
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field">
                        <label>Horas</label>
                        <WebControls:TextBox2 ID="txtVidaHora" runat="server" MaxLength="12" />
                        <span class="sigma-modal-ayuda">Horas de marcha. Un rodamiento.</span>
                    </div>
                    <div class="sigma-modal-field">
                        <label>Días</label>
                        <WebControls:TextBox2 ID="txtVidaDia" runat="server" MaxLength="8" />
                        <span class="sigma-modal-ayuda">Calendario, gire o no. Un filtro de aire.</span>
                    </div>
                    <div class="sigma-modal-field">
                        <label>Ciclos</label>
                        <WebControls:TextBox2 ID="txtVidaCiclo" runat="server" MaxLength="12" />
                        <span class="sigma-modal-ayuda">Maniobras. Un contacto de partida.</span>
                    </div>
                </div>
            </div>

        </rad:RadPageView>

        <rad:RadPageView ID="pvUmbrales" runat="server">
            <%-- ============ UMBRALES POR BODEGA · HU-053 ============ --%>
            <asp:Panel ID="pnlUmbrales" runat="server" Visible="false" CssClass="sigma-modal-section">

                <div class="sigma-modal-section-title">
                    <i class="mdi mdi-gauge"></i>
                    <span>Stock mínimo y máximo por bodega</span>
                </div>

                <div class="sigma-modal-note">
                    <i class="mdi mdi-information-outline"></i>
                    <div>
                        Los umbrales se definen <strong>por bodega</strong>: la misma pieza puede ser
                        crítica en una planta y no en otra. El máximo no puede ser menor que el mínimo,
                        y el punto de reposición tiene que caer entre los dos.
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field">
                        <label>Bodega</label>
                        <rad:RadComboBox2 ID="cboBodega" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Mínimo</label>
                        <WebControls:TextBox2 ID="txtMinimo" runat="server" MaxLength="12" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Máximo</label>
                        <WebControls:TextBox2 ID="txtMaximo" runat="server" MaxLength="12" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Punto de reposición</label>
                        <WebControls:TextBox2 ID="txtReposicion" runat="server" MaxLength="12" />
                        <span class="sigma-modal-ayuda">Cuándo pedir. Opcional.</span>
                    </div>
                </div>

                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnGuardarUmbral" runat="server" Text="Guardar umbrales" OnClick="btnGuardarUmbral_Click" />
                </div>

                <rad:RadGrid2 ID="GridUmbrales" runat="server">
                    <MasterTableView DataKeyNames="rbs_id" CommandItemDisplay="None" />
                </rad:RadGrid2>

            </asp:Panel>
        </rad:RadPageView>

        <rad:RadPageView ID="pvLotes" runat="server">
            <%-- ============ LOTES · HU-054 CA2 ============
                 Solo lectura y solo si el repuesto controla lote. El lote se CREA al
                 recibir la mercadería, en la pantalla de movimientos: nadie sabe el
                 número hasta que llega el camión. Acá se consultan. --%>
            <asp:Panel ID="pnlLotes" runat="server" Visible="false" CssClass="sigma-modal-section">

                <div class="sigma-modal-section-title">
                    <i class="mdi mdi-barcode"></i>
                    <span>Lotes recibidos</span>
                </div>

                <div class="sigma-modal-note">
                    <i class="mdi mdi-information-outline"></i>
                    <div>
                        Los lotes se registran al <strong>ingresar la mercadería</strong>, en
                        Inventario &rsaquo; Movimientos. Acá se consultan.
                    </div>
                </div>

                <rad:RadGrid2 ID="GridLotes" runat="server" OnItemDataBound="GridLotes_ItemDataBound">
                    <MasterTableView CommandItemDisplay="None" />
                </rad:RadGrid2>

            </asp:Panel>
        </rad:RadPageView>

    </rad:RadMultiPage>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Repuesto" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
