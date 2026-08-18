using Telerik.Web.UI;

namespace Telerik.Web.UI
{

	public class RadToolTipManager2 : RadToolTipManager
	{
		public RadToolTipManager2() : base()
		{
			//this.Skin = "Web20";
            this.Skin = "Default";
			this.ShowCallout = true;
			this.Position = ToolTipPosition.MiddleRight;
			this.RelativeTo = ToolTipRelativeDisplay.Element;
			this.ManualClose = true;

			this.ShowEvent = ToolTipShowEvent.OnClick;
		}

	}

	public class RadToolTip2 : RadToolTip
	{

		public RadToolTip2() : base()
		{
			//this.Skin = "Web20";
            this.Skin = "Default";
			this.ShowCallout = true;
			this.Position = ToolTipPosition.MiddleRight;
			this.RelativeTo = ToolTipRelativeDisplay.Element;
			this.ManualClose = true;

			this.ShowEvent = ToolTipShowEvent.OnClick;
		}

	}

}
