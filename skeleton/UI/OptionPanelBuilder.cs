using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Controls.Templates;
using Avalonia.Layout;
using skeleton.Settings;

namespace skeleton.UI;

internal static class OptionPanelBuilder
{
    public static (Control Content, List<OptionBinding> Bindings) BuildContent(
        SettingCategory category,
        string tabKey,
        Action<string, Control>? registerNav = null)
    {
        var rowDefs = SettingCatalog.ForCategory(category).Where(SettingCatalog.IsPanelRow).ToList();
        var bindings = new List<OptionBinding>();
        var bindingByToken = new Dictionary<string, OptionBinding>(StringComparer.Ordinal);

        foreach (var def in rowDefs)
        {
            var shell = new OptionBinding
            {
                Definition = def,
                TabKey = tabKey,
            };
            bindingByToken[def.Token] = shell;
            bindings.Add(shell);
        }

        var itemsControl = new ItemsControl
        {
            ItemsSource = rowDefs,
            Classes = { "settings-panel" },
        };
        itemsControl.ItemsPanel = new FuncTemplate<Panel?>(() => new VirtualizingStackPanel());
        itemsControl.ItemTemplate = new FuncDataTemplate<SettingDefinition?>((def, _) =>
        {
            if (def is null)
                return new Grid();

            var (row, binding) = CreateOptionRow(def, tabKey);
            AttachShell(bindingByToken[def.Token], binding, def.Token, registerNav);
            return row;
        });

        return (itemsControl, bindings);
    }

    public static ScrollViewer CreateScrollHost(Control content) =>
        new()
        {
            Content = content,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            BringIntoViewOnFocusChange = false,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
        };

    private static void AttachShell(
        OptionBinding shell,
        OptionBinding source,
        string token,
        Action<string, Control>? registerNav)
    {
        shell.EnableCheck = source.EnableCheck;
        shell.FocusTarget = source.FocusTarget;
        shell.ValueControl = source.ValueControl;
        shell.PickerButton = source.PickerButton;
        shell.RowAnchor = source.RowAnchor;
        if (source.FocusTarget is not null)
            registerNav?.Invoke(token, source.FocusTarget);
    }

    private static bool UsesTopAlignedRow(SettingDefinition def) =>
        def.Kind == SettingControlKind.MultiSelect;

    private static (Control Row, OptionBinding Binding) CreateOptionRow(SettingDefinition def, string tabKey)
    {
        var topAligned = UsesTopAlignedRow(def);
        var (labelPanel, enableCheck, focusTarget) = CreateLabelPanel(def);
        var tooltip = SettingTooltipHelper.Build(def);
        ToolTip.SetTip(labelPanel, tooltip);
        if (enableCheck is not null)
            ToolTip.SetTip(enableCheck, tooltip);

        labelPanel.Margin = UiMetrics.OptionRowMargin;
        if (topAligned)
            labelPanel.MinHeight = UiMetrics.MultiRowHeight(def.Choices?.Length ?? def.ChoiceLabels?.Length ?? 0);
        labelPanel.Classes.Add("option-row");

        Control valueCtrl;
        Button? picker = null;
        Control? gridValue = null;

        if (def.Kind == SettingControlKind.Boolean)
        {
            valueCtrl = enableCheck!;
        }
        else
        {
            valueCtrl = CreateValueControl(def);

            if (def.Kind == SettingControlKind.Text && def.PathPicker != PathPickerKind.None && valueCtrl is TextBox textBox)
            {
                picker = MdiButtons.IconOnly(
                    MdiIcons.ForPathPicker(def.PathPicker),
                    def.PickerButtonTooltip ?? def.PickerButtonText ?? tooltip);
                textBox.Width = double.NaN;
                textBox.MinHeight = UiMetrics.ControlHeight;
                textBox.Height = UiMetrics.ControlHeight;
                textBox.HorizontalAlignment = HorizontalAlignment.Stretch;
                textBox.VerticalAlignment = VerticalAlignment.Center;
                ToolTip.SetTip(textBox, tooltip);
                var pickerRow = new Grid
                {
                    Width = UiMetrics.TextWidthLong,
                    ColumnDefinitions = new ColumnDefinitions("*,Auto"),
                    Margin = UiMetrics.OptionRowMargin,
                    Classes = { "option-value" },
                };
                picker.Margin = new Thickness(6, 0, 0, 0);
                Grid.SetColumn(textBox, 0);
                Grid.SetColumn(picker, 1);
                pickerRow.Children.Add(textBox);
                pickerRow.Children.Add(picker);
                gridValue = pickerRow;
            }
            else
            {
                ToolTip.SetTip(valueCtrl, tooltip);
                valueCtrl.Margin = UiMetrics.OptionRowMargin;
                valueCtrl.HorizontalAlignment = HorizontalAlignment.Left;
                valueCtrl.Classes.Add("option-value");
                gridValue = valueCtrl;
            }
        }

        var rowGrid = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions($"{UiMetrics.TokenColWidth},Auto"),
        };

        var labelCell = WrapRowCell(labelPanel, topAligned);
        Grid.SetColumn(labelCell, 0);
        rowGrid.Children.Add(labelCell);

        if (gridValue is not null)
        {
            var valueCell = WrapRowCell(gridValue, topAligned);
            Grid.SetColumn(valueCell, 1);
            rowGrid.Children.Add(valueCell);
        }

        var binding = new OptionBinding
        {
            Definition = def,
            EnableCheck = enableCheck,
            FocusTarget = focusTarget,
            ValueControl = valueCtrl,
            PickerButton = picker,
            RowAnchor = labelPanel,
            TabKey = tabKey,
        };

        return (rowGrid, binding);
    }

    private static Grid WrapRowCell(Control content, bool topAlign)
    {
        content.VerticalAlignment = topAlign ? VerticalAlignment.Top : VerticalAlignment.Center;
        content.HorizontalAlignment = HorizontalAlignment.Left;

        return new Grid
        {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            Children = { content },
        };
    }

    private static (Panel Panel, CheckBox? EnableCheck, Control FocusTarget) CreateLabelPanel(SettingDefinition def)
    {
        var children = new List<Control>();
        CheckBox? enableCheck = null;
        Control focusTarget;
        TextBlock? token = def.ShowToken ? CreateTokenTextBlock(def) : null;

        if (def.Kind == SettingControlKind.Boolean || def.ShowEnableCheckbox)
        {
            var labelStack = new StackPanel { Spacing = 2 };
            labelStack.Children.Add(new TextBlock { Text = def.Label, Classes = { "setting-label" } });
            if (token is not null)
                labelStack.Children.Add(token);

            enableCheck = new CheckBox
            {
                Content = labelStack,
                MaxWidth = UiMetrics.TokenColWidth - UiMetrics.CellPadH,
                VerticalAlignment = VerticalAlignment.Center,
            };
            children.Add(enableCheck);
            focusTarget = enableCheck;
        }
        else
        {
            var label = new TextBlock
            {
                Text = def.Label,
                Classes = { "setting-label" },
                MaxWidth = UiMetrics.TokenColWidth - UiMetrics.CellPadH,
                VerticalAlignment = VerticalAlignment.Center,
            };
            children.Add(label);
            focusTarget = label;
            if (token is not null)
                children.Add(token);
        }

        var stack = new StackPanel { Spacing = 2 };
        foreach (var child in children)
            stack.Children.Add(child);
        return (stack, enableCheck, focusTarget);
    }

    private static TextBlock CreateTokenTextBlock(SettingDefinition def)
    {
        var token = new TextBlock
        {
            Text = def.Token,
            Classes = { "setting-token" },
        };

        if (!string.IsNullOrEmpty(def.DocUrl))
        {
            token.Classes.Add("link");
            token.PointerPressed += (_, _) => Platform.PlatformServices.Current.OpenUrl(def.DocUrl!);
        }

        return token;
    }

    private static Control CreateValueControl(SettingDefinition def) => def.Kind switch
    {
        SettingControlKind.Numeric => CreateNumeric(def),
        SettingControlKind.Decimal => CreateDecimal(def),
        SettingControlKind.MultiSelect => CreateMultiSelect(def),
        SettingControlKind.Choice => CreateCombo(def),
        _ => CreateText(def),
    };

    private static NumericUpDown CreateNumeric(SettingDefinition def) =>
        new()
        {
            Minimum = def.NumericMin,
            Maximum = def.NumericMax,
            Value = def.NumericDefault,
            Width = UiMetrics.WidthNumeric,
            FormatString = "0",
        };

    private static NumericUpDown CreateDecimal(SettingDefinition def)
    {
        var places = Math.Max(0, def.DecimalPlaces);
        return new NumericUpDown
        {
            Minimum = def.DecimalMin,
            Maximum = def.DecimalMax,
            Value = def.DecimalDefault,
            Width = UiMetrics.WidthNumeric,
            FormatString = places == 0 ? "0" : $"F{places}",
        };
    }

    private static TextBox CreateText(SettingDefinition def) =>
        new()
        {
            Width = def.TextWidthBaseline,
            HorizontalAlignment = HorizontalAlignment.Left,
            MinHeight = UiMetrics.ControlHeight,
            Height = UiMetrics.ControlHeight,
            VerticalAlignment = VerticalAlignment.Center,
        };

    private static ComboBox CreateCombo(SettingDefinition def)
    {
        var display = def.ChoiceLabels ?? def.Choices ?? [];
        var c = new ComboBox
        {
            Width = UiMetrics.WidthCombo,
            ItemsSource = display,
            HorizontalAlignment = HorizontalAlignment.Left,
        };
        if (display.Length > 0)
            c.SelectedIndex = 0;
        return c;
    }

    private static Control CreateMultiSelect(SettingDefinition def)
    {
        var display = def.ChoiceLabels ?? def.Choices ?? [];
        var panel = new StackPanel { Spacing = 2 };
        foreach (var label in display)
            panel.Children.Add(new CheckBox { Content = label });

        return new Border
        {
            Classes = { "setting-input-frame" },
            Width = UiMetrics.WidthMulti,
            Height = UiMetrics.MultiRowHeight(display.Length),
            HorizontalAlignment = HorizontalAlignment.Left,
            Child = panel,
        };
    }
}
