using Windows.Media.Control;
using Windows.Storage.Streams;
using System.Windows.Media.Imaging;

namespace TisaDynamicIsland.Services;

public sealed class MediaService
{
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(4);
    private GlobalSystemMediaTransportControlsSessionManager? manager;
    private GlobalSystemMediaTransportControlsSession? session;
    private string? artworkKey;
    public string Title { get; private set; } = "Your music, right here";
    public string Artist { get; private set; } = "Play something in Spotify, a browser or another media app.";
    public bool IsPlaying { get; private set; }
    public bool Available => session != null;
    public bool CanPrevious { get; private set; }
    public bool CanNext { get; private set; }
    public bool CanToggle { get; private set; }
    public bool CanSeek { get; private set; }
    public double Position { get; private set; }
    public double Duration { get; private set; }
    private TimeSpan start;
    public BitmapImage? Artwork { get; private set; }
    public async Task RefreshAsync()
    {
        try
        {
            manager ??= await GlobalSystemMediaTransportControlsSessionManager.RequestAsync().AsTask().WaitAsync(Timeout);
            var current = manager.GetCurrentSession();
            if (current == null) { Reset("Your music, right here", "Play something in Spotify, a browser or another media app."); return; }
            var properties = await current.TryGetMediaPropertiesAsync().AsTask().WaitAsync(Timeout);
            session = current;
            Title = string.IsNullOrWhiteSpace(properties.Title) ? "Unknown track" : properties.Title;
            Artist = string.IsNullOrWhiteSpace(properties.Artist) ? "Windows media session" : properties.Artist;
            var playback = current.GetPlaybackInfo();
            IsPlaying = playback.PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
            CanPrevious = playback.Controls.IsPreviousEnabled;
            CanNext = playback.Controls.IsNextEnabled;
            CanToggle = playback.Controls.IsPlayPauseToggleEnabled;
            var timeline = current.GetTimelineProperties();
            start = timeline.StartTime;
            Duration = Math.Max(0, (timeline.EndTime - start).TotalSeconds);
            Position = Math.Clamp((timeline.Position - start).TotalSeconds, 0, Duration);
            CanSeek = playback.Controls.IsPlaybackPositionEnabled && Duration > 0;
            var key = current.SourceAppUserModelId + "|" + properties.Title + "|" + properties.Artist;
            if (key != artworkKey)
            {
                Artwork = null;
                artworkKey = key;
                if (properties.Thumbnail != null)
                {
                    try
                    {
                        using var stream = await properties.Thumbnail.OpenReadAsync().AsTask().WaitAsync(Timeout);
                        if (stream.Size is > 0 and <= 4_194_304)
                        {
                            using var reader = new DataReader(stream.GetInputStreamAt(0));
                            await reader.LoadAsync((uint)stream.Size).AsTask().WaitAsync(Timeout);
                            var bytes = new byte[(int)stream.Size];
                            reader.ReadBytes(bytes);
                            using var memory = new MemoryStream(bytes);
                            var bitmap = new BitmapImage();
                            bitmap.BeginInit(); bitmap.CacheOption = BitmapCacheOption.OnLoad;
                            bitmap.DecodePixelWidth = 240; bitmap.StreamSource = memory; bitmap.EndInit(); bitmap.Freeze();
                            Artwork = bitmap;
                        }
                    }
                    catch (Exception e) when (e is COMException or IOException or TimeoutException or NotSupportedException or ArgumentException) { /* Artwork is optional; controls remain usable. */ }
                }
            }
        }
        catch (Exception e) when (e is COMException or UnauthorizedAccessException or TimeoutException)
        { manager = null; Reset("Media temporarily unavailable", "The player isn't responding. We'll reconnect automatically."); }
    }
    private void Reset(string title, string artist)
    {
        session = null; Title = title; Artist = artist;
        IsPlaying = CanPrevious = CanNext = CanToggle = CanSeek = false;
        Position = Duration = 0; Artwork = null; artworkKey = null;
    }
    public async Task ControlAsync(string command)
    {
        var current = session;
        if (current == null) return;
        bool accepted = command switch
        {
            "previous" when CanPrevious => await current.TrySkipPreviousAsync().AsTask().WaitAsync(Timeout),
            "next" when CanNext => await current.TrySkipNextAsync().AsTask().WaitAsync(Timeout),
            "toggle" when CanToggle => await current.TryTogglePlayPauseAsync().AsTask().WaitAsync(Timeout),
            _ => false
        };
        if (!accepted) throw new InvalidOperationException("This player doesn't support that control right now.");
    }
    public async Task SeekAsync(double seconds)
    {
        if (session == null || !CanSeek) return;
        var target = start + TimeSpan.FromSeconds(Math.Clamp(seconds, 0, Duration));
        if (!await session.TryChangePlaybackPositionAsync(target.Ticks).AsTask().WaitAsync(Timeout))
            throw new InvalidOperationException("This player couldn't seek to that position.");
    }
}
