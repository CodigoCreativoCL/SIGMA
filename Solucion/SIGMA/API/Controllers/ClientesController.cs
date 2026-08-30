using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Clientes de SIGMA (HU-010).
    ///
    /// ESTE RECURSO NO SE ACOTA POR CLIENTE EN CONTEXTO
    ///   Es el único. Los demás listan lo que hay DENTRO de un cliente;
    ///   este lista los clientes mismos, y quien lo consulta es la
    ///   plataforma. SEL_CLIENTE recibe @USUARIO y decide qué puede ver esa
    ///   persona: quien administra la plataforma los ve todos, quien
    ///   pertenece a dos ve esos dos.
    ///
    ///   Por eso acá NO se llama a ExigirCliente(): pedirle un cliente
    ///   seleccionado a quien todavía no eligió ninguno haría imposible
    ///   dar de alta el primero.
    /// </summary>
    [RoutePrefix("clientes")]
    public class ClientesController : ApiBase
    {
        /// <summary>GET /clientes — listado.                        HU-010</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<ClienteDto> todo = Datos.Listar<ClienteDto>("SEL_CLIENTE",
                    new Dictionary<string, object>
                    {
                        // El SP filtra por lo que este usuario puede ver.
                        { "@USUARIO", SesionApi.UsuarioId() },
                        { "@FILTRO", p.filtro },
                        { "@HABILITADO", habilitado }
                    });

                return Ok(Paginado<ClienteDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /clientes/{id} — detalle.                   HU-010</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                List<ClienteDto> r = Datos.Listar<ClienteDto>("SEL_CLIENTE",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El cliente");

                return Ok(r[0]);
            });
        }

        /// <summary>
        /// POST /clientes — alta.                                   HU-010
        ///
        /// El identificador tributario lo valida el SP contra el país
        /// (FNC_IDENTIFICADOR_VALIDO): en Chile es RUT con módulo 11, en
        /// Perú un RUC de 11 dígitos, y así. No se reimplementa acá porque
        /// esa tabla de reglas vive en Paises y cambia con los países que
        /// se agreguen, no con el código de la API.
        ///
        /// LA SUSCRIPCION NO NACE ACA. Un cliente puede existir mientras se
        /// negocia el trato comercial; obligar a elegir plan en el alta
        /// impediría registrarlo. Es un paso aparte.
        /// </summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(ClienteAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                if (dto.pais <= 0)
                    throw new ArgumentException("Indique el país: de él dependen las reglas del identificador tributario.");

                int id = Datos.Ejecutar("INS_CLIENTE",
                    new Dictionary<string, object>
                    {
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@PAIS", dto.pais },
                        { "@RAZON_SOCIAL", dto.razon_social },
                        { "@IDENTIFICADOR", dto.identificador },
                        { "@NOMBRE_FANTASIA", dto.nombre_fantasia },
                        { "@ZONA_HORARIA", dto.zona_horaria },
                        { "@IDIOMA", dto.idioma },
                        { "@MONEDA", dto.moneda },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /clientes/{id} — edición.                   HU-010</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, ClienteAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                Datos.Ejecutar("UPD_CLIENTE",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@PAIS", dto.pais },
                        { "@RAZON_SOCIAL", dto.razon_social },
                        { "@IDENTIFICADOR", dto.identificador },
                        { "@NOMBRE_FANTASIA", dto.nombre_fantasia },
                        { "@ZONA_HORARIA", dto.zona_horaria },
                        { "@IDIOMA", dto.idioma },
                        { "@MONEDA", dto.moneda },
                        { "@HABILITADO", dto.habilitado },
                        { "@USUARIO", SesionApi.UsuarioId() },
                        // Sin esta bandera el SP interpretaría el logo nulo
                        // como "bórralo", y editar el teléfono borraría el
                        // logo.
                        { "@CAMBIA_LOGO", false }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>DELETE /clientes/{id} — baja.                   HU-010</summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();

                Datos.Ejecutar("DEL_CLIENTE",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id, mensaje = "Cliente dado de baja." });
            });
        }
    }
}
