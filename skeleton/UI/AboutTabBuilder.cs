using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using skeleton.ViewModels;

namespace skeleton.UI;

internal static class AboutTabBuilder
{
    public static Control Build(MainWindowViewModel viewModel)
    {
        var icon = new Image
        {
            Width = UiMetrics.AboutIconPx,
            Height = UiMetrics.AboutIconPx,
            Margin = new Thickness(0, 2, 8, 0),
            VerticalAlignment = VerticalAlignment.Top,
            HorizontalAlignment = HorizontalAlignment.Left,
        };
        AppIconLoader.TryLoadAboutIcon(icon);

        var version = new SelectableTextBlock { Text = viewModel.VersionText };

        var repo = UiLinks.Command(viewModel.RepoUrl, viewModel.OpenRepoCommand);

        var checkBtn = new Button { Content = "Check for updates" };
        checkBtn.Click += (_, _) => viewModel.CheckForUpdatesManualCommand.Execute(null);

        var lead = new SelectableTextBlock
        {
            Text = viewModel.AboutLeadText,
            TextWrapping = TextWrapping.Wrap,
            MaxWidth = UiMetrics.AboutTextMaxWidthPx,
        };

        var textStack = new StackPanel
        {
            Spacing = 8,
            VerticalAlignment = VerticalAlignment.Top,
            HorizontalAlignment = HorizontalAlignment.Left,
            Children = { version, lead, repo, checkBtn },
        };

        var layout = new Grid
        {
            Margin = UiMetrics.TabContentPadding,
            VerticalAlignment = VerticalAlignment.Top,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            ColumnDefinitions = new ColumnDefinitions("Auto,*"),
            RowDefinitions = new RowDefinitions("Auto"),
            Children = { icon, textStack },
        };
        Grid.SetColumn(textStack, 1);
        return layout;
    }
}
