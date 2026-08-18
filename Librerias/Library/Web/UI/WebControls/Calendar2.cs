using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;
using System.Web;
using System.Data.SqlClient;
using Telerik.Web.UI;
using Telerik.Web.UI.Calendar.View;
using System.Globalization;

namespace WebControls
{
    public class Calendar2 : RadDatePicker
    {
        private const string DefaultFormatString = "dd-MM-yyyy";

        public string FormatString
        {
            get
            {
                string objeto = Convert.ToString(ViewState["FormatString"]);
                if (string.IsNullOrEmpty(objeto))
                    objeto = DefaultFormatString;
                return objeto;
            }
            set { ViewState["FormatString"] = value; }
        }

        public bool ValidaFeriados
        {
            get
            {
                object objeto = ViewState["ValidaFeriados"];
                return ((objeto != null) ? Convert.ToBoolean(objeto) : true);
            }
            set { ViewState["ValidaFeriados"] = value; }
        }

        public bool ReadOnly
        {
            get
            {
                object objeto = ViewState["ReadOnly"];
                return ((objeto != null) ? Convert.ToBoolean(objeto) : false);
            }
            set { ViewState["ReadOnly"] = value; }
        }

        public object DbValue
        {
            get { return SelectedDate; }

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

                        this.SelectedDate = new DateTime(datetime__1.Year, datetime__1.Month, datetime__1.Day, datetime__1.Hour, datetime__1.Minute, datetime__1.Second, datetime__1.Millisecond, DateTimeKind.Unspecified);

                    }
                    else
                    {
                        this.SelectedDate = null;
                    }

                }
                else if (SelectedDate == null)
                {
                    this.SelectedDate = null;

                }
                else
                {
                    this.SelectedDate = (System.Nullable<DateTime>)value;

                }
            }
        }

        public string Text
        {
            get { return SelectedDate.ToString(); }

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

                        this.SelectedDate = new DateTime(datetime__1.Year, datetime__1.Month, datetime__1.Day, datetime__1.Hour, datetime__1.Minute, datetime__1.Second, datetime__1.Millisecond, DateTimeKind.Unspecified);

                    }
                    else
                    {
                        this.SelectedDate = null;
                    }

                }
                else if (SelectedDate == null)
                {
                    this.SelectedDate = null;

                }
                else
                {
                    this.SelectedDate = null;

                }
            }
        }

        public DateTime? Value
        {
            get { return SelectedDate; }
            set { SelectedDate = value; }
        }

        public Calendar2() : base()
        {
            this.Skin = "Office2007";
        }

        protected override void OnPreRender(System.EventArgs e)
        {
            base.OnPreRender(e);
        }

        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
            this.Calendar.FirstDayOfWeek = System.Web.UI.WebControls.FirstDayOfWeek.Monday;

            //if (ValidaFeriados)
            //{
            //    using (SqlDataReader drFeriados = Conexion.GetDataReader("SEL_FERIADOS"))
            //    {
            //        while (drFeriados.Read())
            //        {
            //            DateTime fecha = DateTime.Parse(drFeriados["FRD_FECHA_FERIADOS"].ToString());
            //            string descripcion = drFeriados["FRD_DESCRIPCION"].ToString();

            //            RadCalendarDay holiday = new RadCalendarDay();
            //            holiday.Date = fecha;
            //            holiday.ToolTip = descripcion;
            //            holiday.ItemStyle.BackColor = System.Drawing.Color.IndianRed;
            //            this.Calendar.SpecialDays.Add(holiday);
            //        }
            //    }
            //}

            if (this.ReadOnly)
            {
                if (SelectedDate.HasValue)
                    writer.Write(string.Format("<span>{0}</span>", SelectedDate.Value.ToShortDateString()));
                else
                    writer.Write(string.Format("<span>{0}</span>", string.Empty));

                this.Visible = false;
                this.Style.Add("display", "none");

                base.Render(writer);
            }
            else
            {
                base.Render(writer);
            }
        }
    }
}