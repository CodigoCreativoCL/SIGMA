using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CodigoBarrasQR
{
    public static class CodigoBarras
    {

        public static string Codigo(string strCodigo)
        {
            string base64String = "";

            if (strCodigo != "")
            {
                //Aca debe ocurrir la magia verdara

                LabelKit.BarcodeGenerator code = new LabelKit.BarcodeGenerator();
                System.Drawing.Graphics g = Graphics.FromImage(new Bitmap(1, 1));
                System.Drawing.Bitmap bmp = new System.Drawing.Bitmap(1, 1, PixelFormat.Format32bppArgb);

                g = Graphics.FromImage(bmp);

                Image imgCodigo = code.DrawCode128(g, strCodigo, 0, 0);

                using (MemoryStream m = new MemoryStream())
                {
                    imgCodigo.Save(m, ImageFormat.Png);
                    byte[] imageBytes = m.ToArray();

                    // Convert byte[] to Base64 String
                    base64String = Convert.ToBase64String(imageBytes);
                } 

            }

            return base64String;
        }

    }
}
