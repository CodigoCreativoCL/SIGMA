using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Los permisos del usuario que llama (HU-006).
    ///
    /// PARA QUE SIRVE ESTE ENDPOINT
    ///   Para que la app sepa qué botones pintar. NO es lo que autoriza:
    ///   cada endpoint que escribe vuelve a comprobar del lado del servidor,
    ///   porque ocultar un botón no impide que alguien llame al endpoint
    ///   directamente. Esto es la mitad de la historia -"en la interfaz"-;
    ///   la otra mitad -"y en el servidor"- vive en los SPs.
    ///
    /// SIEMPRE DEL USUARIO DEL TOKEN
    ///   No recibe ?usuario=. Un endpoint que devuelve los permisos de
    ///   quien se le pida es un mapa de la seguridad del sistema servido a
    ///   cualquiera con un token.
    /// </summary>
    [RoutePrefix("usuario-permisos")]
    public class UsuarioPermisosController : ApiBase
    {
        /// <summary>
        /// GET /usuario-permisos — mis permisos, con caché corta.
        ///                                                     HU-006
        ///
        /// El filtro por módulo y la paginación existen porque la lista
        /// crece con cada sprint; hoy son 45 códigos y en el Sprint 3 serán
        /// varias decenas más.
        /// </summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? instalacion = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                int usuario = SesionApi.UsuarioId();
                int cliente = SesionApi.ClienteId();

                /* Caché de 60 segundos. Lo que se ahorra es real: la app
                   consulta esto antes de pintar cada pantalla, y en una
                   navegación normal son varias peticiones seguidas para
                   recibir exactamente lo mismo.

                   Un minuto y no más porque son PERMISOS: uno revocado
                   tiene que dejar de valer pronto, y "pronto" no puede
                   depender de que la persona cierre sesión. */
                string clave = CacheCorta.Clave("permisos", usuario, cliente,
                                                instalacion.HasValue ? instalacion.Value.ToString() : null);

                List<PermisoDto> todo = CacheCorta.Obtener(clave, () =>
                    Datos.Listar<PermisoDto>("SEL_USUARIO_PERMISOS",
                        new Dictionary<string, object>
                        {
                            { "@USUARIO", usuario },
                            { "@CLIENTE", cliente > 0 ? (object)cliente : null },
                            { "@INSTALACION", instalacion }
                        }));

                if (todo == null) todo = new List<PermisoDto>();

                // El filtro se aplica DESPUES de la caché: filtrar antes
                // guardaría una lista recortada bajo una clave que no dice
                // que lo está, y la siguiente consulta sin filtro recibiría
                // menos permisos de los que tiene.
                if (!string.IsNullOrEmpty(p.filtro))
                {
                    List<PermisoDto> filtrado = new List<PermisoDto>();
                    string buscar = p.filtro.ToUpperInvariant();

                    foreach (PermisoDto d in todo)
                        if ((d.prm_codigo ?? "").ToUpperInvariant().Contains(buscar))
                            filtrado.Add(d);

                    todo = filtrado;
                }

                return Ok(Paginado<PermisoDto>.Armar(todo, p));
            });
        }

        /// <summary>
        /// GET /usuario-permisos/tengo/{codigo} — ¿tengo este permiso?
        ///
        /// Existe para que la app no tenga que bajar la lista completa y
        /// buscar dentro cuando solo quiere saber si pinta un botón.
        /// </summary>
        [HttpGet]
        [Route("tengo/{codigo}")]
        public IHttpActionResult Tengo(string codigo)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirTexto(codigo, "codigo");

                int usuario = SesionApi.UsuarioId();
                int cliente = SesionApi.ClienteId();

                List<PermisoDto> todo = CacheCorta.Obtener(
                    CacheCorta.Clave("permisos", usuario, cliente), () =>
                    Datos.Listar<PermisoDto>("SEL_USUARIO_PERMISOS",
                        new Dictionary<string, object>
                        {
                            { "@USUARIO", usuario },
                            { "@CLIENTE", cliente > 0 ? (object)cliente : null }
                        }));

                bool tiene = false;

                if (todo != null)
                    foreach (PermisoDto d in todo)
                        if (string.Equals(d.prm_codigo, codigo, StringComparison.OrdinalIgnoreCase))
                        { tiene = true; break; }

                return Ok(new { codigo = codigo, tiene = tiene });
            });
        }
    }
}
