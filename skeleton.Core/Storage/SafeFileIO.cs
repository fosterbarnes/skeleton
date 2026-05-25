using System.Text;

namespace skeleton.Storage;

public static class SafeFileIO
{
    public const int MaxJsonBytes = 256 * 1024;

    public static string ReadAllText(string path, int maxBytes, Encoding? encoding = null)
    {
        var length = new FileInfo(path).Length;
        if (length > maxBytes)
        {
            throw new InvalidOperationException(
                $"File is too large ({FormatBytes(length)}). Maximum is {FormatBytes(maxBytes)}.");
        }

        return encoding is null ? File.ReadAllText(path) : File.ReadAllText(path, encoding);
    }

    private static string FormatBytes(long bytes)
    {
        if (bytes >= 1024 * 1024)
            return $"{bytes / (1024 * 1024)} MB";
        if (bytes >= 1024)
            return $"{bytes / 1024} KB";
        return $"{bytes} bytes";
    }
}
