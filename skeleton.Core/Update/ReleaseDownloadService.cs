using System.IO.Compression;
using skeleton.Storage;

namespace skeleton.Update;

public static class ReleaseDownloadService
{
    public static async Task<string> DownloadPortableZipAsync(
        GitHubRelease release,
        string architecture,
        IProgress<(float Progress, string Status)>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var asset = release.FindPortableAsset(architecture)
            ?? throw new InvalidOperationException(
                $"Release asset not found: {ReleaseAssetNames.PortableZip(release.Version, architecture)}");

        var tempPath = Path.Combine(Path.GetTempPath(), $"{Path.GetRandomFileName()}-{asset.Name}");

        progress?.Report((0f, $"Downloading {asset.Name}..."));
        try
        {
            await GitHubReleaseService.DownloadAssetAsync(asset, tempPath, progress, cancellationToken).ConfigureAwait(false);
            ValidateZip(tempPath, asset.Name);
        }
        catch
        {
            FileDeleteHelper.TryDeleteFile(tempPath);
            throw;
        }

        progress?.Report((1f, $"Downloaded {asset.Name}"));
        return tempPath;
    }

    public static async Task RefreshUpdaterExecutableAsync(
        string installDirectory,
        GitHubRelease release,
        string architecture,
        CancellationToken cancellationToken = default)
    {
        var zipPath = await DownloadPortableZipAsync(release, architecture, cancellationToken: cancellationToken)
            .ConfigureAwait(false);
        try
        {
            ExtractUpdaterFromZip(zipPath, installDirectory);
        }
        finally
        {
            FileDeleteHelper.TryDeleteFile(zipPath);
        }
    }

    public static void ExtractUpdaterFromZip(string zipPath, string installDirectory)
    {
        using var archive = ZipFile.OpenRead(zipPath);
        var entry = archive.Entries.FirstOrDefault(e =>
            string.Equals(e.Name, UpdateConstants.UpdaterExeName, StringComparison.OrdinalIgnoreCase));
        if (entry is null)
            throw new InvalidOperationException($"{UpdateConstants.UpdaterExeName} was not found in the release archive.");

        var tempUpdater = Path.Combine(Path.GetTempPath(), $"{Path.GetRandomFileName()}-{UpdateConstants.UpdaterExeName}");
        try
        {
            entry.ExtractToFile(tempUpdater, overwrite: true);
            var destination = Path.Combine(installDirectory, UpdateConstants.UpdaterExeName);
            File.Copy(tempUpdater, destination, overwrite: true);
        }
        finally
        {
            FileDeleteHelper.TryDeleteFile(tempUpdater);
        }
    }

    private static void ValidateZip(string zipPath, string assetName)
    {
        try
        {
            using var archive = ZipFile.OpenRead(zipPath);
            if (archive.Entries.Count == 0)
                throw new InvalidOperationException($"{assetName} is an empty archive.");
        }
        catch (InvalidDataException ex)
        {
            throw new InvalidOperationException($"{assetName} is not a valid zip archive: {ex.Message}", ex);
        }
    }
}
