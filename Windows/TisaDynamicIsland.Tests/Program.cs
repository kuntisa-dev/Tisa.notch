global using System.Runtime.InteropServices;
global using System.Collections.ObjectModel;
using TisaDynamicIsland.Models;
using TisaDynamicIsland.Services;

// A standalone runner keeps these filesystem rules testable on macOS and Windows.
var cases = new Dictionary<string, bool>
{
    ["installer.exe.crdownload"] = true,
    ["document.pdf.part"] = true,
    ["ARCHIVE.ZIP.CRDOWNLOAD"] = true,
    ["archive.zip"] = false,
    ["notes.part.txt"] = false,
    [".partial"] = false,
};
foreach (var (path, expected) in cases)
    if (DownloadEntry.IsPartial(path) != expected) throw new Exception($"Unexpected classification: {path}");
Console.WriteLine($"Passed {cases.Count} browser download classification cases.");

var assertionCount = cases.Count;
void Check(bool passed, string message) { assertionCount++; if (!passed) throw new Exception(message); }
var sequences = new ClipboardSequence();
Check(!sequences.ShouldCapture(0), "Uninitialized clipboard must be skipped.");
sequences.MarkOwnWrite(10);
Check(!sequences.ShouldCapture(10), "Own clipboard writes must not create history entries.");
Check(sequences.ShouldCapture(11), "A new external copy must not be skipped after an own write.");
sequences.MarkCaptured(11);
Check(!sequences.ShouldCapture(11), "Duplicate clipboard notifications must be ignored.");
sequences.Reset();
Check(sequences.ShouldCapture(11), "Clear must reset sequence tracking.");
Console.WriteLine("Passed clipboard ownership, duplicate-event and reset checks.");

Check(PowerSummary.Describe(false, 0.5f, false) == "Desktop", "No battery must not show a percentage.");
foreach (var invalid in new[] { -1f, 2.55f, float.NaN, float.PositiveInfinity })
    Check(PowerSummary.Describe(true, invalid, false) == "Battery unavailable", "Invalid battery value shown as a percentage.");
Check(PowerSummary.Describe(true, 0.5f, true).Contains("charging"), "Charging state missing.");
Console.WriteLine("Passed absent, invalid and charging battery checks.");

var folder = Path.Combine(Path.GetTempPath(), "tisa-test-" + Guid.NewGuid());
Directory.CreateDirectory(folder);
try
{
    File.WriteAllBytes(Path.Combine(folder, "one.zip.crdownload"), new byte[512]);
    File.WriteAllBytes(Path.Combine(folder, "two.zip.part"), new byte[1024]);
    File.WriteAllText(Path.Combine(folder, "done.zip"), "finished");
    var downloads = DownloadScanner.Scan(folder);
    Check(downloads.Count == 2 && downloads.Sum(d => d.Bytes) == 1536, "Partial-file scan returned incorrect sizes or included completed files.");
    File.Move(Path.Combine(folder, "one.zip.crdownload"), Path.Combine(folder, "one.zip"));
    Check(DownloadScanner.Scan(folder).Count == 1, "Renamed completed download remained active.");
    File.Delete(Path.Combine(folder, "two.zip.part"));
    Check(DownloadScanner.Scan(folder).Count == 0, "Deleted download remained active.");
}
finally { Directory.Delete(folder, true); }
Console.WriteLine("Passed real-file download size, completion and deletion checks.");

foreach (var work in new[] { new PixelArea(0, 0, 1920, 1040), new PixelArea(-2560, 40, 2560, 1400),
    new PixelArea(1920, -1080, 1920, 1040), new PixelArea(48, 0, 1872, 1080), new PixelArea(0, 0, 5120, 1400), new PixelArea(0, 0, 640, 480) })
foreach (var scale in new[] { 1d, 1.25, 1.5, 2, 3 })
foreach (var expanded in new[] { false, true })
foreach (var wide in new[] { false, true })
foreach (var floating in new[] { false, true })
{
    var placed = DesktopPlacement.Calculate(work, scale, expanded, wide, floating);
    Check(placed.Left >= work.Left && placed.Top >= work.Top && placed.Left + placed.Width <= work.Left + work.Width && placed.Top + placed.Height <= work.Top + work.Height,
        $"Island escaped its work area: {work}, {scale}, {expanded}, {wide}, {floating}");
    Check(placed.Width > 0 && placed.Height > 0 && Math.Abs(placed.Left + placed.Width / 2d - (work.Left + work.Width / 2d)) <= 1, "Placement must have positive dimensions and be centered.");
}
var normal = DesktopPlacement.Calculate(new(0, 0, 3840, 2100), 2, true, false, true);
Check(normal.Width == 1600 && normal.Height == 840 && normal.Top == 24, "200% DPI must preserve logical UI dimensions.");
var widePlacement = DesktopPlacement.Calculate(new(0, 0, 3840, 2100), 2, true, true, true);
Check(widePlacement.Width == 1920 && widePlacement.Height == 920, "Desktop-wide layout dimensions are wrong.");
Check(DesktopPlacement.Calculate(new(0, 40, 1920, 1040), 1, false, false, false).Top == 40, "Attached island must respect a top taskbar.");
Check(DesktopPlacement.Calculate(new(0, 0, 1920, 1080), double.NaN, false, false, true).Scale == 1, "Invalid DPI must fall back to 100%.");
var screenBounds = new PixelArea(-1920, 0, 1920, 1080);
Check(DesktopPlacement.CoversScreen(screenBounds, screenBounds), "Full-screen application not detected.");
Check(!DesktopPlacement.CoversScreen(new(-1920, 0, 1920, 1040), screenBounds), "Normal maximized work-area window should not hide the island.");
Check(!DesktopPlacement.CoversScreen(new(0, 0, 1920, 1080), screenBounds), "A full-screen app on another monitor must not hide the island.");
Console.WriteLine("Passed 240 desktop placement combinations plus DPI, taskbar, ultrawide and fullscreen checks.");

Check(IslandInteraction.ExpandOnHotkey(false, true), "Hidden expanded island must reopen, not collapse.");
Check(IslandInteraction.ExpandOnHotkey(false, false), "Hidden collapsed island must open.");
Check(IslandInteraction.ExpandOnHotkey(true, false), "Visible collapsed island must expand.");
Check(!IslandInteraction.ExpandOnHotkey(true, true), "Visible expanded island must collapse.");
Check(!IslandInteraction.ShowOverview(600) && IslandInteraction.ShowOverview(800), "Narrow screens must prioritize the player.");
Check(IslandInteraction.NavigationWidth(300) >= 530, "Tabs must stay usable through scrolling on narrow screens.");
Console.WriteLine("Passed all four hotkey states and responsive layout checks.");

var random = new Random(41);
for (var iteration = 0; iteration < 10_000; iteration++)
{
    var work = new PixelArea(random.Next(-30000, 30000), random.Next(-30000, 30000), random.Next(120, 16000), random.Next(120, 10000));
    var placement = DesktopPlacement.Calculate(work, 0.5 + random.NextDouble() * 7.5, random.Next(2) == 0, random.Next(2) == 0, random.Next(2) == 0);
    Check(placement.Left >= work.Left && placement.Top >= work.Top && placement.Left + placement.Width <= work.Left + work.Width && placement.Top + placement.Height <= work.Top + work.Height,
        "Random display layout escaped its bounds.");
}
Console.WriteLine("Passed 10,000 deterministic randomized desktop geometry cases.");

// Test the actual asynchronous service, including a filesystem operation that is stuck.
using var releaseScan = new ManualResetEventSlim();
using var scanStarted = new ManualResetEventSlim();
var scanCalls = 0;
var stalled = new DownloadService("unused-test-folder", _ =>
{
    Interlocked.Increment(ref scanCalls); scanStarted.Set(); releaseScan.Wait();
    return new[] { new DownloadEntry("recovered.crdownload", 100) };
}, TimeSpan.FromMilliseconds(100));
try
{
    var first = stalled.RefreshAsync();
    Check(scanStarted.Wait(TimeSpan.FromSeconds(5)), "Background scan failed to start.");
    await first;
    Check(stalled.Error != null && stalled.Entries.Count == 0, "A stalled scan must report a timeout, without stale entries.");
    await stalled.RefreshAsync();
    Check(scanCalls == 1, "Retrying a stalled folder must not spawn another blocked filesystem scan.");
    releaseScan.Set();
    await stalled.RefreshAsync();
    Check(stalled.Error == null && stalled.Entries.Count == 1, "Downloads did not recover after the filesystem became responsive.");
}
finally { releaseScan.Set(); }
Console.WriteLine("Passed asynchronous download timeout, single in-flight scan and recovery checks.");

var serviceFolder = Path.Combine(Path.GetTempPath(), "tisa-service-" + Guid.NewGuid());
Directory.CreateDirectory(serviceFolder);
try
{
    var service = new DownloadService(serviceFolder);
    File.WriteAllText(Path.Combine(serviceFolder, "active.part"), "download");
    await service.RefreshAsync();
    var entry = service.Entries.Single();
    await service.RefreshAsync();
    Check(ReferenceEquals(entry, service.Entries.Single()), "Unchanged download should preserve the list item.");
    Directory.Delete(serviceFolder, true);
    await service.RefreshAsync();
    Check(service.Error != null && service.Entries.Count == 0, "Deleted folder must clear stale entries.");
    Directory.CreateDirectory(serviceFolder);
    await service.RefreshAsync();
    Check(service.Error == null && service.Entries.Count == 0, "Recreated folder must recover.");
}
finally { if (Directory.Exists(serviceFolder)) Directory.Delete(serviceFolder, true); }
Console.WriteLine("Passed actual DownloadService list stability, missing-folder and recovery checks.");
Console.WriteLine($"PASS: {assertionCount} assertions.");
