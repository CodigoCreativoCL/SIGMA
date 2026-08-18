using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using Telerik.Web.UI;
using System.Web.UI.WebControls;
using System.Text;
using System.Web.UI.HtmlControls;
using System.Web.UI;

namespace Telerik.Web.UI
{

	public class RadComboCheckBox2 : Telerik.Web.UI.RadComboBox
	{

		private CheckBoxList _ChekcBoxList;
		public string LoadFromSQL {
			get { return Convert.ToString(ViewState["LoadFromSQL"]); }
			set { ViewState["LoadFromSQL"] = value; }
		}

        public string dbValues()
        {
            string values = "";

            foreach (RadComboBoxItem RadItem in this.Items)
            {
                CheckBox chk = (CheckBox)RadItem.FindControl("chk1");

                if (chk.Checked)
                {
                    values += RadItem.Value + ",";
                }
            }

            if (values != "")
                values = values.Remove(values.Length - 1, 1);

            return values;
        }


		public RadComboCheckBox2() : base()
		{
            this.EnableEmbeddedSkins = false;
            this.CssClass = "RadComboBoxDropDown_Default";
			AllowCustomText = true;
			HighlightTemplatedItems = true;
            
		}


		protected override void OnLoad(System.EventArgs e)
		{
			base.OnLoad(e);

			if (!this.Page.ClientScript.IsClientScriptBlockRegistered("CheckBoxScript2")) {
				StringBuilder sb = new StringBuilder();

                //Checked todo y desChecked todo
				sb.AppendLine("function CheckBoxListSelect2(cbControl, state)");
				sb.AppendLine("{");
				sb.AppendLine("var combo = $find(cbControl);");
				sb.AppendLine("var items = combo.get_items();");
                sb.AppendLine(" var count=0;");
				sb.AppendLine(" for (var i = 0; i < items.get_count(); i++) ");
				sb.AppendLine(" {");
				sb.AppendLine("     var chk1 = $get(combo.get_id() + '_i' + i +'_chk1');");
				sb.AppendLine("     chk1.checked = state;");
                sb.AppendLine("     count ++;");
                sb.AppendLine(" }");
                sb.AppendLine(" if(state)");
                sb.AppendLine("     combo.set_text('Todos') ;");
                sb.AppendLine(" else");
                sb.AppendLine("     combo.set_text('');");
				sb.AppendLine("return false;");
				sb.AppendLine("}");

                //StopPropagation
                sb.AppendLine("function StopPropagation(e)");
                sb.AppendLine("{");
                sb.AppendLine(" e.cancelBubble = true;");
                sb.AppendLine(" if (e.stopPropagation)");
                sb.AppendLine(" {");
                sb.AppendLine("     e.stopPropagation();");
                sb.AppendLine(" }");
                sb.AppendLine("}");

                //onCheckBoxClick
                sb.AppendLine("function onCheckBoxClick(cbControl, chk)");
                sb.AppendLine("{");
                sb.AppendLine(" var combo = $find(cbControl);");
                sb.AppendLine(" var items = combo.get_items();");
                sb.AppendLine(" var text = '';");
                sb.AppendLine(" var count=0;");
                sb.AppendLine(" for (var i = 0; i < items.get_count(); i++) ");
                sb.AppendLine(" {");
                sb.AppendLine("     var item = items.getItem(i);");
                sb.AppendLine("     var chk1 = $get(combo.get_id() + '_i' + i +'_chk1');");
                sb.AppendLine("     if(chk1.checked)");
                sb.AppendLine("     {");
                sb.AppendLine("         if(count == 0)");
                sb.AppendLine("             text += item.get_text();");
                sb.AppendLine("         else");
                sb.AppendLine("             text += ', ' + item.get_text();");
                sb.AppendLine("         count ++;");
                sb.AppendLine("     }");
                sb.AppendLine(" }");
                sb.AppendLine(" ");
                sb.AppendLine(" if (text.length > 0)");
                sb.AppendLine(" {");
                sb.AppendLine("     if(count == items.get_count())");
                sb.AppendLine("         combo.set_text('Todos')");
                sb.AppendLine("     else");
                sb.AppendLine("         if(count > 3)");
                sb.AppendLine("             combo.set_text(count + ' Items Seleccionados') ;");
                sb.AppendLine("         else");
                sb.AppendLine("             combo.set_text(text);");
                sb.AppendLine(" }");
                sb.AppendLine(" else");
                sb.AppendLine(" {");
                sb.AppendLine("     combo.set_text('');");
                sb.AppendLine(" }");
                sb.AppendLine("}");

				this.Page.ClientScript.RegisterClientScriptBlock(this.GetType(), "CheckBoxScript2", sb.ToString(), true);
			}

		}

		protected override void CreateChildControls()
		{
			base.CreateChildControls();

			this.HeaderTemplate = new MyItemTemplate(ListItemType.Header);
			this.ItemTemplate = new MyItemTemplate(ListItemType.Item, this.DataTextField);

		}

        
	}
    
	public class MyItemTemplate : System.Web.UI.ITemplate
	{
        private string cbControl;
              

		private System.Web.UI.WebControls.ListItemType templateType;

		private string _DataTextField;

		public MyItemTemplate(System.Web.UI.WebControls.ListItemType type, string DatatextField = "")
		{
			templateType = type;
			_DataTextField = DatatextField;
		}

		public void InstantiateIn(System.Web.UI.Control container)
		{
			PlaceHolder ph = new PlaceHolder();
			Panel pnl = new Panel();
			CheckBox chk = new CheckBox();

			chk.ID = "chk1";

			switch (templateType) {
				case ListItemType.Header:

					HtmlTable table = new HtmlTable();
                    table.Attributes.Add("class", "RadComboBoxDropDown_Default_Header_Table");
					HtmlTableRow tr = new HtmlTableRow();
					HtmlTableCell td = new HtmlTableCell();

					//--crea el control todos/ninguna
					Label label = new Label();
					label.Text = "Seleccione:";
					td.Controls.AddAt(0, label);

					HyperLink all = new HyperLink();
					all.Style.Add("padding-left", "4px");
					all.Text = "Todos";
                    all.Style.Add("color", "Blue");
					td.Controls.AddAt(1, all);

					HyperLink none = new HyperLink();
					none.Text = "Ninguno";
					none.Style.Add("padding-left", "4px");
                    none.Style.Add("color", "Blue");
					td.Controls.AddAt(2, none);

					tr.Cells.Add(td);
					table.Rows.Add(tr);
                    
					ph.Controls.Add(table);

                    cbControl = container.ClientID.Replace("_Header", "");

					//none.Attributes.Add("onclick", "CheckBoxListSelect2('" +  container.ClientID.Replace("_Header", "") + "',false);");
                    //all.Attributes.Add("onclick", "CheckBoxListSelect2('" + container.ClientID.Replace("_Header", "") + "',true);");
                    none.Attributes.Add("onclick", "CheckBoxListSelect2('" +  cbControl + "',false);");
					all.Attributes.Add("onclick", "CheckBoxListSelect2('" + cbControl + "',true);");

					break;


                case ListItemType.Item:

                    cbControl = container.ClientID.Replace("_Header", "");
                    cbControl = cbControl.Replace(container.ID, "");
                    cbControl = cbControl.Remove(cbControl.Length - 1, 1);

                    var _with1 = pnl;
                    _with1.Attributes.Add("onclick", "StopPropagation(event);");
                    
                    _with1.Style.Add("width", "100%");
                    _with1.Controls.Add(chk);

                    ph.Controls.Add(pnl);

                    ph.DataBinding += Item_DataBinding;

                    break;

			}
			container.Controls.Add(ph);
		}

		private void Item_DataBinding(object sender, System.EventArgs e)
		{
            PlaceHolder ph = (PlaceHolder)sender;
            RadComboBoxItem radCombo = (RadComboBoxItem)ph.NamingContainer;

            CheckBox chk = (CheckBox)ph.FindControl("chk1");
 
            chk.Attributes.Add("onclick", "onCheckBoxClick('" + cbControl +"', '" + chk.ID + "');");

            chk.Text = DataBinder.Eval(radCombo.DataItem, _DataTextField).ToString();

		}
	}


}
 
