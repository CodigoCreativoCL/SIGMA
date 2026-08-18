using Microsoft.VisualBasic;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;

namespace WebControls
{

    public class CheckBox2 : System.Web.UI.WebControls.CheckBox
    {
        private bool _checked;
        public CheckBox2()
        {
            _checked = base.Checked;
            this.CssClass = "CheckBox";
        }

        public bool ReadOnly
        {
            get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
            set { ViewState["ReadOnly"] = value; }
        }

        public bool Lock
        {
            get { return Convert.ToBoolean(ViewState["Lock"]); }
            set { ViewState["Lock"] = value; }
        }

        public object dbChecked
        {
            get { return (this.Checked ? 1 : 0); }
            set
            {
                if (value.GetType().Equals(DBNull.Value.GetType()))
                {
                    this.Checked = false;
                }
                else if (object.ReferenceEquals(value.GetType(), typeof(bool)))
                {
                    this.Checked = Convert.ToBoolean(value);
                }
                else if (object.ReferenceEquals(value.GetType(), typeof(int)) && value == "1")
                {
                    this.Checked = true;
                }
                else
                {
                    this.Checked = false;
                }
            }
        }


        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
            this.Enabled = !(this.ReadOnly | this.Lock);

            base.Render(writer);

        }

    }

}
