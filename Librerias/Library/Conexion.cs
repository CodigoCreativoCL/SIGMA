using System;
using System.Collections;
using System.Configuration;
using System.Data;
using System.Data.Common;
using System.Data.SqlClient;
using System.Runtime.CompilerServices;

public class Conexion
{
   
    //obtiene el AplicationName
    public static string GetApplicationName(string conectionString = "")
    { 
        string str2 = "";
        
        if(conectionString == "")
            str2 = ConfigurationManager.AppSettings["DefaultConnectionStringName"];
        else
            str2 = ConfigurationManager.AppSettings[conectionString];
        
        if (str2 == null)
            throw new Exception("No esta definido el atributo \'ApplicationName\' en appSettings del archivo web.config.");
        else
            return str2;
    }

    //Obtiene el ConnectionString
    public static string GetConnectionString(string conectionString = "")
    {
        try
        {
            string str2 = ConfigurationManager.ConnectionStrings[GetApplicationName(conectionString)].ToString();
            return str2;
        }
        catch (Exception)
        {
            throw new Exception("No se puede Obtener el ConnectionSting data.config");
        }
    }

    //Ejecuto el GetDataReder
    public static SqlDataReader GetDataReader(SqlCommand cmdExecute, string conectionString = "")
    {
        //obtengo el ConnectionString
        string Conn = GetConnectionString(conectionString);
        SqlDataReader sqlDataReader1 = null;
        SqlConnection sqlConnection = new SqlConnection(Conn);

        try
        {

            sqlConnection.Open();
            cmdExecute.Connection = sqlConnection;
            cmdExecute.CommandType = CommandType.StoredProcedure;
            sqlDataReader1 = cmdExecute.ExecuteReader(CommandBehavior.CloseConnection);

            return sqlDataReader1;
        }
        catch (Exception ex)
        {
            if (sqlDataReader1 != null)
            {
                sqlConnection.Close();
                sqlDataReader1.Close();
                sqlDataReader1.Dispose();
                sqlConnection.Close();
                sqlConnection.Dispose();
            }
            throw new Exception(ex.Message);
        }

    }

    //Ejecuto el GetDataReder
    public static SqlDataReader GetDataReader(string SQL, string conectionString = "")
    {
        //obtengo el ConnectionString
        string Conn = GetConnectionString(conectionString);
        SqlDataReader sqlDataReader1 = null;
        SqlConnection sqlConnection = new SqlConnection(Conn);
        try
        {
            sqlConnection.Open();
            sqlDataReader1 = new SqlCommand(SQL, sqlConnection).ExecuteReader(CommandBehavior.CloseConnection);
            return sqlDataReader1;
        }
        catch (Exception ex)
        {
            if (sqlDataReader1 != null)
            {
                sqlDataReader1.Close();
                sqlDataReader1.Dispose();
                sqlConnection.Close();
                sqlConnection.Dispose();
            }
            throw new Exception(ex.Message);
        }

    }

    //Ejecuta el GetCommand
    public static SqlCommand GetCommand(string SQL, string conectionString = "")
    {
        try
        {
            //obtengo el ConnectionString
            string Conn = GetConnectionString(conectionString);

            SqlConnection sqlConnection = new SqlConnection(Conn);
            sqlConnection.Open();
            SqlCommand sqlCommand2 = new SqlCommand(SQL, sqlConnection);
            sqlCommand2.CommandType = CommandType.StoredProcedure;
            return sqlCommand2;
        }
        catch (Exception ex)
        {
            throw new Exception(ex.Message);
        }
    }

    //Data Table
    public static DataTable GetDataTable(SqlCommand cmdExecute, string conectionString = "")
    {
        try
        {
            //obtengo el ConnectionString
            string Conn = GetConnectionString(conectionString);

            SqlConnection sqlConnection = new SqlConnection(Conn);
            sqlConnection.Open();
            cmdExecute.Connection = sqlConnection;
            cmdExecute.CommandType = CommandType.StoredProcedure;
      
            DataTable dt = new DataTable();

            using (SqlDataAdapter adpTable = new SqlDataAdapter(cmdExecute))
            {
                adpTable.Fill(dt);
            }            
            cmdExecute.Dispose();
            sqlConnection.Close();
            return dt;
        }
        catch (Exception ex)
        {
            throw new Exception(ex.Message);
        }
    }

    public static DataTable GetDataTable(string SQL, string conectionString = "")
    {
        try
        {
            //obtengo el ConnectionString
            string Conn = GetConnectionString(conectionString);

            DataTable dt = new DataTable();

            using (SqlDataAdapter adpTable = new SqlDataAdapter(SQL, Conn))
            {
                adpTable.Fill(dt);
            }
            return dt;
        }
        catch (Exception ex)
        {
            throw new Exception(ex.Message);
        }
    }

    //Ejecuta insert Bulk
    public static SqlBulkCopy InsertSqlBulkCopy(DataTable dataTable, string tabla, string conectionString = "")
    {
        try
        {
            //obtengo el ConnectionString
            string Conn = GetConnectionString(conectionString);

            SqlConnection sqlConnection = new SqlConnection(Conn);
            sqlConnection.Open();

            SqlBulkCopy sqlBulk2 = new SqlBulkCopy(sqlConnection);
            sqlBulk2.BulkCopyTimeout = 999999999;
            sqlBulk2.DestinationTableName = tabla;
            sqlBulk2.WriteToServer(dataTable);
            sqlConnection.Close();

            return sqlBulk2;
        }
        catch (Exception ex)
        {
            throw new Exception(ex.Message);
        }
    }

}
