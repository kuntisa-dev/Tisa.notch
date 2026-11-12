namespace TisaDynamicIsland.Models;

public static class IslandInteraction
{
    // A hidden expanded island should reopen, rather than toggle straight into collapse.
    public static bool ExpandOnHotkey(bool isVisible, bool isExpanded) => !isVisible || !isExpanded;
    public static bool ShowOverview(double logicalWidth) => logicalWidth >= 680;
    public static double NavigationWidth(double logicalWidth) => Math.Max(530, logicalWidth - 28);
}
