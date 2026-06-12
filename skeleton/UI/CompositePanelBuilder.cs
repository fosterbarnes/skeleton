using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using skeleton.Settings;
using skeleton.ViewModels;

namespace skeleton.UI;

internal static class CompositePanelBuilder
{
    public static (Control Content, Control FocusTarget) Build(SettingDefinition def, MainWindowViewModel viewModel) =>
        def.Kind switch
        {
            SettingControlKind.EntryList => BuildEntryList(def, viewModel),
            SettingControlKind.RadioGroup => BuildRadioGroup(def, viewModel),
            _ => throw new ArgumentOutOfRangeException(nameof(def.Kind), def.Kind, "Not a composite setting kind."),
        };

    private static (Control Content, Control FocusTarget) BuildEntryList(
        SettingDefinition def,
        MainWindowViewModel viewModel)
    {
        var itemCount = viewModel.DemoListItems.Count;
        var listBox = new ListBox
        {
            ItemsSource = viewModel.DemoListItems,
            Height = UiMetrics.EntryListHeight(itemCount),
            HorizontalAlignment = HorizontalAlignment.Stretch,
        };
        ScrollViewer.SetVerticalScrollBarVisibility(listBox, ScrollBarVisibility.Disabled);
        ScrollViewer.SetHorizontalScrollBarVisibility(listBox, ScrollBarVisibility.Disabled);

        var frame = new Border
        {
            Classes = { "setting-input-frame" },
            Child = listBox,
        };

        var btnRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        btnRow.Children.Add(new Button { Content = "Add" });
        btnRow.Children.Add(new Button { Content = "Remove" });
        btnRow.Children.Add(new Button { Content = "Edit" });

        var stack = new StackPanel { Spacing = UiMetrics.CompositeControlGapPx, Children = { frame, btnRow } };
        ToolTip.SetTip(stack, SettingTooltipHelper.Build(def));
        return (stack, listBox);
    }

    private static (Control Content, Control FocusTarget) BuildRadioGroup(
        SettingDefinition def,
        MainWindowViewModel viewModel)
    {
        var options = def.Choices ?? def.ChoiceLabels ?? [];
        var radioPanel = new StackPanel { Spacing = UiMetrics.CompositeRadioSpacingPx };
        var demoRadios = new List<RadioButton>();
        RadioButton? first = null;

        for (var i = 0; i < options.Length; i++)
        {
            var idx = i;
            var rb = new RadioButton
            {
                Content = options[i],
                GroupName = def.Token,
                IsChecked = idx == viewModel.SelectedDemoRadioIndex,
            };
            rb.IsCheckedChanged += (_, _) =>
            {
                if (rb.IsChecked == true)
                    viewModel.SelectedDemoRadioIndex = idx;
            };
            if (first is null)
                first = rb;
            demoRadios.Add(rb);
            radioPanel.Children.Add(rb);
        }

        viewModel.RegisterDemoRadios(demoRadios);

        ToolTip.SetTip(radioPanel, SettingTooltipHelper.Build(def));
        Control focusTarget = first is not null ? first : radioPanel;
        return (radioPanel, focusTarget);
    }
}
