namespace TisaDynamicIsland.Models;

// Identify our own write, rather than discarding the next unrelated clipboard event.
public sealed class ClipboardSequence
{
    private uint ownWrite;
    private uint lastCapture;
    public void MarkOwnWrite(uint sequence) => ownWrite = sequence;
    public bool ShouldCapture(uint sequence) => sequence != 0 && sequence != ownWrite && sequence != lastCapture;
    public void MarkCaptured(uint sequence) => lastCapture = sequence;
    public void Reset() { ownWrite = lastCapture = 0; }
}
