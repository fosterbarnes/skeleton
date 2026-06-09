using System.Runtime.InteropServices;
using skeleton;

namespace skeleton.Update;

public static class ReleaseAssetNames
{
    public static string GetPortableAssetTag()
    {
        if (OperatingSystem.IsMacOS())
        {
            return ArchitectureHelper.GetCurrentArchitecture() switch
            {
                "arm64" => "macOS-arm",
                "x64" => "macOS-intel",
                _ => throw new PlatformNotSupportedException("Unsupported macOS architecture for portable updates."),
            };
        }

        return ArchitectureHelper.GetCurrentArchitecture();
    }

    public static string PortableZip(string version, string assetTag)
    {
        var normalizedVersion = GitHubRelease.NormalizeTag(version);
        if (assetTag.StartsWith("macOS-", StringComparison.Ordinal))
            return $"{AppBranding.Slug}_v{normalizedVersion}_{assetTag}.zip";

        return $"{AppBranding.PortableZipAssetPrefix}_v{normalizedVersion}_{assetTag}.zip";
    }
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
