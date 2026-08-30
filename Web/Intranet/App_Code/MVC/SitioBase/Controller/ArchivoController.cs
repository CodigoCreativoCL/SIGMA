using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Archivos del cliente. Coordina dos mundos: el binario, que va al
    /// Blob Storage por la API de servicios, y la fila de metadatos, que va
    /// a la base.
    ///
    /// EL ORDEN NO ES ARBITRARIO
    ///   Primero el blob, después la fila. Al revés quedaría una fila
    ///   apuntando a un archivo que no existe, y eso no se ve hasta que
    ///   alguien intenta abrirlo -meses después, cuando ya nadie recuerda
    ///   qué se subió-. Si el blob queda y la fila no, en cambio, sobra un
    ///   archivo huérfano: cuesta espacio, no miente.
    /// </summary>
    public class ArchivoController
    {
        /// <summary>Categoría 12 del catálogo Archivo_Categoria.</summary>
        public const int CATEGORIA_COMPROBANTE_PAGO = 12;

        public List<Archivo> GetArchivos(Archivo filtro = null)
        {
            List<Archivo> lista = new List<Archivo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_ARCHIVO";

                    if (filtro != null)
                    {
                        if (filtro.arc_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.arc_id);
                        if (filtro.filtro_cliente != null && filtro.filtro_cliente > 0)
                            cmd.Parameters.AddWithValue("@CLIENTE", filtro.filtro_cliente);
                        if (filtro.filtro_categoria != null && filtro.filtro_categoria > 0)
                            cmd.Parameters.AddWithValue("@CATEGORIA", filtro.filtro_categoria);
                        if (filtro.filtro_habilitado != null)
                            cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Archivo item = new Archivo();

                            item.arc_id = int.Parse(dr["ARC_ID"].ToString());
                            if (dr["ARC_UUID"] != DBNull.Value) item.arc_uuid = new Guid(dr["ARC_UUID"].ToString());
                            item.arc_cliente = int.Parse(dr["ARC_CLIENTE"].ToString());
                            item.arc_archivo_categoria = int.Parse(dr["ARC_ARCHIVO_CATEGORIA"].ToString());
                            item.aca_nombre = dr["ACA_NOMBRE"].ToString();
                            item.arc_nombre_original = dr["ARC_NOMBRE_ORIGINAL"].ToString();
                            item.arc_nombre_almacenado = dr["ARC_NOMBRE_ALMACENADO"].ToString();
                            item.arc_ruta = dr["ARC_RUTA"].ToString();
                            item.arc_mime = dr["ARC_MIME"].ToString();
                            item.arc_extension = dr["ARC_EXTENSION"].ToString();
                            if (dr["ARC_BYTE"] != DBNull.Value) item.arc_byte = long.Parse(dr["ARC_BYTE"].ToString());
                            item.arc_hash = dr["ARC_HASH"].ToString();
                            item.arc_antivirus_estado = int.Parse(dr["ARC_ANTIVIRUS_ESTADO"].ToString());
                            item.aae_nombre = dr["AAE_NOMBRE"].ToString();
                            if (dr["ARC_FECHA_CREACION"] != DBNull.Value)
                                item.arc_fecha_creacion = DateTime.Parse(dr["ARC_FECHA_CREACION"].ToString());
                            item.arc_habilitado = bool.Parse(dr["ARC_HABILITADO"].ToString());

                            lista.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    lista = null;
                }
            }

            return lista;
        }

        public Archivo GetArchivo(Archivo entidad)
        {
            List<Archivo> lista = GetArchivos(new Archivo { arc_id = entidad.arc_id });
            return (lista != null && lista.Count > 0) ? lista[0] : new Archivo();
        }

        /// <summary>
        /// Sube el binario y registra la fila. Devuelve el arc_id en
        /// respuesta.codigo.
        ///
        /// El binario viaja en entidad.contenido y no se guarda en ningún
        /// lado de acá: se envía y se suelta.
        /// </summary>
        public Respuesta InsertArchivo(Archivo entidad, string carpeta)
        {
            Respuesta respuesta = new Respuesta();

            if (!Token.TokenSeguridad()) return respuesta;

            SqlCommand cmdExecute = null;

            try
            {
                if (entidad.contenido == null || entidad.contenido.Length == 0)
                    throw new Exception("El archivo está vacío.");

                IAlmacenamiento almacenamiento = Almacenamiento.Actual();

                if (!almacenamiento.Disponible)
                    throw new Exception(almacenamiento.Motivo);

                // 1. El blob. Si esto falla, no se escribe nada en la base.
                ResultadoSubida subida = almacenamiento.Subir(
                    entidad.arc_cliente, carpeta, entidad.arc_nombre_original,
                    entidad.contenido, entidad.arc_mime);

                // 2. La fila.
                int id = 0;

                cmdExecute = Conexion.GetCommand("INS_ARCHIVO");
                cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@CLIENTE", entidad.arc_cliente);
                cmdExecute.Parameters.AddWithValue("@CATEGORIA", entidad.arc_archivo_categoria);
                cmdExecute.Parameters.AddWithValue("@NOMBRE_ORIGINAL", entidad.arc_nombre_original);
                cmdExecute.Parameters.AddWithValue("@NOMBRE_ALMACENADO", subida.nombre_almacenado);
                cmdExecute.Parameters.AddWithValue("@RUTA", subida.ruta);
                cmdExecute.Parameters.AddWithValue("@MIME", (object)subida.mime ?? DBNull.Value);
                cmdExecute.Parameters.AddWithValue("@EXTENSION", (object)subida.extension ?? DBNull.Value);
                cmdExecute.Parameters.AddWithValue("@BYTE", subida.tamano);
                cmdExecute.Parameters.AddWithValue("@HASH", (object)subida.hash ?? DBNull.Value);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                id = (int)cmdExecute.Parameters["@ID"].Value;

                respuesta.codigo = id;
                respuesta.detalle = "Archivo creado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                if (cmdExecute != null && cmdExecute.Connection != null) cmdExecute.Connection.Close();
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        /// <summary>
        /// Trae el binario desde el Blob Storage. La base solo tiene la
        /// ruta; el contenido siempre se pide.
        /// </summary>
        public byte[] Descargar(int idArchivo)
        {
            Archivo entidad = GetArchivo(new Archivo { arc_id = idArchivo });

            if (entidad == null || entidad.arc_id == 0)
                throw new Exception("El archivo no existe.");

            /* Un archivo de otro cliente no se entrega, aunque el id sea
               correcto. Adivinar un número correlativo es barato. */
            if (entidad.arc_cliente != Session.ClienteId())
                throw new Exception("El archivo no pertenece al cliente seleccionado.");

            return Almacenamiento.Actual().Descargar(entidad.arc_ruta);
        }

        /// <summary>
        /// Baja lógica. El blob no se toca: puede estar referenciado desde
        /// un comprobante de pago que nadie va a borrar nunca.
        /// </summary>
        public Respuesta DeleteArchivo(Archivo entidad)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_ARCHIVO");
                    cmdExecute.Parameters.AddWithValue("@ID", entidad.arc_id);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = entidad.arc_id;
                    respuesta.detalle = "Archivo eliminado con éxito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    cmdExecute.Connection.Close();
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }
    }
}
