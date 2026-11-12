namespace TisaDynamicIsland.Models;

public static class DownloadScanner
{
    public static IReadOnlyList<DownloadEntry> Scan(string folder)
    {
        var entries = new List<DownloadEntry>();
        foreach (var path in Directory.EnumerateFiles(folder).Where(DownloadEntry.IsPartial))
        {
            // A browser can rename/delete a partial file between enumeration and reading its size.
            // That file must not prevent all the other downloads from updating.
            try { entries.Add(new DownloadEntry(path, new FileInfo(path).Length)); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        }
        return entries.OrderBy(d => d.Name, StringComparer.OrdinalIgnoreCase).ToArray();
    }
}
