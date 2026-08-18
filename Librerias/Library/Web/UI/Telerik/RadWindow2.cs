using Telerik.Web.UI;
using System.Web.UI.WebControls;
using System;
using System.Text;


namespace Telerik.Web.UI
{

    public class RadWindow2 : RadWindow
    {
  
        public RadWindow2() : base()
        {
            this.EnableEmbeddedSkins = true;
            this.Skin = "Bootstrap";

            this.Modal = true;
            this.VisibleStatusbar = false;
            this.VisibleOnPageLoad = false;
            this.Behaviors = WindowBehaviors.Move | WindowBehaviors.Resize | WindowBehaviors.Maximize | WindowBehaviors.Close;
            //this.Behaviors = WindowBehaviors.Close;
            //this.Width = 900;
            //this.Height = 650;

            this.OnClientShow = "OnClientShow";
            this.OnClientActivate = "OnClientActivate";
            this.OnClientClose = "bloqueaScroll";
        }

    }

}