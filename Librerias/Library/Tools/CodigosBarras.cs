using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.VisualBasic;
using Microsoft.VisualBasic.CompilerServices;

namespace Tools
{
    public class CodigoBarra
    {
        private string LstrFlag = "AAAAA,ABABB,ABBAB,ABBBA,BAABB,BBAAB,BBBAA,BABAB,BABBA,BBABA";
        private string LstrHeight = "25";
        private string LstrLeftA = "0001101,0011001,0010011,0111101,0100011,0110001,0101111,0111011,0110111,0001011";
        private string LstrLeftB = "0100111,0110011,0011011,0100001,0011101,0111001,0000101,0010001,0001001,0010111";
        private string LstrRight = "1110010,1100110,1101100,1000010,1011100,1001110,1010000,1000100,1001000,1110100";
        private string LstrWidth = "2";
        private string strFactor;

        private object LstrFindValue(int intCol, string strListIn, string strChar)
        {
            int num2 = 1;
            string str2 = "";
            int num4 = 1;
            string str = " " + strListIn;
            int num5 = Strings.Len(str);
            for (int i = 1; i <= num5; i++)
            {
                int num3 = Strings.InStr(i, str, strChar, 0);
                if (StringType.StrCmp(Strings.Mid(str, i, 1), strChar, false) == 0)
                {
                    if (num2 == intCol)
                    {
                        str2 = Strings.Mid(str, num4 + 1, (num3 - num4) - 1);
                        break;
                    }
                    num2++;
                    num4 = num3;
                    i = num4;
                }
                else if ((num2 == intCol) & (num3 == 0))
                {
                    str2 = Strings.Mid(str, num4 + 1);
                    break;
                }
            }
            return Strings.Trim(str2);
        }

        private string LstrWriteCode(string strCode)
        {
            string str2 = "";
            int num2 = Strings.Len(strCode);
            for (int i = 1; i <= num2; i++)
            {
                if (StringType.StrCmp(Strings.Mid(strCode, i, 1), "1", false) == 0)
                {
                    str2 = str2 + "<img src='Imagen/barra.gif' height=" + this.LstrHeight + " width=" + this.LstrWidth + ">";
                }
                else
                {
                    str2 = str2 + "<img src='Imagen/spacer.gif' height=" + this.LstrHeight + " width=" + this.LstrWidth + ">";
                }
            }
            return str2;
        }

        public object strDV(string strParidad, string strFlag, string strN)
        {
            string str2 = strFlag + strN;
            string str3 = StringType.FromInteger(0);
            string str = StringType.FromInteger(0);
            int num2 = Strings.Len(str2);
            for (int i = 1; i <= num2; i++)
            {
                str = StringType.FromDouble(DoubleType.FromString(str) + (DoubleType.FromString(Strings.Mid(str2, i, 1)) * (((i + DoubleType.FromString(strParidad)) + 1.0) % 2.0)));
                str3 = StringType.FromDouble(DoubleType.FromString(str3) + (DoubleType.FromString(Strings.Mid(str2, i, 1)) * ((i + DoubleType.FromString(strParidad)) % 2.0)));
            }
            return (10.0 - (((DoubleType.FromString(str3) * 3.0) + DoubleType.FromString(str)) % 10.0));
        }

        public string strWriteEAN13(string strFlag, string strN)
        {
            string str4 = "<table border=0 cellspacing=0 cellpadding=0><tr><td>";
            str4 = str4 + this.LstrWriteCode("101");
            string str = Strings.Right(strFlag, 1);
            string strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrLeftA, ","));
            str4 = str4 + this.LstrWriteCode(strCode);
            string str2 = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(Strings.Left(strFlag, 1)) + 1.0)), this.LstrFlag, ","));
            int num2 = Strings.Len(strN);
            for (int i = 1; i <= num2; i++)
            {
                str = Strings.Mid(strN, i, 1);
                if (i < 6)
                {
                    if (StringType.StrCmp(Strings.Mid(str2, i, 1), "A", false) == 0)
                    {
                        strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrLeftA, ","));
                    }
                    else
                    {
                        strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrLeftB, ","));
                    }
                }
                else
                {
                    strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrRight, ","));
                }
                str4 = str4 + this.LstrWriteCode(strCode);
                if (i == 5)
                {
                    str4 = str4 + this.LstrWriteCode("01010");
                }
            }
            str = StringType.FromObject(this.strDV("1", strFlag, strN));
            if (DoubleType.FromString(str) == 10.0)
            {
                str = StringType.FromInteger(0);
            }
            strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrRight, ","));
            str4 = str4 + this.LstrWriteCode(strCode) + this.LstrWriteCode("101");
            return ((str4 + "</tr><tr><td align=center><font align=center size=1px>&nbsp;" + Strings.Left(strFlag, 1) + "&nbsp;" + Strings.Right(strFlag, 1) + Strings.Mid(strN, 1, 5) + "&nbsp;" + Strings.Mid(strN, 6) + "&nbsp;" + str) + "</font></td></tr></table>");
        }

        public string strWriteEAN8(string strFlag, string strN)
        {
            string str3 = "<table border=0 cellspacing=0 cellpadding=0><tr><td>";
            str3 = str3 + this.LstrWriteCode("101");
            string str = Strings.Right(strFlag, 1);
            string strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrLeftA, ","));
            str3 = str3 + this.LstrWriteCode(strCode);
            int num2 = Strings.Len(strN);
            for (int i = 1; i <= num2; i++)
            {
                str = Strings.Mid(strN, i, 1);
                if (i < 4)
                {
                    strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrLeftA, ","));
                }
                else
                {
                    strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrRight, ","));
                }
                str3 = str3 + this.LstrWriteCode(strCode);
                if (i == 3)
                {
                    str3 = str3 + this.LstrWriteCode("01010");
                }
            }
            str = StringType.FromObject(this.strDV("0", strFlag, strN));
            if (DoubleType.FromString(str) == 10.0)
            {
                str = StringType.FromInteger(0);
            }
            strCode = StringType.FromObject(this.LstrFindValue((int)Math.Round((double)(DoubleType.FromString(str) + 1.0)), this.LstrRight, ","));
            str3 = str3 + this.LstrWriteCode(strCode) + this.LstrWriteCode("101");
            return ((str3 + "</tr><tr><td align=center><font align=center size=1px>" + strFlag + "&nbsp;" + Strings.Right(strFlag, 1) + Strings.Mid(strN, 1, 5) + "&nbsp;" + Strings.Mid(strN, 6) + "&nbsp;" + str) + "</font></td></tr></table>");
        }

        public string strWriteI2of5(string strN, bool blnWithDV)
        {
            int num;
            string str2 = "";
            string[] strArray = new string[] { "11221", "21112", "12112", "22111", "11212", "21211", "12211", "11122", "21121", "12121" };
            int num7 = 0;
            if (blnWithDV)
            {
                num7 = IntegerType.FromObject(this.strDV("0", "00", strN));
                if (num7 == 10)
                {
                    num7 = 0;
                }
                strN = strN + StringType.FromInteger(num7);
            }
            if ((Strings.Len(strN) % 2) != 0)
            {
                strN = "0" + strN;
            }
            int num9 = Strings.Len(strN);
            for (num = 1; num <= num9; num += 2)
            {
                int index = (int)Math.Round(Conversion.Val(Strings.Mid(strN, num, 1)));
                int num3 = (int)Math.Round(Conversion.Val(Strings.Mid(strN, num + 1, 1)));
                int num6 = 1;
                do
                {
                    str2 = str2 + Strings.Mid(strArray[index], num6, 1) + Strings.Mid(strArray[num3], num6, 1);
                    num6++;
                }
                while (num6 <= 5);
            }
            string strCode = "";
            int num8 = Strings.Len(str2);
            for (num = 1; num <= num8; num++)
            {
                if ((num % 2) == 0)
                {
                    if (Conversion.Val(Strings.Mid(str2, num, 1)) == 1.0)
                    {
                        strCode = strCode + "0";
                    }
                    else
                    {
                        strCode = strCode + "00";
                    }
                }
                else if (Conversion.Val(Strings.Mid(str2, num, 1)) == 1.0)
                {
                    strCode = strCode + "1";
                }
                else
                {
                    strCode = strCode + "11";
                }
            }
            string str = "<table border=0 cellspacing=0 cellpadding=0><tr><td>";
            str = (str + this.LstrWriteCode("1010")) + this.LstrWriteCode(strCode) + this.LstrWriteCode("1101");
            if (blnWithDV)
            {
                return (((str + "</tr><tr><td align=center><font align=center size=1px>&nbsp;" + Strings.Mid(strN, 1, Strings.Len(strN) - 1)) + "&nbsp;&nbsp;" + StringType.FromInteger(num7)) + "</font></td></tr></table>");
            }
            return ((str + "</tr><tr><td align=center><font align=center size=1px>&nbsp;" + strN) + "&nbsp;</font></td></tr></table>");
        }

        public string strWriteJAN13(string strN)
        {
            return this.strWriteEAN13("49", strN);
        }

        public string strWriteJAN8(string strN)
        {
            return this.strWriteEAN8("49", strN);
        }

        public string strWriteUPCA(string strN)
        {
            return this.strWriteEAN13("00", strN);
        }

        public double dblHeight
        {
            get
            {
                return Conversion.Val(this.LstrHeight);
            }
            set
            {
                this.LstrHeight = StringType.FromDouble(Conversion.Val(value.ToString().Replace(",", ".")));
            }
        }

        public double dblWidth
        {
            get
            {
                return Conversion.Val(this.LstrWidth);
            }
            set
            {
                this.LstrWidth = StringType.FromDouble(Conversion.Val(value.ToString().Replace(",", ".")));
            }
        }



    }
}
