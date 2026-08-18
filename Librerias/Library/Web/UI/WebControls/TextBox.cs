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

    public class TextBox2 : System.Web.UI.WebControls.TextBox
    {
        public bool UpperCase
        {
            get
            {
                object o = ViewState["UpperCase"];
                return ((o != null) ? Convert.ToBoolean(o) : false);
            }
            set { ViewState["UpperCase"] = value; }
        }

        public bool LowerCase
        {
            get
            {
                object o = ViewState["LowerCase"];
                return ((o != null) ? Convert.ToBoolean(o) : false);
            }
            set { ViewState["LowerCase"] = value; }
        }

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

        public TextBox2()
        {
            this.TextMode = TextBoxMode.SingleLine;
            this.Rows = 1;
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

            if (UpperCase)
            {
                this.Attributes.Add("onkeyup", "this.value=this.value.toUpperCase();");
                this.Style.Add("text-transform", "uppercase");
            }

            if (LowerCase)
            {
                this.Attributes.Add("onkeyup", "this.value=this.value.toLowerCase();");
                this.Style.Add("text-transform", "lowercase");
            }
            
        }


        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
            
            if (this.ReadOnly)
            {
                writer.Write(string.Format("<span>{0}</span>", this.Text));

                this.Visible = false;
                this.Style.Add("display", "none !important");

                base.Render(writer);


            }
            else
            {
                base.Render(writer);

                if (_lblVisor != null)
                {
                    _lblVisor.Font.Size = 7;
                    _lblVisor.Font.Name = "SmallFont";
                    _lblVisor.RenderControl(writer);
                }

                if (_Validator != null)
                {
                    _Validator.RenderControl(writer);
                }

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

}