using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SitioBase.Controller
{
    /// <summary>
    /// Compatibilidad de repuestos (HU-051, bloque 92).
    ///
    /// EL AISLAMIENTO VA POR EL REPUESTO
    ///   Repuesto_Compatibilidad no tiene columna de cliente: la pertenencia
    ///   sale de rco_repuesto -> Repuesto.rep_cliente. Todos los SP hacen ese
    ///   JOIN y reciben @CLIENTE desde la sesion, nunca desde la pantalla.
    ///
    ///   Por eso GetCompatibilidad(id) no confia en el id: llama al mismo
    ///   SEL_ con el cliente de la sesion. Un SP aparte "por id" seria el
    ///   sitio donde algun dia se olvida el filtro.
    /// </summary>
    public class RepuestoCompatibilidadController
    {
        public List<RepuestoCompatibilidad> GetCompatibilidades(RepuestoCompatibilidad filtro = null)
        {
            List<RepuestoCompatibilidad> lista = new List<RepuestoCompatibilidad>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_REPUESTO_COMPATIBILIDAD";
                    cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                    if (filtro != null)
                    {
                        if (filtro.rco_id > 0)
                            cmd.Parameters.AddWithValue("@ID", filtro.rco_id);

                        if (filtro.filtro_repuesto > 0)
                            cmd.Parameters.AddWithValue("@REPUESTO", filtro.filtro_repuesto);

                        if (filtro.filtro_tipo > 0)
                            cmd.Parameters.AddWithValue("@TIPO", filtro.filtro_tipo);

                        if (filtro.filtro_modelo > 0)
                            cmd.Parameters.AddWithValue("@MODELO", filtro.filtro_modelo);

                        if (filtro.filtro_componente > 0)
                            cmd.Parameters.AddWithValue("@COMPONENTE", filtro.filtro_componente);

                        if (!string.IsNullOrEmpty(filtro.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            RepuestoCompatibilidad item = new RepuestoCompatibilidad();

                            item.rco_id = int.Parse(dr["rco_id"].ToString());
                            item.rco_repuesto = int.Parse(dr["rco_repuesto"].ToString());

                            if (dr["rco_activo_tipo"] != DBNull.Value)
                                item.rco_activo_tipo = int.Parse(dr["rco_activo_tipo"].ToString());

                            if (dr["rco_activo_modelo"] != DBNull.Value)
                                item.rco_activo_modelo = int.Parse(dr["rco_activo_modelo"].ToString());

                            if (dr["rco_activo_componente"] != DBNull.Value)
                                item.rco_activo_componente = int.Parse(dr["rco_activo_componente"].ToString());

                            item.rco_observacion = dr["rco_observacion"].ToString();
                            item.rco_usuario_creacion = int.Parse(dr["rco_usuario_creacion"].ToString());

                            if (dr["rco_fecha_creacion"] != DBNull.Value)
                                item.rco_fecha_creacion = DateTime.Parse(dr["rco_fecha_creacion"].ToString());

                            if (dr["rco_usuario_actualizacion"] != DBNull.Value)
                                item.rco_usuario_actualizacion = int.Parse(dr["rco_usuario_actualizacion"].ToString());

                            if (dr["rco_fecha_actualizacion"] != DBNull.Value)
                                item.rco_fecha_actualizacion = DateTime.Parse(dr["rco_fecha_actualizacion"].ToString());

                            item.repuesto_codigo = dr["REPUESTO_CODIGO"].ToString();
                            item.repuesto_nombre = dr["REPUESTO_NOMBRE"].ToString();
                            item.unidad = dr["UNIDAD"].ToString();
                            item.alcance = dr["ALCANCE"].ToString();
                            item.alcance_nombre = dr["ALCANCE_NOMBRE"].ToString();
                            item.usuario_creacion_nombre = dr["USUARIO_CREACION_NOMBRE"].ToString();
                            item.usuario_actualizacion_nombre = dr["USUARIO_ACTUALIZACION_NOMBRE"].ToString();

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
        /// Una sola. Devuelve un objeto vacio —no null— cuando no existe o no
        /// es de este cliente, para que la ficha se abra en blanco en vez de
        /// reventar con una referencia nula.
        /// </summary>
        public RepuestoCompatibilidad GetCompatibilidad(int id)
        {
            List<RepuestoCompatibilidad> lista =
                GetCompatibilidades(new RepuestoCompatibilidad { rco_id = id });

            if (lista == null || lista.Count == 0) return new RepuestoCompatibilidad();

            return lista[0];
        }

        public Respuesta InsertCompatibilidad(RepuestoCompatibilidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_REPUESTO_COMPATIBILIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@REPUESTO", entidad.rco_repuesto);
                    cmdExecute.Parameters.AddWithValue("@TIPO", Id(entidad.rco_activo_tipo));
                    cmdExecute.Parameters.AddWithValue("@MODELO", Id(entidad.rco_activo_modelo));
                    cmdExecute.Parameters.AddWithValue("@COMPONENTE", Id(entidad.rco_activo_componente));
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION", Texto(entidad.rco_observacion));
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Compatibilidad guardada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public Respuesta UpdateCompatibilidad(RepuestoCompatibilidad entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_REPUESTO_COMPATIBILIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.rco_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@TIPO", Id(entidad.rco_activo_tipo));
                    cmdExecute.Parameters.AddWithValue("@MODELO", Id(entidad.rco_activo_modelo));
                    cmdExecute.Parameters.AddWithValue("@COMPONENTE", Id(entidad.rco_activo_componente));

                    /* Cadena vacia y no NULL: en el UPD_ la observacion va con
                       ISNULL(@X, columna), asi que un NULL significa "no me
                       toques esto". Mandando NULL al borrarla, la observacion
                       vieja se quedaria puesta y la pantalla diria que se
                       guardo. */
                    cmdExecute.Parameters.AddWithValue("@OBSERVACION",
                        entidad.rco_observacion == null ? (object)"" : entidad.rco_observacion.Trim());

                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.rco_id;
                    respuesta.detalle = "Compatibilidad actualizada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// Borrado FISICO, a proposito. Una compatibilidad es una afirmacion
        /// de hecho: si esta mal, esta mal. Nada en la base depende de esta
        /// fila, y guardarla "deshabilitada" es dejar puesto justo el dato que
        /// la historia quiere evitar.
        /// </summary>
        public Respuesta DeleteCompatibilidad(int id)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_REPUESTO_COMPATIBILIDAD");
                    cmdExecute.Parameters.AddWithValue("@ID", id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = id;
                    respuesta.detalle = "Compatibilidad eliminada con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        private object Id(int? valor)
        {
            return (valor == null || valor.Value <= 0) ? (object)DBNull.Value : valor.Value;
        }

        private object Texto(string valor)
        {
            if (string.IsNullOrEmpty(valor) || valor.Trim().Length == 0) return DBNull.Value;
            return valor.Trim();
        }
    }
}
