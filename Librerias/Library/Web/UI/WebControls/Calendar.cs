using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;
using System.Web;
using System.Data.SqlClient;

namespace WebControls
{

    public class Calendar : Library.Web.UI.WebControls.DateBox
    {

        public bool ValidaFeriados
        {
            get
            {
                object o = ViewState["ValidaMaxLength"];
                return ((o != null) ? Convert.ToBoolean(o) : true);
            }
            set { ViewState["ValidaMaxLength"] = value; }
        }
        
        public Calendar()
        {
            RJS.Web.WebControl.PopCalendar.JavaScriptCustomPath = HttpContext.Current.Request.ApplicationPath + "/CSS/UI/WebControls/calendar";
            this.CssClass = "form-control";
            this.Style.Add("width", "95px !important");
            this.Style.Add("display", "inline !important");
        }

       
        protected override void OnPreRender(System.EventArgs e)
        {
            base.OnPreRender(e);
        }


        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
            //this.Attributes.Add("onBlur", "validaFecha(" + this.ClientID + ");");
            this.Calendar.StartAt = RJS.Web.WebControl.PopCalendar.StartAtEnum.Monday;

            this.MaxLength = 10;

            //Agregar Feriados
            //if (ValidaFeriados)
            //{
            //    using (SqlDataReader drFeriados = Conexion.GetDataReader("SEL_FERIADOS"))
            //    {
            //        while (drFeriados.Read())
            //        {
            //            DateTime fecha = DateTime.Parse(drFeriados["FRD_FECHA_FERIADOS"].ToString());
            //            this.Calendar.AddHoliday(fecha.Day, fecha.Month, fecha.Year, drFeriados["FRD_DESCRIPCION"].ToString());
            //        }
            //    }
            //}

            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.Text));

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