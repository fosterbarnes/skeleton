using System.Runtime.InteropServices;
using skeleton;

namespace skeleton.Update;

public static class ReleaseAssetNames
{
    public static string GetPortableAssetTag()
    {
        var arch = ArchitectureHelper.GetCurrentArchitecture();
        if (OperatingSystem.IsMacOS())
            return $"osx-{arch}";
        return arch;
    }

    public static string PortableZip(string version, string assetTag) =>
        $"{AppBranding.PortableZipAssetPrefix}_v{GitHubRelease.NormalizeTag(version)}_{assetTag}.zip";
}

public static class GitHubReleaseExtensions
{
    extension(GitHubRelease release)
    {
        public GitHubReleaseAsset? FindPortableAsset(string? assetTag = null)
        {
            assetTag ??= ReleaseAssetNames.GetPortableAssetTag();
            var expected = ReleaseAssetNames.PortableZip(release.Version, assetTag);
            return release.Assets.FirstOrDefault(a =>
                string.Equals(a.Name, expected, StringComparison.OrdinalIgnoreCase));
        }
    }
}
