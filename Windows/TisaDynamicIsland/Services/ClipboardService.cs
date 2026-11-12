using System.Windows;
using System.Windows.Media.Imaging;
using TisaDynamicIsland.Models;

namespace TisaDynamicIsland.Services;

public sealed record ClipboardEntry(string Preview, string? Text, BitmapSource? Image);

public sealed class ClipboardService
{
    public ObservableCollection<ClipboardEntry> Entries { get; } = new();
    private readonly ClipboardSequence sequences = new();
    private readonly uint excluded = NativeMethods.RegisterClipboardFormat("ExcludeClipboardContentFromMonitorProcessing");
    private readonly uint history = NativeMethods.RegisterClipboardFormat("CanIncludeInClipboardHistory");

    // False means a transient read failure; the caller may retry a bounded number of times.
    public bool Capture(IntPtr hwnd)
    {
        var sequence = NativeMethods.GetClipboardSequenceNumber();
        if (!sequences.ShouldCapture(sequence)) return true;
        if (NativeMethods.IsClipboardFormatAvailable(excluded)) return true;
        // Honor Windows' opt-out format, used by credential tools.
        if (NativeMethods.IsClipboardFormatAvailable(history))
        {
            if (!NativeMethods.OpenClipboard(hwnd)) return false;
            try
            {
                var handle = NativeMethods.GetClipboardData(history);
                if (handle == IntPtr.Zero || NativeMethods.GlobalSize(handle).ToUInt64() < sizeof(int)) return true;
                var pointer = NativeMethods.GlobalLock(handle);
                if (pointer == IntPtr.Zero) return true;
                try { if (Marshal.ReadInt32(pointer) == 0) return true; }
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
                if (string.IsNullOrWhiteSpace(text) || text.Length > 100_000) return true;
                if (Entries.FirstOrDefault()?.Text == text) return true;
                entry = new(text.Length > 160 ? text[..160] + "…" : text, text, null);
            }
            else if (Clipboard.ContainsImage())
            {
                var image = Clipboard.GetImage();
                if (image == null || (long)image.PixelWidth * image.PixelHeight > 2_000_000) return true;
                image.Freeze();
                entry = new("Copied image", null, image);
            }
            // If another application changed the clipboard while reading, discard this snapshot.
            if (sequence != NativeMethods.GetClipboardSequenceNumber()) return false;
            if (entry == null) return true;
            sequences.MarkCaptured(sequence);
            Entries.Insert(0, entry);
            long ImageBytes(ClipboardEntry item) => item.Image == null ? 0 : (long)item.Image.PixelWidth * item.Image.PixelHeight * 4;
            var imageBytes = Entries.Sum(ImageBytes);
            while (Entries.Count > 30 || imageBytes > 32 * 1024 * 1024)
            {
                imageBytes -= ImageBytes(Entries[^1]);
                Entries.RemoveAt(Entries.Count - 1);
            }
            return true;
        }
        catch (Exception e) when (e is ExternalException or InvalidOperationException) { return false; }
        catch (Exception e) when (e is NotSupportedException or ArgumentException or FileFormatException) { return true; }
    }
    public void Copy(ClipboardEntry entry)
    {
        if (entry.Text != null) Clipboard.SetText(entry.Text);
        else if (entry.Image != null) Clipboard.SetImage(entry.Image);
        sequences.MarkOwnWrite(NativeMethods.GetClipboardSequenceNumber());
    }
    public void Clear() { Entries.Clear(); sequences.Reset(); }
}
