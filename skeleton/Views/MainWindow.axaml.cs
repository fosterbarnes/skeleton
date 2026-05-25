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
        AddHandler(KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
    }

    protected override void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        ViewModel.RestoreWindowBounds(this);
        UiTheme.ApplyWindowTheme(this, ViewModel.SelectedTheme);
        ViewModel.ThemeChanged += theme => UiTheme.ApplyWindowTheme(this, theme);
        ViewModel.FontsChanged += () => TabChromeHelper.ResetAndSyncTabWidths(MainTabs);
        ViewModel.EnsureSelectedTabContent();
        TabChromeHelper.ApplyUniformTabWidths(MainTabs);
        WireSearch();

        Dispatcher.UIThread.Post(() =>
        {
            ViewModel.RegisterPickerButtons();
            ViewModel.BeginStartupUpdateCheck();
        }, DispatcherPriority.Background);
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
