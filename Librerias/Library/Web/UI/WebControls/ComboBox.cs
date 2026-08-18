using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.ComponentModel;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Data.SqlClient;


namespace Library.Web.UI.WebControls
{

    [ToolboxData("<{0}:ComboBox runat=\"server\"> </{0}:ComboBox>")]
    public class ComboBox : System.Web.UI.WebControls.DropDownList
    {
     
        private RequiredFieldValidator _Validator;

        const string _ValidationText = "<img src='{0}' hspace='2' align='absmiddle' alt='{1}' width='16' height='16' style='cursor:hand'/>";
       

        #region " Properties "

        
        public bool ReadOnly
        {
            get { return Convert.ToBoolean(ViewState["ReadOnly"]); }
            set { ViewState["ReadOnly"] = value; }
        }

        public string DisabledCssClass
        {
            get { return Convert.ToString(ViewState["DisabledCssClass"]); }
            set { ViewState["DisabledCssClass"] = value; }
        }

        public string Value
        {
            get { return base.SelectedValue; }
            set
            {
                base.SelectedIndex = -1;
                foreach (ListItem li in this.Items)
                {
                    if (li.Value.Trim().ToLower().Equals(value.Trim().ToLower()))
                    {
                        base.SelectedValue = value;
                        break; 
                    }
                }
                InvalidBindValue = value;
            }
        }

        public string InvalidBindValue
        {
            get { return Convert.ToString(ViewState["InvalidBindValue"]); }
            set { ViewState["InvalidBindValue"] = value; }
        }

        public string Caption
        {
            get { return Convert.ToString(ViewState["Caption"]); }
            set { ViewState["Caption"] = value; }
        }

        public string EmptyText
        {
            get { return Convert.ToString(ViewState["EmptyText"]); }
            set { ViewState["EmptyText"] = value; }
        }

        #endregion

        #region " Procedures "


        public void AddItem(string Value, string Text, int Position = -1, string GroupText = "")
        {
            ListItem item = new ListItem();

            item.Text = Text;
            item.Value = Value;

            if (!string.IsNullOrEmpty(GroupText))
            {
                item.Attributes["OptionGroup"] = GroupText;
            }

            if (Position > -1)
            {
                base.Items.Insert(Position, item);
            }
            else
            {
                base.Items.Add(item);
            }

        }

        public void AddNullItem(int Position = 0)
        {
            AddItem("", "", Position);
        }

        
        public void LoadFromSQL(string SQL, string ValueField, string TextFields, bool FirstBlankItem = false, string DefaultValue = "", string GroupField = "", string DefaultText = "", string value = "")
        {
            string strSelected = null;
            string strArr = "";

            CreateChildControls();

            var _with1 = this;

            if (!string.IsNullOrEmpty(DefaultValue))
            {
                strSelected = DefaultValue;
            }
            else
            {
                strSelected = _with1.SelectedValue;
            }

            _with1.Items.Clear();

            if (FirstBlankItem)
            {
                AddNullItem();
            }


            if (DefaultText != "")
            {
                _with1.Items.Add(new ListItem(DefaultText, value));
            }


            string[] arrParametros = TextFields.Split(',');  //Strings.Split(TextFields, ",");

                   
            using (SqlDataReader objReader = Conexion.GetDataReader(SQL))
            {

                while (objReader.Read())
                {

                    if (!string.IsNullOrEmpty(TextFields))
                    {
                        if (arrParametros.Length > 1)
                        {
                            strArr = objReader[arrParametros[0]].ToString() + " - " + objReader[arrParametros[1]].ToString();
                        }
                        else
                        {
                            strArr = objReader[TextFields].ToString();
                        }
                    }
                    else
                    {
                        strArr = objReader[1].ToString();
                    }

                    ListItem Item = new ListItem();
                    Item.Text = strArr;
                    if (!string.IsNullOrEmpty(ValueField))
                    {
                        Item.Value = objReader[ValueField].ToString();
                    }
                    else
                    {
                        Item.Value = objReader[0].ToString();
                    }

                    if (!string.IsNullOrEmpty(GroupField))
                    {
                        Item.Attributes["OptionGroup"] = objReader[GroupField].ToString();
                    }

                    _with1.Items.Add(Item);

                }

            }


            if ((_with1.Items.FindByValue(strSelected) != null))
            {
                _with1.SelectedValue = strSelected;
            }

        }

        #endregion

        #region " Overrides "

        public ComboBox()
            : base()
        {

            LoadingText = "";
            PromptText = "";

        }

        protected override System.Web.UI.ControlCollection CreateControlCollection()
        {
            return new ControlCollection(this);
        }

        protected override void OnLoad(System.EventArgs e)
        {
            base.OnLoad(e);

            if (PreventLostData)
            {
                Tools.tools.RegisterWebResource(this.Page, "PreventLostData.js");
            }

        }

        [Obsolete("Usar Library.Web.UI.ClientScript.RegisterWebResource().")]
        private void RegisterIncludeScript(string ScriptName)
        {
            Type rstype = this.GetType();
            string rsname = Page.ClientScript.GetWebResourceUrl(rstype, ScriptName);

            ScriptManager sm = ScriptManager.GetCurrent(this.Page);
            if (sm != null)
            {
                sm.Scripts.Add(new ScriptReference(rsname));
            }
            else
            {
                if (!Page.ClientScript.IsClientScriptIncludeRegistered(rstype, ScriptName))
                {
                    Page.ClientScript.RegisterClientScriptInclude(rstype, ScriptName, rsname);
                }
            }

        }

        protected override void CreateChildControls()
        {
            base.CreateChildControls();

            if (this.RequiredField & _Validator == null)
            {
                this.AddRequiredFieldValidator();
            }

        }


        protected override void OnDataBinding(System.EventArgs e)
        {
            if (this.AppendDataBoundItems)
            {
                if (ReadOnly)
                {
                    this.Items.Insert(0, EmptyText);
                }
                else
                {
                    this.Items.Insert(0, PromptText);
                }
                this.SelectedIndex = 0;
            }

            base.OnDataBinding(e);

        }


        protected override void OnPreRender(System.EventArgs e)
        {

            if (PreventLostData)
            {
                this.Attributes.Add("onchange", "setPreventLostData();");
            }

            if (!string.IsNullOrEmpty(TargetControlID))
            {
                RegisterLookupScript();
            }

            base.OnPreRender(e);

        }


        protected override void Render(System.Web.UI.HtmlTextWriter writer)
        {
           
            if (!string.IsNullOrEmpty(Caption))
            {
                writer.Write("<div>");
                writer.Write(Caption + ":<br />");
            }

            base.Render(writer);

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

        #region " Validator "

        /// <summary>
        /// Obtiene la instancia del control RequeredFieldValidator.
        /// </summary>
        [Browsable(true)]
        [Description("Obtiene la instancia del control RequeredFieldValidator.")]
        [NotifyParentProperty(true)]
        [DesignerSerializationVisibility(DesignerSerializationVisibility.Content)]
        [PersistenceMode(PersistenceMode.InnerProperty)]
        
        public RequiredFieldValidator RequiredValidator
        {
            get
            {
                if (_Validator == null)
                {
                    this.RequiredField = true;
                    AddRequiredFieldValidator();
                }
                return _Validator;
            }
        }

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

            var _with2 = _Validator;

            _with2.ID = this.ID + "_validator";
            _with2.ControlToValidate = this.ID;
            _with2.EnableClientScript = true;
            _with2.Display = this.ValidationDisplayMode;
            
            if (!string.IsNullOrEmpty(this.ValidationText))
            {
                _with2.Text = this.ValidationText;
            }
            else
            {
                _with2.Text = "&nbsp;*";
            }

            _with2.ErrorMessage = this.ValidationMessage;

            if (this.ValidationGroup != string.Empty)
            {
                _with2.ValidationGroup = this.ValidationGroup;
            }


            base.Controls.Add(_Validator);

        }

        #endregion

        #region " Prevent Lost Data "

        public bool PreventLostData
        {
            get
            {
                object o = ViewState["PreventLostData"];
                return ((o == null) ? false : Convert.ToBoolean(o));
            }
            set { ViewState["PreventLostData"] = value; }
        }

        #endregion

        #region " Group "

        protected override void RenderContents(HtmlTextWriter writer)
        {
            string currentOptionGroup = null;
            List<string> renderedOptionGroups = new List<string>();
            foreach (ListItem item in this.Items)
            {
                if (item.Attributes["OptionGroup"] == null)
                {
                    RenderListItem(item, writer);
                }
                else
                {
                    currentOptionGroup = item.Attributes["OptionGroup"];
                    if (renderedOptionGroups.Contains(currentOptionGroup))
                    {
                        RenderListItem(item, writer);
                    }
                    else
                    {
                        if (renderedOptionGroups.Count > 0)
                        {
                            RenderOptionGroupEndTag(writer);
                        }
                        RenderOptionGroupBeginTag(currentOptionGroup, writer);
                        renderedOptionGroups.Add(currentOptionGroup);
                        RenderListItem(item, writer);
                    }
                }
            }
            if (renderedOptionGroups.Count > 0)
            {
                RenderOptionGroupEndTag(writer);
            }
        }

        private void RenderOptionGroupBeginTag(string name, HtmlTextWriter writer)
        {
            writer.WriteBeginTag("optgroup");
            writer.WriteAttribute("label", name);
            writer.Write(HtmlTextWriter.TagRightChar);
            writer.WriteLine();
        }

        private void RenderOptionGroupEndTag(HtmlTextWriter writer)
        {
            writer.WriteEndTag("optgroup");
            writer.WriteLine();
        }

        private void RenderListItem(ListItem item, HtmlTextWriter writer)
        {
            writer.WriteBeginTag("option");
            writer.WriteAttribute("value", item.Value, true);
            if (item.Selected)
            {
                writer.WriteAttribute("selected", "selected", false);
            }
            foreach (string key in item.Attributes.Keys)
            {
                writer.WriteAttribute(key, item.Attributes[key]);
            }
            writer.Write(HtmlTextWriter.TagRightChar);
            HttpUtility.HtmlEncode(item.Text, writer);
            writer.WriteEndTag("option");
            writer.WriteLine();
        }

        #endregion

        #region " Cascading (Lookup) "

        public string TargetControlID
        {
            get { return Convert.ToString(ViewState["TargetControlID"]); }
            set { ViewState["TargetControlID"] = value; }
        }

        public string LoadingText
        {
            get { return Convert.ToString(ViewState["LoadingText"]); }
            set { ViewState["LoadingText"] = value; }
        }

        public string PromptText
        {
            get { return Convert.ToString(ViewState["PromptText"]); }
            set
            {
                ViewState["PromptText"] = value;
                if (!string.IsNullOrEmpty(PromptText))
                {
                    this.Attributes.Add("lookupPromptText", PromptText);
                }
            }
        }

        public string WebMethod
        {
            get { return Convert.ToString(ViewState["WebMethod"]); }
            set { ViewState["WebMethod"] = value; }
        }

        private Control FindControl(Control parent, string id)
        {
            if (parent.ID == id)
            {
                return parent;
            }
            foreach (Control child in parent.Controls)
            {
                Control recurse = FindControl(child, id);
                if (recurse != null)
                {
                    return recurse;
                }
            }
            return null;
        }


        private void RegisterLookupScript()
        {
            ComboBox TargetControl = FindControl(this.Parent, TargetControlID) as ComboBox;

            if (TargetControl == null)
            {
                throw new ArgumentException("No existe un control con el TargetControlID='" + TargetControlID + "'.");

            }
            else
            {
                this.Attributes.Add("lookupClientId", TargetControl.ClientID);
                this.Attributes.Add("lookupMethod", WebMethod);

                string CallBackFuction = "lookup_" + this.ID;


                if (!Page.ClientScript.IsStartupScriptRegistered(CallBackFuction))
                {
                    System.Text.StringBuilder init = new System.Text.StringBuilder();

                    init.AppendLine("");
                    init.AppendLine("if (typeof(cboLookup_initialize) == 'function') {");
                    init.AppendLine("   var e = document.getElementById('" + this.ClientID + "');");
                    init.AppendLine("   if (e) { cboLookup_initialize(e) }");
                    init.AppendLine("}");

                    Tools.tools.RegisterStartupScript(this.Page, CallBackFuction, init.ToString());

                    Tools.tools.RegisterWebResource(this, "ComboBox.js");

                }

            }

        }

        #endregion

    }

}

