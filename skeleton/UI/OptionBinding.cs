using Avalonia.Controls;
using skeleton.Settings;

namespace skeleton.UI;

internal sealed class OptionBinding
{
    public required SettingDefinition Definition { get; init; }
    public CheckBox? EnableCheck { get; set; }
    public Control? FocusTarget { get; set; }
    public Control? ValueControl { get; set; }
    public Button? PickerButton { get; set; }
    public Control? RowAnchor { get; set; }
    public string TabKey { get; init; } = string.Empty;
}
