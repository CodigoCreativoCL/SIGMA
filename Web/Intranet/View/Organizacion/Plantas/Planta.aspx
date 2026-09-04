<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Planta.aspx.cs" Inherits="View_Organizacion_Plantas_Planta" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Instalaciones/ConfiguracionApp.ascx" TagPrefix="wuc" TagName="ConfiguracionApp" %>
<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Responsables" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }

        /* ------------------------------------------------------------------
           Dirección -> latitud y longitud.

           Se geocodifica EN EL NAVEGADOR y no en el servidor: la clave de
           Maps es de JavaScript, y hacerlo acá evita que el servidor tenga
           que salir a Internet en medio de un guardado —con su timeout— para
           un dato que es de apoyo, no obligatorio.

           NO pisa coordenadas ya escritas. Alguien que las pegó desde un GPS
           tiene el punto exacto del portón; el geocodificador devuelve el
           centro aproximado de la calle. Entre los dos gana la persona.
           Para reemplazarlas hay que apretar el botón a propósito.
           ------------------------------------------------------------------ */

        function sigmaGeo(forzar) {
            var txtDir = document.getElementById('<%=txtDireccion.ClientID %>');
            var txtLat = document.getElementById('<%=txtLatitud.ClientID %>');
            var txtLng = document.getElementById('<%=txtLongitud.ClientID %>');
            var estado = document.getElementById('sigmaGeoEstado');

            if (!txtDir || !txtLat || !txtLng) return;

            var direccion = (txtDir.value || '').trim();

            if (direccion.length < 6) return;

            // Ya tiene coordenadas y nadie pidió reemplazarlas.
            if (!forzar && (txtLat.value || '').trim() !== '' && (txtLng.value || '').trim() !== '')
                return;

            if (typeof google === 'undefined' || !google.maps) {
                if (estado) estado.innerHTML = 'El mapa no está disponible. Escriba las coordenadas a mano.';
                return;
            }

            if (estado) estado.innerHTML = 'Buscando la dirección…';

            new google.maps.Geocoder().geocode(
                { address: direccion, region: 'cl' },
                function (res, status) {
                    if (status === 'OK' && res && res[0]) {
                        var p = res[0].geometry.location;

                        // toFixed(6) fija el punto decimal: la columna es
                        // DECIMAL(9,6) y el separador tiene que ser punto,
                        // no la coma de es-CL.
                        txtLat.value = p.lat().toFixed(6);
                        txtLng.value = p.lng().toFixed(6);

                        if (estado)
                            estado.innerHTML = 'Ubicación encontrada: <strong>' +
                                res[0].formatted_address + '</strong>. Corrija las coordenadas si el punto no es exacto.';
                    }
                    else if (status === 'ZERO_RESULTS') {
                        if (estado) estado.innerHTML = 'No se encontró esa dirección. Puede escribir las coordenadas a mano.';
                    }
                    else {
                        if (estado) estado.innerHTML = 'No se pudo consultar el mapa (' + status + '). Escriba las coordenadas a mano.';
                    }
                });
        }
    </script>

    <asp:Literal ID="litMaps" runat="server" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-modal">

                <div class="sigma-modal-eyebrow">
                    <i class="mdi mdi-sitemap-outline"></i>
                    Organización &middot; <asp:Literal ID="litCliente" runat="server" />
                </div>

                <h1 class="sigma-modal-title"><asp:Literal ID="litTitulo" runat="server" /></h1>

                <div class="sigma-modal-hero">
                    <div class="sigma-modal-hero-icon">
                        <i class="mdi mdi-factory"></i>
                    </div>
                    <div class="sigma-modal-hero-body">
                        <asp:Literal ID="litChipEstado" runat="server" />
                        <div class="sigma-modal-hero-titulo"><asp:Literal ID="litHeroTitulo" runat="server" /></div>
                        <p class="sigma-modal-hero-detalle"><asp:Literal ID="litHeroDetalle" runat="server" /></p>
                    </div>
                </div>

                <div class="sigma-modal-grid">

                    <div class="sigma-modal-field">
                        <span class="sigma-modal-label">ID</span>
                        <div class="sigma-modal-valor"><asp:Label ID="lblId" runat="server" /></div>
                    </div>

                    <div class="sigma-modal-field">
                        <label>Código (*)</label>
                        <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                             lo escribe quien crea el registro. Van juntos en una sola
                             caja para que se lea como UN codigo y no como dos campos. --%>
                        <div class="sg-codigo">
                            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                        </div>
                        <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
                        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Planta" />
                        <span class="sigma-modal-ayuda">Mayúsculas sin espacios. Único dentro del cliente.</span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Nombre (*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Planta" />
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Dirección</label>
                        <WebControls:TextBox2 ID="txtDireccion" runat="server" MaxLength="200" />
                        <span class="sigma-modal-ayuda" id="sigmaGeoEstado">
                            Al salir de este campo se buscan las coordenadas automáticamente.
                        </span>
                    </div>

                    <div class="sigma-modal-field">
                        <label>Latitud</label>
                        <WebControls:TextBox2 ID="txtLatitud" runat="server" MaxLength="12" />
                    </div>

                    <div class="sigma-modal-field">
                        <label>Longitud</label>
                        <WebControls:TextBox2 ID="txtLongitud" runat="server" MaxLength="12" />
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Zona horaria</label>
                        <rad:RadComboBox2 ID="cboZonaHoraria" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">
                            Vacío hereda la del cliente. Con una propia, las programaciones de esta planta
                            se calculan con ella.
                        </span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="200" />
                    </div>

                    <div class="sigma-modal-field">
                        <label>Habilitada (*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Planta" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Planta" />
                        </div>
                    </div>

                </div>

                <%-- Lo que antes vivia en NuevaInstalacion.aspx.

                     Solo aparece con la planta ya creada: no se puede
                     autorizar gente ni configurar la app de una planta que
                     todavia no existe, porque las dos cosas se guardan
                     contra su id. --%>
                <asp:Panel ID="pnlExistente" runat="server" Visible="false">

                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-cellphone-cog"></i> Configuración de la app
                    </div>
                    <wuc:ConfiguracionApp runat="server" ID="wucConfiguracionApp" />

                    <div class="sigma-modal-seccion">
                        <i class="mdi mdi-account-hard-hat"></i> Responsables de la planta
                    </div>
                    <wuc:Responsables runat="server" ID="wucResponsables" />

                </asp:Panel>

                <div class="sigma-modal-actions">
                    <span class="sigma-modal-actions-nota">
                        Una planta con áreas, activos u órdenes no se borra: se deshabilita.
                    </span>
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Planta" />
                </div>

            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
