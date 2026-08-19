<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Login.aspx.cs" Inherits="Login" %>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8" />
    <title>SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta content="A fully featured admin theme which can be used to build CRM, CMS, etc." name="description" />
    <meta content="Coderthemes" name="author" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <!-- App favicon -->
    <link href="Imagen/fav.ico" rel="shortcut icon" type="image/vnd.microsoft.icon" />

    <!-- Bootstrap Css -->
    <link href="Css/Login/assets/css/bootstrap.min.css" id="bootstrap-stylesheet" rel="stylesheet" type="text/css" />
    <link href="Css/Adminto/assets/css/bootstrap.min.css" rel="stylesheet" type="text/css" />

    <!-- Icons Css -->
    <link href="Css/Login/assets/css/icons.min.css" rel="stylesheet" type="text/css" />
    <!-- App Css-->
    <link href="Css/Login/assets/css/app.min.css" id="app-stylesheet" rel="stylesheet" type="text/css" />
     
    <!-- SweetAlert CSS -->
    <link href="Css/SweetAlert/sweetalert.css" rel="stylesheet" />
    <link href="Css/SweetAlert/sweetalert2.min.css" rel="stylesheet" />

    <script src="Js/jquery-1.11.3.min.js"></script>
    <script src="Css/SweetAlert/sweetalert2.min.js"></script>
    <script src="Css/Login/assets/js/vendor.min.js"></script>
    <script src="Css/Login/assets/js/app.min.js"></script>
    <script src="Js/Library.js"></script>
</head>
<body class="fg-login-body">
    <form id="form" runat="server">

        <div>
            <div class="form-group">
                <label for="<%= txtLogin.ClientID %>">Usuario</label>
                <div class="fg-input-icon-wrapper">
                    <i class="mdi mdi-account-outline fg-input-icon"></i>
                    <asp:TextBox ID="txtLogin" runat="server" CssClass="form-control fg-input-with-icon" placeholder="Ingresa tu usuario" />
                </div>
            </div>

            <div class="form-group">
                <label for="<%= txtPassword.ClientID %>">Contraseña</label>
                <div class="fg-password-wrapper fg-input-icon-wrapper">
                    <i class="mdi mdi-lock-outline fg-input-icon"></i>
                    <asp:TextBox ID="txtPassword" runat="server" CssClass="form-control fg-input-with-icon" placeholder="Ingresa tu contraseña" TextMode="Password" />
                    <i class="mdi mdi-eye-outline fg-password-toggle" onclick="fgTogglePassword(this, '<%= txtPassword.ClientID %>')"></i>
                </div>
            </div>

            <div class="form-group fg-login-options">
                <label class="fg-checkbox-label" for="<%= chkRecordarme.ClientID %>">
                    <asp:CheckBox ID="chkRecordarme" runat="server" />
                    Recordarme
                </label>
            </div>

            <div class="form-group text-center">
                <asp:Label ID="lblMensaje" runat="server" CssClass="text-danger" />
            </div>

            <div class="form-group mb-0 text-center">
                <asp:Button ID="btnLoginEmpresa" runat="server" Text="Ingresar" OnClick="btnLoginEmpresa_Click" CssClass="btn btn-primary btn-block" />
            </div>

        </div>

        <asp:ScriptManager ID="ScriptManager2" runat="server"></asp:ScriptManager>

        <script type="text/javascript">

</script>
    </form>
</body>
</html>
