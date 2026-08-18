using System.Web.UI;
using System.Web.UI.WebControls;
using System.ComponentModel;
using System;
using System.Linq;

namespace Telerik.Web.UI
{

    public class RadComboBox2 : RadComboBox
    {

        public virtual bool ReadOnly { get; set; }

        [Bindable(BindableSupport.Yes, BindingDirection.TwoWay)]
        public string dbValues()
        {
            string values = "";

            foreach (RadComboBoxItem item in this.CheckedItems)
            {
                values += item.Value + ",";
            }

            if (values != "")
                values = values.Remove(values.Length - 1, 1);

            return values;
        }

        [Bindable(BindableSupport.Yes, BindingDirection.TwoWay)]
        public void SetValues(string values)
        {
            if (values.Length > 0)
            {
                foreach (string value in values.Split(','))
                {
                    RadComboBoxItem item = this.Items.Where(x => x.Value == value).FirstOrDefault();
                    if (item != null) item.Checked = true;
                }
            }
        }

        public RadComboBox2() : base()
        {
            this.Skin = "Bootstrap";
            this.CssClass = "RadComboBox_Bootstrap";

            this.Localization.CheckAllString = "Seleccionar Todos";
            this.Localization.AllItemsCheckedString = "Todos Seleccionados";
            this.Localization.ItemsCheckedString = "Seleccionados";
            this.ExpandAnimation.Type = AnimationType.None;
            this.CollapseAnimation.Type = AnimationType.None;
        }

        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.Text));

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
