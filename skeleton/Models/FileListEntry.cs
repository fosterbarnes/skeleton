namespace skeleton.Models;

public sealed class FileListEntry
{
    public required string Path { get; init; }

    public string FileName => System.IO.Path.GetFileName(Path);
}
