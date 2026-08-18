using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using SitioBase.Model;

namespace SitioBase.Controller
{
    public class SqLiteController
    {

        public List<SqLite> GetSqLtes(SqLite sqLite)
        {
            List<SqLite> sqLites = new List<SqLite>();

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_SQLITE";
                   


                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        while (dr.Read())
                        {
                            sqLite = new SqLite();

                            sqLite.sql_id = int.Parse(dr["SQL_ID"].ToString());
                            sqLite.sql_usuario = int.Parse(dr["SQL_USUARIO"].ToString());
                            sqLite.sql_fecha_creacion = DateTime.Parse(dr["SQL_FECHA_CREACION"].ToString());
                            sqLite.usuario_nombre = dr["USU_NOMBRE"].ToString() + " " + dr["USU_APELLIDO_PATERNO"].ToString() + " " + dr["USU_APELLIDO_MATERNO"].ToString();
                            
                            sqLites.Add(sqLite);
                        }
                    }

                    cmd.Connection.Close();
                    cmd.Dispose();
                }
                catch (Exception ex)
                {
                    cmd.Connection.Close();
                    cmd.Dispose();

                    sqLites = null;
                }
            }

            return sqLites;
        }

        public void DownloadSqLte(SqLite sqLite)
        {

            if (Token.TokenSeguridad())
            {
                SqlCommand cmd = new SqlCommand();

                try
                {
                    cmd.CommandText = "SEL_SQLITE";
                    cmd.Parameters.AddWithValue("@ID", sqLite.sql_id);
                    

                    using (SqlDataReader dr = Conexion.GetDataReader(cmd))
                    {
                        if (dr.Read())
                        {
                            sqLite = new SqLite();

                            sqLite.sql_id = int.Parse(dr["SQL_ID"].ToString());
                            sqLite.sql_usuario = int.Parse(dr["SQL_USUARIO"].ToString());
                            sqLite.sql_fecha_creacion = DateTime.Parse(dr["SQL_FECHA_CREACION"].ToString());
                            sqLite.usuario_nombre = dr["USU_NOMBRE"].ToString() + " " + dr["USU_APELLIDO_PATERNO"].ToString() + " " + dr["USU_APELLIDO_MATERNO"].ToString();
                            sqLite.base_sqlite = (byte[])dr["SQL_BINARIO"];


                            HttpContext.Current.Response.Clear();
                            HttpContext.Current.Response.Charset = "";
                            //HttpContext.Current.Response.ContentType = dr["ARC_CONTENIDO"].ToString();
                            HttpContext.Current.Response.AddHeader("content-disposition", "attachment; filename=" + sqLite.usuario_nombre + "_" + sqLite.sql_fecha_creacion + ".db3");
                            HttpContext.Current.Response.BinaryWrite(sqLite.base_sqlite);
                            HttpContext.Current.Response.End();



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

        }

       
    }
}