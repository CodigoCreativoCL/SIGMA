using Telerik.Web.UI;
using System.IO;
using System.Web.UI.WebControls;
using System;
using System.Web.UI;


namespace Telerik.Web.UI
{

    public class RadGrid2 : Telerik.Web.UI.RadGrid
    {

        private RadToolBar _Toolbar;
        public ParameterCollection SelectParameters;
        public string SelectCommand;
        public SqlDataSourceCommandType SelectCommandType;
        public string ConnectionString;

        public RadGrid2() : base()
        {
            //this.EnableEmbeddedSkins = false;
            //this.CssClass = "RadGrid_Bootstrap";
            this.Skin = "Bootstrap";

            ClientSettings.EnableRowHoverStyle = true;

            // Columnas
            AutoGenerateColumns = false;

            // Grupos
            ShowGroupPanel = false;
            GroupingEnabled = true;
            MasterTableView.GroupLoadMode = GridGroupLoadMode.Client;

            // Paginacion y ordenamiento
            PageSizeSelectorMode = GridPageSizeSelectorMode.RadComboBox;

            AllowSorting = true;
            AllowPaging = true;
            PageSize = 25;
           
            PagerStyle.AlwaysVisible = true;
            PagerStyle.Position = GridPagerPosition.Bottom;
            PagerStyle.Mode = GridPagerMode.NextPrevAndNumeric;

            // Seleccion
            AllowMultiRowSelection = true;
            ClientSettings.Selecting.EnableDragToSelectRows = false;

            var _with2 = ClientSettings;
            _with2.Selecting.AllowRowSelect = true;
            _with2.AllowDragToGroup = true;
            _with2.AllowColumnsReorder = true;

            // Traduccion
            MasterTableView.NoMasterRecordsText = "La consulta no tiene registros.";
            var _with3 = PagerStyle;
            _with3.PrevPageToolTip = "Anterior";
            _with3.PrevPagesToolTip = "Anterior";
            _with3.NextPageToolTip = "Siguiente";
            _with3.NextPagesToolTip = "Siguiente";
            _with3.PagerTextFormat = "Cambiar página: {4} &nbsp;|&nbsp; Página {0} de {1}, ítems {2} de {3} de {5}.";
            _with3.PageSizeLabelText = "Registros por página:";

            var _with4 = SortingSettings;
            _with4.SortToolTip = "Haga click para ordenar la columna";

            // grouping
            var _with5 = GroupingSettings;
            _with5.CollapseTooltip = "Contraer Grupo";
            _with5.ExpandTooltip = "Expandir Grupo";
            _with5.GroupContinuedFormatString = " ... continuación de la página anterior. ";
            _with5.GroupContinuesFormatString = " Continúa en la página siguiente ... ";
            _with5.GroupSplitDisplayFormat = "Mostrando {0} de {1} registros.";


            GroupPanel.Text = "Arrastre aquí la columna deseada para agrupar lo datos.";

            this.ClientSettings.ClientEvents.OnPopUpShowing = "PopUpShowing";

        }

        public void AddCheckboxColumn(string Field, string Header, string Width = "", bool Resizable = false, bool Editable = false, bool HederWrap = false)
        {
            GridCheckBoxColumn colItem = new GridCheckBoxColumn();

            this.MasterTableView.Columns.Add(colItem);
            this.ClientSettings.Selecting.AllowRowSelect = true;

            colItem.DataField = Field;

            colItem.HeaderText = Header;
            colItem.HeaderStyle.Wrap = false;
            colItem.HeaderStyle.HorizontalAlign = HorizontalAlign.Left;
            colItem.HeaderStyle.Font.Bold = true;
            colItem.HeaderStyle.Wrap = HederWrap;

            colItem.Resizable = Resizable;
            colItem.ItemStyle.HorizontalAlign = HorizontalAlign.Center;
            


            if (!string.IsNullOrEmpty(Width))
            {
                if (Width.Substring(Width.Length - 1, 1) == "%")
                {
                    colItem.HeaderStyle.Width = Unit.Percentage(Int32.Parse(Width.Replace("%","")));
                }
                else
                {
                    colItem.HeaderStyle.Width = Unit.Pixel(Int32.Parse(Width));
                }
            }

        }

        public void AddSelectColumn(string Width = "30", bool Resizable = false, HorizontalAlign Align = HorizontalAlign.Left, HorizontalAlign HeaderAlign = HorizontalAlign.Left)
        {
            this.ClientSettings.Selecting.AllowRowSelect = true;

            GridClientSelectColumn colItem = new GridClientSelectColumn();
            colItem.UniqueName = "ClientSelectColumn";
            colItem.HeaderStyle.HorizontalAlign = HeaderAlign;

            this.MasterTableView.Columns.Add(colItem);

            colItem.Resizable = Resizable;
            colItem.Reorderable = false;
            //colItem.ItemStyle.HorizontalAlign = WebControls.HorizontalAlign.Center
            colItem.ItemStyle.HorizontalAlign = Align;

            if (!string.IsNullOrEmpty(Width))
            {
                if (Width.Substring(Width.Length - 1, 1) == "%")
                {
                    colItem.HeaderStyle.Width = Unit.Percentage(Int32.Parse(Width.Replace("%", "")));
                }
                else
                {
                    colItem.HeaderStyle.Width = Unit.Pixel(Int32.Parse(Width));
                }
            }

        }

        public void AddEditColumn(string Text = "Editar", string Header = "", string Width = "10", bool Resizable = false)
        {
            GridEditCommandColumn colItem = new GridEditCommandColumn();
            colItem.UniqueName = "EditCommandColumn";

            this.MasterTableView.Columns.Add(colItem);

            colItem.HeaderText = Header;
            colItem.EditText = Text;
            colItem.Resizable = Resizable;
            colItem.Reorderable = false;

            if (!string.IsNullOrEmpty(Width))
            {
                if (Width.Substring(Width.Length - 1, 1) == "%")
                {
                    colItem.HeaderStyle.Width = Unit.Percentage(Int32.Parse(Width.Replace("%", "")));
                }
                else
                {
                    colItem.HeaderStyle.Width = Unit.Pixel(Int32.Parse(Width));
                }
            }

        }

        public void AddGroupField(string Field, string Header, string HeaderValueSeparator = "", string FormatString = "")
        {
            GridGroupByExpression expression = new GridGroupByExpression();
            GridGroupByField gridGroupByField = new GridGroupByField();
            
            var _with3 = gridGroupByField;
            _with3.FieldName = Field;
            _with3.HeaderText = Header;
            
            if (!string.IsNullOrEmpty(HeaderValueSeparator))
                _with3.HeaderValueSeparator = HeaderValueSeparator;
            if (!string.IsNullOrEmpty(FormatString))
                _with3.FormatString = FormatString;
            expression.SelectFields.Add(gridGroupByField);
            expression.GroupByFields.Add(gridGroupByField);
            
            this.MasterTableView.GroupByExpressions.Add(expression);

        }

        public void AddColumn(string Field, string Header, string Width = "", HorizontalAlign Align = HorizontalAlign.Left, bool Wrap = true, string SortExpression = "", string DataFormat = "", bool ReadOnly = false, GridAggregateFunction Agregate = GridAggregateFunction.None, string FooterText = "", bool HederWrap = true, HorizontalAlign HeaderAlign = HorizontalAlign.Left, string HerderToolTip = "", string headerColor = "")
        {
            GridBoundColumn colItem = new GridBoundColumn();
            colItem.UniqueName = Field.Replace(' ', '_');
            this.MasterTableView.Columns.Add(colItem);

            if (!string.IsNullOrEmpty(Field))
            {
                colItem.DataField = Field;
                colItem.DataFormatString = DataFormat;
                colItem.ReadOnly = ReadOnly;
            }

            //if (Header == "")
            //    Header = "&nbsp";    
            colItem.HeaderText = Header;
            colItem.HeaderTooltip = HerderToolTip;
            colItem.HeaderStyle.Wrap = HederWrap;
            colItem.HeaderStyle.HorizontalAlign = HeaderAlign;
            colItem.HeaderStyle.Font.Bold = true;

            if (headerColor != "")
                colItem.HeaderStyle.BackColor = System.Drawing.ColorTranslator.FromHtml(headerColor);

            colItem.SortExpression = SortExpression;

            colItem.ItemStyle.HorizontalAlign = Align;
            colItem.ItemStyle.Wrap = Wrap;

            if (!string.IsNullOrEmpty(Width))
            {
                if (Width.Substring(Width.Length - 1, 1) == "%")
                {
                    colItem.HeaderStyle.Width = Unit.Percentage(Int32.Parse(Width.Replace("%", "")));
                }
                else
                {
                    colItem.HeaderStyle.Width = Unit.Pixel(Int32.Parse(Width));
                }
                colItem.FooterStyle.Width = colItem.HeaderStyle.Width;
            }

            colItem.FooterStyle.HorizontalAlign = colItem.ItemStyle.HorizontalAlign;

            colItem.Aggregate = Agregate;
            colItem.FooterText = FooterText;

        }

        public void AddTemplateColumn(string uniqueName, string Field, string Header, string Width = "", bool HederWrap = false, bool Wrap = false, HorizontalAlign HederPosition = HorizontalAlign.Left, HorizontalAlign ItemPosition = HorizontalAlign.Left, string HerderToolTip = "")
        {

            GridTemplateColumn boundColumn;
            boundColumn = new GridTemplateColumn();
            this.MasterTableView.Columns.Add(boundColumn);
            boundColumn.UniqueName = uniqueName;
            boundColumn.HeaderText = Header;
            boundColumn.HeaderTooltip = HerderToolTip;
            boundColumn.HeaderStyle.HorizontalAlign = HederPosition;
            boundColumn.DataField = Field;
            boundColumn.HeaderStyle.Font.Bold = true;

            boundColumn.ItemStyle.HorizontalAlign = ItemPosition;
            boundColumn.ItemStyle.Wrap = Wrap;

            if (!string.IsNullOrEmpty(Width))
            {
                if (Width.Substring(Width.Length - 1, 1) == "%")
                {
                    boundColumn.HeaderStyle.Width = Unit.Percentage(Int32.Parse(Width.Replace("%", "")));
                }
                else
                {
                    boundColumn.HeaderStyle.Width = Unit.Pixel(Int32.Parse(Width));
                }
                boundColumn.FooterStyle.Width = boundColumn.HeaderStyle.Width;
            }

            boundColumn.FooterStyle.HorizontalAlign = boundColumn.ItemStyle.HorizontalAlign;
           
        }
        

        public void AddCommandColumn(string Text, string CommandName)
        {
            GridButtonColumn Comm = new GridButtonColumn();

            this.MasterTableView.Columns.Add(Comm);

            var _with4 = Comm;
            _with4.Text = Text;
            _with4.CommandName = CommandName;

        }
        
        public void AddCommandColumn(string Text, string CommandName, string ImageUrl)
        {
            GridButtonColumn Comm = new GridButtonColumn();

            this.MasterTableView.Columns.Add(Comm);

            var _with5 = Comm;
            _with5.Text = Text;
            _with5.CommandName = CommandName;
            _with5.ButtonType = GridButtonColumnType.ImageButton;
            _with5.ImageUrl = ImageUrl;

        }

        public Control FindControlRecursive(string id)
        {
            return FindControlRecursive(this.MasterTableView, id);
        }

        public Control FindControlRecursive(Control control, string id)
        {

            // Return null if parameter control is null 
            if (control == null)
            {
                return null;
            }

            // Try to find the control at the current level 
            Control ctrl = control.FindControl(id);
            if (ctrl == null)
            {
                // Loop through child controls 
                foreach (Control child in control.Controls)
                {
                    // Try to find the control at the next level 
                    ctrl = FindControlRecursive(child, id);

                    // Stop search when control is found 
                    if (ctrl != null)
                    {
                        break; // TODO: might not be correct. Was : Exit For
                    }
                }
            }
            return ctrl;
        }

        //ComboBox
        public enum GridPageSizeSelectorMode
        {
            Hide,
            RadComboBox
        }
               
        public GridPageSizeSelectorMode PageSizeSelectorMode
        {
            get
            {
                object o = ViewState["PageSizeSelectorMode"];
                return (o != null ? (GridPageSizeSelectorMode)o : GridPageSizeSelectorMode.Hide);
            }
            set { ViewState.Add("PageSizeSelectorMode", value); }
        }

        protected override void OnItemCreated(GridItemEventArgs e)
        {
            base.OnItemCreated(e);


            if (e.Item is GridPagerItem)
            {
                GridPagerItem PagerItem = (GridPagerItem)e.Item;


                if (PageSizeSelectorMode == GridPageSizeSelectorMode.RadComboBox)
                {

                    RadComboBox PageSizeCombo = (RadComboBox)e.Item.FindControl("PageSizeComboBox");
                    PageSizeCombo.RenderMode = RenderMode.Lightweight;
                    PageSizeCombo.Skin = "Bootstrap";
                    PageSizeCombo.CssClass = "RadComboBox_Bootstrap";
                    PageSizeCombo.Style.Add("width", "75px !important");

                    PageSizeCombo.Items.Clear();
                    PageSizeCombo.Items.Add(new RadComboBoxItem("25"));
                    PageSizeCombo.FindItemByText("25").Attributes.Add("ownerTableViewId", this.MasterTableView.ClientID);
                    PageSizeCombo.Items.Add(new RadComboBoxItem("50"));
                    PageSizeCombo.FindItemByText("50").Attributes.Add("ownerTableViewId", this.MasterTableView.ClientID);
                    PageSizeCombo.Items.Add(new RadComboBoxItem("100"));
                    PageSizeCombo.FindItemByText("100").Attributes.Add("ownerTableViewId", this.MasterTableView.ClientID);
                    PageSizeCombo.Items.Add(new RadComboBoxItem("200"));
                    PageSizeCombo.FindItemByText("200").Attributes.Add("ownerTableViewId", this.MasterTableView.ClientID);
                    PageSizeCombo.Items.Add(new RadComboBoxItem("500"));
                    PageSizeCombo.FindItemByText("500").Attributes.Add("ownerTableViewId", this.MasterTableView.ClientID);
                    PageSizeCombo.Items.Add(new RadComboBoxItem("1000"));
                    PageSizeCombo.FindItemByText("1000").Attributes.Add("ownerTableViewId", this.MasterTableView.ClientID);
                    PageSizeCombo.FindItemByText(e.Item.OwnerTableView.PageSize.ToString()).Selected = true;

                }

            }

        }

        private void ChangePageSize(object sender, System.EventArgs e)
        {
            this.PageSize = Int32.Parse(((RadComboBox)sender).SelectedValue);
            this.DataBind();
        }


    }

}
