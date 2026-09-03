using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Programaciones (HU-070 a HU-075, bloques 103-106).
    ///
    /// TODO SE ACOTA POR CLIENTE, SIEMPRE
    ///   @CLIENTE sale de la sesion, nunca de la pantalla, y los SPs de
    ///   detalle lo vuelven a exigir. Un id puesto a mano en la URL no
    ///   alcanza para ver ni tocar la programacion de otra empresa: el SP
    ///   responde "LA PROGRAMACION NO EXISTE PARA ESTE CLIENTE".
    ///
    /// EL DETALLE SE CARGA APARTE Y A PROPOSITO
    ///   GetProgramaciones() trae solo la cabecera, porque el listado no
    ///   necesita mas y traer cinco detalles por fila son cinco consultas
    ///   por fila. GetProgramacion(id) si arma el objeto completo: es una
    ///   sola ficha.
    /// </summary>
    public class ProgramacionController
    {
        #region Cabecera

        public List<Programacion> GetProgramaciones(Programacion filtro = null)
        {
            List<Programacion> lista = new List<Programacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.pro_id > 0)
                            cmd.Parameters.AddWithValue("@ID", filtro.pro_id);

                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);

                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);

                        if (filtro.filtro_vigente != null)
                            cmd.Parameters.AddWithValue("@VIGENTE", filtro.filtro_vigente);

                        if (filtro.filtro_tipo != null)
                            cmd.Parameters.AddWithValue("@TIPO", filtro.filtro_tipo);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Programacion item = new Programacion();

                            item.pro_id = int.Parse(dr["pro_id"].ToString());
                            item.pro_cliente = int.Parse(dr["pro_cliente"].ToString());
                            item.pro_programacion_tipo = int.Parse(dr["pro_programacion_tipo"].ToString());
                            item.pro_nombre = dr["pro_nombre"].ToString();

                            if (dr["pro_zona_horaria"] != DBNull.Value)
                                item.pro_zona_horaria = int.Parse(dr["pro_zona_horaria"].ToString());

                            if (dr["pro_fecha_inicio"] != DBNull.Value)
                                item.pro_fecha_inicio = DateTime.Parse(dr["pro_fecha_inicio"].ToString());

                            if (dr["pro_fecha_fin"] != DBNull.Value)
                                item.pro_fecha_fin = DateTime.Parse(dr["pro_fecha_fin"].ToString());

                            item.pro_tolerancia_antes_minuto = int.Parse(dr["pro_tolerancia_antes_minuto"].ToString());
                            item.pro_tolerancia_despues_minuto = int.Parse(dr["pro_tolerancia_despues_minuto"].ToString());

                            item.pro_permite_anticipada = Convert.ToBoolean(dr["pro_permite_anticipada"]);
                            item.pro_permite_atrasada = Convert.ToBoolean(dr["pro_permite_atrasada"]);
                            item.pro_genera_automaticamente = Convert.ToBoolean(dr["pro_genera_automaticamente"]);
                            item.pro_habilitado = Convert.ToBoolean(dr["pro_habilitado"]);
                            item.vigente = Convert.ToBoolean(dr["VIGENTE"]);

                            if (dr["pro_cumplimiento_politica"] != DBNull.Value)
                                item.pro_cumplimiento_politica = int.Parse(dr["pro_cumplimiento_politica"].ToString());

                            item.pro_usuario_creacion = int.Parse(dr["pro_usuario_creacion"].ToString());

                            if (dr["pro_fecha_creacion"] != DBNull.Value)
                                item.pro_fecha_creacion = DateTime.Parse(dr["pro_fecha_creacion"].ToString());

                            if (dr["pro_usuario_actualizacion"] != DBNull.Value)
                                item.pro_usuario_actualizacion = int.Parse(dr["pro_usuario_actualizacion"].ToString());

                            if (dr["pro_fecha_actualizacion"] != DBNull.Value)
                                item.pro_fecha_actualizacion = DateTime.Parse(dr["pro_fecha_actualizacion"].ToString());

                            item.tipo_codigo = dr["TIPO_CODIGO"].ToString();
                            item.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                            item.zona_horaria_nombre = dr["ZONA_HORARIA_NOMBRE"].ToString();
                            item.cumplimiento_politica_nombre = dr["CUMPLIMIENTO_POLITICA_NOMBRE"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

                            /* Alcance y asignación. Se leen con tolerancia
                               —comprobando que la columna venga— porque este
                               mismo mapeador sirve al listado y a la ficha, y
                               un SP que todavía no las devuelva no tiene por
                               qué reventar la pantalla entera. */
                            item.pro_cliente_instalacion = EnteroNulo(dr, "pro_cliente_instalacion");
                            item.INSTALACION_NOMBRE      = TextoCol(dr, "INSTALACION_NOMBRE");
                            item.pro_instalacion_area    = EnteroNulo(dr, "pro_instalacion_area");
                            item.AREA_NOMBRE             = TextoCol(dr, "AREA_NOMBRE");
                            item.pro_activo              = EnteroNulo(dr, "pro_activo");
                            item.ACTIVO_CODIGO           = TextoCol(dr, "ACTIVO_CODIGO");
                            item.ACTIVO_NOMBRE           = TextoCol(dr, "ACTIVO_NOMBRE");
                            item.RESPONSABLES            = TextoCol(dr, "RESPONSABLES");
                            item.RESPONSABLES_IDS        = TextoCol(dr, "RESPONSABLES_IDS");
                            item.pro_grupo_trabajo       = EnteroNulo(dr, "pro_grupo_trabajo");
                            item.GRUPO_NOMBRE            = TextoCol(dr, "GRUPO_NOMBRE");

                            item.detalle = dr["DETALLE"].ToString();
                            item.exclusiones = int.Parse(dr["EXCLUSIONES"].ToString());
                            item.ocurrencias = int.Parse(dr["OCURRENCIAS"].ToString());

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        /// <summary>
        /// La ficha completa: cabecera mas el detalle de SU tipo, mas las
        /// exclusiones. Devuelve un objeto vacio —no null— cuando no existe
        /// o es de otro cliente, para que la ficha se abra en blanco en vez
        /// de reventar con una referencia nula.
        /// </summary>
        public Programacion GetProgramacion(int id, bool conDetalle = true)
        {
            List<Programacion> lista = GetProgramaciones(new Programacion { pro_id = id });

            if (lista == null || lista.Count == 0) return new Programacion();

            Programacion p = lista[0];

            if (!conDetalle) return p;

            switch (p.tipo_codigo)
            {
                case "FECHA UNICA":      p.fechas = GetFechas(id); break;
                case "CALENDARIO":       p.calendario = GetCalendario(id); break;
                case "INTERVALO TIEMPO": p.intervalo = GetIntervalo(id); break;
                case "MEDIDOR":          p.medidor = GetMedidor(id); break;
                case "CONDICION":        p.condiciones = GetCondiciones(id); break;
            }

            p.lista_exclusiones = GetExclusiones(id);

            return p;
        }

        public Respuesta InsertProgramacion(Programacion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("INS_PROGRAMACION");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@TIPO", entidad.pro_programacion_tipo);
                    cmd.Parameters.AddWithValue("@NOMBRE", (object)entidad.pro_nombre ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@FECHA_INICIO", (object)entidad.pro_fecha_inicio ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@FECHA_FIN", (object)entidad.pro_fecha_fin ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ZONA_HORARIA", (object)entidad.pro_zona_horaria ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@TOLERANCIA_ANTES", entidad.pro_tolerancia_antes_minuto);
                    cmd.Parameters.AddWithValue("@TOLERANCIA_DESPUES", entidad.pro_tolerancia_despues_minuto);
                    cmd.Parameters.AddWithValue("@PERMITE_ANTICIPADA", entidad.pro_permite_anticipada);
                    cmd.Parameters.AddWithValue("@PERMITE_ATRASADA", entidad.pro_permite_atrasada);
                    cmd.Parameters.AddWithValue("@CUMPLIMIENTO_POLITICA", (object)entidad.pro_cumplimiento_politica ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@GENERA_AUTOMATICAMENTE", entidad.pro_genera_automaticamente);

                    cmd.Parameters.AddWithValue("@INSTALACION", (object)entidad.pro_cliente_instalacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@AREA", (object)entidad.pro_instalacion_area ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ACTIVO", (object)entidad.pro_activo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@GRUPO", (object)entidad.pro_grupo_trabajo ?? DBNull.Value);

                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Programación creada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public Respuesta UpdateProgramacion(Programacion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPD_PROGRAMACION");
                    cmd.Parameters.AddWithValue("@ID", entidad.pro_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    /* Los interruptores. En el UPD, NULL no puede significar
                       "no cambiar" para estas cinco: quitarle el alcance a una
                       programación es una edición real, no una omisión. La
                       ficha manda siempre los dos en 1 porque siempre trae el
                       estado completo del formulario. */
                    cmd.Parameters.AddWithValue("@APLICA_ALCANCE", true);
                    cmd.Parameters.AddWithValue("@INSTALACION", (object)entidad.pro_cliente_instalacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@AREA", (object)entidad.pro_instalacion_area ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@ACTIVO", (object)entidad.pro_activo ?? DBNull.Value);

                    cmd.Parameters.AddWithValue("@APLICA_ASIGNACION", true);
                    cmd.Parameters.AddWithValue("@GRUPO", (object)entidad.pro_grupo_trabajo ?? DBNull.Value);

                    cmd.Parameters.AddWithValue("@NOMBRE", (object)entidad.pro_nombre ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@FECHA_INICIO", (object)entidad.pro_fecha_inicio ?? DBNull.Value);

                    /* La fecha de termino se BORRA cuando el usuario la deja
                       en blanco. Mandar NULL significaria "no la toques" por
                       el ISNULL(@X, columna) del SP, asi que hace falta la
                       bandera: sin ella una programacion no se puede volver
                       indefinida despues de haber tenido termino. */
                    if (entidad.pro_fecha_fin == null)
                        cmd.Parameters.AddWithValue("@LIMPIA_FECHA_FIN", true);
                    else
                        cmd.Parameters.AddWithValue("@FECHA_FIN", entidad.pro_fecha_fin);

                    cmd.Parameters.AddWithValue("@ZONA_HORARIA", (object)entidad.pro_zona_horaria ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@TOLERANCIA_ANTES", entidad.pro_tolerancia_antes_minuto);
                    cmd.Parameters.AddWithValue("@TOLERANCIA_DESPUES", entidad.pro_tolerancia_despues_minuto);
                    cmd.Parameters.AddWithValue("@PERMITE_ANTICIPADA", entidad.pro_permite_anticipada);
                    cmd.Parameters.AddWithValue("@PERMITE_ATRASADA", entidad.pro_permite_atrasada);
                    cmd.Parameters.AddWithValue("@CUMPLIMIENTO_POLITICA", (object)entidad.pro_cumplimiento_politica ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@GENERA_AUTOMATICAMENTE", entidad.pro_genera_automaticamente);
                    cmd.Parameters.AddWithValue("@HABILITADO", entidad.pro_habilitado);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = entidad.pro_id;
                    respuesta.detalle = "Programación actualizada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// Baja logica. El SP rechaza si hay hitos de planes usandola, y
        /// conserva las ocurrencias ya generadas (HU-076 #4).
        /// </summary>
        public Respuesta DeleteProgramacion(int id)
        {
            return Ejecutar("DEL_PROGRAMACION", id, "Programación eliminada con éxito.");
        }

        /// <summary>
        /// Crea una copia editable de la programación completa: cabecera,
        /// regla, responsables y exclusiones. La copia nace habilitada y con
        /// "(copia)" en el nombre para que nunca se confunda con el original.
        ///
        /// Los procedimientos de cada detalle conservan sus propias barreras
        /// por cliente. Si uno falla, la cabecera recién creada se da de baja
        /// para no dejar una programación incompleta generando trabajo.
        /// </summary>
        public Respuesta DuplicarProgramacion(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = "No fue posible validar la sesión.";
                return respuesta;
            }

            Programacion origen = GetProgramacion(id);

            if (origen == null || origen.pro_id == 0)
            {
                respuesta.error = true;
                respuesta.codigo = -1;
                respuesta.detalle = "La programación no existe para este cliente.";
                return respuesta;
            }

            string baseNombre = (origen.pro_nombre ?? "Programación").Trim();
            if (baseNombre.Length > 192) baseNombre = baseNombre.Substring(0, 192).TrimEnd();

            origen.pro_nombre = baseNombre + " (copia)";

            Respuesta cabecera = InsertProgramacion(origen);
            if (cabecera.error) return cabecera;

            int nuevoId = cabecera.codigo;

            try
            {
                if (origen.pro_grupo_trabajo == null && !string.IsNullOrEmpty(origen.RESPONSABLES_IDS))
                    VerificarCopia(GuardarResponsables(nuevoId, origen.RESPONSABLES_IDS), "los responsables");

                switch (origen.tipo_codigo)
                {
                    case "CALENDARIO":
                        if (origen.calendario != null)
                        {
                            origen.calendario.pca_programacion = nuevoId;
                            VerificarCopia(SaveCalendario(origen.calendario), "la regla de calendario");
                        }
                        break;

                    case "INTERVALO TIEMPO":
                        if (origen.intervalo != null)
                        {
                            origen.intervalo.pin_programacion = nuevoId;
                            VerificarCopia(SaveIntervalo(origen.intervalo), "la regla de intervalo");
                        }
                        break;

                    case "MEDIDOR":
                        if (origen.medidor != null)
                        {
                            origen.medidor.pme_programacion = nuevoId;
                            VerificarCopia(SaveMedidor(origen.medidor), "la regla de medidor");
                        }
                        break;

                    case "FECHA UNICA":
                        if (origen.fechas != null)
                            foreach (ProgramacionFecha fecha in origen.fechas)
                            {
                                ProgramacionFecha copia = new ProgramacionFecha();
                                copia.pfe_programacion = nuevoId;
                                copia.pfe_fecha = fecha.pfe_fecha;
                                copia.pfe_hora = fecha.pfe_hora;
                                copia.pfe_incluida = fecha.pfe_incluida;
                                VerificarCopia(InsertFecha(copia), "las fechas programadas");
                            }
                        break;

                    case "CONDICION":
                        if (origen.condiciones != null)
                            foreach (ProgramacionCondicion condicion in origen.condiciones)
                            {
                                ProgramacionCondicion copia = new ProgramacionCondicion();
                                copia.pco_programacion = nuevoId;
                                copia.pco_activo_variable = condicion.pco_activo_variable;
                                copia.pco_operador_comparacion = condicion.pco_operador_comparacion;
                                copia.pco_umbral = condicion.pco_umbral;
                                copia.pco_umbral_hasta = condicion.pco_umbral_hasta;
                                copia.pco_duracion_minima_minuto = condicion.pco_duracion_minima_minuto;
                                copia.pco_severidad = condicion.pco_severidad;
                                VerificarCopia(InsertCondicion(copia), "las condiciones");
                            }
                        break;
                }

                if (origen.lista_exclusiones != null)
                    foreach (ProgramacionExclusion exclusion in origen.lista_exclusiones)
                    {
                        ProgramacionExclusion copia = new ProgramacionExclusion();
                        copia.pxc_programacion = nuevoId;
                        copia.pxc_fecha_inicio_utc = exclusion.pxc_fecha_inicio_utc;
                        copia.pxc_fecha_fin_utc = exclusion.pxc_fecha_fin_utc;
                        copia.pxc_motivo = exclusion.pxc_motivo;
                        copia.pxc_desplaza = exclusion.pxc_desplaza;
                        VerificarCopia(InsertExclusion(copia), "las exclusiones");
                    }

                respuesta.codigo = nuevoId;
                respuesta.error = false;
                respuesta.detalle = "Programación duplicada con éxito.";
            }
            catch (Exception ex)
            {
                Respuesta baja = DeleteProgramacion(nuevoId);
                respuesta.codigo = -1;
                respuesta.error = true;
                respuesta.detalle = "No fue posible completar la copia: " + ex.Message;

                if (baja.error)
                    respuesta.detalle += " La copia incompleta quedó registrada; deshabilítela antes de usarla.";
            }

            return respuesta;
        }

        private static void VerificarCopia(Respuesta respuesta, string parte)
        {
            if (respuesta == null || respuesta.error)
                throw new Exception("No se pudieron copiar " + parte + ". " +
                                    (respuesta == null ? "" : respuesta.detalle));
        }

        #endregion

        #region Detalle por tipo

        public ProgramacionCalendario GetCalendario(int programacion)
        {
            ProgramacionCalendario item = null;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_CALENDARIO";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            item = new ProgramacionCalendario();
                            item.pca_id = int.Parse(dr["pca_id"].ToString());
                            item.pca_programacion = int.Parse(dr["pca_programacion"].ToString());
                            item.pca_frecuencia_tipo = int.Parse(dr["pca_frecuencia_tipo"].ToString());
                            item.pca_intervalo = int.Parse(dr["pca_intervalo"].ToString());

                            if (dr["pca_semana_ordinal"] != DBNull.Value)
                                item.pca_semana_ordinal = int.Parse(dr["pca_semana_ordinal"].ToString());

                            if (dr["pca_dia_mes"] != DBNull.Value)
                                item.pca_dia_mes = int.Parse(dr["pca_dia_mes"].ToString());

                            if (dr["pca_mes"] != DBNull.Value)
                                item.pca_mes = int.Parse(dr["pca_mes"].ToString());

                            if (dr["pca_hora_local"] != DBNull.Value)
                                item.pca_hora_local = TimeSpan.Parse(dr["pca_hora_local"].ToString());

                            item.pca_habilitado = Convert.ToBoolean(dr["pca_habilitado"]);
                            item.frecuencia_codigo = dr["FRECUENCIA_CODIGO"].ToString();
                            item.frecuencia_nombre = dr["FRECUENCIA_NOMBRE"].ToString();
                            item.dias = dr["DIAS"].ToString();
                            item.dias_nombre = dr["DIAS_NOMBRE"].ToString();
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                }
            }

            return item;
        }

        public Respuesta SaveCalendario(ProgramacionCalendario entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPS_PROGRAMACION_CALENDARIO");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@PROGRAMACION", entidad.pca_programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@FRECUENCIA", entidad.pca_frecuencia_tipo);
                    cmd.Parameters.AddWithValue("@INTERVALO", entidad.pca_intervalo);
                    cmd.Parameters.AddWithValue("@SEMANA_ORDINAL", (object)entidad.pca_semana_ordinal ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DIA_MES", (object)entidad.pca_dia_mes ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@MES", (object)entidad.pca_mes ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@HORA_LOCAL", (object)entidad.pca_hora_local ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DIAS", (object)entidad.dias ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Regla de calendario guardada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public ProgramacionIntervalo GetIntervalo(int programacion)
        {
            ProgramacionIntervalo item = null;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_INTERVALO";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            item = new ProgramacionIntervalo();
                            item.pin_id = int.Parse(dr["pin_id"].ToString());
                            item.pin_programacion = int.Parse(dr["pin_programacion"].ToString());
                            item.pin_unidad_tiempo = int.Parse(dr["pin_unidad_tiempo"].ToString());
                            item.pin_cantidad = int.Parse(dr["pin_cantidad"].ToString());

                            if (dr["pin_fecha_ancla_utc"] != DBNull.Value)
                                item.pin_fecha_ancla_utc = DateTime.Parse(dr["pin_fecha_ancla_utc"].ToString());

                            item.pin_desde_ejecucion = Convert.ToBoolean(dr["pin_desde_ejecucion"]);
                            item.pin_habilitado = Convert.ToBoolean(dr["pin_habilitado"]);
                            item.unidad_codigo = dr["UNIDAD_CODIGO"].ToString();
                            item.unidad_nombre = dr["UNIDAD_NOMBRE"].ToString();
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                }
            }

            return item;
        }

        public Respuesta SaveIntervalo(ProgramacionIntervalo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPS_PROGRAMACION_INTERVALO");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@PROGRAMACION", entidad.pin_programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@UNIDAD_TIEMPO", entidad.pin_unidad_tiempo);
                    cmd.Parameters.AddWithValue("@CANTIDAD", entidad.pin_cantidad);
                    cmd.Parameters.AddWithValue("@FECHA_ANCLA_UTC", (object)entidad.pin_fecha_ancla_utc ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESDE_EJECUCION", entidad.pin_desde_ejecucion);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Regla de intervalo guardada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public ProgramacionMedidor GetMedidor(int programacion)
        {
            ProgramacionMedidor item = null;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_MEDIDOR";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            item = new ProgramacionMedidor();
                            item.pme_id = int.Parse(dr["pme_id"].ToString());
                            item.pme_programacion = int.Parse(dr["pme_programacion"].ToString());
                            item.pme_activo_medidor = int.Parse(dr["pme_activo_medidor"].ToString());
                            item.pme_valor_inicial = decimal.Parse(dr["pme_valor_inicial"].ToString());
                            item.pme_cada_cantidad = decimal.Parse(dr["pme_cada_cantidad"].ToString());

                            if (dr["pme_aviso_anticipacion"] != DBNull.Value)
                                item.pme_aviso_anticipacion = decimal.Parse(dr["pme_aviso_anticipacion"].ToString());

                            item.pme_habilitado = Convert.ToBoolean(dr["pme_habilitado"]);
                            item.medidor_codigo = dr["MEDIDOR_CODIGO"].ToString();
                            item.medidor_nombre = dr["MEDIDOR_NOMBRE"].ToString();
                            item.medidor_valor_actual = decimal.Parse(dr["MEDIDOR_VALOR_ACTUAL"].ToString());
                            item.ame_activo = int.Parse(dr["ame_activo"].ToString());
                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();

                            if (dr["PROXIMO_VALOR"] != DBNull.Value)
                                item.proximo_valor = decimal.Parse(dr["PROXIMO_VALOR"].ToString());
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                }
            }

            return item;
        }

        public Respuesta SaveMedidor(ProgramacionMedidor entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPS_PROGRAMACION_MEDIDOR");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@PROGRAMACION", entidad.pme_programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ACTIVO_MEDIDOR", entidad.pme_activo_medidor);
                    cmd.Parameters.AddWithValue("@VALOR_INICIAL", entidad.pme_valor_inicial);
                    cmd.Parameters.AddWithValue("@CADA_CANTIDAD", entidad.pme_cada_cantidad);
                    cmd.Parameters.AddWithValue("@AVISO_ANTICIPACION", (object)entidad.pme_aviso_anticipacion ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Regla de medidor guardada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public List<ProgramacionFecha> GetFechas(int programacion)
        {
            List<ProgramacionFecha> lista = new List<ProgramacionFecha>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_FECHA";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ProgramacionFecha item = new ProgramacionFecha();
                            item.pfe_id = int.Parse(dr["pfe_id"].ToString());
                            item.pfe_programacion = int.Parse(dr["pfe_programacion"].ToString());
                            item.pfe_fecha = DateTime.Parse(dr["pfe_fecha"].ToString());

                            if (dr["pfe_hora"] != DBNull.Value)
                                item.pfe_hora = TimeSpan.Parse(dr["pfe_hora"].ToString());

                            item.pfe_incluida = Convert.ToBoolean(dr["pfe_incluida"]);
                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public Respuesta InsertFecha(ProgramacionFecha entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("INS_PROGRAMACION_FECHA");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@PROGRAMACION", entidad.pfe_programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@FECHA", entidad.pfe_fecha);
                    cmd.Parameters.AddWithValue("@HORA", (object)entidad.pfe_hora ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@INCLUIDA", entidad.pfe_incluida);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Fecha agregada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// Corrige una fecha existente.
        ///
        /// No es un borrar + insertar: eso cambiaría el pfe_id, y el pfe_id
        /// es lo que cuelga la ocurrencia. Corregir el día se convertiría en
        /// borrar el trabajo de un día y crear otro distinto.
        /// </summary>
        public Respuesta UpdateFecha(ProgramacionFecha entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("UPD_PROGRAMACION_FECHA");
                    cmd.Parameters.AddWithValue("@ID", entidad.pfe_id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@FECHA", entidad.pfe_fecha);
                    cmd.Parameters.AddWithValue("@HORA", (object)entidad.pfe_hora ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@INCLUIDA", entidad.pfe_incluida);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = entidad.pfe_id;
                    respuesta.detalle = "Fecha actualizada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public Respuesta DeleteFecha(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("DEL_PROGRAMACION_FECHA");
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = "Fecha eliminada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public List<ProgramacionCondicion> GetCondiciones(int programacion)
        {
            List<ProgramacionCondicion> lista = new List<ProgramacionCondicion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_CONDICION";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ProgramacionCondicion item = new ProgramacionCondicion();
                            item.pco_id = int.Parse(dr["pco_id"].ToString());
                            item.pco_programacion = int.Parse(dr["pco_programacion"].ToString());
                            item.pco_activo_variable = int.Parse(dr["pco_activo_variable"].ToString());
                            item.pco_operador_comparacion = int.Parse(dr["pco_operador_comparacion"].ToString());
                            item.pco_umbral = decimal.Parse(dr["pco_umbral"].ToString());

                            if (dr["pco_umbral_hasta"] != DBNull.Value)
                                item.pco_umbral_hasta = decimal.Parse(dr["pco_umbral_hasta"].ToString());

                            if (dr["pco_duracion_minima_minuto"] != DBNull.Value)
                                item.pco_duracion_minima_minuto = int.Parse(dr["pco_duracion_minima_minuto"].ToString());

                            item.pco_severidad = int.Parse(dr["pco_severidad"].ToString());
                            item.pco_habilitado = Convert.ToBoolean(dr["pco_habilitado"]);

                            if (dr["ava_activo"] != DBNull.Value)
                                item.ava_activo = int.Parse(dr["ava_activo"].ToString());

                            item.activo_nombre = dr["ACTIVO_NOMBRE"].ToString();
                            item.variable_nombre = dr["VARIABLE_NOMBRE"].ToString();
                            item.operador_codigo = dr["OPERADOR_CODIGO"].ToString();
                            item.operador_nombre = dr["OPERADOR_NOMBRE"].ToString();
                            item.severidad_nombre = dr["SEVERIDAD_NOMBRE"].ToString();
                            item.regla = dr["REGLA"].ToString();

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public Respuesta InsertCondicion(ProgramacionCondicion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("INS_PROGRAMACION_CONDICION");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@PROGRAMACION", entidad.pco_programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@ACTIVO_VARIABLE", entidad.pco_activo_variable);
                    cmd.Parameters.AddWithValue("@OPERADOR", entidad.pco_operador_comparacion);
                    cmd.Parameters.AddWithValue("@UMBRAL", entidad.pco_umbral);
                    cmd.Parameters.AddWithValue("@UMBRAL_HASTA", (object)entidad.pco_umbral_hasta ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DURACION_MINIMA", (object)entidad.pco_duracion_minima_minuto ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@SEVERIDAD", entidad.pco_severidad);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Condición creada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public Respuesta DeleteCondicion(int id)
        {
            return Ejecutar("DEL_PROGRAMACION_CONDICION", id, "Condición eliminada con éxito.");
        }

        #endregion

        #region Exclusiones

        public List<ProgramacionExclusion> GetExclusiones(int programacion)
        {
            List<ProgramacionExclusion> lista = new List<ProgramacionExclusion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_EXCLUSION";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@HABILITADO", true);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ProgramacionExclusion item = new ProgramacionExclusion();
                            item.pxc_id = int.Parse(dr["pxc_id"].ToString());
                            item.pxc_programacion = int.Parse(dr["pxc_programacion"].ToString());
                            item.pxc_fecha_inicio_utc = DateTime.Parse(dr["pxc_fecha_inicio_utc"].ToString());
                            item.pxc_fecha_fin_utc = DateTime.Parse(dr["pxc_fecha_fin_utc"].ToString());
                            item.pxc_motivo = dr["pxc_motivo"].ToString();
                            item.pxc_desplaza = Convert.ToBoolean(dr["pxc_desplaza"]);
                            item.pxc_habilitado = Convert.ToBoolean(dr["pxc_habilitado"]);
                            item.pxc_usuario_creacion = int.Parse(dr["pxc_usuario_creacion"].ToString());

                            if (dr["pxc_fecha_creacion"] != DBNull.Value)
                                item.pxc_fecha_creacion = DateTime.Parse(dr["pxc_fecha_creacion"].ToString());

                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.dias = int.Parse(dr["DIAS"].ToString());
                            item.efecto = dr["EFECTO"].ToString();

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public Respuesta InsertExclusion(ProgramacionExclusion entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand("INS_PROGRAMACION_EXCLUSION");
                    cmd.Parameters.AddWithValue("@ID", 0).Direction = System.Data.ParameterDirection.Output;
                    cmd.Parameters.AddWithValue("@PROGRAMACION", entidad.pxc_programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@FECHA_INICIO", entidad.pxc_fecha_inicio_utc);
                    cmd.Parameters.AddWithValue("@FECHA_FIN", entidad.pxc_fecha_fin_utc);
                    cmd.Parameters.AddWithValue("@MOTIVO", (object)entidad.pxc_motivo ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@DESPLAZA", entidad.pxc_desplaza);
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = (int)cmd.Parameters["@ID"].Value;
                    respuesta.detalle = "Exclusión creada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public Respuesta DeleteExclusion(int id)
        {
            return Ejecutar("DEL_PROGRAMACION_EXCLUSION", id, "Exclusión eliminada con éxito.");
        }

        #endregion

        #region Proyeccion

        /// <summary>
        /// Las fechas que la regla produciria. No crea nada: es el calculo
        /// que la ficha muestra como "próximas fechas" y que el generador de
        /// HU-076 va a reutilizar cuando exista el plan del Sprint 4.
        /// </summary>
        public List<ProgramacionProyeccion> GetProyeccion(int programacion, int top = 12)
        {
            List<ProgramacionProyeccion> lista = new List<ProgramacionProyeccion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_PROYECCION";
                    cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@TOP", top);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ProgramacionProyeccion item = new ProgramacionProyeccion();
                            item.fecha = DateTime.Parse(dr["FECHA"].ToString());

                            if (dr["FECHA_ORIGINAL"] != DBNull.Value)
                                item.fecha_original = DateTime.Parse(dr["FECHA_ORIGINAL"].ToString());

                            item.desplazada = Convert.ToBoolean(dr["DESPLAZADA"]);
                            item.motivo = dr["MOTIVO"].ToString();
                            item.es_pasada = Convert.ToBoolean(dr["ES_PASADA"]);
                            item.descartada = dr["DESCARTADA"] != DBNull.Value && Convert.ToBoolean(dr["DESCARTADA"]);
                            item.tipo_codigo = dr["TIPO_CODIGO"].ToString();

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        #endregion

        #region Catalogos

        /// <summary>
        /// Los ocho combos de la ficha. Nombres validos: PROGRAMACION_TIPO,
        /// FRECUENCIA_TIPO, UNIDAD_TIEMPO, DIA_SEMANA, ZONA_HORARIA,
        /// CUMPLIMIENTO_POLITICA, OPERADOR_COMPARACION, SEVERIDAD.
        ///
        /// El SP los resuelve contra una lista blanca: el nombre no se
        /// concatena en ningun EXEC.
        /// </summary>
        public List<CatalogoItem> GetCatalogo(string catalogo)
        {
            List<CatalogoItem> lista = new List<CatalogoItem>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_PROGRAMACION_CATALOGO";
                    cmd.Parameters.AddWithValue("@CATALOGO", catalogo);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            CatalogoItem item = new CatalogoItem();
                            item.id = int.Parse(dr["ID"].ToString());
                            item.codigo = dr["CODIGO"].ToString();
                            item.nombre = dr["NOMBRE"].ToString();
                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        #endregion

        /// <summary>
        /// Los DEL_ de este modulo tienen la misma firma —@ID, @CLIENTE,
        /// @USUARIO— asi que comparten cuerpo en vez de repetirlo cuatro
        /// veces con un nombre de SP distinto.
        /// </summary>
        private Respuesta Ejecutar(string sp, int id, string mensaje)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = null;

                try
                {
                    cmd = Conexion.GetCommand(sp);
                    cmd.Parameters.AddWithValue("@ID", id);
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmd.ExecuteNonQuery();
                    cmd.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = mensaje;
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }
    
        /// <summary>
        /// Reemplaza la lista completa de personas responsables.
        ///
        /// Se manda el estado final y no un "agregar uno / quitar uno": el
        /// diferencial obligaría a que la pantalla supiera qué había antes,
        /// que son más viajes y más formas de quedar desincronizado.
        ///
        /// El SP filtra a las personas que no son de este cliente y rechaza
        /// la operación si la programación ya tiene un grupo: personas O
        /// cuadrilla, nunca las dos.
        /// </summary>
        public Respuesta GuardarResponsables(int programacion, string idsSeparadosPorComa)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad())
            {
                respuesta.error = true;
                respuesta.detalle = "Sesión no válida.";
                return respuesta;
            }

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("UPS_PROGRAMACION_RESPONSABLE");
                cmd.Parameters.AddWithValue("@PROGRAMACION", programacion);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@USUARIOS", (object)(idsSeparadosPorComa ?? "") ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                respuesta.codigo = programacion;
                respuesta.detalle = "Responsables actualizados.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        #region Alcance

        /// <summary>Existe la columna en este resultado.</summary>
        private static bool Hay(SqlDataReader dr, string columna)
        {
            for (int i = 0; i < dr.FieldCount; i++)
                if (string.Equals(dr.GetName(i), columna, StringComparison.OrdinalIgnoreCase))
                    return true;

            return false;
        }

        private static int? EnteroNulo(SqlDataReader dr, string columna)
        {
            if (!Hay(dr, columna) || dr[columna] == DBNull.Value) return null;

            int v;
            return int.TryParse(dr[columna].ToString(), out v) ? (int?)v : null;
        }

        private static string TextoCol(SqlDataReader dr, string columna)
        {
            if (!Hay(dr, columna) || dr[columna] == DBNull.Value) return "";
            return dr[columna].ToString();
        }

        /// <summary>
        /// Instalaciones, áreas, activos, usuarios y perfiles del cliente.
        ///
        /// Va contra un SP distinto del catálogo general a propósito: estos
        /// cinco son POR CLIENTE, y mezclarlos con los que no lo son es cómo
        /// se termina mostrándole a una empresa las instalaciones de otra.
        ///
        /// <paramref name="padre"/> encadena: las áreas de una instalación,
        /// los activos de esa misma instalación.
        /// </summary>
        public List<CatalogoItem> GetCatalogoAlcance(string catalogo, int? padre = null)
        {
            List<CatalogoItem> lista = new List<CatalogoItem>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_PROGRAMACION_CATALOGO_ALCANCE");
                cmd.Parameters.AddWithValue("@CATALOGO", catalogo);
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@PADRE", padre == null ? (object)DBNull.Value : padre.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        CatalogoItem c = new CatalogoItem();
                        c.id = int.Parse(dr["ID"].ToString());
                        c.codigo = dr["CODIGO"].ToString();
                        c.nombre = dr["NOMBRE"].ToString();
                        lista.Add(c);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            return lista;
        }


        /// <summary>
        /// Las cuadrillas del cliente.
        ///
        /// SP propio y no una rama del catálogo de alcance porque los grupos
        /// se filtran además por instalación: ofrecerle a alguien la cuadrilla
        /// de otra planta es ofrecerle gente que no puede ir.
        /// </summary>
        public List<CatalogoItem> GetGrupos(int? instalacion = null)
        {
            List<CatalogoItem> lista = new List<CatalogoItem>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = null;

            try
            {
                cmd = Conexion.GetCommand("SEL_PROGRAMACION_CATALOGO_GRUPO");
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@PADRE",
                    instalacion == null ? (object)DBNull.Value : instalacion.Value);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        CatalogoItem c = new CatalogoItem();
                        c.id = int.Parse(dr["ID"].ToString());
                        c.codigo = dr["CODIGO"].ToString();
                        c.nombre = dr["NOMBRE"].ToString();
                        lista.Add(c);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
            }

            return lista;
        }

        #endregion
}
}
