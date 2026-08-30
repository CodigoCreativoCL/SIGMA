using API.MVC.Model;
using API.Utils;
using System;
using System.Collections.Generic;
using System.Web.Http;

namespace API.Controllers
{
    /// <summary>
    /// Centros de costo (HU-013). Árbol, con el código único dentro del
    /// cliente. Igual que las áreas: los ciclos los rechaza el SP.
    /// </summary>
    [RoutePrefix("centros-costo")]
    public class CentrosCostoController : ApiBase
    {
        /// <summary>GET /centros-costo — listado.                HU-013</summary>
        [HttpGet]
        [Route("")]
        public IHttpActionResult Listar(int pagina = 1, int tamano = Pagina.TAMANO_DEFECTO,
                                        string filtro = null, int? padre = null,
                                        bool soloRaiz = false, bool? habilitado = null)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Pagina p = new Pagina { pagina = pagina, tamano = tamano, filtro = filtro };

                List<CentroCostoDto> todo = Datos.Listar<CentroCostoDto>("SEL_CENTRO_COSTO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CENTRO_COSTO_PADRE", padre },
                        { "@SOLO_RAIZ", soloRaiz ? (object)true : null },
                        { "@HABILITADO", habilitado },
                        { "@FILTRO", p.filtro }
                    });

                return Ok(Paginado<CentroCostoDto>.Armar(todo, p));
            });
        }

        /// <summary>GET /centros-costo/{id} — detalle.           HU-013</summary>
        [HttpGet]
        [Route("{id:int}")]
        public IHttpActionResult Detalle(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                List<CentroCostoDto> r = Datos.Listar<CentroCostoDto>("SEL_CENTRO_COSTO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CLIENTE", SesionApi.ClienteId() }
                    });

                if (r == null || r.Count == 0) return NoEncontrado("El centro de costo");

                return Ok(r[0]);
            });
        }

        /// <summary>POST /centros-costo — alta.                  HU-013</summary>
        [HttpPost]
        [Route("")]
        public IHttpActionResult Crear(CentroCostoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.codigo, "codigo");
                ExigirTexto(dto.nombre, "nombre");

                int id = Datos.Ejecutar("INS_CENTRO_COSTO",
                    new Dictionary<string, object>
                    {
                        { "@CLIENTE", SesionApi.ClienteId() },
                        { "@CENTRO_COSTO_PADRE", dto.centro_costo_padre },
                        { "@CODIGO", dto.codigo.Trim() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    }, true);

                return Creado(id);
            });
        }

        /// <summary>PUT /centros-costo/{id} — edición.           HU-013</summary>
        [HttpPut]
        [Route("{id:int}")]
        public IHttpActionResult Editar(int id, CentroCostoAltaDto dto)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();
                ExigirCuerpo(dto);
                ExigirTexto(dto.codigo, "codigo");
                ExigirTexto(dto.nombre, "nombre");

                Datos.Ejecutar("UPD_CENTRO_COSTO",
                    new Dictionary<string, object>
                    {
                        { "@ID", id },
                        { "@CENTRO_COSTO_PADRE", dto.centro_costo_padre },
                        { "@CODIGO", dto.codigo.Trim() },
                        { "@NOMBRE", dto.nombre.Trim() },
                        { "@HABILITADO", dto.habilitado },
                        { "@QUITA_PADRE", dto.quita_padre },
                        { "@USUARIO", SesionApi.UsuarioId() }
                    });

                return Ok(new { id = id });
            });
        }

        /// <summary>DELETE /centros-costo/{id} — baja.           HU-013</summary>
        [HttpDelete]
        [Route("{id:int}")]
        public IHttpActionResult Eliminar(int id)
        {
            return Ejecutar(() =>
            {
                ExigirUsuario();
                ExigirCliente();

                Datos.Ejecutar("DEL_CENTRO_COSTO",
                    new Dictionary<string, object> { { "@ID", id } });

                return Ok(new { id = id, mensaje = "Centro de costo dado de baja." });
            });
        }
    }
}
