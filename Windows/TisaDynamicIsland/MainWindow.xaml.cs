using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Threading;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using TisaDynamicIsland.Services;
using TisaDynamicIsland.Models;
using Forms = System.Windows.Forms;

namespace TisaDynamicIsland;

public partial class MainWindow : Window
{
    private readonly UserSettings settings = SettingsStore.Load();
    private readonly ClipboardService clipboard = new();
    private readonly DownloadService downloads = new();
    private readonly MediaService media = new();
    private readonly ObservableCollection<ShelfEntry> shelf = new();
    private const double ExpandedHeight = 420, CollapsedHeight = 64;
    private bool mediaCommandPending, seeking;
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly DispatcherTimer collapseTimer = new() { Interval = TimeSpan.FromMilliseconds(700) };
    private Forms.NotifyIcon? tray;
    private HwndSource? source;
    private IntPtr handle;
    private bool refreshing, expanded, pinned, quitting;
    private bool sessionLocked;
    private bool refreshingDisplays, userHidden, hiddenForFullscreen, positioning;
    private DateTime fullscreenGraceUntil;
    private Point shelfDragOrigin;
    private ShelfEntry? shelfDragEntry;
    private string selectedPage = "Home";

    public MainWindow()
    {
        InitializeComponent();
        ClipboardList.ItemsSource = clipboard.Entries;
        DownloadsList.ItemsSource = downloads.Entries;
        ShelfList.ItemsSource = shelf;
        clipboard.Entries.CollectionChanged += (_, _) => UpdateEmptyStates();
        downloads.Entries.CollectionChanged += (_, _) => UpdateEmptyStates();
        shelf.CollectionChanged += (_, _) => UpdateEmptyStates();
        ClipboardToggle.IsChecked = settings.ClipboardEnabled;
        DownloadsToggle.IsChecked = settings.DownloadsEnabled;
        HoverToggle.IsChecked = settings.ExpandOnHover;
        WideToggle.IsChecked = settings.WideLayout;
        FloatingToggle.IsChecked = settings.FloatingIsland;
        FullscreenToggle.IsChecked = settings.HideForFullscreen;
        RefreshDisplayChoices();
        UpdateClipboardHint();
        UpdateEmptyStates();
        SourceInitialized += (_, _) => InitializeNative();
        Loaded += async (_, _) => { SetExpanded(false); PositionIsland(); await RefreshAsync(); };
        timer.Tick += async (_, _) => { UpdateFullscreenVisibility(); await RefreshAsync(); };
        timer.Start();
        collapseTimer.Tick += (_, _) =>
        {
            collapseTimer.Stop();
            if (!pinned && !Island.IsMouseOver) SetExpanded(false);
        };
        SystemEvents.DisplaySettingsChanged += DisplayChanged;
        SystemEvents.SessionSwitch += SessionChanged;
        Closing += (_, e) => { if (!quitting) { e.Cancel = true; HideToTray(this, new RoutedEventArgs()); } };
    }

    private void InitializeNative()
    {
        handle = new WindowInteropHelper(this).Handle;
        source = HwndSource.FromHwnd(handle);
        source.AddHook(WindowMessage);
        if (!NativeMethods.AddClipboardFormatListener(handle)) Status.Text = "Clipboard monitoring could not start.";
        if (!NativeMethods.RegisterHotKey(handle, 1, 0x4003, 0x20))
        {
            ShortcutHint.Text = "Ctrl + Alt + Space is used by another app. Open this island from its tray icon instead.";
            Status.Text = "Shortcut unavailable · use the tray icon to open";
        }
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Show island", null, (_, _) => Dispatcher.Invoke(() => { RevealIsland(); Activate(); pinned = true; SetExpanded(true); }));
        menu.Items.Add("Settings", null, (_, _) => Dispatcher.Invoke(() => { RevealIsland(); Activate(); pinned = true; ShowPage("Settings"); }));
        menu.Items.Add("Quit", null, (_, _) => Dispatcher.Invoke(Quit));
        tray = new Forms.NotifyIcon { Text = "Tisa Dynamic Island", Icon = System.Drawing.SystemIcons.Application, Visible = true, ContextMenuStrip = menu };
        tray.DoubleClick += (_, _) => Dispatcher.Invoke(() => { RevealIsland(); Activate(); pinned = true; SetExpanded(true); });
    }

    private IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (NativeMethods.ShowIslandMessage != 0 && (uint)message == NativeMethods.ShowIslandMessage)
        {
            RevealIsland(); pinned = true; SetExpanded(true); Activate(); handled = true;
        }
        // Let WPF handle DPI changes, then reapply placement using the updated window DPI.
        if (message is 0x02E0 or 0x001A) Dispatcher.BeginInvoke(PositionIsland);
        if (message == NativeMethods.ClipboardUpdate && settings.ClipboardEnabled && !sessionLocked) clipboard.Capture(hwnd);
        if (message == NativeMethods.Hotkey && wParam.ToInt32() == 1)
        {
            RevealIsland(); pinned = !expanded; SetExpanded(!expanded); Activate(); handled = true;
        }
        return IntPtr.Zero;
    }

    private void PositionIsland()
    {
        if (handle == IntPtr.Zero || positioning || quitting) return;
        positioning = true;
        try
        {
            var placement = DesktopService.Place(handle, settings, expanded);
            Width = placement.LogicalWidth;
            Height = placement.LogicalHeight;
            PageArea.Height = Math.Max(80, (settings.WideLayout ? 460 : ExpandedHeight) - 170);
            // Constrain the content as well as the HWND on short work areas.
            if (expanded) PageArea.Height = Math.Max(40, Height - 170);
            Island.CornerRadius = settings.FloatingIsland ? new CornerRadius(24) : new CornerRadius(0, 0, 26, 26);
            if (!NativeMethods.SetWindowPos(handle, IntPtr.Zero, placement.Left, placement.Top, placement.Width, placement.Height, 0x0014))
                Status.Text = "Couldn't position the island. Choose a display in Settings to try again.";
        }
        finally { positioning = false; }
    }
    private void DisplayChanged(object? sender, EventArgs e) => Dispatcher.BeginInvoke(() => { RefreshDisplayChoices(); PositionIsland(); });
    private void RefreshDisplayChoices()
    {
        refreshingDisplays = true;
        try
        {
            var displays = DesktopService.Displays();
            var available = displays.Any(display => display.DeviceName == settings.DisplayDevice);
            DisplaySelector.ItemsSource = available ? displays : displays.Append(new DisplayChoice(settings.DisplayDevice, "Saved display (disconnected) — using primary")).ToArray();
            DisplaySelector.SelectedValue = settings.DisplayDevice;
            DisplayHint.Text = available ? "The island follows the taskbar work area and display scaling." : "Saved display disconnected. Using the primary display until it reconnects.";
        }
        finally { refreshingDisplays = false; }
    }
    private void SelectDisplay(object sender, SelectionChangedEventArgs e)
    {
        if (refreshingDisplays || !IsLoaded || DisplaySelector.SelectedValue is not string device) return;
        settings.DisplayDevice = device;
        SavePreferences(); PositionIsland(); RefreshDisplayChoices();
    }
    private void RevealIsland()
    {
        userHidden = hiddenForFullscreen = false;
        fullscreenGraceUntil = DateTime.UtcNow.AddSeconds(8);
        Show();
    }
    private void UpdateFullscreenVisibility()
    {
        if (handle == IntPtr.Zero || userHidden || sessionLocked || quitting || DateTime.UtcNow < fullscreenGraceUntil) return;
        var shouldHide = settings.HideForFullscreen && DesktopService.IsForegroundFullscreen(handle, settings.DisplayDevice);
        if (shouldHide && !hiddenForFullscreen) { hiddenForFullscreen = true; Hide(); }
        else if (!shouldHide && hiddenForFullscreen) { hiddenForFullscreen = false; Show(); PositionIsland(); }
    }
    private void SessionChanged(object sender, SessionSwitchEventArgs e)
    {
        Dispatcher.BeginInvoke(() =>
        {
            if (e.Reason == SessionSwitchReason.SessionLock) { sessionLocked = true; clipboard.Clear(); }
            else if (e.Reason == SessionSwitchReason.SessionUnlock) sessionLocked = false;
        });
    }

    private async Task RefreshAsync()
    {
        if (refreshing || quitting || sessionLocked) return;
        refreshing = true;
        try
        {
            var mediaTask = media.RefreshAsync();
            if (settings.DownloadsEnabled) await downloads.RefreshAsync(); else downloads.Entries.Clear();
            await mediaTask;
            if (quitting) return;
            if (!settings.DownloadsEnabled) downloads.Entries.Clear();
            TrackTitle.Text = media.Title; TrackArtist.Text = media.Artist;
            PlayButton.Content = media.IsPlaying ? "\uE769" : "\uE768";
            System.Windows.Automation.AutomationProperties.SetName(PlayButton, media.IsPlaying ? "Pause" : "Play");
            PreviousButton.IsEnabled = media.CanPrevious && !mediaCommandPending;
            PlayButton.IsEnabled = media.CanToggle && !mediaCommandPending;
            NextButton.IsEnabled = media.CanNext && !mediaCommandPending;
            Artwork.Source = media.Artwork;
            ArtworkPlaceholder.Visibility = media.Artwork == null ? Visibility.Visible : Visibility.Collapsed;
            SeekSlider.IsEnabled = media.CanSeek && !mediaCommandPending && !seeking;
            if (!SeekSlider.IsMouseCaptureWithin && !seeking)
            { SeekSlider.Maximum = Math.Max(1, media.Duration); SeekSlider.Value = media.Position; }
            Elapsed.Text = FormatTime(media.Position); TrackDuration.Text = FormatTime(media.Duration);
            var power = Forms.SystemInformation.PowerStatus;
            var batteryKnown = power.BatteryChargeStatus != Forms.BatteryChargeStatus.Unknown;
            Battery.Text = PowerSummary.Describe(!batteryKnown || !power.BatteryChargeStatus.HasFlag(Forms.BatteryChargeStatus.NoSystemBattery),
                power.BatteryLifePercent, batteryKnown && power.BatteryChargeStatus.HasFlag(Forms.BatteryChargeStatus.Charging));
            Battery.ToolTip = Battery.Text;
            Battery.Visibility = batteryKnown && power.BatteryChargeStatus.HasFlag(Forms.BatteryChargeStatus.NoSystemBattery)
                ? Visibility.Collapsed : Visibility.Visible;
            CompactTitle.Text = downloads.Entries.Count > 0 ? $"↓ {downloads.Entries.Count} active downloads" : media.Available ? media.Title : "Tisa Dynamic Island";
            Today.Text = DateTime.Now.ToString("ddd, dd MMM");
            UpdateEmptyStates();
            DownloadHint.Text = !settings.DownloadsEnabled ? "Download monitoring is off in Settings." : downloads.Error ?? (downloads.Entries.Count == 0 ? "No active downloads in your Downloads folder." : "Browser totals are unavailable; showing bytes downloaded.");
            DownloadsEmpty.Text = !settings.DownloadsEnabled ? "Download monitoring is off" : downloads.Error != null ? "Folder unavailable" : "All caught up";
        }
        catch (Exception e) when (e is COMException or IOException or UnauthorizedAccessException)
        { Status.Text = "Windows service unavailable: " + e.Message; }
        finally { refreshing = false; }
    }

    private void SetExpanded(bool value)
    {
        expanded = value;
        Expanded.Visibility = value ? Visibility.Visible : Visibility.Collapsed;
        // Shrink the native window too, so collapsed transparent space never blocks other apps.
        Height = value ? ExpandedHeight : CollapsedHeight;
        PinButton.Visibility = value ? Visibility.Visible : Visibility.Collapsed;
        PinButton.Content = pinned ? "Unpin" : "Pin";
        CollapseButton.Content = value ? "⌃" : "⌄";
        PositionIsland();
    }
    private void ToggleExpanded(object sender, RoutedEventArgs e) { pinned = !expanded; SetExpanded(!expanded); }
    private void TogglePin(object sender, RoutedEventArgs e)
    {
        pinned = !pinned; SetExpanded(true);
        Status.Text = pinned ? "Pinned open · click Unpin to collapse when you leave" : "Unpinned · collapses when you leave";
    }
    private void OnIslandEnter(object sender, MouseEventArgs e) { collapseTimer.Stop(); if (settings.ExpandOnHover) SetExpanded(true); }
    private void OnIslandLeave(object sender, MouseEventArgs e) { if (!pinned) collapseTimer.Start(); }
    private void OnKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape) { pinned = false; SetExpanded(false); e.Handled = true; }
        if (Keyboard.Modifiers == ModifierKeys.Control && e.Key >= Key.D1 && e.Key <= Key.D5)
        { pinned = true; ShowPage(new[] { "Home", "Clipboard", "Downloads", "Shelf", "Settings" }[e.Key - Key.D1]); e.Handled = true; }
    }
    private void SelectTab(object sender, RoutedEventArgs e)
    { if (IsLoaded && sender is RadioButton { Tag: string tab } && selectedPage != tab) { pinned = true; ShowPage(tab); } }
    private void ShowPage(string tab)
    {
        selectedPage = tab;
        SetExpanded(true);
        HomePage.Visibility = tab == "Home" ? Visibility.Visible : Visibility.Collapsed;
        ClipboardPage.Visibility = tab == "Clipboard" ? Visibility.Visible : Visibility.Collapsed;
        DownloadsPage.Visibility = tab == "Downloads" ? Visibility.Visible : Visibility.Collapsed;
        ShelfPage.Visibility = tab == "Shelf" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPage.Visibility = tab == "Settings" ? Visibility.Visible : Visibility.Collapsed;
        foreach (var button in TabBar.Children.OfType<RadioButton>()) button.IsChecked = (string)button.Tag == tab;
        Status.Text = "Ctrl + 1–5 to switch tabs · Escape to collapse";
    }
    private async void MediaCommand(object sender, RoutedEventArgs e)
    {
        if (mediaCommandPending) return;
        mediaCommandPending = true;
        PreviousButton.IsEnabled = PlayButton.IsEnabled = NextButton.IsEnabled = false;
        try { await media.ControlAsync((string)((Button)sender).Tag); }
        catch (Exception ex) when (ex is COMException or InvalidOperationException or TimeoutException) { Status.Text = ex is TimeoutException ? "The player took too long to respond. Try again." : ex.Message; }
        finally { mediaCommandPending = false; await RefreshAsync(); }
    }
    private async void SeekTrack(object sender, RoutedEventArgs e)
    {
        if (e is KeyEventArgs key && key.Key is not (Key.Left or Key.Right or Key.Home or Key.End or Key.Up or Key.Down or Key.PageUp or Key.PageDown)) return;
        if (seeking || !media.CanSeek) return;
        seeking = true;
        try { await media.SeekAsync(SeekSlider.Value); }
        catch (Exception ex) when (ex is COMException or InvalidOperationException or TimeoutException) { Status.Text = "Couldn't change playback position. Try again."; }
        finally { seeking = false; await RefreshAsync(); }
    }
    private static string FormatTime(double seconds) => TimeSpan.FromSeconds(seconds).ToString(seconds >= 3600 ? @"h\:mm\:ss" : @"m\:ss");
    private void UpdateEmptyStates()
    {
        ClipboardEmpty.Visibility = clipboard.Entries.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        EnableClipboardButton.Visibility = settings.ClipboardEnabled ? Visibility.Collapsed : Visibility.Visible;
        DownloadsEmpty.Visibility = downloads.Entries.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        ShelfEmpty.Visibility = shelf.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        ClearClipboardButton.IsEnabled = clipboard.Entries.Count > 0;
        ClearShelfButton.IsEnabled = shelf.Count > 0;
        Summary.Text = $"{clipboard.Entries.Count} recent copies\n{downloads.Entries.Count} downloads\n{shelf.Count} shelf files";
    }
    private void EnableClipboard(object sender, RoutedEventArgs e) { ClipboardToggle.IsChecked = true; SaveSettings(sender, e); }
    private void HideToTray(object sender, RoutedEventArgs e) { userHidden = true; hiddenForFullscreen = false; pinned = false; SetExpanded(false); Hide(); }
    private void OpenPowerSettings(object sender, RoutedEventArgs e) => OpenPath("ms-settings:powersleep");
    private void OpenDisplaySettings(object sender, RoutedEventArgs e) => OpenPath("ms-settings:display");
    private void CopyEntry(object sender, SelectionChangedEventArgs e)
    {
        if (ClipboardList.SelectedItem is not ClipboardEntry entry) return;
        try { clipboard.Copy(entry); Status.Text = "Copied. Paste it into another app with Ctrl + V."; }
        catch (ExternalException) { Status.Text = "Clipboard is busy. Try again."; }
        ClipboardList.SelectedItem = null;
    }
    private void ClearClipboard(object sender, RoutedEventArgs e) => clipboard.Clear();
    private void UpdateClipboardHint() => ClipboardHint.Text = settings.ClipboardEnabled ? "Click an item to copy again. History stays in memory." : "Enable clipboard history in Settings to start recording.";
    private void SaveSettings(object sender, RoutedEventArgs e)
    {
        settings.ClipboardEnabled = ClipboardToggle.IsChecked == true;
        settings.DownloadsEnabled = DownloadsToggle.IsChecked == true;
        settings.ExpandOnHover = HoverToggle.IsChecked == true;
        settings.WideLayout = WideToggle.IsChecked == true;
        settings.FloatingIsland = FloatingToggle.IsChecked == true;
        settings.HideForFullscreen = FullscreenToggle.IsChecked == true;
        if (!settings.ClipboardEnabled) clipboard.Clear();
        UpdateClipboardHint();
        UpdateEmptyStates();
        if (!settings.DownloadsEnabled) downloads.Entries.Clear();
        SavePreferences(); PositionIsland(); UpdateFullscreenVisibility();
    }
    private void SavePreferences()
    {
        try { SettingsStore.Save(settings); Status.Text = "Settings saved."; }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { Status.Text = "Couldn't save settings: " + ex.Message; }
    }
    private void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        foreach (var path in (string[])e.Data.GetData(DataFormats.FileDrop))
            if ((File.Exists(path) || Directory.Exists(path)) && !shelf.Any(entry => string.Equals(entry.Path, path, StringComparison.OrdinalIgnoreCase)) && shelf.Count < 100) shelf.Add(new ShelfEntry(path));
        pinned = true; ShowPage("Shelf"); e.Handled = true;
        Status.Text = shelf.Count == 100 ? "Shelf limit reached (100 files). Remove an item to add another." : "Files stay in their original folders · Delete removes only the shelf reference";
    }
    private void OnDragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }
    private void ClearShelf(object sender, RoutedEventArgs e) => shelf.Clear();
    private void OpenShelfItem(object sender, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is DependencyObject element && ItemsControl.ContainerFromElement(ShelfList, element) is ListBoxItem { DataContext: ShelfEntry entry })
            OpenPath(entry.Path);
    }
    private void ShelfKeyDown(object sender, KeyEventArgs e)
    {
        if (ShelfList.SelectedItem is not ShelfEntry entry) return;
        if (e.Key == Key.Delete) { shelf.Remove(entry); e.Handled = true; }
        else if (e.Key == Key.Enter) { OpenPath(entry.Path); e.Handled = true; }
    }
    private void BeginShelfDrag(object sender, MouseButtonEventArgs e)
    {
        shelfDragOrigin = e.GetPosition(ShelfList);
        shelfDragEntry = e.OriginalSource is DependencyObject element && ItemsControl.ContainerFromElement(ShelfList, element) is ListBoxItem item
            ? item.DataContext as ShelfEntry : null;
    }
    private void DragShelfItem(object sender, MouseEventArgs e)
    {
        var delta = e.GetPosition(ShelfList) - shelfDragOrigin;
        if (e.LeftButton == MouseButtonState.Pressed && shelfDragEntry is ShelfEntry entry &&
            (Math.Abs(delta.X) >= SystemParameters.MinimumHorizontalDragDistance || Math.Abs(delta.Y) >= SystemParameters.MinimumVerticalDragDistance))
        {
            shelfDragEntry = null;
            DragDrop.DoDragDrop(ShelfList, new DataObject(DataFormats.FileDrop, new[] { entry.Path }), DragDropEffects.Copy);
        }
    }
    private void OpenDownloads(object sender, RoutedEventArgs e) => OpenPath(downloads.Folder);
    private void OpenPath(string path)
    {
        try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
        catch (Exception ex) when (ex is Win32Exception or IOException) { Status.Text = "Couldn't open that path: " + ex.Message; }
    }
    private void Quit() => ShutdownApp(0);
    private void ShutdownApp(int code)
    {
        quitting = true;
        timer.Stop(); collapseTimer.Stop(); clipboard.Clear();
        SystemEvents.DisplaySettingsChanged -= DisplayChanged;
        SystemEvents.SessionSwitch -= SessionChanged;
        NativeMethods.RemoveClipboardFormatListener(handle);
        NativeMethods.UnregisterHotKey(handle, 1);
        source?.RemoveHook(WindowMessage);
        tray?.Dispose();
        Application.Current.Shutdown(code);
    }

    internal async Task RunSmokeTestAsync(string output)
    {
        timer.Stop(); collapseTimer.Stop();
        settings.WideLayout = false;
        settings.HideForFullscreen = false;
        settings.DisplayDevice = "";
        SetExpanded(false);
        await RefreshAsync();
        if (Height != CollapsedHeight || Expanded.Visibility != Visibility.Collapsed)
            throw new InvalidOperationException("Collapsed island must not block the desktop below it.");
        foreach (var tab in new[] { "Home", "Clipboard", "Downloads", "Shelf", "Settings" })
        {
            ShowPage(tab);
            UpdateLayout();
            if (Height != ExpandedHeight || Expanded.Visibility != Visibility.Visible)
                throw new InvalidOperationException("Page did not expand: " + tab);
            if (TabBar.Children.OfType<RadioButton>().Single(b => b.IsChecked == true).Tag as string != tab)
                throw new InvalidOperationException("Selected tab doesn't match the displayed page.");
            var dpi = VisualTreeHelper.GetDpi(this);
            var bitmap = new RenderTargetBitmap((int)(ActualWidth * dpi.DpiScaleX),
                (int)(ActualHeight * dpi.DpiScaleY), dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
            bitmap.Render(this);
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using var file = File.Create(Path.Combine(output, tab + ".png"));
            encoder.Save(file);
        }
        // Check that availability notes remain reachable inside the compact settings page.
        ShowPage("Settings");
        FeatureAvailability.IsExpanded = true;
        UpdateLayout();
        SettingsPage.ScrollToBottom();
        UpdateLayout();
        if (SettingsPage.ScrollableHeight <= 0 || SettingsPage.VerticalOffset <= 0)
            throw new InvalidOperationException("Feature availability notes must be scrollable in Settings.");
        var supportDpi = VisualTreeHelper.GetDpi(this);
        var supportBitmap = new RenderTargetBitmap((int)(ActualWidth * supportDpi.DpiScaleX),
            (int)(ActualHeight * supportDpi.DpiScaleY), supportDpi.PixelsPerInchX, supportDpi.PixelsPerInchY, PixelFormats.Pbgra32);
        supportBitmap.Render(this);
        var supportEncoder = new PngBitmapEncoder();
        supportEncoder.Frames.Add(BitmapFrame.Create(supportBitmap));
        using (var supportFile = File.Create(Path.Combine(output, "FeatureAvailability.png"))) supportEncoder.Save(supportFile);
        // Exercise folder disappearance and recovery using real temporary files.
        var fixture = Path.Combine(Path.GetTempPath(), "tisa-download-test-" + Guid.NewGuid());
        Directory.CreateDirectory(fixture);
        try
        {
            var service = new DownloadService(fixture);
            File.WriteAllText(Path.Combine(fixture, "browser.zip.crdownload"), "partial");
            await service.RefreshAsync();
            if (service.Entries.Count != 1) throw new InvalidOperationException("Download was not detected.");
            var stable = service.Entries[0];
            await service.RefreshAsync();
            if (!ReferenceEquals(stable, service.Entries[0])) throw new InvalidOperationException("Unchanged downloads must preserve list items.");
            Directory.Delete(fixture, true);
            await service.RefreshAsync();
            if (service.Entries.Count != 0 || service.Error == null) throw new InvalidOperationException("Missing folder left stale downloads.");
            Directory.CreateDirectory(fixture);
            await service.RefreshAsync();
            if (service.Error != null) throw new InvalidOperationException("Folder recovery failed.");
        }
        finally { if (Directory.Exists(fixture)) Directory.Delete(fixture, true); }
        ShowPage("Home");
        Width = 600;
        UpdateLayout();
        var narrow = new RenderTargetBitmap(600, (int)ActualHeight, 96, 96, PixelFormats.Pbgra32);
        narrow.Render(this);
        var narrowEncoder = new PngBitmapEncoder();
        narrowEncoder.Frames.Add(BitmapFrame.Create(narrow));
        using (var narrowFile = File.Create(Path.Combine(output, "HomeNarrow.png"))) narrowEncoder.Save(narrowFile);
        settings.WideLayout = true;
        settings.DisplayDevice = "Tisa-test-disconnected-display";
        PositionIsland();
        UpdateLayout();
        if (!NativeMethods.GetWindowRect(handle, out var desktopRect)) throw new InvalidOperationException("Couldn't inspect desktop placement.");
        var primaryArea = Forms.Screen.PrimaryScreen!.WorkingArea;
        if (desktopRect.Left < primaryArea.Left || desktopRect.Top < primaryArea.Top || desktopRect.Right > primaryArea.Right || desktopRect.Bottom > primaryArea.Bottom)
            throw new InvalidOperationException("Disconnected display fallback escaped the primary work area.");
        var desktopDpi = VisualTreeHelper.GetDpi(this);
        var desktopBitmap = new RenderTargetBitmap((int)(ActualWidth * desktopDpi.DpiScaleX),
            (int)(ActualHeight * desktopDpi.DpiScaleY), desktopDpi.PixelsPerInchX, desktopDpi.PixelsPerInchY, PixelFormats.Pbgra32);
        desktopBitmap.Render(this);
        var desktopEncoder = new PngBitmapEncoder();
        desktopEncoder.Frames.Add(BitmapFrame.Create(desktopBitmap));
        using (var desktopFile = File.Create(Path.Combine(output, "DesktopWide.png"))) desktopEncoder.Save(desktopFile);
        settings.WideLayout = false;
        settings.DisplayDevice = "";
        TogglePin(this, new RoutedEventArgs());
        if (!pinned || !expanded) throw new InvalidOperationException("Pin must keep the island open.");
        TogglePin(this, new RoutedEventArgs());
        if (pinned) throw new InvalidOperationException("Unpin didn't release the island.");
        SetExpanded(false);
        if (Height != CollapsedHeight) throw new InvalidOperationException("Collapse failed after navigation.");
    }
    internal void FinishSmokeTest(int code)
    {
        ShutdownApp(code);
    }
}
