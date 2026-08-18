using Telerik.Web.UI;

namespace Telerik.Web.UI
{

	public class RadTabStrip2 : RadTabStrip
	{

		public RadTabStrip2() : base()
		{
			//this.CausesValidation = false;
			//         this.EnableEmbeddedSkins = false;
			//         this.CssClass = "RadTabStrip_Default";

			//this.Skin = "Bootstrap";
			this.Skin = "Default";
		}

		protected override void OnInit(System.EventArgs e)
		{
			base.OnInit(e);
		}
        
		protected override void OnPreRender(System.EventArgs e)
		{
			if (this.Tabs.Count > 1 & this.SelectedIndex == -1) {
				this.SelectedIndex = 0;
			}

			base.OnPreRender(e);
		}

		public Tab2 AddTab(string Text, string Description = "", string URL = "", string ImagenURL = "", string OnClienClick = "", string Target = "", string Value = "")
		{
			Tab2 tabItem = new Tab2();

			this.Tabs.Add(tabItem);

			tabItem.Text = Text;
			tabItem.NavigateUrl = URL;
			tabItem.ToolTip = Description;
			tabItem.Attributes["onclick"] = OnClienClick;
			tabItem.Target = Target;
			tabItem.Value = Value;

			return tabItem;
		}

	}

    public class Tab2 : RadTab
    {

        public void AddTab(string Text, string Description = "", string URL = "", string ImagenURL = "", string OnClienClick = "", string Target = "")
        {
            RadTab tabItem = new RadTab();

            this.Tabs.Add(tabItem);

            tabItem.Text = Text;
            tabItem.NavigateUrl = URL;
            tabItem.ToolTip = Description;
            tabItem.Attributes["onclick"] = OnClienClick;
            tabItem.Target = Target;

        }

    }

}
