using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Linq;
using System.Web;
using SitioBase;
using SitioBase.Model;


namespace Facilityges.Controller
{
    public class InformeUsuarioMarcacionController
    {
        private SqlCommand cmdExecute = null;

        //Listo todas las InformeUsuarioMarcacion (grilla)
        public List<InformeUsuarioMarcacion> GetInformeUsuarioMarcaciones(InformeUsuarioMarcacion informeUsuarioMarcacion)
        {
            List<InformeUsuarioMarcacion> informeUsuarioMarcaciones = new List<InformeUsuarioMarcacion>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_MARCACION";
                    if (informeUsuarioMarcacion.mar_id > 0) cmd.Parameters.AddWithValue("@ID", informeUsuarioMarcacion.mar_id);
                    if (informeUsuarioMarcacion.id_cliente > 0) cmd.Parameters.AddWithValue("@ID_CLIENTE", informeUsuarioMarcacion.id_cliente);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro)) cmd.Parameters.AddWithValue("@FILTRO", informeUsuarioMarcacion.filtro);
                    if (informeUsuarioMarcacion.Desde != null) cmd.Parameters.AddWithValue("@DESDE", informeUsuarioMarcacion.Desde);
                    if (informeUsuarioMarcacion.Hasta != null) cmd.Parameters.AddWithValue("@HASTA", informeUsuarioMarcacion.Hasta);
                    if (informeUsuarioMarcacion.id_Monitor > 0) cmd.Parameters.AddWithValue("@USUARIO", informeUsuarioMarcacion.id_Monitor);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_paises)) cmd.Parameters.AddWithValue("@PAISES", informeUsuarioMarcacion.filtro_paises);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_estado)) cmd.Parameters.AddWithValue("@FILTRO_ESTADO", informeUsuarioMarcacion.filtro_estado);
                    if (informeUsuarioMarcacion.id_Instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", informeUsuarioMarcacion.id_Instalacion);
                    if (informeUsuarioMarcacion.usuario > 0) cmd.Parameters.AddWithValue("@ADMINISTRATIVO", informeUsuarioMarcacion.usuario);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_cliente)) cmd.Parameters.AddWithValue("@FILTRO_CLIENTE", informeUsuarioMarcacion.filtro_cliente);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_instalacion)) cmd.Parameters.AddWithValue("@FILTRO_INSTALACION", informeUsuarioMarcacion.filtro_instalacion);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            InformeUsuarioMarcacion item = new InformeUsuarioMarcacion();

                            item.mar_id = int.Parse(dr["MAR_ID"].ToString());
                            item.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            item.mar_tipo = dr["MAR_TIPO"].ToString();
                            if (!string.IsNullOrEmpty(dr["MAR_FECHA"].ToString())) item.mar_fecha = DateTime.Parse(dr["MAR_FECHA"].ToString());
                            if (!string.IsNullOrEmpty(dr["CLI_NOMBRE"].ToString())) item.cli_nombre = dr["cli_nombre"].ToString();
                            if (!string.IsNullOrEmpty(dr["INS_NOMBRE"].ToString())) item.ins_nombre = dr["INS_NOMBRE"].ToString();
                            if (!string.IsNullOrEmpty(dr["MAR_FECHA_REMOTA"].ToString())) item.mar_fecha_remota = DateTime.Parse(dr["MAR_FECHA_REMOTA"].ToString());
                            if (!string.IsNullOrEmpty(dr["MAR_FECHA_CREACION"].ToString())) item.mar_fecha_creacion = DateTime.Parse(dr["MAR_FECHA_CREACION"].ToString());

                            informeUsuarioMarcaciones.Add(item);
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    informeUsuarioMarcaciones = null;
                }
            }
            return informeUsuarioMarcaciones;
        }

        public InformeUsuarioMarcacion GetInformeUsuarioMarcacion(InformeUsuarioMarcacion informeUsuarioMarcacion)
        {
            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_USUARIO_MARCACION";
                    if (informeUsuarioMarcacion.mar_id > 0) cmd.Parameters.AddWithValue("@ID", informeUsuarioMarcacion.mar_id);
                    if (informeUsuarioMarcacion.id_cliente > 0) cmd.Parameters.AddWithValue("@ID_CLIENTE", informeUsuarioMarcacion.id_cliente);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro)) cmd.Parameters.AddWithValue("@FILTRO", informeUsuarioMarcacion.filtro);
                    if (informeUsuarioMarcacion.Desde != null) cmd.Parameters.AddWithValue("@DESDE", informeUsuarioMarcacion.Desde);
                    if (informeUsuarioMarcacion.Hasta != null) cmd.Parameters.AddWithValue("@HASTA", informeUsuarioMarcacion.Hasta);
                    if (informeUsuarioMarcacion.id_Monitor > 0) cmd.Parameters.AddWithValue("@USUARIO", informeUsuarioMarcacion.id_Monitor);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_paises)) cmd.Parameters.AddWithValue("@PAISES", informeUsuarioMarcacion.filtro_paises);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_estado)) cmd.Parameters.AddWithValue("@FILTRO_ESTADO", informeUsuarioMarcacion.filtro_estado);
                    if (informeUsuarioMarcacion.id_Instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", informeUsuarioMarcacion.id_Instalacion);
                    if (informeUsuarioMarcacion.usuario > 0) cmd.Parameters.AddWithValue("@ADMINISTRATIVO", informeUsuarioMarcacion.usuario);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_cliente)) cmd.Parameters.AddWithValue("@FILTRO_CLIENTE", informeUsuarioMarcacion.filtro_cliente);
                    if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_instalacion)) cmd.Parameters.AddWithValue("@FILTRO_INSTALACION", informeUsuarioMarcacion.filtro_instalacion);
                    cmd.Parameters.AddWithValue("@FOTO", 1);

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            informeUsuarioMarcacion = new InformeUsuarioMarcacion();

                            informeUsuarioMarcacion.mar_id = int.Parse(dr["MAR_ID"].ToString());
                            informeUsuarioMarcacion.usuario_nombre = dr["USUARIO_NOMBRE"].ToString();
                            informeUsuarioMarcacion.mar_tipo = dr["MAR_TIPO"].ToString();
                            if (!string.IsNullOrEmpty(dr["MAR_FECHA"].ToString())) informeUsuarioMarcacion.mar_fecha = DateTime.Parse(dr["MAR_FECHA"].ToString());
                            if (!string.IsNullOrEmpty(dr["CLI_NOMBRE"].ToString())) informeUsuarioMarcacion.cli_nombre = dr["cli_nombre"].ToString();
                            if (!string.IsNullOrEmpty(dr["INS_NOMBRE"].ToString())) informeUsuarioMarcacion.ins_nombre = dr["INS_NOMBRE"].ToString();
                            if (!string.IsNullOrEmpty(dr["ARC_NOMBRE_ARCHIVO"].ToString())) informeUsuarioMarcacion.arc_nombre_archivo = dr["ARC_NOMBRE_ARCHIVO"].ToString();
                            if (!string.IsNullOrEmpty(dr["ARC_EXTENSION"].ToString())) informeUsuarioMarcacion.arc_extension = dr["ARC_EXTENSION"].ToString();
                            informeUsuarioMarcacion.abi_archivo_binario = (byte[])dr["ABI_ARCHIVO_BINARIO"];
                        }
                    }
                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    informeUsuarioMarcacion = null;
                }
            }
            return informeUsuarioMarcacion;
        }

        public void InformeInformeUsuarioMarcacion(InformeUsuarioMarcacion informeUsuarioMarcacion)
        {
            SqlCommand cmd = new SqlCommand();
            cmd.CommandText = "SEL_USUARIO_MARCACION";
            cmd.Parameters.AddWithValue("@EXCEL", true);
            if (informeUsuarioMarcacion.mar_id > 0) cmd.Parameters.AddWithValue("@ID", informeUsuarioMarcacion.mar_id);
            if (informeUsuarioMarcacion.id_cliente > 0) cmd.Parameters.AddWithValue("@ID_CLIENTE", informeUsuarioMarcacion.id_cliente);
            if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro)) cmd.Parameters.AddWithValue("@FILTRO", informeUsuarioMarcacion.filtro);
            if (informeUsuarioMarcacion.Desde != null) cmd.Parameters.AddWithValue("@DESDE", informeUsuarioMarcacion.Desde);
            if (informeUsuarioMarcacion.Hasta != null) cmd.Parameters.AddWithValue("@HASTA", informeUsuarioMarcacion.Hasta);
            if (informeUsuarioMarcacion.id_Monitor > 0) cmd.Parameters.AddWithValue("@USUARIO", informeUsuarioMarcacion.id_Monitor);
            if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_paises)) cmd.Parameters.AddWithValue("@PAISES", informeUsuarioMarcacion.filtro_paises);
            if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_estado)) cmd.Parameters.AddWithValue("@FILTRO_ESTADO", informeUsuarioMarcacion.filtro_estado);
            if (informeUsuarioMarcacion.id_Instalacion > 0) cmd.Parameters.AddWithValue("@INSTALACION", informeUsuarioMarcacion.id_Instalacion);
            if (informeUsuarioMarcacion.usuario > 0) cmd.Parameters.AddWithValue("@ADMINISTRATIVO", informeUsuarioMarcacion.usuario);
            if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_cliente)) cmd.Parameters.AddWithValue("@FILTRO_CLIENTE", informeUsuarioMarcacion.filtro_cliente);
            if (!string.IsNullOrEmpty(informeUsuarioMarcacion.filtro_instalacion)) cmd.Parameters.AddWithValue("@FILTRO_INSTALACION", informeUsuarioMarcacion.filtro_instalacion);

            string filename = "INFORME INFORME USUARIO MARCACION - " + DateTime.Now;
            Tools.Excel.exportExcel(Conexion.GetDataTable(cmd), filename, true);
        }

    }
}