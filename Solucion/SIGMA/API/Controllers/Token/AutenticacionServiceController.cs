using Controllers;
using MVC.Model;
using System;
using System.Configuration;
using System.Data;
using System.Net;
using System.Web.Http;
using System.Web.Http.Results;


namespace Agendamiento.Controllers
{
    [AllowAnonymous]
    [RoutePrefix("auth")]
    public class AuthController : ApiController
    {
        [HttpPost]
        [Route("authenticate")]
        public JsonResult<DataTable> Authenticate(Autenticacion autenticacion)
        {
            DataTable data = new DataTable();
            bool isCredentialValid = false;
            string[] paramLoginAPI = new string[2];
            string[] valLoginAPI = new string[2];
            try
            {
                if (autenticacion == null || autenticacion.Username == null || autenticacion.Password == null)
                {
                    data.Columns.Add("Code");
                    data.Columns.Add("Message");
                    data.Columns.Add("Exception");

                    DataRow row = data.NewRow();

                    row["Code"] = "400";
                    row["Message"] = "No se ha indicado Username y Password enviado como una petición JSON, debe incluirla.";
                    row["Exception"] = HttpStatusCode.BadRequest;

                    data.Rows.Add(row);

                }
                else
                {

                    var Username = ConfigurationManager.AppSettings["Username"];
                    var Password = ConfigurationManager.AppSettings["Password"];
                    if (Username == autenticacion.Username && Password == autenticacion.Password)
                    {
                        isCredentialValid = true;
                    }
                    else
                    {
                        data = new DataTable();
                        data.Columns.Add("Code");
                        data.Columns.Add("Message");

                        DataRow row = data.NewRow();

                        row["Code"] = "401";
                        row["Message"] = "Usuario o contraseña incorrecto";


                        data.Rows.Add(row);
                    }

                    if (isCredentialValid)
                    {
                        var token = TokenGenerator.GenerateTokenJwt(autenticacion.Username);

                        data.Columns.Add("Code");
                        data.Columns.Add("Token");

                        DataRow row = data.NewRow();

                        row["Code"] = "200";
                        row["Token"] = token;

                        data.Rows.Add(row);
                    }
                }
            }
            catch (Exception ex)
            {
                data = new DataTable();
                data.Columns.Add("Code");
                data.Columns.Add("Message");
                data.Columns.Add("Exception");

                DataRow row = data.NewRow();

                row["Code"] = "500";
                row["Message"] = "Ha ocurrido un error interno en el servidor, intentelo nuevamente más tarde. Si el problema persiste comuniquese con el administrador de la API.";
                row["Exception"] = ex.Message;

                data.Rows.Add(row);
            }

            return Json(data);
        }
    }
}