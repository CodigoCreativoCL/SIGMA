using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;

namespace WebControls
{

    public class ComboBox2 : Library.Web.UI.WebControls.ComboBox
    {

        public ComboBox2()
        {
            this.CssClass = "Textbox";
        }

        public bool Lock
        {
            get { return Convert.ToBoolean(ViewState["Lock"]); }
            set { ViewState["Lock"] = value; }
        }

        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {

            if (this.ReadOnly | this.Lock)
            {
                if (this.SelectedItem != null)
                {
                    writer.Write(string.Format("<span{0}>{1}</span>", (!string.IsNullOrEmpty(this.DisabledCssClass) ? " class='" + this.DisabledCssClass + "'" : ""), this.SelectedItem.Text));
                }

                this.Visible = false;
                this.Style.Add("display", "none");

                base.Render(writer);

            }
            else
            {
                base.Render(writer);
            }

        }

        public string dbValue
        {
            get { return this.Value; }
            set
            {
                try
                {
                    this.CreateChildControls();
                    this.Value = value;

                }
                catch (Exception ex)
                {
                }
            }
        }

    }

}
