using TisaDynamicIsland.Models;

namespace TisaDynamicIsland.Services;

public sealed class DownloadService
{
    public ObservableCollection<DownloadEntry> Entries { get; } = new();
    public string Folder { get; } = NativeMethods.DownloadsFolder();
    public string? Error { get; private set; }
    public void Refresh()
    {
        try
        {
            var downloads = Directory.EnumerateFiles(Folder).Where(DownloadEntry.IsPartial)
                .Select(p => new DownloadEntry(p, new FileInfo(p).Length)).OrderBy(d => d.Name).ToArray();
            Entries.Clear();
            foreach (var download in downloads) Entries.Add(download);
            Error = null;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { Error = "Downloads folder is unavailable."; }
    }
}
