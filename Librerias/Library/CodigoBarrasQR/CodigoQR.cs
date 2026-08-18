using QRCoder;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.UI.WebControls;

namespace CodigoBarrasQR
{
    public static class CodigoQR
    {

        public static string Codigo(string strCodigo)
        {
            string base64String = "";

            if (strCodigo != "")
            {
                //Aca debe ocurrir la magia verdara

                string code = strCodigo;
                QRCodeGenerator qrGenerator = new QRCodeGenerator();
                QRCodeGenerator.QRCode qrCode = qrGenerator.CreateQrCode(code, QRCodeGenerator.ECCLevel.H);
                
                using (Bitmap bitMap = qrCode.GetGraphic(5))
                {
                    

                    using (MemoryStream ms = new MemoryStream())
                    {
                        bitMap.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                        byte[] byteImage = ms.ToArray();
                        base64String = Convert.ToBase64String(byteImage);
                        
                    }
                    
                }

            }

            return base64String;
        }

    }
}
