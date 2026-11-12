using TisaDynamicIsland.Models;

namespace TisaDynamicIsland.Services;

public sealed class DownloadService
{
    public ObservableCollection<DownloadEntry> Entries { get; } = new();
    public string Folder { get; }
    public DownloadService(string? folder = null)
    {
        try { Folder = folder ?? NativeMethods.DownloadsFolder(); }
        catch (COMException) { Folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"); }
    }
    public string? Error { get; private set; }
    public async Task RefreshAsync()
    {
        try
        {
            var downloads = await Task.Run(() => DownloadScanner.Scan(Folder));
            // Preserve collection items and scroll/selection when the folder hasn't changed.
            for (var index = Entries.Count - 1; index >= 0; index--)
                if (!downloads.Any(d => d.Path == Entries[index].Path)) Entries.RemoveAt(index);
            for (var index = 0; index < downloads.Count; index++)
            {
                var entry = downloads[index];
                var existing = Entries.FirstOrDefault(d => d.Path == entry.Path);
                if (existing == null) Entries.Insert(index, entry);
                else
                {
                    var previous = Entries.IndexOf(existing);
                    if (previous != index) Entries.Move(previous, index);
                    if (existing != entry) Entries[index] = entry;
                }
            }
            Error = null;
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        { Entries.Clear(); Error = "Downloads folder is unavailable. Check the folder and its permissions."; }
    }
}
