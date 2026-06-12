using Avalonia.Controls;
using System.Windows.Input;

namespace skeleton.UI;

internal static class UiLinks
{
    public static HyperlinkButton Command(string text, ICommand command) =>
        new()
        {
            Content = new TextBlock { Text = text },
            Command = command,
            Classes = { "app-link" },
        };
}
