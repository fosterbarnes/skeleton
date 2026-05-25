using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace skeleton.UI;

internal static class TabChromeHelper
{
    private static readonly Dictionary<(string Text, double FontSize), double> HeaderWidthCache = new();

    public static void ApplyUniformTabWidths(TabControl tabs)
    {
        tabs.Loaded += OnTabsLoaded;
    }

    public static void ResetAndSyncTabWidths(TabControl tabs)
    {
        HeaderWidthCache.Clear();
        if (tabs.IsLoaded)
            SyncTabWidths(tabs);
    }

    private static void OnTabsLoaded(object? sender, EventArgs e)
    {
        if (sender is not TabControl tabs)
            return;

        tabs.Loaded -= OnTabsLoaded;
        SyncTabWidths(tabs);
    }

    private static void SyncTabWidths(TabControl tabs)
    {
        if (tabs.Items.Count == 0)
            return;

        for (var i = 0; i < tabs.Items.Count; i++)
        {
            if (tabs.ContainerFromIndex(i) is not TabItem)
                return;
        }

        var maxWidth = 72.0;
        for (var i = 0; i < tabs.Items.Count; i++)
        {
            if (tabs.ContainerFromIndex(i) is not TabItem tabItem)
                continue;

            var header = tabItem.Header?.ToString() ?? string.Empty;
            if (string.IsNullOrEmpty(header))
                continue;

            var width = MeasureHeaderWidth(header) + UiMetrics.TabHorizontalPadding * 2;
            if (width > maxWidth)
                maxWidth = width;
        }

        maxWidth = Math.Min(maxWidth, 140);

        for (var i = 0; i < tabs.Items.Count; i++)
        {
            if (tabs.ContainerFromIndex(i) is TabItem tabItem)
            {
                tabItem.Width = double.NaN;
                tabItem.MinWidth = maxWidth;
            }
        }
    }

    private static double MeasureHeaderWidth(string text)
    {
        var fontSize = UiFontService.GetTabSize(Application.Current);
        var key = (text, fontSize);
        if (HeaderWidthCache.TryGetValue(key, out var cached))
            return cached;

        var probe = new TextBlock
        {
            Text = text,
            FontSize = fontSize,
            FontWeight = FontWeight.Normal,
        };
        probe.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
        HeaderWidthCache[key] = probe.DesiredSize.Width;
        return probe.DesiredSize.Width;
    }
}
