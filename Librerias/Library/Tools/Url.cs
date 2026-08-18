using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Web;
using Microsoft.VisualBasic;



static class Utility
{

    public static string ResolveFullUrl(string PageUrl)
    {

        HttpRequest request = HttpContext.Current.Request;
        if (request != null)
        {
            string absUrl = string.Empty;
            Uri url = request.Url;
            string host = url.DnsSafeHost;
            string appPath = request.ApplicationPath;
            absUrl = string.Format("http://{0}{1}{2}", host, appPath, PageUrl).Replace("~", "");
            return absUrl;
        }
        else
        {
            return PageUrl;
        }

    }

}

