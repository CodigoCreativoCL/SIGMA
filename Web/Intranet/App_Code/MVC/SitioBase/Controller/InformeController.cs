using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;

namespace SitioBase.Controller
{
    public class InformeController
    {
        // INFORME INGRESOS
        public List<InformeUsuarioMarcacion> GetIngresos(InformeUsuarioMarcacion filtro)
        {
            List<InformeUsuarioMarcacion> listado = new List<InformeUsuarioMarcacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "RPT_INFORME_INGRESOS";

                    if (filtro.fecha_desde > DateTime.MinValue) cmd.Parameters.AddWithValue("@FECHA_DESDE", filtro.fecha_desde);
                    if (filtro.fecha_hasta > DateTime.MinValue) cmd.Parameters.AddWithValue("@FECHA_HASTA", filtro.fecha_hasta);
                    if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                    if (filtro.usuario > 0) cmd.Parameters.AddWithValue("@USUARIO", filtro.usuario);
                    if (filtro.id_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.id_cliente);
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InformeUsuarioMarcacion item = new InformeUsuarioMarcacion();
                            item.mar_id = int.Parse(dr["MAR_ID"].ToString());
                            item.usuario_nombre = dr["NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO"].ToString();
                            item.fecha = dr["FECHA"].ToString();
                            item.hora = dr["HORA"].ToString();

                            listado.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    listado = null;
                }
            }

            return listado;
        }

        public void GetIngresosExcel(InformeUsuarioMarcacion filtro)
        {
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();
                cmd.CommandText = "RPT_INFORME_INGRESOS";
                cmd.CommandTimeout = 999999999;
                cmd.Parameters.AddWithValue("@EXCEL", true);

                if (filtro.fecha_desde > DateTime.MinValue) cmd.Parameters.AddWithValue("@FECHA_DESDE", filtro.fecha_desde);
                if (filtro.fecha_hasta > DateTime.MinValue) cmd.Parameters.AddWithValue("@FECHA_HASTA", filtro.fecha_hasta);
                if (!string.IsNullOrEmpty(filtro.filtro)) cmd.Parameters.AddWithValue("@FILTRO", filtro.filtro);
                if (filtro.usuario > 0) cmd.Parameters.AddWithValue("@USUARIO", filtro.usuario);
                if (filtro.id_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.id_cliente);

                string filename = "Informe Ingresos " + DateTime.Now;
                Tools.Excel.exportExcelXLSX(Conexion.GetDataTable(cmd), filename, true);
            }
        }

        public InformeUsuarioMarcacion GetIngresoDetalle(InformeUsuarioMarcacion filtro)
        {
            InformeUsuarioMarcacion item = new InformeUsuarioMarcacion();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "RPT_INFORME_INGRESOS";
                    cmd.Parameters.AddWithValue("@ID", filtro.mar_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            item.mar_id = int.Parse(dr["MAR_ID"].ToString());
                            item.usuario_nombre = dr["NOMBRE"].ToString();
                            item.tipo_nombre = dr["TIPO"].ToString();
                            item.fecha = dr["FECHA"].ToString();
                            item.hora = dr["HORA"].ToString();
                            item.mar_fecha_hora_minuto_segundos = DateTime.Parse(dr["MAR_FECHA_HORA_MARCACION"].ToString());
                            item.mar_longitud = decimal.Parse(dr["MAR_LONGITUD"].ToString());
                            item.mar_latitud = decimal.Parse(dr["MAR_LATITUD"].ToString());
                            if (!string .IsNullOrEmpty(dr["MAB_BINARIO"].ToString())) item.abi_archivo_binario = (byte[])dr["MAB_BINARIO"];
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
            }

            return item;
        }

        // CBO FILTROS
        public List<ClienteInstalacion> GetInstalacionCBO(ClienteInstalacion filtro)
        {
            List<ClienteInstalacion> listado = new List<ClienteInstalacion>();

            if (Token.TokenSeguridad())
            {

                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_INSTALACION";
                    if (filtro.cin_cliente > 0) cmd.Parameters.AddWithValue("@CLIENTE", filtro.cin_cliente);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            ClienteInstalacion item = new ClienteInstalacion();

                            item.cin_id = int.Parse(dr["CIN_ID"].ToString());
                            item.cin_nombre = dr["CIN_NOMBRE"].ToString();

                            listado.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    listado = null;
                }
            }

            return listado;
        }

        public List<Cliente> GetClienteCBO(UsuarioCliente filtro)
        {
            List<Cliente> listado = new List<Cliente>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_CLIENTE_SEGURIDAD";
                    if (filtro.ucl_id > 0) cmd.Parameters.AddWithValue("@USUARIO", filtro.ucl_id);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            Cliente item = new Cliente();

                            item.cli_id = int.Parse(dr["CLI_ID"].ToString());
                            item.cli_nombre = dr["CLI_NOMBRE"].ToString();

                            listado.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    listado = null;
                }
            }

            return listado;
        }

   
        public List<InformeUsuarioMarcacion> GetUsuarioCBO(ClienteUsuario filtro)
        {
            List<InformeUsuarioMarcacion> listado = new List<InformeUsuarioMarcacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_MARCACIONES_CBO";
                    cmd.Parameters.AddWithValue("@CLIENTE", filtro.ucl_id_cliente);
                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InformeUsuarioMarcacion item = new InformeUsuarioMarcacion();

                            item.usuario = int.Parse(dr["ID"].ToString());
                            item.usuario_nombre = dr["NOMBRE"].ToString();

                            listado.Add(item);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();
                    listado = null;
                }
            }

            return listado;
        }

    }
}