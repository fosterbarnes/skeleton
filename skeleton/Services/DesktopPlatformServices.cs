using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Platform;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using skeleton.Platform;
using skeleton.Update;

namespace skeleton.Services;

internal sealed class DesktopPlatformServices : IPlatformServices
{
    public async Task<string?> PickFileAsync(string? title, string? filter)
    {
        var window = GetMainWindow();
        if (window?.StorageProvider is not { } storage)
            return null;

        var options = new FilePickerOpenOptions
        {
            Title = title,
            AllowMultiple = false,
        };

        if (!string.IsNullOrWhiteSpace(filter))
        {
            var ext = filter.Split('|').LastOrDefault()?.Trim('*', '.');
            if (!string.IsNullOrWhiteSpace(ext))
                options.FileTypeFilter = [new FilePickerFileType("Files") { Patterns = [$"*.{ext}"] }];
        }

        var files = await storage.OpenFilePickerAsync(options).ConfigureAwait(true);
        return files.Count > 0 ? files[0].TryGetLocalPath() : null;
    }

    public async Task<string?> PickSaveFileAsync(string? title, string? filter, string? defaultFileName = null)
    {
        var window = GetMainWindow();
        if (window?.StorageProvider is not { } storage)
            return null;

        var options = new FilePickerSaveOptions
        {
            Title = title,
            SuggestedFileName = defaultFileName,
        };

        if (!string.IsNullOrWhiteSpace(filter))
        {
            var ext = filter.Split('|').LastOrDefault()?.Trim('*', '.');
            if (!string.IsNullOrWhiteSpace(ext))
                options.FileTypeChoices = [new FilePickerFileType("Files") { Patterns = [$"*.{ext}"] }];
        }

        var file = await storage.SaveFilePickerAsync(options).ConfigureAwait(true);
        return file?.TryGetLocalPath();
    }

    public async Task<string?> PickFolderAsync(string? title)
    {
        var window = GetMainWindow();
        if (window?.StorageProvider is not { } storage)
            return null;

        var folders = await storage.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = title,
            AllowMultiple = false,
        }).ConfigureAwait(true);

        return folders.Count > 0 ? folders[0].TryGetLocalPath() : null;
    }

    public void OpenUrl(string url)
    {
        if (OperatingSystem.IsWindows() || OperatingSystem.IsLinux() || OperatingSystem.IsMacOS())
        {
            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = url,
                    UseShellExecute = true,
                });
            }
            catch (Exception ex)
            {
                UpdaterLogger.Write($"OpenUrl failed: {ex}");
            }
        }
    }

    public bool IsSystemDarkTheme()
    {
        if (Application.Current?.PlatformSettings?.GetColorValues() is { } colors)
            return colors.ThemeVariant == PlatformThemeVariant.Dark;
        return false;
    }

    public void ShowWarning(string title, string message) => ShowDialog(title, message);

    public void ShowError(string title, string message) => ShowDialog(title, message);

    private static void ShowDialog(string title, string message)
    {
        var window = GetMainWindow();
        if (window is null)
            return;

        Dispatcher.UIThread.Post(async () =>
        {
            var dialog = new Window
            {
                Title = title,
                Width = 420,
                Height = 160,
                WindowStartupLocation = WindowStartupLocation.CenterOwner,
                Content = new StackPanel
                {
                    Margin = new Thickness(16),
                    Spacing = 12,
                    Children =
                    {
                        new TextBlock { Text = message, TextWrapping = Avalonia.Media.TextWrapping.Wrap },
                        new Button
                        {
                            Content = "OK",
                            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
                        },
                    },
                },
            };

            if (dialog.Content is StackPanel panel && panel.Children[^1] is Button ok)
                ok.Click += (_, _) => dialog.Close();

            await dialog.ShowDialog(window);
        });
    }

    private static Window? GetMainWindow()
    {
        if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
            return desktop.MainWindow;
        return null;
    }
}
