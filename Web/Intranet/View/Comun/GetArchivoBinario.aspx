<%@ Page Language="C#" AutoEventWireup="true" CodeFile="GetArchivoBinario.aspx.cs" Inherits="View_Comun_GetArchivoBinario" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Download</title>
</head>
<body>
    <form id="form1" runat="server">
        <div>
            <asp:ScriptManager ID="ScriptManager1" runat="server">
            </asp:ScriptManager>
            <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
                <ContentTemplate>
                    <center>
                        <h3>Obteniendo documento espere...</h3>
                        <br />
                        <img src="../../Imagen/downloading.gif"  width="250" height="100" />
                    </center>
                </ContentTemplate>
            </asp:UpdatePanel>
        </div>
    </form>
</body>
</html>
