using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI.HtmlControls;


namespace Telerik.Web.UI
{

    public class RadScheduler2 : Telerik.Web.UI.RadScheduler
    {

        public RadScheduler2()  : base()
        {

            this.EnableEmbeddedSkins = false;
            this.CssClass = "RadScheduler_Default";

            this.Localization.HeaderToday = "Hoy";
            this.Localization.HeaderDay = "Dia";
            this.Localization.HeaderWeek = "Semana";
            this.Localization.HeaderMonth = "Mes";
            this.Localization.Show24Hours = "Mostrar 24 horas...";
            this.Localization.ShowBusinessHours = "Mostrar horario oficina...";

            this.MultiDayView.UserSelectable = false;
            this.DayView.UserSelectable = true;
            this.WeekView.UserSelectable = true;
            this.MonthView.UserSelectable = true;
            this.TimelineView.UserSelectable = false;

            this.ShowFullTime = false;
            this.WorkDayStartTime = TimeSpan.Parse("08:00");
            this.WorkDayEndTime = TimeSpan.Parse("19:00");
            this.DayStartTime = TimeSpan.Parse("08:00");
            this.DayEndTime = TimeSpan.Parse("19:00");
            this.FirstDayOfWeek = DayOfWeek.Monday;
            this.LastDayOfWeek = DayOfWeek.Sunday;
            this.HoursPanelTimeFormat = "HH:mm tt";

        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            HtmlMeta hm = new HtmlMeta();
            hm.HttpEquiv = "X-UA-Compatible";
            hm.Content = "IE=7";
            Page.Header.Controls.Add(hm);
        }
    }

}