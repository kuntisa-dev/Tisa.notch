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
