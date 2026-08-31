<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Auditoria.ascx.cs" Inherits="Comun_Controls_Auditoria" %>

<%--
    Bloque de trazabilidad de una ficha.

    POR QUE UN CONTROL Y NO CUATRO LABELS EN CADA PANTALLA
      Porque son cuatro datos que van en TODAS las fichas del sistema, con el
      mismo formato y el mismo criterio de "todavia no se ha editado". Copiado
      en cada una, la vigesima nace distinta y nadie lo nota.

    SE USA ASI
      <%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>
      ...
      <wuc:Auditoria runat="server" ID="wucAuditoria" />
      ...
      wucAuditoria.Mostrar(entidad.x_usuario_creacion_nombre, entidad.x_fecha_creacion,
                           entidad.x_usuario_actualizacion_nombre, entidad.x_fecha_actualizacion);
--%>

<asp:Panel ID="pnlAuditoria" runat="server" Visible="false" CssClass="sigma-auditoria">

    <div class="sigma-auditoria-item">
        <i class="mdi mdi-account-plus-outline"></i>
        <div>
            <span class="rotulo">Creado</span>
            <span class="valor"><asp:Literal ID="litCreacion" runat="server" /></span>
        </div>
    </div>

    <div class="sigma-auditoria-item">
        <i class="mdi mdi-account-edit-outline"></i>
        <div>
            <span class="rotulo">Última edición</span>
            <span class="valor"><asp:Literal ID="litActualizacion" runat="server" /></span>
        </div>
    </div>

</asp:Panel>
