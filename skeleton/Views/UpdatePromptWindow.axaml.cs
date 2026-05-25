using Avalonia.Controls;
using skeleton.Update;
using skeleton.UI;

namespace skeleton.Views;

internal sealed class UpdatePromptWindow : Window
{
    private UpdatePromptWindow(UpdateCheckResult result)
    {
        Title = "Update available";
        Width = 420;
        Height = 160;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        CanResize = false;
        AppIconLoader.TryApplyWindowIcon(this);

        var message = new TextBlock
        {
            Text = $"A new version of {AppBranding.DisplayName} is available (v{result.LatestVersion}).\n"
                + $"You are currently running v{result.CurrentVersion}.\n\nApply now?",
            TextWrapping = Avalonia.Media.TextWrapping.Wrap,
            Margin = new Avalonia.Thickness(16, 16, 16, 8),
        };

        var apply = new Button { Content = "Apply now", HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right };
        var later = new Button { Content = "Later", HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right, Margin = new Avalonia.Thickness(0, 0, 8, 0) };

        var buttons = new StackPanel
        {
            Orientation = Avalonia.Layout.Orientation.Horizontal,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
            Margin = new Avalonia.Thickness(16),
            Spacing = 8,
            Children = { later, apply },
        };

        Content = new StackPanel { Children = { message, buttons } };

        apply.Click += (_, _) => Close(true);
        later.Click += (_, _) => Close(false);
    }

    public static bool Prompt(UpdateCheckResult result)
    {
        if (Avalonia.Application.Current?.ApplicationLifetime
            is not Avalonia.Controls.ApplicationLifetimes.IClassicDesktopStyleApplicationLifetime desktop
            || desktop.MainWindow is null)
            return false;

        var dialog = new UpdatePromptWindow(result);
        return dialog.ShowDialog<bool>(desktop.MainWindow).GetAwaiter().GetResult();
    }
}
