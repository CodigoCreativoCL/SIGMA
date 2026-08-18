<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Accesos.aspx.cs" Inherits="View_Mantenedores_Accesos_Accesos" %>

<asp:Content ID="ContenHead" ContentPlaceHolderID="chpScript" runat="server">
    <link href="../../../Css/Formulario.css" rel="stylesheet" type="text/css" />
    <style type="text/css">  
        .AutoHeight  
        {  
            height: 500px !important;
            background-color: lightgray;
        }  
    </style>
    <script type="text/javascript">
       
        function GuardaPermisos(cadena, index, obj) {
            
            var row = $find("<%= rgrPermisos.MasterTableView.ClientID %>").get_dataItems()[index];
           
            var chk = row.findElement(obj);

            $.ajax({
                type: "POST",
                url: "Accesos.aspx/GuardaPermiso",
                data: '{"cadena":"' + cadena + '","val":"' + chk.checked + '"}',
                contentType: "application/json; charset=utf-8",
                dataType: "json",
                success: function (response) {
                    
                },
                error: function (XMLHttpRequest, textStatus, errorThrown) {
                    alert(textStatus + ": " + XMLHttpRequest.responseText);
                }
            });
        }
  
    </script>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
   Accesos
</asp:Content>
<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" Runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel"  UpdateMode="Conditional" >
        <ContentTemplate>
            <div id ="wrapper_title">
	            <div class="edge mantenedores">
	            </div>	
            </div> 
            <div class="content2">
                <div class="subtitulo" style="display:none;">
                    <asp:Label id="lblMenus" runat="server" />
                </div>
                <rad:RadSplitter ID="rdsExterior" runat="server" Width="100%" Orientation="Vertical" BorderSize="0" CssClass="AutoHeight">
		            <rad:RadPane ID="rpnIzquierdo" runat="server" Width="30%"  CssClass="AutoHeight">
			            <rad:RadTreeView ID="trvPaginas" runat="server" OnNodeClick="trvProductos_OnNodeClick" RenderMode="Lightweight" Skin="Bootstrap">
			            </rad:RadTreeView>
		            </rad:RadPane>
		            <rad:RadPane ID="rdnDerecho" runat="server" Width="70%"  CssClass="AutoHeight">
			            <rad:RadGrid2 ID="rgrPermisos" runat="server" ShowStatusBar="true" OnItemCreated="rgrPermisos_OnItemCreated" OnItemDataBound="rgrPermisos_ItemDataBound" AllowPaging="false">
                            <MasterTableView ClientDataKeyNames="PER_ID"/>
                                <ClientSettings>
                                    <Scrolling AllowScroll="True" UseStaticHeaders="True"  ScrollHeight="460px" SaveScrollPosition="true"  />
                                </ClientSettings>
                        </rad:RadGrid2>
		            </rad:RadPane>
	            </rad:RadSplitter>
            </div>          
            </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>