using System.Runtime.InteropServices;

namespace skeleton.Platform;

public static class NativeDialog
{
    public static void ShowError(string title, string message)
    {
        if (OperatingSystem.IsWindows())
            MessageBoxW(IntPtr.Zero, message, title, MbIconError);
    }

    private const uint MbIconError = 0x00000010;

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "MessageBoxW")]
    private static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);
}
