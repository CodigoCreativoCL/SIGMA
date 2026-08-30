using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase;
using SitioBase.Model;

namespace SitioBase.Controller
{
    /// <summary>
    /// Catalogos del sistema (HU-020 y HU-021).
    ///
    /// Este controller no sabe nada de ninguna tabla de catalogo en
    /// particular. Todo pasa por el registro de la tabla Catalogo y por los
    /// SP genericos, que resuelven contra la tabla que corresponda. Por eso
    /// sirve tanto para la pantalla de catalogos como para llenar cualquier
    /// combo del sitio sin escribir un controller por cada uno.
    /// </summary>
    public class CatalogoController
    {
        #region Registro de catalogos

        public List<Catalogo> GetCatalogos(Catalogo filtro = null)
        {
            List<Catalogo> lista = new List<Catalogo>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CATALOGO";

                    if (filtro != null)
                    {
                        if (filtro.ctl_id > 0) cmd.Parameters.AddWithValue("@ID", filtro.ctl_id);
                        if (!string.IsNullOrEmpty(filtro.ctl_codigo)) cmd.Parameters.AddWithValue("@CODIGO", filtro.ctl_codigo);
                        if (!string.IsNullOrEmpty(filtro.filtro_modulo)) cmd.Parameters.AddWithValue("@MODULO", filtro.filtro_modulo);
                        if (filtro.filtro_ampliable != null) cmd.Parameters.AddWithValue("@AMPLIABLE", filtro.filtro_ampliable);
                        if (filtro.filtro_habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", filtro.filtro_habilitado);
                        if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Catalogo item = new Catalogo();

                            item.ctl_id = int.Parse(dr["CTL_ID"].ToString());
                            item.ctl_codigo = dr["CTL_CODIGO"].ToString();
                            item.ctl_nombre = dr["CTL_NOMBRE"].ToString();
                            item.ctl_descripcion = dr["CTL_DESCRIPCION"].ToString();
                            item.ctl_tabla = dr["CTL_TABLA"].ToString();
                            item.ctl_prefijo = dr["CTL_PREFIJO"].ToString();
                            item.ctl_modulo = dr["CTL_MODULO"].ToString();
                            item.ctl_ampliable = bool.Parse(dr["CTL_AMPLIABLE"].ToString());
                            item.ctl_habilitado = bool.Parse(dr["CTL_HABILITADO"].ToString());
                            item.tipo = dr["TIPO"].ToString();

                            if (dr["CTL_ORDEN"] != DBNull.Value)
                                item.ctl_orden = int.Parse(dr["CTL_ORDEN"].ToString());

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

        public Catalogo GetCatalogo(int idCatalogo)
        {
            List<Catalogo> lista = GetCatalogos(new Catalogo { ctl_id = idCatalogo });
            return (lista != null && lista.Count > 0) ? lista[0] : new Catalogo();
        }

        #endregion

        #region Valores de un catalogo

        /// <summary>
        /// Valores de un catalogo, en la forma unica que devuelve
        /// SEL_CATALOGO_VALOR: da igual que tabla haya detras.
        /// </summary>
        public List<CatalogoValor> GetValores(int idCatalogo, int idCliente, bool? habilitado = null, string filtro = null)
        {
            return LeerValores(idCatalogo, null, idCliente, habilitado, filtro);
        }

        /// <summary>
        /// La misma consulta, pero identificando el catalogo por su codigo.
        ///
        /// Es lo que usan los combos del sitio: pedir
        /// GetValoresPorCodigo("INSTALACION_AREA_TIPO", cliente) evita tener
        /// que crear un Model y un Controller por cada catalogo pequeno.
        /// </summary>
        public List<CatalogoValor> GetValoresPorCodigo(string codigoCatalogo, int idCliente)
        {
            return LeerValores(0, codigoCatalogo, idCliente, true, null);
        }

        private List<CatalogoValor> LeerValores(int idCatalogo, string codigoCatalogo, int idCliente, bool? habilitado, string filtro)
        {
            List<CatalogoValor> lista = new List<CatalogoValor>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CATALOGO_VALOR";

                    if (idCatalogo > 0) cmd.Parameters.AddWithValue("@CATALOGO", idCatalogo);
                    if (!string.IsNullOrEmpty(codigoCatalogo)) cmd.Parameters.AddWithValue("@CODIGO", codigoCatalogo);
                    if (idCliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", idCliente);
                    if (habilitado != null) cmd.Parameters.AddWithValue("@HABILITADO", habilitado);
                    if (!string.IsNullOrEmpty(filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            CatalogoValor item = new CatalogoValor();

                            item.valor_id = int.Parse(dr["VALOR_ID"].ToString());
                            item.valor_codigo = dr["VALOR_CODIGO"].ToString();
                            item.valor_nombre = dr["VALOR_NOMBRE"].ToString();
                            item.valor_descripcion = dr["VALOR_DESCRIPCION"].ToString();
                            item.origen = dr["ORIGEN"].ToString();

                            /* Este metodo lee 81 tablas distintas. El registro
                               exige que todas tengan <pfx>_habilitado, pero no
                               que sea NOT NULL: si alguna admite nulo, un
                               bool.Parse("") tumbaria la pantalla completa.
                               Un valor sin bandera se trata como habilitado,
                               que es como se comporta el resto del sistema. */
                            item.valor_habilitado = dr["VALOR_HABILITADO"] == DBNull.Value
                                || bool.Parse(dr["VALOR_HABILITADO"].ToString());

                            if (dr["VALOR_ORDEN"] != DBNull.Value)
                                item.valor_orden = int.Parse(dr["VALOR_ORDEN"].ToString());
                            if (dr["VALOR_CLIENTE"] != DBNull.Value)
                                item.valor_cliente = int.Parse(dr["VALOR_CLIENTE"].ToString());

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

        /// <summary>
        /// Busqueda transversal en todos los catalogos (HU-020 escenario 2).
        /// </summary>
        public List<CatalogoValor> BuscarEnCatalogos(string texto, int idCliente)
        {
            List<CatalogoValor> lista = new List<CatalogoValor>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CATALOGO_BUSQUEDA";
                    cmd.Parameters.AddWithValue("@TEXTO", texto);
                    if (idCliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", idCliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            CatalogoValor item = new CatalogoValor();

                            item.ctl_id = int.Parse(dr["CTL_ID"].ToString());
                            item.ctl_codigo = dr["CTL_CODIGO"].ToString();
                            item.ctl_nombre = dr["CTL_NOMBRE"].ToString();
                            item.ctl_modulo = dr["CTL_MODULO"].ToString();
                            item.ctl_ampliable = bool.Parse(dr["CTL_AMPLIABLE"].ToString());
                            item.valor_id = int.Parse(dr["VALOR_ID"].ToString());
                            item.valor_codigo = dr["VALOR_CODIGO"].ToString();
                            item.valor_nombre = dr["VALOR_NOMBRE"].ToString();

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

        /// <summary>
        /// Cuantos registros usan un valor de catalogo (HU-021 escenario 3).
        /// Se pregunta ANTES de deshabilitarlo, para poder advertir.
        /// </summary>
        public int ContarUsos(int idCatalogo, int idValor)
        {
            int total = 0;

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CATALOGO_VALOR_USO";
                    cmd.Parameters.AddWithValue("@CATALOGO", idCatalogo);
                    cmd.Parameters.AddWithValue("@VALOR_ID", idValor);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        // El SP devuelve dos resultados: el detalle por tabla
                        // y el total. Aqui solo interesa el segundo.
                        while (dr.Read()) { }

                        if (dr.NextResult() && dr.Read())
                            total = int.Parse(dr["TOTAL_REGISTROS"].ToString());
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    total = 0;
                }
            }

            return total;
        }

        #endregion

        #region Escritura de valores propios (HU-021)

        public Respuesta InsertValor(int idCatalogo, int idCliente, CatalogoValor valor)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    int id = 0;

                    cmdExecute = Conexion.GetCommand("INS_CATALOGO_VALOR");
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = System.Data.ParameterDirection.Output;
                    cmdExecute.Parameters.AddWithValue("@CATALOGO", idCatalogo);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", idCliente);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", valor.valor_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", valor.valor_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)valor.valor_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", (object)valor.valor_orden ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Valor creado con éxito.";
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

        public Respuesta UpdateValor(int idCatalogo, int idCliente, CatalogoValor valor)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;

                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_CATALOGO_VALOR");
                    cmdExecute.Parameters.AddWithValue("@CATALOGO", idCatalogo);
                    cmdExecute.Parameters.AddWithValue("@VALOR_ID", valor.valor_id);
                    cmdExecute.Parameters.AddWithValue("@CLIENTE", idCliente);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", valor.valor_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)valor.valor_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@ORDEN", (object)valor.valor_orden ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", valor.valor_habilitado);
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = valor.valor_id;
                    respuesta.detalle = "Valor actualizado con éxito.";
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

        #endregion
    }
}
