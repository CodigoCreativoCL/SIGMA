using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Data.SqlClient;
using System.Web;


public class Global_asax : System.Web.HttpApplication
{

	public void Application_Start(object sender, EventArgs e)
	{
        //// Code that runs on application startup
        //Application["app_inicio"] = DateTime.Now;
        //Application["app_sesiones"] = 0;
        //Application["app_usuarios"] = 0;
	}

	public void Application_End(object sender, EventArgs e)
	{
		// Code that runs on application shutdown
	}

	public void Application_Error(object sender, EventArgs e)
	{
		// Code that runs when an unhandled error occurs
	}

	public void Session_Start(object sender, EventArgs e)
	{
        //// Code that runs when a new session is started
        //// NOTA: Se incrementa este valor en la autenticacion del usuario
        //// Application("app_usuarios") += 1
        //Application.Lock();
        
        //Application.UnLock();

        //Application.Lock();
        //Application["app_sesiones"] = (Int32.Parse(Application["app_sesiones"].ToString()) + 1);
        //Application.UnLock();
        
	}

	public void Session_End(object sender, EventArgs e)
	{
		// Code that runs when a session ends. 
		// Note: The Session_End event is raised only when the sessionstate mode
		// is set to InProc in the Web.config file. If session mode is set to StateServer 
		// or SQLServer, the event is not raised.
        //Application.Lock();
        //Application["app_sesiones"] -= 1;
        //if (!Session.IsNewSession) {
        //    Application["app_usuarios"] -= 1;
        //}
        //Application.UnLock();

        //Application.Lock();
        //Application["app_sesiones"] = (Int32.Parse(Application["app_sesiones"].ToString()) - 1);
        //Application.UnLock();

     
	}


    protected void Application_BeginRequest(object sender, System.EventArgs e)
    {
        if ((HttpContext.Current != null))
        {
            HttpContext.Current.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
            HttpContext.Current.Response.AddHeader("Access-Control-Allow-Headers", "*");
           //// HttpContext.Current.Response.AddHeader("Access-Control-Allow-Credentials", "true");
            HttpContext.Current.Response.AddHeader("Access-Control-Allow-Origin", "*");
            HttpContext.Current.Response.AddHeader("Access-Control-Expose-Headers", "TestHeaderToExpose");
           // HttpContext.Current.Response.End();
        }
    }

}
