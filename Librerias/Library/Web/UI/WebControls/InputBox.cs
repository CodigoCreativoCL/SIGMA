using Microsoft.VisualBasic;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.IO;



[ToolboxData("<{0}:InputBox runat=\"server\"></{0}:InputBox>")]
public class InputBox : System.Web.UI.WebControls.TextBox
{

    public enum InputBoxMode
    {
        Multiline,
        Password,
        SingleLine,
        Number,
        Float
    }


    const string _ValidationText = "<img src='{0}' hspace='2' align='absmiddle' alt='{1}' width='16' height='16' style='cursor:hand'/>";

    private RequiredFieldValidator _Validator;

    const string cnsNumberMask = "999\\.999\\.999";

    const string cnsFloatMask = "999\\.999\\.999.9999";
    #region " Overrides "

    public InputBox() : base()
    {

    }

    protected override void OnInit(System.EventArgs e)
    {
        base.OnInit(e);

    }

    protected override void OnLoad(System.EventArgs e)
    {
        base.OnLoad(e);
    }

    
    protected override void CreateChildControls()
    {
        base.CreateChildControls();

        if (this.RequiredField & _Validator == null)
        {
            this.AddRequiredFieldValidator();
        }
    }

    protected override void OnPreRender(System.EventArgs e)
    {
        base.OnPreRender(e);

        //if (this.InputMode == InputBoxMode.Password)
        //{
        //    this.Attributes.Add("value", this.Text);
        //}

        if (SelectOnFocus)
        {
            this.Attributes.Add("onfocus", "this.select()");
        }

        if (UpperCase)
        {
            this.Attributes.Add("onblur", "this.value=this.value.toUpperCase();");
        }

        //if (PreventLostData)
        //{
        //    this.Attributes.Add("onchange", "setPreventLostData();");
        //}

    }


    protected override void Render(System.Web.UI.HtmlTextWriter writer)
    {
        RenderInputBox(writer);

        RenderValidator(writer);

    }


    internal void RenderInputBox(System.Web.UI.HtmlTextWriter writer)
    {
        if (!string.IsNullOrEmpty(Caption))
        {
            writer.Write("<div>");
            writer.Write(Caption + ":<br />");
        }

        base.Render(writer);
    }


    internal void RenderValidator(System.Web.UI.HtmlTextWriter writer)
    {
        if ((_Validator != null))
        {
            _Validator.RenderControl(writer);
        }

        if (!string.IsNullOrEmpty(Caption))
        {
            writer.Write("</div>");
        }

    }

    #endregion

    #region " Propiedades "

    public override bool ReadOnly
    {
        get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
        set { ViewState["ReadOnly"] = value; }
    }

    public string DisabledCssClass
    {
        get { return Convert.ToString(ViewState["DisabledCssClass"]); }
        set { ViewState["DisabledCssClass"] = value; }
    }

    //public InputBoxMode InputMode
    //{
    //    get
    //    {
    //        object o = ViewState["InputMode"];
    //        return ((o != null) ? Convert.ToInt32(o) : InputBoxMode.SingleLine);
    //        //return ((o == null) ? ValidatorDisplay.Dynamic : (ValidatorDisplay)o);
    //    }

    //    set
    //    {
    //        switch (value)
    //        {
    //            case InputBoxMode.Multiline:
    //                this.TextMode = TextBoxMode.MultiLine;
    //                break;
    //            case InputBoxMode.Password:
    //                this.TextMode = TextBoxMode.Password;
    //                break;
    //            case InputBoxMode.SingleLine:
    //                this.TextMode = TextBoxMode.SingleLine;
    //                break;
    //            case InputBoxMode.Float:
    //                this.TextMode = TextBoxMode.SingleLine;
    //                break;
    //            //Me.Mask = cnsFloatMask
    //            case InputBoxMode.Number:
    //                this.TextMode = TextBoxMode.SingleLine;
    //                break;

    //        }

    //        ViewState["InputMode"] = value;

    //    }
    //}

    public bool UpperCase
    {
        get
        {
            object o = ViewState["UpperCase"];
            return ((o != null) ? Convert.ToBoolean(o) : false);
        }
        set { ViewState["UpperCase"] = value; }
    }

    public bool SelectOnFocus
    {
        get
        {
            object o = ViewState["SelectOnFocus"];
            return ((o != null) ? Convert.ToBoolean(o) : false);
        }
        set { ViewState["SelectOnFocus"] = value; }
    }

    public bool AutoComplete
    {
        get
        {
            object o = ViewState["AutoComplete"];
            return ((o != null) ? Convert.ToBoolean(o) : false);
        }
        set { ViewState["AutoComplete"] = value; }
    }

    public bool AllowNull
    {
        get
        {
            object o = ViewState["AllowNull"];
            return ((o != null) ? Convert.ToBoolean(o) : false);
        }
        set { ViewState["AllowNull"] = value; }
    }

    //public TextAlign TextAlign
    //{
    //    get
    //    {
    //        TextAlign functionReturnValue = default(TextAlign);
    //        object o = ViewState["TextAlign"];
    //        return ((o != null) ? (TextAlign)o : functionReturnValue.Left);
    //        return functionReturnValue;
    //    }
    //    set { ViewState["TextAlign"] = value; }
    //}

    //public override string Text
    //{
    //    get
    //    {
    //        if (this.InputMode == InputBoxMode.Float)
    //        {
    //            return Strings.Replace(Strings.Replace(base.Text, ".", ""), ",", ".");
    //        }
    //        else
    //        {
    //            return base.Text;
    //        }
    //    }
    //    set { base.Text = value; }
    //}

    public string Caption
    {
        get { return Convert.ToString(ViewState["Caption"]); }
        set { ViewState["Caption"] = value; }
    }

    

    #endregion

 
    #region " Validator "

    public bool RequiredField
    {
        get
        {
            object o = ViewState["RequiredField"];
            return ((o != null) ? Convert.ToBoolean(o) : false);
        }
        set { ViewState["RequiredField"] = value; }
    }

    public string ValidationMessage
    {
        get
        {
            object o = ViewState["ValidationMessage"];
            return ((o != null) ? Convert.ToString(o) : "");
        }
        set { ViewState["ValidationMessage"] = value; }
    }

    public string ValidationImageUrl
    {
        get
        {
            object o = ViewState["ValidationImageUrl"];
            return ((o != null) ? Convert.ToString(o) : "");
        }
        set { ViewState["ValidationImageUrl"] = value; }
    }

   
    public ValidatorDisplay ValidationDisplayMode
    {
        get
        {
            object o = ViewState["ValidationDisplayMode"];
            return ((o == null) ? ValidatorDisplay.Dynamic : (ValidatorDisplay)o);
        }
        set { ViewState["ValidationDisplayMode"] = value; }
    }

    public string ValidationText
    {
        get
        {
            object o = ViewState["ValidationText"];
            return ((o != null) ? Convert.ToString(o) : "");
        }
        set { ViewState["ValidationText"] = value; }
    }

    private void AddRequiredFieldValidator()
    {
        _Validator = new RequiredFieldValidator();


        if (Visible)
        {
            var _with1 = _Validator;

            _with1.ID = this.ID + "_RequiredField";
            _with1.ControlToValidate = this.ID;
            _with1.EnableClientScript = true;
            _with1.Display = this.ValidationDisplayMode;

            if (!string.IsNullOrEmpty(this.ValidationText))
            {
                _with1.Text = this.ValidationText;
            }
            else
            {
                _with1.Text = "&nbsp;*";
            }

            _with1.ErrorMessage = this.ValidationMessage;

            if (this.ValidationGroup != string.Empty)
            {
                _with1.ValidationGroup = this.ValidationGroup;
            }


            base.Controls.Add(_Validator);

        }

    }

    #endregion

}


