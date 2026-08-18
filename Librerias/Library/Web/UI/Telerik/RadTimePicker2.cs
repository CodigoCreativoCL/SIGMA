using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.ComponentModel;
using System.Globalization;


namespace Telerik.Web.UI
{

    public class RadTimePicker2 : Telerik.Web.UI.RadTimePicker
    {
        public bool ReadOnly
        {
            get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
            set { ViewState["ReadOnly"] = value; }
        }

        public RadTimePicker2() : base()
        {

            this.Skin = "Bootstrap";
            this.TimeView.Interval = new TimeSpan(0, 15, 0);
            this.TimeView.StartTime = new TimeSpan(8, 0, 0);
            this.TimeView.EndTime = new TimeSpan(21, 0, 0);
            this.Width = 100;
        }
        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {

            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.SelectedTime.ToString()));

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