namespace skeleton;

/// <summary>
/// Central branding for this app template. Customize these values when forking.
/// </summary>
public static class AppBranding
{
    /// <summary>User-facing application name (window titles, dialogs, about text).</summary>
    public const string DisplayName = "skeleton";

    /// <summary>Lowercase slug for exe names, folders, GitHub repo, assets, etc.</summary>
    public const string Slug = "skeleton";

    public const string RepoOwner = "fosterbarnes";

    public const string CopyrightHolder = "Foster Barnes";

    public static string UpdaterTitle => $"{DisplayName} Updater";

    public static string RepoUrl => $"https://github.com/{RepoOwner}/{Slug}";

    public const string ExeFileName = Slug + ".exe";

    public const string SolutionFileName = Slug + ".sln";

    public const string IconFileName = Slug + ".ico";

    public const string IconPngFileName = Slug + "256.png";

    public const string IconAssetsFolder = "Assets";

    public const string UserAgent = Slug + "-updater";

    public static string TempUpdateFolderPrefix => $"{Slug}-update";
}
