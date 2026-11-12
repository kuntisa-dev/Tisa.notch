using System.Text.Json;

namespace TisaDynamicIsland.Services;

public sealed class UserSettings
{
    public bool ClipboardEnabled { get; set; } // Explicit opt-in; never persist copied content.
    public bool DownloadsEnabled { get; set; } = true;
    public bool ExpandOnHover { get; set; } = true;
    public string DisplayDevice { get; set; } = "";
    public bool WideLayout { get; set; }
    public bool FloatingIsland { get; set; } = true;
    public bool HideForFullscreen { get; set; } = true;
}

public static class SettingsStore
{
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "TisaDynamicIsland", "settings.json");
    public static UserSettings Load()
    {
        try { return JsonSerializer.Deserialize<UserSettings>(File.ReadAllText(FilePath)) ?? new(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { return new(); }
    }
    public static void Save(UserSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        var temporary = FilePath + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(settings));
        File.Move(temporary, FilePath, true);
    }
}
