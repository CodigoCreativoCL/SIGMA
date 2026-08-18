using System.IO;
using Telerik.Web.UI;

namespace Telerik.Web.UI
{

    public class RadUpload2  : RadUpload 
    {
        public RadUpload2() : base()
        {
            this.Skin = "Vista";
            this.EnableEmbeddedSkins = true;
            
            // Traduccion
            this.Localization.Add = "Agregar";
            this.Localization.Select = "Examinar";
            this.Localization.Remove = "Remover";
            this.Localization.Delete = "Eliminar";
            
        }
    }

}
