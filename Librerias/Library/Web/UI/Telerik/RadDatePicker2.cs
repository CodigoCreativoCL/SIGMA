using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.ComponentModel;
using System.Globalization;


namespace Telerik.Web.UI
{

    public class RadDatePicker2 : Telerik.Web.UI.RadDatePicker
    {
        private const string DefaultFormatString = "dd-MM-yyyy";

        public bool ReadOnly
        {
            get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
            set { ViewState["ReadOnly"] = value; }
        }

        public string FormatString
        {
            get
            {
                string f = Convert.ToString(ViewState["FormatString"]);
                if (string.IsNullOrEmpty(f))
                    f = DefaultFormatString;
                return f;
            }
            set { ViewState["FormatString"] = value; }
        }

        [Bindable(true, BindingDirection.TwoWay)]
        public virtual System.Nullable<DateTime> Value
        {
            get
            {
                if ((SelectedDate == null))
                {
                    return null;
                }
                else
                {
                    return DateTime.ParseExact(SelectedDate.ToString(), this.FormatString, DateTimeFormatInfo.InvariantInfo);
                }
            }
            set
            {
                if (value.HasValue)
                {
                    base.SelectedDate = value.Value;
                }
                else
                {
                    base.SelectedDate = null;
                }
            }
        }

        public object DbValue
        {
            get { return Value; }

            set
            {

                if (value is string)
                {
                    string sValue = Convert.ToString(value);

                    if (!string.IsNullOrEmpty(sValue + ""))
                    {
                        bool isParsed = false;

                        DateTime datetime__1 = default(DateTime);

                        isParsed = DateTime.TryParse(sValue, new CultureInfo("es-ES"), DateTimeStyles.None, out datetime__1);

                        if (!isParsed)
                        {
                            isParsed = DateTime.TryParse(sValue, DateTimeFormatInfo.InvariantInfo, DateTimeStyles.None, out datetime__1);
                        }

                        if (!isParsed)
                        {
                            isParsed = DateTime.TryParseExact(sValue, this.FormatString, DateTimeFormatInfo.InvariantInfo, DateTimeStyles.None, out datetime__1);
                        }

                        if (!isParsed)
                        {
                            isParsed = DateTime.TryParseExact(sValue, this.FormatString, new CultureInfo("es-ES"), DateTimeStyles.None, out datetime__1);
                        }

                        if (!isParsed)
                        {
                            isParsed = DateTime.TryParseExact(sValue, this.FormatString, DateTimeFormatInfo.InvariantInfo, DateTimeStyles.None, out datetime__1);
                        }

                        if (!isParsed)
                        {
                            isParsed = DateTime.TryParseExact(sValue, this.FormatString, new CultureInfo("es-ES"), DateTimeStyles.None, out datetime__1);
                        }

                        if (!isParsed)
                        {
                            throw new FormatException("The string was not recognized as a valid DateTime.");
                        }

                        this.Value = new DateTime(datetime__1.Year, datetime__1.Month, datetime__1.Day, datetime__1.Hour, datetime__1.Minute, datetime__1.Second, datetime__1.Millisecond, DateTimeKind.Unspecified);

                    }
                    else
                    {
                        this.Value = null;
                    }

                }
                else if (Value == null)
                {
                    this.Value = null;

                }
                else
                {
                    this.Value = (System.Nullable<DateTime>)value;

                }

            }
        }


        public RadDatePicker2() : base()
        {
                       

        }

        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {

            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.Value.ToString()));

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