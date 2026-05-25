using skeleton;

namespace skeleton.Update;

public static class ReleaseAssetNames
{
    public static string PortableZip(string version, string architecture) =>
        $"{AppBranding.PortableZipAssetPrefix}_v{GitHubRelease.NormalizeTag(version)}_{architecture}.zip";
}

public static class GitHubReleaseExtensions
{
    extension(GitHubRelease release)
    {
        public GitHubReleaseAsset? FindPortableAsset(string architecture)
        {
            var expected = ReleaseAssetNames.PortableZip(release.Version, architecture);
            return release.Assets.FirstOrDefault(a =>
                string.Equals(a.Name, expected, StringComparison.OrdinalIgnoreCase));
        }
    }
}
