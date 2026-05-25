using skeleton;

namespace skeleton.Update;

public static class UpdateConstants
{
    public const string RepoOwner = AppBranding.RepoOwner;
    public const string RepoName = AppBranding.Slug;
    public const string UserAgent = AppBranding.UserAgent;
    public const string AppExeName = AppBranding.ExeFileName;
    public const string UpdaterExeName = "updater.exe";
    public const string VersionFileName = "Version";
    public const string VersionBuildFileName = "VersionBuild";
    public const string PendingUpdaterRefreshFileName = ".pending-updater-refresh";

    public static string LatestReleaseApiUrl =>
        $"https://api.github.com/repos/{RepoOwner}/{RepoName}/releases/latest";

    public static string ReleasesPageUrl =>
        $"https://github.com/{RepoOwner}/{RepoName}/releases";
}
