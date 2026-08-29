using SitioBase;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using System.Text;
using System.Web;
using OfficeOpenXml.Style;
using OfficeOpenXml;
using System.Drawing;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class MenuMaterialApoyoController
    {
        public List<MenuMaterialApoyo> GetMenuMaterialApoyos(MenuMaterialApoyo item)
        {
            List<MenuMaterialApoyo> capsulas = new List<MenuMaterialApoyo>();

            SqlCommand cmd = new SqlCommand();

            try
            {
                cmd.CommandText = "SEL_MENU_MATERIAL_APOYO";
                if (item.mma_menu > 0) cmd.Parameters.AddWithValue("@ID_MENU", item.mma_menu);
                if (item.mma_ruta != "") cmd.Parameters.AddWithValue("@RUTA", item.mma_ruta);
                if (item.filtro_habilitado != "") cmd.Parameters.AddWithValue("@FILTRO_HABILITADO", item.filtro_habilitado);

                using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                {
                    while (dr.Read())
                    {
                        item = new MenuMaterialApoyo();

                        item.mma_id = int.Parse(dr["mma_id"].ToString());
                        item.mma_menu = int.Parse(dr["mma_menu"].ToString());
                        item.mma_contenedor = dr["mma_contenedor"].ToString();
                        item.mma_nombre = dr["mma_nombre"].ToString();
                        item.mma_ruta = dr["mma_ruta"].ToString();
                        item.mma_orden = int.Parse(dr["mma_orden"].ToString());
                        item.mma_habilitado = bool.Parse(dr["mma_habilitado"].ToString());
                        item.noMeGusta = int.Parse(dr["NO_ME_GUSTA"].ToString());
                        item.meGusta = int.Parse(dr["ME_GUSTA"].ToString());
                        item.visto = int.Parse(dr["VISTO"].ToString());
                        capsulas.Add(item);
                    }
                }

                cmd.Connection.Close();
                cmd.Dispose();

                return capsulas;
            }
            catch (Exception ex)
            {
                cmd.Connection.Close();
                cmd.Dispose();
                return capsulas;
            }
        }

        public MenuMaterialApoyo GetMenuMaterialApoyo(MenuMaterialApoyo item)
        {

            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEL_MENU_MATERIAL_APOYO";
            if (item.mma_id > 0) cmd.Parameters.AddWithValue("@ID", item.mma_id);
            if (item.mma_menu > 0) cmd.Parameters.AddWithValue("@ID_MENU", item.mma_menu);
            if (item.mma_ruta != "") cmd.Parameters.AddWithValue("@RUTA", item.mma_ruta);

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {

                if (dr.Read())
                {
                    item.mma_id = int.Parse(dr["mma_id"].ToString());
                    item.mma_menu = int.Parse(dr["mma_menu"].ToString());
                    item.mma_contenedor = dr["mma_contenedor"].ToString();
                    item.mma_nombre = dr["mma_nombre"].ToString();
                    item.mma_ruta = dr["mma_ruta"].ToString();
                    item.mma_orden = int.Parse(dr["mma_orden"].ToString());
                    item.mma_habilitado = bool.Parse(dr["mma_habilitado"].ToString());
                    item.noMeGusta = int.Parse(dr["NO_ME_GUSTA"].ToString());
                    item.meGusta = int.Parse(dr["ME_GUSTA"].ToString());
                    item.visto = int.Parse(dr["VISTO"].ToString());
                }
            }

            cmd.Connection.Close();
            cmd.Dispose();

            return item;
        }

        public Respuesta InsertMenuMaterialApoyo(MenuMaterialApoyo item)
        {
            SqlCommand cmdExecute = new SqlCommand();

            //Creo el objeto respuesta
            Respuesta respuesta = new Respuesta();

            try
            {
                int Id = 0;

                cmdExecute = Conexion.GetCommand("INS_MENU_MATERIAL_APOYO");
                cmdExecute.Parameters.AddWithValue("@ID", Id).Direction = System.Data.ParameterDirection.Output;
                cmdExecute.Parameters.AddWithValue("@ID_MENU", item.mma_menu);
                cmdExecute.Parameters.AddWithValue("@NOMBRE", item.mma_nombre);
                cmdExecute.Parameters.AddWithValue("@CONTENEDOR", item.mma_contenedor);
                cmdExecute.Parameters.AddWithValue("@RUTA", item.mma_ruta);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                Id = (int)cmdExecute.Parameters["@ID"].Value;

                respuesta.codigo = Id;
                respuesta.detalle = "Registro creado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                cmdExecute.Connection.Close();
                cmdExecute.Dispose();

                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdateMenuMaterialApoyo(MenuMaterialApoyo item)
        {
            SqlCommand cmdExecute = new SqlCommand();
            Respuesta respuesta = new Respuesta();

            try
            {

                cmdExecute = Conexion.GetCommand("UPD_MENU_MATERIAL_APOYO");
                cmdExecute.Parameters.AddWithValue("@ID", item.mma_id);
                cmdExecute.Parameters.AddWithValue("@ID_MENU", item.mma_menu);
                cmdExecute.Parameters.AddWithValue("@NOMBRE", item.mma_nombre);
                cmdExecute.Parameters.AddWithValue("@CONTENEDOR", item.mma_contenedor);
                cmdExecute.Parameters.AddWithValue("@RUTA", item.mma_ruta);
                cmdExecute.Parameters.AddWithValue("@HABILITADO", item.mma_habilitado);
                cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = 0;
                respuesta.detalle = "Registro actualizado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                cmdExecute.Connection.Close();
                cmdExecute.Dispose();

                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }

        public Respuesta UpdateMenuMaterialApoyoOrden(MenuMaterialApoyo capsula)
        {
            Respuesta respuesta = new Respuesta();

            try
            {
                int id = 0;
                SqlCommand cmdExecute = Conexion.GetCommand("UPD_MENU_MATERIAL_APOYO_ORDEN");

                cmdExecute.Parameters.AddWithValue("@ID", capsula.mma_id);
                cmdExecute.Parameters.AddWithValue("@ORDEN", capsula.mma_orden);

                cmdExecute.ExecuteNonQuery();
                cmdExecute.Connection.Close();

                respuesta.codigo = id;
                respuesta.detalle = "Orden actualizado con éxito.";
                respuesta.error = false;
            }
            catch (Exception ex)
            {
                respuesta.codigo = -1;
                respuesta.detalle = ex.Message;
                respuesta.error = true;
            }

            return respuesta;
        }
        public Respuesta DeleteMenuMaterialApoyo(List<MenuMaterialApoyo> listado)
        {
            Respuesta respuesta = new Respuesta();

            DataTable dt2 = new DataTable();
            dt2.Columns.Add("mma_id", typeof(string));
            dt2.Columns.Add("mensaje", typeof(string));

            //Nuevo row
            DataRow filaNueva = null;

            if (Token.TokenSeguridad())
            {
                try
                {
                    int countError = 0;
                    int cantidaCargada = 0;
                    foreach (MenuMaterialApoyo item in listado)
                    {
                        SqlCommand cmdExecute = new SqlCommand();
                        try
                        {
                            cmdExecute = Conexion.GetCommand("DEL_MENU_MATERIAL_APOYO");
                            cmdExecute.Parameters.AddWithValue("@ID", item.mma_id);
                            cmdExecute.Parameters.AddWithValue("@USUARIO", Session.UsuarioId());
                            cmdExecute.Parameters.AddWithValue("@PAIS", Session.UsuarioIdPaises());
                            cmdExecute.ExecuteNonQuery();
                            cmdExecute.Connection.Close();

                            respuesta.detalle = "Material(es) Eliminado(s) con éxito";
                            cantidaCargada++;
                        }
                        catch (Exception ex)
                        {
                            cmdExecute.Connection.Close();

                            filaNueva = dt2.NewRow();
                            filaNueva["mma_id"] = item.mma_id;
                            filaNueva["mensaje"] = ex.Message;
                            respuesta.error = true;
                            respuesta.detalle = ex.Message + " - ID Material de Apoyo: " + item.mma_id;

                            dt2.Rows.Add(filaNueva);

                            countError++;
                        }

                    }
                    respuesta.cantidaError = countError;
                    respuesta.cantidaCargada = cantidaCargada;
                    respuesta.table = dt2;
                }
                catch (Exception ex)
                {
                    respuesta.codigo = -1;
                    respuesta.detalle = ex.Message;
                    respuesta.error = true;
                }
            }

            return respuesta;
        }

        public void GenerarExcelEstadisticas(MenuMaterialApoyo filtro = null)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandTimeout = 999999999;
            cmd.CommandText = "SEL_MENU_MATERIAL_APOYO_ESTADISTICAS";
            cmd.Parameters.AddWithValue("@EXCEL", true);

            DataTable dt = Conexion.GetDataTable(cmd);

            // === Generar Excel con EPPlus ===
            ExcelPackage.LicenseContext = LicenseContext.Commercial;

            using (ExcelPackage excelPackage = new ExcelPackage())
            {
                ExcelWorksheet ws = excelPackage.Workbook.Worksheets.Add("Hoja 1");

                // Cargar datos
                ws.Cells["A1"].LoadFromDataTable(dt, true);

                //  Estilos de encabezado 
                ws.Row(1).Style.Font.Bold = true;
                ws.Row(1).Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
                ws.Row(1).Style.VerticalAlignment = ExcelVerticalAlignment.Center;

                //  Colores pastel 
                using (var rangoCeleste = ws.Cells["A1:C1"])
                {
                    rangoCeleste.Style.Fill.PatternType = ExcelFillStyle.Solid;
                    rangoCeleste.Style.Fill.BackgroundColor.SetColor(ColorTranslator.FromHtml("#B7E3F7"));
                }

                using (var rangoVerde = ws.Cells["D1:F1"])
                {
                    rangoVerde.Style.Fill.PatternType = ExcelFillStyle.Solid;
                    rangoVerde.Style.Fill.BackgroundColor.SetColor(ColorTranslator.FromHtml("#C8E6C9"));
                }

                //  Agregar Filtros 
                // Determinar último encabezado en base al número de columnas
                int lastColumn = dt.Columns.Count;
                string lastColumnLetter = GetExcelColumnName(lastColumn);
                ws.Cells["A1:" + lastColumnLetter + "1"].AutoFilter = true;

                // === Ajustar ancho automático ===
                ws.Cells[ws.Dimension.Address].AutoFitColumns();

                // Convertir a binario
                byte[] binario = excelPackage.GetAsByteArray();

                //  Respuesta HTTP 
                string filename = "Informe Estadistico de Material Apoyo " + DateTime.Now.ToString("dd-MM-yyyy HHmm");
                HttpContext.Current.Response.Clear();
                HttpContext.Current.Response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
                HttpContext.Current.Response.HeaderEncoding = Encoding.Default;
                HttpContext.Current.Response.ContentEncoding = Encoding.Default;
                HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + filename + ".xlsx");
                HttpContext.Current.Response.BinaryWrite(binario);
                HttpContext.Current.Response.End();
            }
        }

        //  Función auxiliar para convertir número de columna a letra Excel 
        private string GetExcelColumnName(int columnNumber)
        {
            string columnName = String.Empty;
            while (columnNumber > 0)
            {
                int modulo = (columnNumber - 1) % 26;
                columnName = Convert.ToChar(65 + modulo).ToString() + columnName;
                columnNumber = (columnNumber - modulo) / 26;
            }
            return columnName;
        }

    }
}