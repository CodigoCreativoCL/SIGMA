
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.IO;
using System.Globalization;



namespace Library.Web.UI.WebControls
{

    [ToolboxData("<{0}:DateBox runat=\"server\"> </{0}:DateBox>")]
    public class DateBox : InputBox
    {


        private RJS.Web.WebControl.PopCalendar _Calendar;

        #region " Propiedades "

        private const string DefaultFormatString = "dd-MM-yyyy";

        private const string DbFormatString = "yyyyMMdd";

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
                if ((Text == null) || (Text == String.Empty))
                {
                    return null;
                }
                else
                {
                    return DateTime.ParseExact(Text, this.FormatString, DateTimeFormatInfo.InvariantInfo);
                }
            }
            set
            {
                if (value.HasValue)
                {
                    base.Text = value.Value.ToString(this.FormatString, DateTimeFormatInfo.InvariantInfo);
                }
                else
                {
                    base.Text = null;
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

        protected virtual DateTime TruncateTimeComponent(DateTime value)
        {
            return value.Subtract(value.TimeOfDay);
        }



        public bool Today
        {
            get { return Convert.ToBoolean(ViewState["Today"]); }
            set { ViewState["Today"] = value; }
        }

        #endregion

        #region " Procedures "


        #endregion

        #region " Overrides "

        public DateBox()
            : base()
        {

            //this.Width = Unit.Pixel(80);

        }

        protected override void OnInit(System.EventArgs e)
        {
            base.OnInit(e);

            if (_Calendar == null)
            {
                this.AddCalendarControl();
            }

        }


        protected override void OnPreRender(System.EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                if (Today & Text.Length == 0)
                {
                    Text = String.Format(FormatString, DateTime.Now);
                }
            }

            base.OnPreRender(e);

        }


        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
            //base.Render(writer);
            base.RenderInputBox(writer);

            if ((_Calendar != null))
            {
                _Calendar.RenderControl(writer);
            }

            base.RenderValidator(writer);

        }

        protected override void OnLoad(System.EventArgs e)
        {
            base.OnLoad(e);

        }

        #endregion

        #region " Calendar "

        /// <summary>
        /// Obtiene la instancia del control PopCalendar.
        /// </summary>
        [Browsable(true)]
        [Description("Obtiene la instancia del control PopCalendar.")]
        [NotifyParentProperty(true)]
        [DesignerSerializationVisibility(DesignerSerializationVisibility.Content)]
        [PersistenceMode(PersistenceMode.InnerProperty)]
        public RJS.Web.WebControl.PopCalendar Calendar
        {
            get
            {
                if (_Calendar == null)
                {
                    AddCalendarControl();
                }
                return _Calendar;
            }
        }

        private void AddCalendarControl()
        {
            _Calendar = new RJS.Web.WebControl.PopCalendar();

            var _with1 = _Calendar;

            _with1.ID = this.ID + "_PopCalendar";
            _with1.Control = this.ID;

            _with1.TodayText = "Hoy es [Today]";
            _with1.SelectDateText = "Seleccionar [Date]";
            //.RequiredDate = True
            //.RequiredDateMessage = "La Fecha es Requerida"
            _with1.From.Message = "&nbsp";
            _with1.To.Message = "&nbsp";
            _with1.InvalidDateMessage = "&nbsp";
            _with1.HolidayMessage = "No puede seleccionar Días Feriados";
            _with1.WeekendMessage = "No puede seleccionar Fines de Semana";
            _with1.ToolTip = "Seleccione una Fecha. Formato: ([Format])";
            _with1.SelectHoliday = true;
            _with1.SelectWeekend = true;
            _with1.ShowGoodFriday = "Feriado";
            _with1.GoodFridayText = "Viernes Santo";
            _with1.Shadow = true;
            _with1.ShowWeekend = true;
            _with1.Move = true;
            _with1.Format = "dd MM yyyy";
            _with1.Separator = "-";
            _with1.MessageAlignment = RJS.Web.WebControl.PopCalendar.MessageAlignmentEnum.RightCalendarControl;
            _with1.ShowBlankFieldText = true;
            _with1.BlankFieldText = "[ Borrar Campo ]";
            _with1.ShowDaysOutOfMonth = true;
            _with1.WeekNumberFormula = RJS.Web.WebControl.PopCalendar.WeekNumberFormulaEnum.AlwaysJanuary1IsWeek1;

            _with1.Style.Add("padding-left", "3px");


            this.Controls.Add(_Calendar);

        }

        #endregion

    }

}

