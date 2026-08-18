using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.UI.WebControls;

namespace Library.Web.UI.WebControls
{
    public class CodigoBarra : System.Web.UI.WebControls.Label
    {
                

        //public CodigoBarra()
        //{
        //    this.Font.Name = "Code 2 de 5 entrelacé";
        //}

        protected override void OnPreRender(System.EventArgs e)
        {
            Tools.CodigoBarra _CodigoBarra = new Tools.CodigoBarra();

            if (this.Text != "")
                this.Text = _CodigoBarra.strWriteI2of5(this.Text, false);
        }
       

    }


}
