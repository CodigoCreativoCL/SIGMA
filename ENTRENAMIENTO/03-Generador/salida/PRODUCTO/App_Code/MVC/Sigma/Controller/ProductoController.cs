using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using Sigma.Model;
using SitioBase;

namespace Sigma.Controller
{
    /// <summary>
    /// CONTROLLER de la entidad PRODUCTO.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 3):
    ///  1. Namespace Sigma.Controller. Una clase por entidad.
    ///  2. TODA operacion arranca con if (Token.TokenSeguridad()).
    ///  3. NUNCA SQL embebido. Siempre Stored Procedures:
    ///        SEL_PRODUCTO  INS_PRODUCTO  UPD_PRODUCTO  DEL_PRODUCTO
    ///  4. Acceso a datos SIEMPRE via SitioBase.Conexion.
    ///  5. Los metodos de escritura devuelven SitioBase.Respuesta.
    ///  6. try/catch en todos los metodos, cerrando la conexion en AMBOS caminos.
    ///  7. Los parametros de filtro se agregan SOLO si vienen informados.
    ///
    /// ARCHIVO GENERADO por 03-Generador.
    /// </summary>
    public class ProductoController
    {
        #region LECTURA

        /// <summary>
        /// LISTADO. Se usa como DataSource del RadGrid2.
        /// Recibe un Model que actua SOLO como bolsa de filtros.
        /// </summary>
        public List<Producto> GetProductos(Producto producto = null)
        {
            List<Producto> productos = new List<Producto>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_PRODUCTO";

                    // Cada filtro se agrega SOLO si viene informado. Lo que no se
                    // agrega llega al SP como NULL y ese IF del WHERE no se concatena.
                    if (producto != null)
                    {
                        if (producto.pro_id > 0)
                            cmd.Parameters.AddWithValue("@ID", producto.pro_id);

                        if (!string.IsNullOrEmpty(producto.filtro))
                            cmd.Parameters.AddWithValue("@FILTRO", producto.filtro);

                        if (producto.filtro_habilitado.HasValue)
                            cmd.Parameters.AddWithValue("@HABILITADO", producto.filtro_habilitado.Value);

                        if (producto.filtro_categoria.HasValue && producto.filtro_categoria.Value > 0)
                            cmd.Parameters.AddWithValue("@CATEGORIA", producto.filtro_categoria.Value);

                        if (producto.filtro_proveedor.HasValue && producto.filtro_proveedor.Value > 0)
                            cmd.Parameters.AddWithValue("@PROVEEDOR", producto.filtro_proveedor.Value);
                    }

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Producto item = new Producto();

                            item.pro_id = int.Parse(dr["PRO_ID"].ToString());
                            item.pro_codigo = dr["PRO_CODIGO"].ToString();
                            item.pro_nombre = dr["PRO_NOMBRE"].ToString();
                            item.pro_descripcion = dr["PRO_DESCRIPCION"].ToString();
                            item.pro_categoria = int.Parse(dr["PRO_CATEGORIA"].ToString());
                            item.pro_proveedor = int.Parse(dr["PRO_PROVEEDOR"].ToString());
                            item.pro_precio = decimal.Parse(dr["PRO_PRECIO"].ToString());
                            item.pro_stock = int.Parse(dr["PRO_STOCK"].ToString());
                            item.pro_vencimiento = dr["PRO_VENCIMIENTO"] == DBNull.Value ? (DateTime?)null : DateTime.Parse(dr["PRO_VENCIMIENTO"].ToString());
                            item.pro_habilitado = bool.Parse(dr["PRO_HABILITADO"].ToString());

                            // Campos del JOIN: se muestran en el grid.
                            item.cat_nombre = dr["CAT_NOMBRE"].ToString();
                            item.prv_nombre = dr["PRV_NOMBRE"].ToString();

                            productos.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    // En los Get devolvemos null para que la vista distinga
                    // "error" de "lista vacia".
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    productos = null;
                }
            }

            return productos;
        }

        /// <summary>
        /// REGISTRO UNICO. Se usa al abrir el formulario de edicion.
        /// Reutiliza el mismo SP SEL_PRODUCTO pasandole @ID.
        /// </summary>
        public Producto GetProducto(Producto producto)
        {
            Producto item = new Producto();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                try
                {
                    cmd.CommandText = "SEL_PRODUCTO";
                    cmd.Parameters.AddWithValue("@ID", producto.pro_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            item.pro_id = int.Parse(dr["PRO_ID"].ToString());
                            item.pro_codigo = dr["PRO_CODIGO"].ToString();
                            item.pro_nombre = dr["PRO_NOMBRE"].ToString();
                            item.pro_descripcion = dr["PRO_DESCRIPCION"].ToString();
                            item.pro_categoria = int.Parse(dr["PRO_CATEGORIA"].ToString());
                            item.pro_proveedor = int.Parse(dr["PRO_PROVEEDOR"].ToString());
                            item.pro_precio = decimal.Parse(dr["PRO_PRECIO"].ToString());
                            item.pro_stock = int.Parse(dr["PRO_STOCK"].ToString());
                            item.pro_vencimiento = dr["PRO_VENCIMIENTO"] == DBNull.Value ? (DateTime?)null : DateTime.Parse(dr["PRO_VENCIMIENTO"].ToString());
                            item.pro_habilitado = bool.Parse(dr["PRO_HABILITADO"].ToString());

                            // Campos del JOIN: se muestran en el grid.
                            item.cat_nombre = dr["CAT_NOMBRE"].ToString();
                            item.prv_nombre = dr["PRV_NOMBRE"].ToString();
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception)
                {
                    if (cmd.Connection != null) cmd.Connection.Close();
                    cmd.Dispose();
                    item = null;
                }
            }

            return item;
        }

        #endregion

        #region ESCRITURA

        /// <summary>
        /// ALTA. El SP INS_PRODUCTO devuelve el id generado por el parametro @ID OUTPUT.
        /// </summary>
        public Respuesta InsertProducto(Producto producto)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    int id = 0;
                    cmdExecute = Conexion.GetCommand("INS_PRODUCTO");

                    // @ID SIEMPRE primero y como OUTPUT: el SP hace SET @ID = SCOPE_IDENTITY().
                    cmdExecute.Parameters.AddWithValue("@ID", id).Direction = ParameterDirection.Output;

                    cmdExecute.Parameters.AddWithValue("@CODIGO", producto.pro_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", producto.pro_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)producto.pro_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CATEGORIA", producto.pro_categoria);
                    cmdExecute.Parameters.AddWithValue("@PROVEEDOR", producto.pro_proveedor > 0 ? (object)producto.pro_proveedor : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PRECIO", producto.pro_precio);
                    cmdExecute.Parameters.AddWithValue("@STOCK", producto.pro_stock);
                    cmdExecute.Parameters.AddWithValue("@VENCIMIENTO", (object)producto.pro_vencimiento ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", producto.pro_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    id = (int)cmdExecute.Parameters["@ID"].Value;

                    respuesta.codigo = id;
                    respuesta.detalle = "Producto creado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    // ex.Message trae el texto del RAISERROR del SP.
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// MODIFICACION. Mismo patron que el alta pero con @ID de entrada.
        /// </summary>
        public Respuesta UpdateProducto(Producto producto)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("UPD_PRODUCTO");

                    cmdExecute.Parameters.AddWithValue("@ID", producto.pro_id);
                    cmdExecute.Parameters.AddWithValue("@CODIGO", producto.pro_codigo);
                    cmdExecute.Parameters.AddWithValue("@NOMBRE", producto.pro_nombre);
                    cmdExecute.Parameters.AddWithValue("@DESCRIPCION", (object)producto.pro_descripcion ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@CATEGORIA", producto.pro_categoria);
                    cmdExecute.Parameters.AddWithValue("@PROVEEDOR", producto.pro_proveedor > 0 ? (object)producto.pro_proveedor : DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@PRECIO", producto.pro_precio);
                    cmdExecute.Parameters.AddWithValue("@STOCK", producto.pro_stock);
                    cmdExecute.Parameters.AddWithValue("@VENCIMIENTO", (object)producto.pro_vencimiento ?? DBNull.Value);
                    cmdExecute.Parameters.AddWithValue("@HABILITADO", producto.pro_habilitado);

                    // La auditoria NUNCA la manda la pantalla: se toma de la sesion.
                    cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = producto.pro_id;
                    respuesta.detalle = "Producto actualizado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// BAJA. PRODUCTO es una tabla MAESTRO: el patron pide baja LOGICA
        /// (UPD_PRODUCTO con @HABILITADO = 0), no DELETE fisico.
        /// DEL_PRODUCTO existe solo para casos excepcionales.
        /// </summary>
        public Respuesta DeleteProducto(Producto producto)
        {
            Respuesta respuesta = new Respuesta();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmdExecute = null;
                try
                {
                    cmdExecute = Conexion.GetCommand("DEL_PRODUCTO");
                    cmdExecute.Parameters.AddWithValue("@ID", producto.pro_id);

                    cmdExecute.ExecuteNonQuery();
                    cmdExecute.Connection.Close();

                    respuesta.codigo = producto.pro_id;
                    respuesta.detalle = "Producto eliminado con exito.";
                    respuesta.error = false;
                }
                catch (Exception ex)
                {
                    if (cmdExecute != null && cmdExecute.Connection != null)
                        cmdExecute.Connection.Close();

                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        /// <summary>
        /// BAJA LOGICA: la que realmente usa el boton "Deshabilitar" del grid.
        /// Reutiliza UPD_PRODUCTO en vez de crear un SP nuevo.
        /// </summary>
        public Respuesta DeshabilitarProducto(Producto producto)
        {
            producto.pro_habilitado = false;
            Respuesta respuesta = UpdateProducto(producto);

            if (!respuesta.error)
                respuesta.detalle = "Producto deshabilitado con exito.";

            return respuesta;
        }

        #endregion
    }
}
