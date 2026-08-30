using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Áreas de una planta (HU-012).
    ///
    /// SON UN ARBOL. Un área puede colgar de otra, y el SP rechaza los
    /// ciclos —incluidos los INDIRECTOS: A padre de B, B padre de C, y
    /// alguien intenta poner C como padre de A—. Esa comprobación NO se
    /// repite acá: está en INS_/UPD_INSTALACION_AREA, que es donde puede
    /// mirar el árbol completo dentro de la misma transacción.
    /// </summary>
    [RoutePrefix("instalacion-areas")]
    public class InstalacionAreasController : ApiBase
    {
        /// <summary>GET /instalacion-areas — listado.            HU-012</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? instalacion = null,
                                        int? padre = null, bool soloRaiz = false,
                                        bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<InstalacionAreaDto> todo = Datos.Listar<InstalacionAreaDto>("SEL_INSTALACION_AREA",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CLIENTE_INSTALACION", instalacion },
                        { "@AREA_PADRE", padre },
                        { "@SOLO_RAIZ", soloRaiz ? (object)true : null },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<InstalacionAreaDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /instalacion-areas/{id} — detalle.       HU-012</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<InstalacionAreaDto> r = Datos.Listar<InstalacionAreaDto>("SEL_INSTALACION_AREA",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El área");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /instalacion-areas — alta.              HU-012</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(InstalacionAreaAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                if (dto.cliente_instalacion <= 0)
                    throw new ArgumentException("Indique la planta a la que pertenece el área.");

                int id = Datos.Ejecutar("INS_INSTALACION_AREA",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CLIENTE_INSTALACION", dto.cliente_instalacion },
                        { "@AREA_PADRE", dto.area_padre },
                        { "@INSTALACION_AREA_TIPO", dto.tipo },
                        { "@CODIGO", dto.codigo },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>
        /// PUT /instalacion-areas/{id} — edición.                HU-012
        ///
        /// quita_padre existe porque no se puede distinguir "no me mandaron
        /// el padre" de "quiero dejarla sin padre" mirando solo un nulo: el
        /// SP usa ISNULL para conservar lo que no viene. Sin esta bandera,
        /// un área nunca podría subir a la raíz.
        /// </summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, InstalacionAreaAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.nombre, "nombre");

                Datos.Ejecutar("UPD_INSTALACION_AREA",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@AREA_PADRE", dto.area_padre },
                        { "@INSTALACION_AREA_TIPO", dto.tipo },
                        { "@CODIGO", dto.codigo },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@DESCRIPCION", dto.descripcion },
                        { "@HABILITADO", dto.habilitado },
                        { "@QUITA_PADRE", dto.quita_padre },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>DELETE /instalacion-areas/{id} — baja.       HU-012</summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("DEL_INSTALACION_AREA",
                    new Dictionary<string, object> { { "@ID", id } });

                return Ok(new { id = id, mensaje = "Área dada de baja." });
            });
        }
    }
}
