using System.Windows;
using System.Windows.Media.Imaging;

namespace TisaDynamicIsland.Services;

public sealed record ClipboardEntry(string Preview, string? Text, BitmapSource? Image);

public sealed class ClipboardService
{
    public ObservableCollection<ClipboardEntry> Entries { get; } = new();
    private bool ignoreNext;
    private readonly uint excluded = NativeMethods.RegisterClipboardFormat("ExcludeClipboardContentFromMonitorProcessing");
    private readonly uint history = NativeMethods.RegisterClipboardFormat("CanIncludeInClipboardHistory");

    public void Capture(IntPtr hwnd)
    {
        if (ignoreNext) { ignoreNext = false; return; }
        if (NativeMethods.IsClipboardFormatAvailable(excluded)) return;
        // Honor Windows' opt-out format, used by credential tools.
        if (NativeMethods.IsClipboardFormatAvailable(history))
        {
            if (!NativeMethods.OpenClipboard(hwnd)) return;
            try
            {
                var handle = NativeMethods.GetClipboardData(history);
                var pointer = NativeMethods.GlobalLock(handle);
                if (pointer == IntPtr.Zero) return;
                try { if (Marshal.ReadInt32(pointer) == 0) return; }
                finally { NativeMethods.GlobalUnlock(handle); }
            }
            finally { NativeMethods.CloseClipboard(); }
        }
        try
        {
            ClipboardEntry? entry = null;
            if (Clipboard.ContainsText())
            {
                var text = Clipboard.GetText();
                if (string.IsNullOrWhiteSpace(text) || text.Length > 100_000) return;
                if (Entries.FirstOrDefault()?.Text == text) return;
                entry = new(text.Length > 160 ? text[..160] + "…" : text, text, null);
            }
            else if (Clipboard.ContainsImage())
            {
                var image = Clipboard.GetImage();
                if (image == null || (long)image.PixelWidth * image.PixelHeight > 2_000_000) return;
                image.Freeze();
                entry = new("Copied image", null, image);
            }
            if (entry == null) return;
            Entries.Insert(0, entry);
            while (Entries.Count > 30) Entries.RemoveAt(Entries.Count - 1);
        }
        catch (Exception e) when (e is ExternalException or InvalidOperationException) { /* Clipboard is busy; wait for its next change. */ }
    }
    public void Copy(ClipboardEntry entry)
    {
        try
        {
            ignoreNext = true;
            if (entry.Text != null) Clipboard.SetText(entry.Text);
            else if (entry.Image != null) Clipboard.SetImage(entry.Image);
        }
        catch { ignoreNext = false; throw; }
    }
    public void Clear() { Entries.Clear(); ignoreNext = false; }
}
