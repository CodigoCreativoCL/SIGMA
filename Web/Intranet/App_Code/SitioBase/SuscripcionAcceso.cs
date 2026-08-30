using System;
using System.Collections.Generic;
using System.Web;
using SitioBase.Controller;
using SitioBase.Model;

namespace SitioBase
{
    /// <summary>
    /// La compuerta de suscripción (ANEXO F §6.6 · HU-193).
    ///
    /// Hace con la suscripción lo que <see cref="Token"/> hace con los
    /// permisos: la llama el master, y ninguna página tiene que saber que
    /// existe.
    ///
    /// QUÉ SE BLOQUEA, SEGÚN §6.6
    ///
    ///   VIGENTE      todo
    ///   POR VENCER   todo + aviso
    ///   EN GRACIA    todo + aviso destacado
    ///   VENCIDA      solo la página de renovación
    ///   SUSPENDIDA   solo renovación + contacto
    ///   CANCELADA    solo exportar sus datos
    ///
    /// LOS DATOS NUNCA SE BORRAN POR FALTA DE PAGO. Vencida, la información
    /// sigue completa y se recupera íntegra al renovar. Esta clase impide
    /// *entrar*; no toca ni un registro.
    /// </summary>
    public class SuscripcionAcceso
    {
        private const string CLAVE_ESTADO = "_sigma_suscripcion_estado";
        private const string CLAVE_DIA = "_sigma_suscripcion_dia";

        /// <summary>
        /// Páginas que siguen abiertas con la suscripción caída.
        ///
        /// Bloquear sin dejar a dónde ir sería encerrar al administrador
        /// del cliente: no podría ni renovar ni cerrar sesión. Mi Cuenta
        /// queda abierta porque cambiar la propia contraseña no consume
        /// nada del plan, y dejar a alguien sin poder cambiar una clave
        /// comprometida es peor que dejarlo ver una pantalla.
        ///
        /// Renovar.aspx está aquí para que la compuerta no la ataje, pero
        /// eso NO la hace pública: quién puede abrirla lo sigue decidiendo
        /// Token contra su fila en Menus, y el permiso lo tiene solo el
        /// Administrador del Cliente.
        ///
        /// Default.aspx NO está exenta a propósito: el tablero muestra
        /// datos de operación, que es justo lo que §6.6 cierra. Quien
        /// entra vencido cae en la renovación desde la primera pantalla.
        /// </summary>
        private static readonly HashSet<string> EXENTAS =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "~/renovar.aspx",
                "~/login.aspx",
                "~/seleccionarcliente.aspx",
                "~/recuperarclave.aspx",
                "~/restablecerclave.aspx",
                "~/view/comun/micuenta/micuenta.aspx",
                "~/view/comun/procesamiento.aspx",
                "~/privacidad/privacidad.aspx"
            };

        /// <summary>
        /// El estado del cliente en sesión, cacheado por día.
        ///
        /// Se cachea porque el master lo consulta en cada petición, y se
        /// vence al cambiar el día porque VENCIDA y EN GRACIA dependen del
        /// calendario: alguien que deja el navegador abierto de un día para
        /// otro tiene que ver el estado de hoy, no el de ayer.
        /// </summary>
        public static SuscripcionEstadoCliente Estado()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Session == null) return null;

            int cliente = Session.ClienteId();
            if (cliente == 0) return null;

            string hoy = DateTime.Today.ToString("yyyy-MM-dd");

            if (ctx.Session[CLAVE_ESTADO] != null
                && ctx.Session[CLAVE_DIA] != null
                && ctx.Session[CLAVE_DIA].ToString() == hoy)
            {
                SuscripcionEstadoCliente cacheado = ctx.Session[CLAVE_ESTADO] as SuscripcionEstadoCliente;

                // Cambió de cliente durante la sesión: el estado cacheado es
                // de otra empresa y no sirve.
                if (cacheado != null && cacheado.cliente == cliente) return cacheado;
            }

            SuscripcionController controller = new SuscripcionController();
            SuscripcionEstadoCliente estado = controller.GetEstadoCliente(cliente);

            ctx.Session[CLAVE_ESTADO] = estado;
            ctx.Session[CLAVE_DIA] = hoy;

            return estado;
        }

        /// <summary>
        /// Bota el estado cacheado. Se llama al cambiar de cliente y
        /// después de verificar un pago, para que la vigencia recién
        /// extendida se note sin tener que volver a entrar.
        /// </summary>
        public static void Refrescar()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null || ctx.Session == null) return;

            ctx.Session[CLAVE_ESTADO] = null;
            ctx.Session[CLAVE_DIA] = null;
        }

        /// <summary>
        /// La llama el master. Si la suscripción no permite operar, deja
        /// constancia y manda a la página de renovación.
        ///
        /// NO se aplica a las cuentas de plataforma: quien administra SIGMA
        /// no tiene cliente en sesión, y bloquearlo por una suscripción que
        /// no es suya dejaría a nadie pudiendo arreglarla.
        /// </summary>
        public static void Exigir()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null) return;

            if (!Token.TokenSeguridad()) return;

            // Sin cliente en sesión no hay suscripción que exigir.
            if (Session.ClienteId() == 0) return;

            string pagina = Token.PaginaActual();
            if (string.IsNullOrEmpty(pagina) || EXENTAS.Contains(pagina)) return;

            SuscripcionEstadoCliente estado = Estado();

            // Sin estado resoluble o sin suscripción, se deja pasar: ver el
            // comentario de GetEstadoCliente. Bloquear ante la duda castiga
            // al cliente que está al día.
            if (estado == null || estado.SinSuscripcion || estado.puede_operar) return;

            int idUsuario = 0;
            int.TryParse(Session.UsuarioId(), out idUsuario);

            SuscripcionController controller = new SuscripcionController();
            controller.RegistrarBloqueo(
                estado.cliente,
                estado.estado,
                pagina,
                ctx.Request != null ? ctx.Request.UserHostAddress : null,
                idUsuario);

            /* Quien administra la suscripción va a la renovación; puede
               hacer algo al respecto. El resto, no: renovar no es tarea de
               un técnico ni de un supervisor, y dejarlo dando vueltas por
               un sistema donde cada pantalla lo rebota es peor que
               decírselo de una vez.

               A esta rama solo llega quien tiene más de un cliente y eligió
               el que está caído -SEL_LOGIN ya rechaza en la puerta a quien
               no tiene ninguno al día-. Se le cierra la sesión y vuelve al
               login, desde donde puede entrar y elegir otro. */
            if (PuedeRenovar())
            {
                ctx.Response.Redirect("~/Renovar.aspx");
                return;
            }

            ctx.Session.Clear();
            ctx.Session.Abandon();

            ctx.Response.Redirect("~/Login.aspx?motivo=suscripcion");
        }

        /// <summary>
        /// Si esta persona puede abrir la renovación en el cliente que
        /// tiene en sesión.
        ///
        /// No pregunta por el nombre del perfil: pregunta por la pantalla,
        /// igual que cualquier otro permiso del sistema. Que mañana un
        /// cliente quiera que su jefe de mantenimiento también renueve es
        /// un INSERT en Perfil_Permiso, no un cambio aquí.
        /// </summary>
        public static bool PuedeRenovar()
        {
            return Token.PuedePagina("~/renovar.aspx");
        }

        /// <summary>
        /// El aviso del encabezado, ya redactado. Devuelve cadena vacía
        /// cuando no hay nada que avisar.
        ///
        /// El texto se arma aquí y no en el master para que el master no
        /// tenga lógica: solo pinta lo que reciba.
        /// </summary>
        public static string TextoAviso()
        {
            SuscripcionEstadoCliente estado = Estado();

            if (estado == null || estado.SinSuscripcion || !estado.avisar) return "";

            if (estado.estado == "EN GRACIA")
            {
                return "Tu suscripción venció el " +
                       (estado.fecha_fin != null ? estado.fecha_fin.Value.ToString("dd-MM-yyyy") : "") +
                       " y estás en período de gracia. Regulariza el pago para no perder el acceso.";
            }

            int dias = estado.dias_restantes != null ? estado.dias_restantes.Value : 0;

            if (dias <= 0) return "Tu suscripción vence hoy.";
            if (dias == 1) return "Tu suscripción vence mañana.";

            return "Tu suscripción vence en " + dias + " días.";
        }

        /// <summary>
        /// Qué tan urgente es el aviso, para que el encabezado lo pinte
        /// distinto. En gracia ya se está fuera de plazo: no puede verse
        /// igual que un recordatorio a diez días.
        /// </summary>
        public static string NivelAviso()
        {
            SuscripcionEstadoCliente estado = Estado();

            if (estado == null || estado.SinSuscripcion || !estado.avisar) return "";

            return estado.estado == "EN GRACIA" ? "is-alerta" : "is-info";
        }
    }
}
