using TisaDynamicIsland.Models;

namespace TisaDynamicIsland.Services;

public sealed class DownloadService
{
    public ObservableCollection<DownloadEntry> Entries { get; } = new();
    public string Folder { get; }
    private readonly Func<string, IReadOnlyList<DownloadEntry>> scan;
    private readonly TimeSpan timeout;
    public DownloadService(string? folder = null) : this(folder, DownloadScanner.Scan, TimeSpan.FromSeconds(3)) { }
    internal DownloadService(string? folder, Func<string, IReadOnlyList<DownloadEntry>> scanner, TimeSpan scanTimeout)
    {
        scan = scanner;
        timeout = scanTimeout;
        try { Folder = folder ?? NativeMethods.DownloadsFolder(); }
        catch (COMException) { Folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"); }
    }
    public string? Error { get; private set; }
    private Task<IReadOnlyList<DownloadEntry>>? pendingScan;
    public async Task RefreshAsync()
    {
        try
        {
            // Reuse a blocked filesystem scan instead of spawning another thread each poll.
            pendingScan ??= Task.Run(() => scan(Folder));
            var downloads = await pendingScan.WaitAsync(timeout);
            pendingScan = null;
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
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or TimeoutException)
        {
            if (pendingScan?.IsCompleted == true) pendingScan = null;
            Entries.Clear(); Error = "Downloads folder is unavailable. Check the folder and its permissions.";
        }
    }
}
