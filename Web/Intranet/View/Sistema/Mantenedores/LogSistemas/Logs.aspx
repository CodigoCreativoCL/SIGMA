<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Logs.aspx.cs" Inherits="View_Root_Mantenedores_Log_Logs" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>
<asp:Content ID="ContenHead" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Logs del Sistema
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <!-- Habilitado -->
                <div class="col-lg-3 col-md-3 col-sm-6 mb-2">
                    <label for="cboAccion">Acción:</label>
                    <rad:RadComboBox2 ID="cboAccion" runat="server" Width="100%" MarkFirstMatch="true" CheckBoxes="true" Filter="Contains">
                        <Items>
                            <rad:RadComboBoxItem Text="CREADO" Value="1" Checked="true" />
                            <rad:RadComboBoxItem Text="ACTUALIZADO" Value="2" Checked="true" />
                            <rad:RadComboBoxItem Text="ELIMINADO" Value="3" Checked="true" />
                        </Items>
                    </rad:RadComboBox2>
                </div>

                <div class="col-lg-3 col-md-3 col-sm-6 mb-2">
                    <label for="cboTabla">Tablas:</label>
                    <rad:RadComboBox2 ID="cboTabla" runat="server" Width="100%" MarkFirstMatch="true" CheckBoxes="true" Filter="Contains" OnLoad="LoadControls"/>
                </div>

                <!-- Filtro vacío reservado 1 -->
                <div class="col-lg-3 col-md-3 col-sm-6 mb-2">
                    <label for="cboUsuarios">Usuarios:</label>
                    <rad:RadComboBox2 ID="cboUsuarios" runat="server" Width="100%" MarkFirstMatch="true" CheckBoxes="true" Filter="Contains" OnLoad="LoadControls" />
                </div>

                <!-- Filtro vacío reservado 2 -->
                <div class="col-lg-3 col-md-3 col-sm-6 mb-2">
                    <!-- Espacio reservado para futuro filtro -->
                </div>

            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" EnableEmbeddedSkins="true" Skin="MetroTouch" />
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server">
                <MasterTableView DataKeyNames="log_id">
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
