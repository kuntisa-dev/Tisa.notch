namespace TisaDynamicIsland.Models;

public readonly record struct PixelArea(int Left, int Top, int Width, int Height);
public readonly record struct IslandPlacement(int Left, int Top, int Width, int Height, double Scale)
{
    public double LogicalWidth => Width / Scale;
    public double LogicalHeight => Height / Scale;
}

public static class DesktopPlacement
{
    // Screen work areas are physical pixels. Requested UI sizes are device-independent pixels.
    public static IslandPlacement Calculate(PixelArea work, double scale, bool expanded, bool wide, bool floating)
    {
        if (!double.IsFinite(scale) || scale <= 0) scale = 1;
        var margin = Math.Min((int)Math.Round(12 * scale), Math.Max(0, Math.Min(work.Width, work.Height) / 4));
        var topGap = floating ? margin : 0;
        var width = Math.Clamp((int)Math.Round((expanded ? wide ? 960 : 800 : 420) * scale), 1, Math.Max(1, work.Width - margin * 2));
        var height = Math.Clamp((int)Math.Round((expanded ? wide ? 460 : 420 : 64) * scale), 1, Math.Max(1, work.Height - topGap - margin));
        return new(work.Left + (work.Width - width) / 2, work.Top + topGap, width, height, scale);
    }
    public static bool CoversScreen(PixelArea window, PixelArea screen) =>
        Math.Abs((long)window.Left - screen.Left) <= 2 && Math.Abs((long)window.Top - screen.Top) <= 2 &&
        Math.Abs((long)window.Width - screen.Width) <= 4 && Math.Abs((long)window.Height - screen.Height) <= 4;
}
