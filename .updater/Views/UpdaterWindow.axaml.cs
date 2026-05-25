using Avalonia.Controls;
using skeleton.Updater.ViewModels;

namespace skeleton.Updater.Views;

public partial class UpdaterWindow : Window
{
    private UpdaterWindowViewModel ViewModel => (UpdaterWindowViewModel)DataContext!;

    public UpdaterWindow()
    {
        InitializeComponent();
    }

    protected override async void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        ViewModel.RequestClose += Close;
        Closing += (_, _) => ViewModel.OnClosing();
        await ViewModel.OnShownAsync();
    }
}
