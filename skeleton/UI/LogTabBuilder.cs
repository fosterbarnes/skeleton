using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;

namespace skeleton.UI;

internal static class LogTabBuilder
{
    internal const string DisabledPlaceholder =
        "# Debug logging is disabled.\r\n# Enable it in App Settings → Logging.";

    public static (Control Content, TextBox Viewer) Build(string? initialText = null)
    {
        var viewer = new TextBox
        {
            AcceptsReturn = true,
            IsReadOnly = true,
            TextWrapping = TextWrapping.NoWrap,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            Text = initialText ?? DisabledPlaceholder,
            Classes = { "raw-editor" },
        };

        return (viewer, viewer);
    }
}
