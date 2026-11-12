namespace TisaDynamicIsland.Models;

public sealed record ShelfEntry(string Path)
{
    public string Name => System.IO.Path.GetFileName(System.IO.Path.TrimEndingDirectorySeparator(Path));
}
