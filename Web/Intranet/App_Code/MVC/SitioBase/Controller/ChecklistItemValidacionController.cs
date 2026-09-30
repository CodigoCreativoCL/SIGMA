﻿using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// CONTROLLER de Checklist_Item_Validacion (HU-091): umbrales y acciones de
    /// un ítem. Toda operación pasa por Token.TokenSeguridad y por SP; el cliente
    /// va desde la sesión. SP: SEL/INS/UPD/DEL_CHECKLIST_ITEM_VALIDACION y
    /// SEL_CHECKLIST_ITEM_LISTA para el combo de ítems de la ficha.
    /// </summary>
    public class ChecklistItemValidacionController
    {
        #region LECTURA

        public List<ChecklistItemValidacion> GetValidaciones(ChecklistItemValidacion filtro = null)
        {
            List<ChecklistItemValidacion> lista = new List<ChecklistItemValidacion>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM_VALIDACION";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                if (filtro != null)
                {
                    if (filtro.filtro_plantilla.HasValue && filtro.filtro_plantilla.Value > 0)
                        cmd.Parameters.AddWithValue("@PLANTILLA", filtro.filtro_plantilla.Value);
                    if (!string.IsNullOrEmpty(filtro.filtro))
                        cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                }

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    while (dr.Read()) lista.Add(Map(dr));

                cmd.Connection.Close(); cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
                lista = null;
            }
            return lista;
        }

        public ChecklistItemValidacion GetValidacion(int id)
        {
            ChecklistItemValidacion item = null;

            if (!Token.TokenSeguridad()) return null;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM_VALIDACION";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ID", id);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    if (dr.Read()) item = Map(dr);

                cmd.Connection.Close(); cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return item;
        }

        /// <summary>Ítems del cliente para el combo de la ficha (con su pauta y si ya tienen validación).</summary>
        public List<ChecklistItemValidacion> GetItems()
        {
            List<ChecklistItemValidacion> lista = new List<ChecklistItemValidacion>();

            if (!Token.TokenSeguridad()) return lista;

            SqlCommand cmd = new SqlCommand();
            try
            {
                cmd.CommandText = "SEL_CHECKLIST_ITEM_LISTA";
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    while (dr.Read())
                    {
                        ChecklistItemValidacion x = new ChecklistItemValidacion();
                        x.item_id = int.Parse(dr["ITEM_ID"].ToString());
                        x.item_codigo = dr["ITEM_CODIGO"].ToString();
                        x.item_texto = dr["ITEM_TEXTO"].ToString();
                        x.tipo_codigo = dr["TIPO_CODIGO"].ToString();
                        x.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
                        x.plantilla_nombre = dr["PLANTILLA_NOMBRE"].ToString();
                        x.seccion_nombre = dr["SECCION_NOMBRE"].ToString();
                        x.tiene_validacion = dr["TIENE_VALIDACION"].ToString() == "1";
                        lista.Add(x);
                    }

                cmd.Connection.Close(); cmd.Dispose();
            }
            catch (Exception)
            {
                if (cmd.Connection != null) cmd.Connection.Close();
                cmd.Dispose();
            }
            return lista;
        }

        private static ChecklistItemValidacion Map(SqlDataReader dr)
        {
            ChecklistItemValidacion v = new ChecklistItemValidacion();
            v.civ_id = int.Parse(dr["CIV_ID"].ToString());
            v.item_id = int.Parse(dr["ITEM_ID"].ToString());
            v.item_codigo = dr["ITEM_CODIGO"].ToString();
            v.item_texto = dr["ITEM_TEXTO"].ToString();
            v.tipo_codigo = dr["TIPO_CODIGO"].ToString();
            v.tipo_nombre = dr["TIPO_NOMBRE"].ToString();
            v.seccion_nombre = dr["SECCION_NOMBRE"].ToString();
            v.plantilla_id = int.Parse(dr["PLANTILLA_ID"].ToString());
            v.plantilla_nombre = dr["PLANTILLA_NOMBRE"].ToString();
            v.version_numero = int.Parse(dr["VERSION_NUMERO"].ToString());
            if (dr["VALOR_MINIMO"] != DBNull.Value) v.valor_minimo = (decimal)dr["VALOR_MINIMO"];
            if (dr["VALOR_MAXIMO"] != DBNull.Value) v.valor_maximo = (decimal)dr["VALOR_MAXIMO"];
            if (dr["VALOR_ADVERTENCIA"] != DBNull.Value) v.valor_advertencia = (decimal)dr["VALOR_ADVERTENCIA"];
            if (dr["VALOR_CRITICO"] != DBNull.Value) v.valor_critico = (decimal)dr["VALOR_CRITICO"];
            if (dr["LARGO_MINIMO"] != DBNull.Value) v.largo_minimo = int.Parse(dr["LARGO_MINIMO"].ToString());
            if (dr["LARGO_MAXIMO"] != DBNull.Value) v.largo_maximo = int.Parse(dr["LARGO_MAXIMO"].ToString());
            v.expresion_regular = dr["EXPRESION_REGULAR"] == DBNull.Value ? null : dr["EXPRESION_REGULAR"].ToString();
            if (dr["UNIDAD_MEDIDA"] != DBNull.Value) v.unidad_medida = int.Parse(dr["UNIDAD_MEDIDA"].ToString());
            v.requiere_comentario = bool.Parse(dr["REQUIERE_COMENTARIO"].ToString());
            v.requiere_evidencia = bool.Parse(dr["REQUIERE_EVIDENCIA"].ToString());
            v.genera_alerta = bool.Parse(dr["GENERA_ALERTA"].ToString());
            v.genera_hallazgo = bool.Parse(dr["GENERA_HALLAZGO"].ToString());
            v.mensaje = dr["MENSAJE"].ToString();
            v.habilitado = bool.Parse(dr["HABILITADO"].ToString());
            return v;
        }

        #endregion

        #region ESCRITURA

        public Respuesta InsertValidacion(ChecklistItemValidacion e)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "Sesión no válida."; r.codigo = -1; return r; }

            SqlCommand cmd = null;
            try
            {
                int id = 0;
                cmd = Conexion.GetCommand("INS_CHECKLIST_ITEM_VALIDACION");
                cmd.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@CLIENTE", Session.ClienteId());
                cmd.Parameters.AddWithValue("@ITEM", e.item_id);
                Umbrales(cmd, e);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = (int)cmd.Parameters["@ID"].Value;
                r.detalle = "Validación creada con éxito.";
                r.error = false;
            }
            catch (Exception ex) { Cerrar(cmd); r.codigo = -1; r.detalle = ex.Message; r.error = true; }
            return r;
        }

        public Respuesta UpdateValidacion(ChecklistItemValidacion e)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "Sesión no válida."; r.codigo = -1; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("UPD_CHECKLIST_ITEM_VALIDACION");
                cmd.Parameters.AddWithValue("@ID", e.civ_id);
                Umbrales(cmd, e);
                cmd.Parameters.AddWithValue("@HABILITADO", e.habilitado);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = e.civ_id;
                r.detalle = "Validación actualizada con éxito.";
                r.error = false;
            }
            catch (Exception ex) { Cerrar(cmd); r.codigo = -1; r.detalle = ex.Message; r.error = true; }
            return r;
        }

        public Respuesta DeleteValidacion(ChecklistItemValidacion e)
        {
            Respuesta r = new Respuesta();
            if (!Token.TokenSeguridad()) { r.error = true; r.detalle = "Sesión no válida."; r.codigo = -1; return r; }

            SqlCommand cmd = null;
            try
            {
                cmd = Conexion.GetCommand("DEL_CHECKLIST_ITEM_VALIDACION");
                cmd.Parameters.AddWithValue("@ID", e.civ_id);
                cmd.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmd.ExecuteNonQuery();
                cmd.Connection.Close();

                r.codigo = e.civ_id;
                r.detalle = "Validación dada de baja con éxito.";
                r.error = false;
            }
            catch (Exception ex) { Cerrar(cmd); r.codigo = -1; r.detalle = ex.Message; r.error = true; }
            return r;
        }

        /// <summary>Los mismos umbrales y acciones para INS y UPD; NULL cuando no vienen.</summary>
        private static void Umbrales(SqlCommand cmd, ChecklistItemValidacion e)
        {
            cmd.Parameters.AddWithValue("@VALOR_MINIMO", (object)e.valor_minimo ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@VALOR_MAXIMO", (object)e.valor_maximo ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@VALOR_ADVERTENCIA", (object)e.valor_advertencia ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@VALOR_CRITICO", (object)e.valor_critico ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@LARGO_MINIMO", (object)e.largo_minimo ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@LARGO_MAXIMO", (object)e.largo_maximo ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@EXPRESION_REGULAR", (object)e.expresion_regular ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@UNIDAD_MEDIDA", (object)e.unidad_medida ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@REQUIERE_COMENTARIO", e.requiere_comentario);
            cmd.Parameters.AddWithValue("@REQUIERE_EVIDENCIA", e.requiere_evidencia);
            cmd.Parameters.AddWithValue("@GENERA_ALERTA", e.genera_alerta);
            cmd.Parameters.AddWithValue("@GENERA_HALLAZGO", e.genera_hallazgo);
            cmd.Parameters.AddWithValue("@MENSAJE", (object)e.mensaje ?? DBNull.Value);
        }

        private static void Cerrar(SqlCommand cmd)
        {
            if (cmd != null && cmd.Connection != null) cmd.Connection.Close();
        }

        #endregion
    }
}
