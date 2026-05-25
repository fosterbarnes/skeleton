using System.Collections.ObjectModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Data;
using Avalonia.Layout;
using Material.Icons;
using skeleton.Models;

namespace skeleton.UI;

internal static class GridViewTabBuilder
{
    public sealed class Handle
    {
        public required DataGrid Grid { get; init; }
        public required Button AddButton { get; init; }
        public required Button RemoveButton { get; init; }
    }

    public static (Control Content, Handle Tab) Build(ObservableCollection<FileListEntry> items)
    {
        var addButton = MdiButtons.IconOnly(MaterialIconKind.PlusThick, "Add");
        var removeButton = MdiButtons.IconOnly(MaterialIconKind.MinusThick, "Remove");

        var toolbar = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = UiMetrics.StatusFooterButtonSpacingPx,
            Margin = new Thickness(0, 0, 0, UiMetrics.GroupBoxBottomGapPx),
            Children = { addButton, removeButton },
        };

        var grid = new DataGrid
        {
            Classes = { "file-list-grid" },
            ItemsSource = items,
            IsReadOnly = true,
            CanUserSortColumns = true,
            CanUserReorderColumns = false,
            CanUserResizeColumns = true,
            AutoGenerateColumns = false,
            HeadersVisibility = DataGridHeadersVisibility.Column,
            SelectionMode = DataGridSelectionMode.Single,
            GridLinesVisibility = DataGridGridLinesVisibility.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch,
            Columns =
            {
                new DataGridTextColumn
                {
                    Header = "File",
                    Binding = new Binding(nameof(FileListEntry.FileName)),
                    Width = new DataGridLength(1, DataGridLengthUnitType.Star),
                },
                new DataGridTextColumn
                {
                    Header = "Path",
                    Binding = new Binding(nameof(FileListEntry.Path)),
                    Width = new DataGridLength(2, DataGridLengthUnitType.Star),
                },
            },
        };

        var layout = new Grid
        {
            Margin = UiMetrics.TabContentPadding,
            RowDefinitions = new RowDefinitions("Auto,*"),
            Children = { toolbar, grid },
        };
        Grid.SetRow(toolbar, 0);
        Grid.SetRow(grid, 1);

        return (layout, new Handle { Grid = grid, AddButton = addButton, RemoveButton = removeButton });
    }
}
