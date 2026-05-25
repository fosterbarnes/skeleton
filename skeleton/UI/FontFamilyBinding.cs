using Avalonia.Controls;
using skeleton.Settings;

namespace skeleton.UI;

internal sealed class FontFamilyBinding
{
    public required string Token { get; init; }
    public required SettingDefinition Definition { get; init; }
    public required ComboBox Combo { get; init; }
    public required Control FocusTarget { get; init; }
}
