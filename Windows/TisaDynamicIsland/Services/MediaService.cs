using Windows.Media.Control;

namespace TisaDynamicIsland.Services;

public sealed class MediaService
{
    private GlobalSystemMediaTransportControlsSessionManager? manager;
    private GlobalSystemMediaTransportControlsSession? session;
    public string Title { get; private set; } = "Nothing playing";
    public string Artist { get; private set; } = "Start music in a Windows media app";
    public bool IsPlaying { get; private set; }
    public bool Available => session != null;
    public async Task RefreshAsync()
    {
        try
        {
            manager ??= await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
            session = manager.GetCurrentSession();
            if (session == null) { Title = "Nothing playing"; Artist = "Start music in a Windows media app"; IsPlaying = false; return; }
            var properties = await session.TryGetMediaPropertiesAsync();
            Title = string.IsNullOrEmpty(properties.Title) ? "Unknown track" : properties.Title;
            Artist = properties.Artist;
            IsPlaying = session.GetPlaybackInfo().PlaybackStatus == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
        }
        catch (Exception e) when (e is COMException or UnauthorizedAccessException)
        { session = null; IsPlaying = false; Title = "Media controls unavailable"; Artist = "Windows could not access the current media session"; }
    }
    public async Task ControlAsync(string command)
    {
        if (session == null) return;
        bool accepted = command switch
        {
            "previous" => await session.TrySkipPreviousAsync(),
            "next" => await session.TrySkipNextAsync(),
            _ => await session.TryTogglePlayPauseAsync()
        };
        if (!accepted) throw new InvalidOperationException("The media app did not accept that command.");
        await RefreshAsync();
    }
}
