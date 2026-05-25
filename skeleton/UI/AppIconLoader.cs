using Avalonia.Controls;
using Avalonia.Media.Imaging;

namespace skeleton.UI;

internal static class AppIconLoader
{
    public static void TryApplyWindowIcon(Window window)
    {
        foreach (var path in ResolveIcoPaths())
        {
            if (!File.Exists(path))
                continue;

            window.Icon = new WindowIcon(path);
            return;
        }
    }

    public static void TryLoadAboutIcon(Image image)
    {
        foreach (var path in ResolvePngPaths())
        {
            if (!File.Exists(path))
                continue;

            image.Source = new Bitmap(path);
            return;
        }
    }

    private static IEnumerable<string> ResolveIcoPaths()
    {
        var dir = AppContext.BaseDirectory;
        yield return Path.Combine(dir, AppBranding.IconAssetsFolder, AppBranding.IconFileName);
        yield return Path.Combine(dir, AppBranding.IconFileName);
    }

    private static IEnumerable<string> ResolvePngPaths()
    {
        var dir = AppContext.BaseDirectory;
        yield return Path.Combine(dir, AppBranding.IconAssetsFolder, AppBranding.IconPngFileName);
        yield return Path.Combine(dir, AppBranding.IconPngFileName);
    }
}
