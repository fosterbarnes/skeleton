using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using skeleton.Models;
using skeleton.Platform;
using skeleton.UI;
using skeleton.Updater.Services;
using skeleton.Updater.ViewModels;
using skeleton.Updater.Views;

namespace skeleton.Updater;

public partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        PlatformServices.Current = new UpdaterPlatformServices();
        UiTheme.ApplyAppTheme(this, UiThemeKind.System);

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop
            && Program.LaunchContext is { } context)
        {
            desktop.MainWindow = new UpdaterWindow
            {
                DataContext = new UpdaterWindowViewModel(context),
            };
        }

        base.OnFrameworkInitializationCompleted();
    }
}
