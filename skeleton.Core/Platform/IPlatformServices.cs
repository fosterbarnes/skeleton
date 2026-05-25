namespace skeleton.Platform;

public interface IPlatformServices
{
    Task<string?> PickFileAsync(string? title, string? filter);
    Task<string?> PickSaveFileAsync(string? title, string? filter, string? defaultFileName = null);
    Task<string?> PickFolderAsync(string? title);
    void OpenUrl(string url);
    bool IsSystemDarkTheme();
    void ShowWarning(string title, string message);
    void ShowError(string title, string message);
}
