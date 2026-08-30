using Microsoft.IdentityModel.Tokens;
using System;
using System.Configuration;
using System.Security.Claims;

namespace Controllers
{
    internal static class TokenGenerator
    {
        public static string GenerateTokenJwt(string username)
        {
            // appsetting for Token JWT
            var secretKey = ConfigurationManager.AppSettings["JWT_SECRET_KEY"];
            var audienceToken = ConfigurationManager.AppSettings["JWT_AUDIENCE_TOKEN"];
            var issuerToken = ConfigurationManager.AppSettings["JWT_ISSUER_TOKEN"];
            var expireTime = ConfigurationManager.AppSettings["JWT_EXPIRE_MINUTES"];

            var securityKey = new SymmetricSecurityKey(System.Text.Encoding.Default.GetBytes(secretKey));
            var signingCredentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256Signature);

            // create a claimsIdentity
            ClaimsIdentity claimsIdentity = new ClaimsIdentity(new[] { new Claim(ClaimTypes.Name, username) });

            // create token to the user
            var tokenHandler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
            var jwtSecurityToken = tokenHandler.CreateJwtSecurityToken(
                audience: audienceToken,
                issuer: issuerToken,
                subject: claimsIdentity,
                notBefore: DateTime.UtcNow,
                expires: DateTime.UtcNow.AddMinutes(Convert.ToInt32(expireTime)),
                signingCredentials: signingCredentials);

            var jwtTokenString = tokenHandler.WriteToken(jwtSecurityToken);
            return jwtTokenString;
        }

        /// <summary>
        /// Token de un USUARIO de SIGMA, no de la cuenta de servicio.
        ///
        /// POR QUE HACIA FALTA OTRO
        ///   GenerateTokenJwt firma un token con el usuario fijo de
        ///   Web.config: sirve para que un sistema se identifique ante la
        ///   API, no para saber QUIEN esta operando. Y sin saber quien
        ///   opera no se puede resolver un permiso ni escribir el @USUARIO
        ///   que audita cada SP: todo quedaria firmado por "Sigma".
        ///
        /// LO QUE VA EN EL TOKEN Y LO QUE NO
        ///   Van el id de usuario, su login y el cliente en contexto:
        ///   lo minimo para resolver permisos sin volver a la base en cada
        ///   peticion.
        ///
        ///   NO van los permisos. Un token dura ocho horas; los permisos
        ///   cambian antes. Incrustarlos significaria que revocar uno no
        ///   surte efecto hasta que la persona vuelva a entrar, que es
        ///   exactamente el problema que se acaba de corregir en el sitio
        ///   web. Los permisos se consultan, con cache de un minuto.
        /// </summary>
        public static string GenerarTokenUsuario(int usuarioId, string login, int clienteId)
        {
            var secretKey = ConfigurationManager.AppSettings["JWT_SECRET_KEY"];
            var audienceToken = ConfigurationManager.AppSettings["JWT_AUDIENCE_TOKEN"];
            var issuerToken = ConfigurationManager.AppSettings["JWT_ISSUER_TOKEN"];
            var expireTime = ConfigurationManager.AppSettings["JWT_EXPIRE_MINUTES"];

            var securityKey = new SymmetricSecurityKey(System.Text.Encoding.Default.GetBytes(secretKey));
            var signingCredentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256Signature);

            ClaimsIdentity claimsIdentity = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.Name, login ?? ""),
                new Claim(ClaimTypes.NameIdentifier, usuarioId.ToString()),
                new Claim("sigma_usuario", usuarioId.ToString()),
                new Claim("sigma_cliente", clienteId.ToString())
            });

            var tokenHandler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
            var jwtSecurityToken = tokenHandler.CreateJwtSecurityToken(
                audience: audienceToken,
                issuer: issuerToken,
                subject: claimsIdentity,
                notBefore: DateTime.UtcNow,
                expires: DateTime.UtcNow.AddMinutes(Convert.ToInt32(expireTime)),
                signingCredentials: signingCredentials);

            return tokenHandler.WriteToken(jwtSecurityToken);
        }
    }
}