using System;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace API.Utils
{
    /// <summary>
    /// El cuerpo de error que devuelve toda la API cuando algo no se pudo
    /// hacer. Uno solo, para que la app tenga un único formato que leer.
    /// </summary>
    public class ErrorApi
    {
        public int codigo { get; set; }
        public string mensaje { get; set; }

        /// <summary>
        /// True cuando es una regla de negocio: la app puede mostrar el
        /// mensaje tal cual. False cuando es una falla: mostrarlo no ayuda
        /// y hay que reintentar o escalar.
        /// </summary>
        public bool esDeNegocio { get; set; }
    }


    /// <summary>
    /// Base de los controllers de SIGMA.
    ///
    /// LO QUE RESUELVE UNA VEZ PARA LAS QUINCE ENTIDADES
    ///   1. Traducir el RAISERROR de un SP a un código HTTP con mensaje
    ///      legible, en vez de un 500 genérico.
    ///   2. Exigir que el token identifique a una persona antes de escribir.
    ///   3. Devolver 404 cuando un detalle no existe, sin repetir el if.
    ///
    ///   Los tres estaban escritos como tarea aparte en cada historia. Una
    ///   base común es la diferencia entre arreglarlos una vez y arreglarlos
    ///   quince —y entre que la respuesta de error sea la misma en toda la
    ///   API o dependa de quién escribió cada endpoint—.
    /// </summary>
    public abstract class ApiBase : ApiController
    {
        /// <summary>
        /// Ejecuta la operación y traduce lo que falle.
        ///
        /// El try envuelve TODO el cuerpo del endpoint a propósito: una
        /// regla de negocio puede saltar desde la validación del DTO o
        /// desde el SP, y las dos tienen que salir con el mismo formato.
        /// </summary>
        protected IHttpActionResult Ejecutar(Func<IHttpActionResult> operacion)
        {
            try
            {
                return operacion();
            }
            catch (PermisoDenegadoException ex)
            {
                /* 403 y no 401: el token es válido, lo que falta es el
                   permiso. Distinguirlos importa porque la app reacciona
                   distinto —ante un 401 vuelve a pedir credenciales, ante
                   un 403 no tiene nada que reintentar—. */
                return Error(HttpStatusCode.Forbidden, ex.Message, true);
            }
            catch (ArgumentException ex)
            {
                // Validación del cuerpo antes de llegar a la base.
                return Error(HttpStatusCode.BadRequest, ex.Message, true);
            }
            catch (Exception ex)
            {
                HttpStatusCode codigo = ErrorSql.Codigo(ex);
                string mensaje = ErrorSql.Mensaje(ex);
                bool negocio = ErrorSql.EsDeNegocio(ex);

                /* El detalle real de una falla no viaja al cliente —nombres
                   de tablas y de servidores son justo lo que sirve para
                   atacar la base— pero tiene que quedar en alguna parte, o
                   el 500 no se puede diagnosticar. */
                if (!negocio)
                    System.Diagnostics.Trace.TraceError(
                        "SIGMA API: " + Request.Method + " " + Request.RequestUri + " :: " + ex);

                return Error(codigo, mensaje, negocio);
            }
        }

        /// <summary>
        /// 201 Created con un Location que funciona en cualquier despliegue.
        ///
        /// POR QUE NO SE ARMA A MANO
        ///   Created("clientes/7") escribe una ruta relativa, y la API no
        ///   vive en la raiz del sitio: esta publicada bajo
        ///   http://localhost/SIGMA/Servicio/API. Con la ruta relativa el
        ///   header sale apuntando a /clientes/7 —sin el prefijo— y el
        ///   cliente que lo siga recibe un 404.
        ///
        ///   Se arma quitandole a la URL de la peticion su ultimo segmento
        ///   y agregando el id, de modo que la Location hereda la base real
        ///   sea cual sea: localhost con carpeta virtual, una IP, o el
        ///   dominio del dia que esto se publique.
        /// </summary>
        protected IHttpActionResult Creado(int id)
        {
            Uri destino;

            try
            {
                /* La peticion que crea es un POST al listado
                   (.../API/clientes), asi que basta con agregarle el id.
                   Se descarta la query, que no forma parte de la identidad
                   del recurso nuevo. */
                string sinQuery = Request.RequestUri.GetLeftPart(UriPartial.Path).TrimEnd('/');

                destino = new Uri(sinQuery + "/" + id);
            }
            catch (Exception ex)
            {
                // Un Location mal formado no puede tumbar una creación que
                // ya ocurrió: se responde 201 sin él.
                return Content(HttpStatusCode.Created, new { id = id });
            }

            return Created(destino, new { id = id });
        }

        protected IHttpActionResult Error(HttpStatusCode codigo, string mensaje, bool esDeNegocio = true)
        {
            ErrorApi cuerpo = new ErrorApi
            {
                codigo = (int)codigo,
                mensaje = mensaje,
                esDeNegocio = esDeNegocio
            };

            return Content(codigo, cuerpo);
        }

        /// <summary>
        /// Un detalle que no existe es 404, no un 200 con el objeto vacío.
        ///
        /// Devolver 200 con todo en cero obliga a quien llama a inventarse
        /// una regla para saber si el registro existía, y cada consumidor
        /// se inventa una distinta.
        /// </summary>
        protected IHttpActionResult NoEncontrado(string que)
        {
            return Error(HttpStatusCode.NotFound, que + " no existe.", true);
        }

        /// <summary>
        /// Exige que el token identifique a una persona. Lo llaman los
        /// endpoints que escriben: sin usuario no hay a quién auditar, y
        /// los SPs reciben @USUARIO obligatorio.
        /// </summary>
        protected void ExigirUsuario()
        {
            if (!SesionApi.HayUsuario())
                throw new ArgumentException(
                    "El token no identifica a un usuario de SIGMA. " +
                    "Inicie sesión en POST /sesion.");
        }

        /// <summary>
        /// Exige que haya cliente en contexto. Casi toda consulta de SIGMA
        /// se acota por cliente; sin él, un listado devolvería datos de
        /// todos, que es la fuga más fácil de cometer en un multicliente.
        /// </summary>
        protected void ExigirCliente()
        {
            if (SesionApi.ClienteId() <= 0)
                throw new ArgumentException(
                    "No hay cliente seleccionado. Use POST /cliente-usuarios/seleccionar.");
        }

        /// <summary>
        /// Exige un permiso concreto, con el mismo código que usa la web.
        ///
        /// EL EQUIVALENTE DE Token.Puede(), QUE A LA API LE FALTABA
        ///   Ocultar un botón en Flutter no impide llamar al endpoint: el
        ///   teléfono es del usuario y el tráfico también. GET /menus dice
        ///   qué pintar; esto es lo que autoriza.
        ///
        ///   Se llama ANTES de tocar la base. Un SP que rechaza también
        ///   sirve, pero muchos de los heredados no validan permiso —dan
        ///   por hecho que la web ya lo hizo— y confiar en eso es confiar en
        ///   una comprobación que ocurre en otro proyecto.
        /// </summary>
        protected void ExigirPermiso(string codigo)
        {
            ExigirUsuario();

            if (!Permisos.Tiene(codigo))
                throw new PermisoDenegadoException(
                    "Tu perfil no tiene el permiso '" + codigo + "'.");
        }

        /// <summary>
        /// Exige cualquiera de varios permisos. Existe porque una misma
        /// acción a veces la habilitan dos códigos distintos —ver lo propio
        /// y ver todo— y pedir los dos dejaría fuera a quien solo tiene uno.
        /// </summary>
        protected void ExigirAlgunPermiso(params string[] codigos)
        {
            ExigirUsuario();

            if (codigos != null)
            {
                foreach (string c in codigos)
                {
                    if (Permisos.Tiene(c)) return;
                }
            }

            throw new PermisoDenegadoException(
                "Tu perfil no tiene ninguno de los permisos requeridos para esta acción.");
        }

        protected void ExigirCuerpo(object dto)
        {
            if (dto == null)
                throw new ArgumentException("Falta el cuerpo de la petición o no es un JSON válido.");
        }

        protected void ExigirTexto(string valor, string campo)
        {
            if (string.IsNullOrEmpty(valor) || string.IsNullOrEmpty(valor.Trim()))
                throw new ArgumentException("El campo '" + campo + "' es obligatorio.");
        }
    }
}
