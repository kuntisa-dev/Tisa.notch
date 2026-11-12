using TisaDynamicIsland.Models;

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

void Check(bool passed, string message) { if (!passed) throw new Exception(message); }
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
