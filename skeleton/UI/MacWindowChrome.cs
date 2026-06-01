using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Chrome;
using Avalonia.Controls.Presenters;
using Avalonia.Controls.Templates;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Threading;
using Avalonia.VisualTree;

namespace skeleton.UI;

internal static class MacWindowChrome
{
    public static void TryApplyUnifiedTitleBar(
        Window window,
        Grid macChromeBar,
        ListBox macTabHeaders,
        TabControl mainTabs,
        TextBox searchBox)
    {
        if (!OperatingSystem.IsMacOS())
            return;

        window.ExtendClientAreaToDecorationsHint = true;
        window.ExtendClientAreaTitleBarHeightHint = (int)UiMetrics.TabStripHeight;
        window.Classes.Add("mac-unified-chrome");

        macChromeBar.IsVisible = true;
        if (macChromeBar.ColumnDefinitions.Count > 0)
            macChromeBar.ColumnDefinitions[0].Width = new GridLength(UiMetrics.MacTrafficLightLeadingInset);
        ReparentSearchBox(macChromeBar, searchBox);

        WindowDecorationProperties.SetElementRole(macChromeBar, WindowDecorationsElementRole.TitleBar);
        WindowDecorationProperties.SetElementRole(macTabHeaders, WindowDecorationsElementRole.TitleBar);
        WindowDecorationProperties.SetElementRole(searchBox, WindowDecorationsElementRole.User);
        WireMacTabHeaderSelection(macTabHeaders);

        mainTabs.TemplateApplied += (_, e) => HideBuiltInTabHeaders(mainTabs, e.NameScope);
        mainTabs.Loaded += (_, _) => HideBuiltInTabHeaders(mainTabs, null);
        macTabHeaders.Loaded += (_, _) => TabChromeHelper.SyncMacTabHeaderWidths(macTabHeaders);
    }

    public static void ScheduleMacTabHeaderWidthSync(ListBox macTabHeaders)
    {
        if (!OperatingSystem.IsMacOS())
            return;

        Dispatcher.UIThread.Post(
            () => TabChromeHelper.SyncMacTabHeaderWidths(macTabHeaders),
            DispatcherPriority.Background);
    }

    private static void ReparentSearchBox(Grid macChromeBar, TextBox searchBox)
    {
        if (searchBox.Parent is Panel parent)
            parent.Children.Remove(searchBox);

        Grid.SetColumn(searchBox, 2);
        Grid.SetRow(searchBox, 0);
        searchBox.VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center;
        searchBox.HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Stretch;
        searchBox.Margin = UiMetrics.MacChromeSearchMargin;
        macChromeBar.Children.Add(searchBox);
    }

    private static ItemsPresenter? FindTabHeaderPresenter(TabControl mainTabs, INameScope? nameScope) =>
        nameScope?.Find<ItemsPresenter>("PART_ItemsPresenter")
        ?? mainTabs.GetVisualDescendants().OfType<ItemsPresenter>()
            .FirstOrDefault(p => p.Name == "PART_ItemsPresenter");

    private static void HideBuiltInTabHeaders(TabControl mainTabs, INameScope? nameScope)
    {
        if (!OperatingSystem.IsMacOS())
            return;

        var itemsPresenter = FindTabHeaderPresenter(mainTabs, nameScope);
        if (itemsPresenter is null)
            return;

        itemsPresenter.IsVisible = false;
        itemsPresenter.Height = 0;
        itemsPresenter.MinHeight = 0;
        itemsPresenter.MaxHeight = 0;
    }

    private static void WireMacTabHeaderSelection(ListBox macTabHeaders)
    {
        Point? pressOrigin = null;

        macTabHeaders.AddHandler(
            InputElement.PointerPressedEvent,
            (_, e) =>
            {
                if (e.GetCurrentPoint(macTabHeaders).Properties.IsLeftButtonPressed)
                    pressOrigin = e.GetPosition(macTabHeaders);
            },
            RoutingStrategies.Tunnel);

        macTabHeaders.AddHandler(
            InputElement.PointerReleasedEvent,
            (_, e) =>
            {
                if (pressOrigin is not Point origin)
                    return;

                var release = e.GetPosition(macTabHeaders);
                pressOrigin = null;
                var dx = release.X - origin.X;
                var dy = release.Y - origin.Y;
                if (dx * dx + dy * dy >= 16)
                    return;

                var index = HitTestTabHeaderIndex(macTabHeaders, release);
                if (index >= 0)
                    macTabHeaders.SelectedIndex = index;
            },
            RoutingStrategies.Tunnel);
    }

    private static int HitTestTabHeaderIndex(ListBox macTabHeaders, Point position)
    {
        for (var i = 0; i < macTabHeaders.Items.Count; i++)
        {
            if (macTabHeaders.ContainerFromIndex(i) is not Visual item)
                continue;

            var topLeft = item.TranslatePoint(new Point(), macTabHeaders);
            if (topLeft is null)
                continue;

            var rect = new Rect(topLeft.Value, item.Bounds.Size);
            if (rect.Contains(position))
                return i;
        }

        return -1;
    }

}
