using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Threading;
using skeleton.UI;
using skeleton.ViewModels;

namespace skeleton.Views;

public partial class MainWindow : Window
{
    private MainWindowViewModel ViewModel => (MainWindowViewModel)DataContext!;

    public MainWindow()
    {
        InitializeComponent();
        AppIconLoader.TryApplyWindowIcon(this);
        MacWindowChrome.TryApplyUnifiedTitleBar(this, MacChromeBar, MacTabHeaders, MainTabs, SearchBox);
        AddHandler(KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
    }

    protected override void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        ViewModel.RestoreWindowBounds(this);
        UiTheme.ApplyWindowThemeVariant(this, ViewModel.SelectedTheme);
        ViewModel.ThemeChanged += theme => UiTheme.ApplyWindowTheme(this, theme);
        ViewModel.FontsChanged += () =>
            TabChromeHelper.ResetAndSyncTabWidths(MainTabs, MacTabHeaders);
        TabChromeHelper.ApplyUniformTabWidths(MainTabs, MacTabHeaders);
        WireSearch();
        ScheduleDeferredStartupWork();
    }

    private void ScheduleDeferredStartupWork()
    {
        Dispatcher.UIThread.Post(() =>
        {
            ViewModel.EndDeferTabContentBuild();
            ViewModel.EnsureSelectedTabContent();
            ViewModel.RegisterPickerButtons();
            MacWindowChrome.ScheduleMacTabHeaderWidthSync(MacTabHeaders);
        }, DispatcherPriority.Background);

        Dispatcher.UIThread.Post(ViewModel.BeginStartupUpdateCheck, DispatcherPriority.ApplicationIdle);
    }

    protected override void OnClosing(WindowClosingEventArgs e)
    {
        ViewModel.SaveWindowState(this);
        base.OnClosing(e);
    }

    private void WireSearch()
    {
        SearchResults.ItemsSource = ViewModel.SearchResults;
        SearchResults.SelectionChanged += (_, _) =>
        {
            if (SearchResults.SelectedItem is SettingSearchHit hit)
            {
                ViewModel.PickSearchResultCommand.Execute(hit);
                SearchPopup.IsOpen = false;
                SearchResults.SelectedItem = null;
            }
        };

        ViewModel.SearchResults.CollectionChanged += (_, _) =>
            SearchPopup.IsOpen = ViewModel.SearchResults.Count > 0;
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (ViewModel.SearchEnabled && e.KeyModifiers.HasFlag(KeyModifiers.Control) && e.Key == Key.F)
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
            e.Handled = true;
        }
    }
}
