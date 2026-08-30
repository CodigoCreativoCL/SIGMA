using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using SitioBase.Model;

namespace SitioBase
{
    
    public class Token
    {
        private const string CACHE_PERMISOS = "_sigma_permisos";

        /// <summary>
        /// Las unicas cuatro paginas fuera del modelo de permisos, todas de
        /// infraestructura: el destino del propio rechazo, el login, la
        /// pantalla de espera y el aviso de privacidad publico. Cualquier
        /// pagina de negocio va en Menus, no aca.
        /// </summary>
        private static readonly HashSet<string> EXENTAS =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "~/default.aspx",
                "~/login.aspx",
                "~/view/comun/procesamiento.aspx",
                "~/privacidad/privacidad.aspx",

                /* HU-004. Se abren SIN sesion: son el camino de vuelta de
                   quien no puede entrar. Pedirles permiso seria pedirselo a
                   alguien que por definicion no lo tiene.

                   La seguridad de estas dos no esta aqui sino en el token:
                   un enlace de un solo uso, con vigencia de 60 minutos, del
                   que la base guarda solo el hash. */
                "~/recuperarclave.aspx",
                "~/restablecerclave.aspx",

                /* HU-002. Se llega recien entrado, antes de haber elegido
                   cliente. Exigir un permiso de cliente para poder elegir
                   cliente seria un circulo.

                   No es un agujero: el selector solo ofrece los clientes de
                   la propia persona, y ClienteSesionController.CambiarCliente
                   vuelve a comprobar la pertenencia antes de fijarlo, sin
                   confiar en el id que llega del navegador. */
                "~/seleccionarcliente.aspx",

                /* HU-005. Mi Cuenta muestra y edita los datos de UNO MISMO:
                   su nombre, su foto, su contrasena. No hay nada ahi que
                   pedirle permiso, y exigirlo tiene una consecuencia fea:
                   la pagina esta enlazada dos veces en el encabezado, asi
                   que sin fila en Menus el enlace rebotaba al tablero para
                   todo el mundo -Root incluido- y nadie podia cambiar su
                   propia clave desde el sitio.

                   Va exenta y no registrada en Menus a proposito: un
                   permiso para "verse a si mismo" seria un permiso que hay
                   que acordarse de dar a cada perfil nuevo, y el dia que
                   alguien se olvide vuelve el mismo problema. */
                "~/view/comun/micuenta/micuenta.aspx"
            };

        private static Dictionary<int, string> _codigoPorId;
        private static Dictionary<string, string> _codigoPorPagina;
        private static Dictionary<string, Dictionary<string, string>> _funcionesPorPagina;
        private static readonly object _candado = new object();

        /// <summary>
        /// Cuando se cargo el mapa. Lo usa el reintento de abajo.
        /// </summary>
        private static DateTime _mapaCargadoUtc = DateTime.MinValue;

        /// <summary>
        /// Cada cuanto, como maximo, se acepta releer el mapa por un fallo de
        /// busqueda. Sin este piso, cada peticion a una URL que no existe
        /// -un enlace roto, un bot probando rutas- dispararia una consulta.
        ///
        /// Diez segundos: lo bastante corto para que registrar una pantalla
        /// por script se sienta inmediato, y lo bastante largo para que una
        /// rafaga de 404 no se convierta en una rafaga de consultas.
        /// </summary>
        private static readonly TimeSpan RELECTURA_MINIMA = TimeSpan.FromSeconds(10);


        public static bool TokenSeguridad()
        {
            return !string.IsNullOrEmpty(Session.UsuarioId());
        }


        /* ================================================================
           PERMISOS DEL USUARIO
           ================================================================ */

        /// <summary>
        /// Los permisos del usuario en el cliente que tenga en contexto.
        ///
        /// EL CACHE DURA UNA PETICION, NO UNA SESION
        ///   Estaba en Session y sin caducidad: quien recibia un permiso o un
        ///   menu nuevo no lo veia hasta volver a entrar, y quien lo perdia lo
        ///   conservaba hasta entonces -que es lo grave de los dos-. Un
        ///   permiso revocado tiene que dejar de valer cuando se revoca, no
        ///   cuando la persona decida cerrar sesion.
        ///
        ///   Ahora vive en HttpContext.Items, o sea que se lee una vez por
        ///   peticion: dentro de una misma pagina todas las comprobaciones
        ///   ven lo mismo -no puede pasar que el menu diga una cosa y el
        ///   boton otra- y el siguiente clic ya trae la foto nueva.
        ///
        ///   El costo es una llamada a SEL_USUARIO_PERMISOS por pagina
        ///   servida. Es un SP sobre tablas chicas, y la alternativa era
        ///   seguir sirviendo permisos viejos.
        /// </summary>
        public static HashSet<string> Permisos()
        {
            HttpContext ctx = HttpContext.Current;

            if (ctx == null || ctx.Session == null)
                return new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            HashSet<string> permisos = ctx.Items[CACHE_PERMISOS] as HashSet<string>;
            if (permisos != null)
                return permisos;

            permisos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            if (ctx.Session["usu_id"] != null)
            {
                int usuario;
                if (int.TryParse(ctx.Session["usu_id"].ToString(), out usuario))
                {
                    SqlCommand cmd = new SqlCommand();
                    cmd.CommandText = "SEL_USUARIO_PERMISOS";
                    cmd.Parameters.AddWithValue("@USUARIO", usuario);

                    // El cliente en contexto acota los permisos por perfil de
                    // cliente y las reglas puntuales. Mientras el selector de
                    // cliente no exista, va NULL y solo pesan los globales.
                    if (ctx.Session["cli_id"] != null)
                        cmd.Parameters.AddWithValue("@CLIENTE", ctx.Session["cli_id"]);

                    if (ctx.Session["cin_id"] != null)
                        cmd.Parameters.AddWithValue("@INSTALACION", ctx.Session["cin_id"]);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                            permisos.Add(dr["prm_codigo"].ToString());
                    }
                }
            }

            ctx.Items[CACHE_PERMISOS] = permisos;
            return permisos;
        }

        public static bool Puede(string codigo)
        {
            if (string.IsNullOrEmpty(codigo)) return false;
            if (!TokenSeguridad()) return false;

            return Permisos().Contains(codigo);
        }

        /// <summary>Vuelve a leer los permisos del usuario en la proxima consulta.</summary>
        /// <summary>
        /// Bota los permisos ya leidos en ESTA peticion. Lo llaman el cambio
        /// de cliente y el login, que cambian el contexto a mitad de camino:
        /// sin esto, el resto de la pagina seguiria respondiendo con los
        /// permisos del cliente anterior.
        ///
        /// Ya no hace falta llamarla para "que se vea un permiso nuevo": el
        /// cache dura una peticion y la siguiente lo relee sola.
        /// </summary>
        public static void Refrescar()
        {
            if (HttpContext.Current == null) return;

            HttpContext.Current.Items.Remove(CACHE_PERMISOS);

            // La clave vieja en Session, por si quedo una sesion en curso
            // levantada antes de este cambio.
            if (HttpContext.Current.Session != null)
                HttpContext.Current.Session.Remove(CACHE_PERMISOS);
        }


        /* ================================================================
           MAPA DE URLS
           ================================================================ */

        private static void CargarMapa()
        {
            lock (_candado)
            {
                if (_codigoPorPagina != null) return;

                Dictionary<int, string> porId = new Dictionary<int, string>();
                Dictionary<string, string> porPagina =
                    new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                Dictionary<string, Dictionary<string, string>> funciones =
                    new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);

                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "SEL_MENUS_PERMISOS_MAPA";

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        string link = dr["mnu_link"].ToString();
                        string codigo = dr["prm_codigo"].ToString();
                        porPagina[link] = codigo;
                        porId[Convert.ToInt32(dr["mnu_id"])] = codigo;
                    }

                    if (dr.NextResult())
                    {
                        while (dr.Read())
                        {
                            string link = dr["mnu_link"].ToString();

                            if (!funciones.ContainsKey(link))
                                funciones[link] = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                            funciones[link][dr["mfu_nombre"].ToString()] = dr["prm_codigo"].ToString();
                        }
                    }
                }

                _codigoPorId = porId;
                _funcionesPorPagina = funciones;
                _mapaCargadoUtc = DateTime.UtcNow;
                _codigoPorPagina = porPagina;   // al final: marca el mapa como cargado
            }
        }

        /// <summary>
        /// Relee el mapa si la pagina buscada no aparecio y ya paso el piso de
        /// tiempo. Devuelve true si efectivamente se releyo.
        ///
        /// POR QUE EXISTE ESTO
        ///   En SIGMA registrar una pantalla es un INSERT en Menus, no un
        ///   cambio de codigo. Esa decision tiene una contrapartida que
        ///   costo una sesion entera de depuracion: el mapa es un cache de
        ///   AppDomain que se carga UNA vez, asi que un INSERT hecho por
        ///   script no lo veia nadie hasta reiniciar el sitio. La pantalla
        ///   nueva existia, el permiso existia, el usuario lo tenia, y aun
        ///   asi ExigirPagina() devolvia a Default.aspx.
        ///
        ///   Cerrar sesion no servia: eso limpia Session, y el mapa es
        ///   estatico. RefrescarMapa() si sirve, pero solo lo llamaba el
        ///   mantenedor de menus, que no es por donde entran los scripts.
        ///
        ///   Con esto, un INSERT se refleja solo, dentro de 30 segundos.
        /// </summary>
        private static bool RecargarMapaSiCorresponde()
        {
            lock (_candado)
            {
                if (DateTime.UtcNow - _mapaCargadoUtc < RELECTURA_MINIMA)
                    return false;

                _codigoPorId = null;
                _codigoPorPagina = null;
                _funcionesPorPagina = null;

                // Se adelanta la marca: si la lectura falla, no queremos que
                // la siguiente peticion vuelva a intentarlo de inmediato.
                _mapaCargadoUtc = DateTime.UtcNow;
            }

            CargarMapa();
            return true;
        }

        /// <summary>El mantenedor de menus llama aca despues de guardar.</summary>
        public static void RefrescarMapa()
        {
            lock (_candado)
            {
                _codigoPorId = null;
                _codigoPorPagina = null;
                _funcionesPorPagina = null;
            }
        }

        /// <summary>La pagina que se esta sirviendo, tal como se guarda en mnu_link.</summary>
        public static string PaginaActual()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Request == null) return "";

            return ctx.Request.AppRelativeCurrentExecutionFilePath;
        }


        /* ================================================================
           LO QUE USAN EL MASTER Y LOS CONTROLES
           ================================================================ */

        /// <summary>
        /// Chequea la pagina actual contra su permiso. Lo llama Default.master,
        /// asi que ninguna pagina tiene que hacer nada.
        /// </summary>
        public static void ExigirPagina()
        {
            if (!TokenSeguridad()) return;

            string pagina = PaginaActual();
            if (EXENTAS.Contains(pagina)) return;

            if (!PuedePagina(pagina))
                HttpContext.Current.Response.Redirect("~/Default.aspx");
        }

        /// <summary>True si el usuario puede abrir esa pagina. Sin fila en Menus, no.</summary>
        public static bool PuedePagina(string pagina)
        {
            if (string.IsNullOrEmpty(pagina)) return false;
            if (EXENTAS.Contains(pagina)) return true;

            CargarMapa();

            string codigo;

            if (!_codigoPorPagina.TryGetValue(pagina, out codigo))
            {
                /* No estar en el mapa puede significar dos cosas muy
                   distintas: que la pagina no existe -y entonces se deniega,
                   que es la regla- o que se registro despues de que el mapa
                   se cargo. Antes de denegar se comprueba la segunda. */
                if (!RecargarMapaSiCorresponde()) return false;

                if (!_codigoPorPagina.TryGetValue(pagina, out codigo))
                    return false;
            }

            return Puede(codigo);
        }

        /// <summary>
        /// True si el usuario puede usar esa funcion EN LA PAGINA ACTUAL.
        /// El nombre es el de Menu_Funcion.mfu_nombre: "Ver todo",
        /// "Ver todo paises", "Crear y editar".
        /// </summary>
        public static bool PuedeFuncion(string nombreFuncion)
        {
            if (string.IsNullOrEmpty(nombreFuncion)) return false;

            CargarMapa();

            string pagina = PaginaActual();

            Dictionary<string, string> deLaPagina;
            string codigo;

            /* Mismo caso que en PuedePagina, con una consecuencia mas
               silenciosa: aqui no redirige a nadie, simplemente el boton de
               Crear o de Emitir no aparece y quien mira concluye que le
               falta un permiso que en realidad tiene. */
            if (!_funcionesPorPagina.TryGetValue(pagina, out deLaPagina) ||
                !deLaPagina.TryGetValue(nombreFuncion, out codigo))
            {
                if (!RecargarMapaSiCorresponde()) return false;

                if (!_funcionesPorPagina.TryGetValue(pagina, out deLaPagina)) return false;
                if (!deLaPagina.TryGetValue(nombreFuncion, out codigo)) return false;
            }

            return Puede(codigo);
        }

        /// <summary>
        /// True si el usuario puede ver ese menu. Un nodo sin permiso es un
        /// contenedor: se resuelve por sus hijos, asi que devuelve true.
        /// </summary>
        public static bool PuedeMenu(int idMenu)
        {
            CargarMapa();

            string codigo;

            if (!_codigoPorId.TryGetValue(idMenu, out codigo))
            {
                /* Un menu sin permiso NO se muestra.
                
                   Antes esto devolvia true, y era la unica pieza del sistema
                   que fallaba abierta: bastaba crear una fila en Menus sin
                   asignarle permiso -cosa que el mantenedor deja hacer- para
                   que esa pantalla apareciera en el menu de todo el mundo,
                   incluido quien no tiene ni un permiso.

                   Ahora hace lo mismo que PuedePagina, que siempre fallo
                   cerrado: sin fila que lo autorice, no. Que las dos
                   respondan igual tambien evita el caso raro de un item que
                   se ve pero al abrirlo rebota. */
                if (!RecargarMapaSiCorresponde()) return false;

                if (!_codigoPorId.TryGetValue(idMenu, out codigo)) return false;
            }

            return Puede(codigo);
        }


        /* ================================================================
           COMPATIBILIDAD
           ================================================================ */

        public static bool SecurityManagerPermisoMenu(MenuPerfil menuPerfil)
        {
            if (menuPerfil == null) return false;
            return PuedeMenu(menuPerfil.mpe_menu);
        }
    }
}
