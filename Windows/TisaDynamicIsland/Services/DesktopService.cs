using System.Text;
using TisaDynamicIsland.Models;
using Forms = System.Windows.Forms;

namespace TisaDynamicIsland.Services;

public sealed record DisplayChoice(string DeviceName, string Label);

public static class DesktopService
{
    public static IReadOnlyList<DisplayChoice> Displays() => new[] { new DisplayChoice("", "Follow the primary display") }
        .Concat(Forms.Screen.AllScreens.Select((screen, index) => new DisplayChoice(screen.DeviceName,
            $"Display {index + 1}{(screen.Primary ? " (primary)" : "")} · {screen.Bounds.Width} × {screen.Bounds.Height}"))).ToArray();

    private static Forms.Screen Target(string device) => Forms.Screen.AllScreens.FirstOrDefault(screen => screen.DeviceName == device)
        ?? Forms.Screen.PrimaryScreen ?? Forms.Screen.AllScreens[0];

    public static IslandPlacement Place(IntPtr hwnd, UserSettings settings, bool expanded)
    {
        var target = Target(settings.DisplayDevice);
        var area = target.WorkingArea;
        if (Forms.Screen.FromHandle(hwnd).DeviceName != target.DeviceName)
        {
            // Move first so WPF processes WM_DPICHANGED before asking for the target window DPI.
            NativeMethods.SetWindowPos(hwnd, IntPtr.Zero, area.Left + 12, area.Top + 12, 1, 1, 0x0014);
        }
        var scale = NativeMethods.GetDpiForWindow(hwnd) / 96d;
        return DesktopPlacement.Calculate(new(area.Left, area.Top, area.Width, area.Height), scale,
            expanded, settings.WideLayout, settings.FloatingIsland);
    }

    public static bool IsForegroundFullscreen(IntPtr ownWindow, string device)
    {
        var foreground = NativeMethods.GetForegroundWindow();
        if (foreground == IntPtr.Zero || foreground == ownWindow || NativeMethods.IsIconic(foreground)) return false;
        var name = new StringBuilder(128);
        NativeMethods.GetClassName(foreground, name, name.Capacity);
        if (name.ToString() is "Progman" or "WorkerW" or "Shell_TrayWnd" or "Shell_SecondaryTrayWnd") return false;
        var screen = Target(device);
        if (Forms.Screen.FromHandle(foreground).DeviceName != screen.DeviceName) return false;
        if (!NativeMethods.GetWindowRect(foreground, out var rect)) return false;
        var bounds = screen.Bounds;
        return DesktopPlacement.CoversScreen(new(rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top),
            new(bounds.Left, bounds.Top, bounds.Width, bounds.Height));
    }
}
