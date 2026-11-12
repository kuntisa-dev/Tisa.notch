namespace TisaDynamicIsland.Models;

public static class PowerSummary
{
    public static string Describe(bool hasBattery, float fraction, bool charging)
    {
        if (!hasBattery) return "Desktop";
        if (!float.IsFinite(fraction) || fraction < 0 || fraction > 1) return "Battery unavailable";
        return $"{fraction:P0}" + (charging ? " · charging" : " battery");
    }
}
