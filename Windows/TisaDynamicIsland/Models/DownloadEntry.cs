namespace TisaDynamicIsland.Models;

public record DownloadEntry(string Path, long Bytes)
{
    public string Name => System.IO.Path.GetFileName(Path);
    public string Detail => $"{Bytes / 1048576d:0.0} MB downloaded • total size unavailable";
    public static bool IsPartial(string path) =>
        path.EndsWith(".crdownload", StringComparison.OrdinalIgnoreCase) ||
        path.EndsWith(".part", StringComparison.OrdinalIgnoreCase);
}
