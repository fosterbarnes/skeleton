namespace skeleton.Platform;

public static class PlatformServices
{
    public static IPlatformServices Current { get; set; } = NullPlatformServices.Instance;
}

internal sealed class NullPlatformServices : IPlatformServices
{
    public static NullPlatformServices Instance { get; } = new();

    public Task<string?> PickFileAsync(string? title, string? filter) => Task.FromResult<string?>(null);
    public Task<string?> PickSaveFileAsync(string? title, string? filter, string? defaultFileName = null) =>
        Task.FromResult<string?>(null);
    public Task<string?> PickFolderAsync(string? title) => Task.FromResult<string?>(null);
    public void OpenUrl(string url) { }
    public bool IsSystemDarkTheme() => false;
    public void ShowWarning(string title, string message) { }
    public void ShowError(string title, string message) { }
}
