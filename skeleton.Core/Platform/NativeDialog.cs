using System.Diagnostics;
using System.Runtime.InteropServices;

namespace skeleton.Platform;

public static class NativeDialog
{
    public static void ShowError(string title, string message)
    {
        if (OperatingSystem.IsWindows())
        {
            MessageBoxW(IntPtr.Zero, message, title, MbIconError);
            return;
        }

        if (OperatingSystem.IsMacOS())
        {
            RunOsascriptAlert(title, message);
        }
    }

    private static void RunOsascriptAlert(string title, string message)
    {
        var script = $"display alert {Quote(title)} message {Quote(message)} as critical";
        using var process = Process.Start(new ProcessStartInfo
        {
            FileName = "osascript",
            ArgumentList = { "-e", script },
            UseShellExecute = false,
            CreateNoWindow = true,
        });
        process?.WaitForExit(5000);
    }

    private static string Quote(string value) =>
        '"' + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + '"';

    private const uint MbIconError = 0x00000010;

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "MessageBoxW")]
    private static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);
}
