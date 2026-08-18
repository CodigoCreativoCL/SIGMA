using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using Telerik.Web.UI;
using System.Web.UI.WebControls;
using System.Configuration;
using System.Data.SqlClient;


namespace Telerik.Web.UI
{

    public class RadEditor2 : Telerik.Web.UI.RadEditor
    {
        public bool ReadOnly
        {
            get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
            set { ViewState["ReadOnly"] = value; }
        }


        public RadEditor2(): base()
        {
            this.ToolsFile = "~/App_code/Telerik/xml/BasicTools.xml";
        }

        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {

            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.Content));

                this.Visible = false;
                this.Style.Add("display", "none !important");

                base.Render(writer);


            }
            else
            {
                base.Render(writer);
            }

        }

    }

}
