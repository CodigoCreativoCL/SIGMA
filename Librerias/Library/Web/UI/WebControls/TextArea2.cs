using Microsoft.VisualBasic;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.IO;
using System.Web.UI;
using System.ComponentModel;
using System.Web.UI.WebControls;

namespace WebControls
{

    public class TextArea2 : System.Web.UI.WebControls.TextBox
    {
        
        public bool ValidaMaxLength
        {
            get
            {
                object o = ViewState["ValidaMaxLength"];
                return ((o != null) ? Convert.ToBoolean(o) : true);
            }
            set { ViewState["ValidaMaxLength"] = value; }
        }

        private Label _lblVisor;

        private RequiredFieldValidator _Validator;

        public TextArea2()
        {
            this.TextMode = TextBoxMode.MultiLine;
            this.Rows = 3;
            this.CssClass = "form-control";
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
            if (this.ValidaMaxLength)
            {
                if (this.MaxLength > 0)
                {
                    //if (!Page.ClientScript.IsClientScriptIncludeRegistered("TextArea"))
                    //{
                    //    Page.ClientScript.RegisterClientScriptInclude("TextArea", ResolveClientUrl("~/Js/textarea.js"));
                    //}

                    //_lblVisor = new Label();
                    //_lblVisor.Style.Add("color", "Red");
                    //_lblVisor.ID = this.ClientID + "_lblVisor";
                    //this.Attributes.Add("counterId", _lblVisor.ClientID);

                    //this.Attributes.Add("onkeyup", "LimitInput(this)");
                    //this.Attributes.Add("onkeydown", "LimitInput(this)");
                    //this.Attributes.Add("onbeforepaste", "doBeforePaste(this)");
                    //this.Attributes.Add("onpaste", "doPaste(this)");
                    //this.Attributes.Add("onmousemove", "LimitInput(this)");
                    //this.Attributes.Add("maxLength", this.MaxLength.ToString());

                }
            }

            base.OnPreRender(e);

        }
        
        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {

            //this.Attributes.Add("onfocus", "onfocusTexBox(" + this.ClientID + ", true)");
            //this.Attributes.Add("onfocusout", "onfocusTexBox(" + this.ClientID + ", false)");

            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.Text));

                this.Visible = false;
                this.Style.Add("display", "none !important");

                base.Render(writer);


            }
            else
            {
                //writer.Write("<div>");

                base.Render(writer);

                if (_lblVisor != null)
                {
                    writer.Write("<br/>");
                    _lblVisor.Font.Size = 7;
                    _lblVisor.Font.Name = "SmallFont";
                    _lblVisor.RenderControl(writer);
                }

                if (_Validator != null)
                {
                    _Validator.RenderControl(writer);
                }

                //writer.Write("</div>");

            }

        }
        
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
                    _with1.Text = "&nbsp;&nbsp;&nbsp;" + this.ValidationText;
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

}