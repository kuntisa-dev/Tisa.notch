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
using Forms = System.Windows.Forms;

namespace TisaDynamicIsland;

public partial class MainWindow : Window
{
    private readonly UserSettings settings = SettingsStore.Load();
    private readonly ClipboardService clipboard = new();
    private readonly DownloadService downloads = new();
    private readonly MediaService media = new();
    private readonly ObservableCollection<string> shelf = new();
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromSeconds(2) };
    private readonly DispatcherTimer collapseTimer = new() { Interval = TimeSpan.FromMilliseconds(700) };
    private Forms.NotifyIcon? tray;
    private HwndSource? source;
    private IntPtr handle;
    private bool refreshing, expanded, pinned, quitting;
    private bool sessionLocked;
    private Point shelfDragOrigin;

    public MainWindow()
    {
        InitializeComponent();
        ClipboardList.ItemsSource = clipboard.Entries;
        DownloadsList.ItemsSource = downloads.Entries;
        ShelfList.ItemsSource = shelf;
        ClipboardToggle.IsChecked = settings.ClipboardEnabled;
        DownloadsToggle.IsChecked = settings.DownloadsEnabled;
        HoverToggle.IsChecked = settings.ExpandOnHover;
        UpdateClipboardHint();
        SourceInitialized += (_, _) => InitializeNative();
        Loaded += async (_, _) => { SetExpanded(false); PositionIsland(); await RefreshAsync(); };
        timer.Tick += async (_, _) => await RefreshAsync();
        timer.Start();
        collapseTimer.Tick += (_, _) =>
        {
            collapseTimer.Stop();
            if (!pinned && !Island.IsMouseOver) SetExpanded(false);
        };
        SystemEvents.DisplaySettingsChanged += DisplayChanged;
        SystemEvents.SessionSwitch += SessionChanged;
        Closing += (_, e) => { if (!quitting) { e.Cancel = true; Hide(); } };
    }

    private void InitializeNative()
    {
        handle = new WindowInteropHelper(this).Handle;
        source = HwndSource.FromHwnd(handle);
        source.AddHook(WindowMessage);
        if (!NativeMethods.AddClipboardFormatListener(handle)) Status.Text = "Clipboard monitoring could not start.";
        if (!NativeMethods.RegisterHotKey(handle, 1, 0x4003, 0x20)) Status.Text = "Ctrl + Alt + Space is already used by another app.";
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Show island", null, (_, _) => Dispatcher.Invoke(() => { Show(); Activate(); pinned = true; SetExpanded(true); }));
        menu.Items.Add("Settings", null, (_, _) => Dispatcher.Invoke(() => { Show(); pinned = true; ShowPage("Settings"); }));
        menu.Items.Add("Quit", null, (_, _) => Dispatcher.Invoke(Quit));
        tray = new Forms.NotifyIcon { Text = "Tisa Dynamic Island", Icon = System.Drawing.SystemIcons.Application, Visible = true, ContextMenuStrip = menu };
        tray.DoubleClick += (_, _) => Dispatcher.Invoke(() => { Show(); Activate(); pinned = true; SetExpanded(true); });
    }

    private IntPtr WindowMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == NativeMethods.ClipboardUpdate && settings.ClipboardEnabled && !sessionLocked) clipboard.Capture(hwnd);
        if (message == NativeMethods.Hotkey && wParam.ToInt32() == 1)
        {
            Show(); pinned = !expanded; SetExpanded(!expanded); Activate(); handled = true;
        }
        return IntPtr.Zero;
    }

    private void PositionIsland()
    {
        // WPF work-area values are in device-independent units, including taskbar insets.
        var area = SystemParameters.WorkArea;
        Width = Math.Min(760, area.Width - 24);
        Left = area.Left + (area.Width - Width) / 2;
        Top = area.Top;
    }
    private void DisplayChanged(object? sender, EventArgs e) => Dispatcher.BeginInvoke(PositionIsland);
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
        if (refreshing) return;
        refreshing = true;
        try
        {
            await media.RefreshAsync();
            TrackTitle.Text = media.Title; TrackArtist.Text = media.Artist;
            PlayButton.Content = media.IsPlaying ? "Pause" : "Play";
            PreviousButton.IsEnabled = PlayButton.IsEnabled = NextButton.IsEnabled = media.Available;
            if (settings.DownloadsEnabled) downloads.Refresh(); else downloads.Entries.Clear();
            var power = Forms.SystemInformation.PowerStatus;
            Battery.Text = power.BatteryChargeStatus.HasFlag(Forms.BatteryChargeStatus.NoSystemBattery) || power.BatteryLifePercent < 0
                ? "AC" : $"{power.BatteryLifePercent:P0}";
            CompactTitle.Text = downloads.Entries.Count > 0 ? $"↓ {downloads.Entries.Count} active downloads" : media.Title == "Nothing playing" ? "Tisa Dynamic Island" : media.Title;
            Today.Text = DateTime.Now.ToString("ddd, dd MMM");
            Summary.Text = $"{clipboard.Entries.Count} recent copies\n{downloads.Entries.Count} downloads\n{shelf.Count} shelf files";
            DownloadHint.Text = !settings.DownloadsEnabled ? "Download monitoring is off in Settings." : downloads.Error ?? (downloads.Entries.Count == 0 ? "No active downloads in your Downloads folder." : "Browser totals are unavailable; showing bytes downloaded.");
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
        Height = value ? 340 : 64;
    }
    private void ToggleExpanded(object sender, RoutedEventArgs e) { pinned = !expanded; SetExpanded(!expanded); }
    private void OnIslandEnter(object sender, MouseEventArgs e) { collapseTimer.Stop(); if (settings.ExpandOnHover) SetExpanded(true); }
    private void OnIslandLeave(object sender, MouseEventArgs e) { if (!pinned) collapseTimer.Start(); }
    private void OnKeyDown(object sender, KeyEventArgs e) { if (e.Key == Key.Escape) { pinned = false; SetExpanded(false); e.Handled = true; } }
    private void SelectTab(object sender, RoutedEventArgs e) { if (sender is Button { Tag: string tab }) { pinned = true; ShowPage(tab); } }
    private void ShowPage(string tab)
    {
        SetExpanded(true);
        HomePage.Visibility = tab == "Home" ? Visibility.Visible : Visibility.Collapsed;
        ClipboardPage.Visibility = tab == "Clipboard" ? Visibility.Visible : Visibility.Collapsed;
        DownloadsPage.Visibility = tab == "Downloads" ? Visibility.Visible : Visibility.Collapsed;
        ShelfPage.Visibility = tab == "Shelf" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPage.Visibility = tab == "Settings" ? Visibility.Visible : Visibility.Collapsed;
        Status.Text = "";
    }
    private async void MediaCommand(object sender, RoutedEventArgs e)
    {
        try { await media.ControlAsync((string)((Button)sender).Tag); await RefreshAsync(); }
        catch (Exception ex) when (ex is COMException or InvalidOperationException) { Status.Text = ex.Message; }
    }
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
        if (!settings.ClipboardEnabled) clipboard.Clear();
        UpdateClipboardHint();
        try { SettingsStore.Save(settings); Status.Text = "Settings saved."; }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { Status.Text = "Couldn't save settings: " + ex.Message; }
    }
    private void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        foreach (var path in (string[])e.Data.GetData(DataFormats.FileDrop))
            if ((File.Exists(path) || Directory.Exists(path)) && !shelf.Contains(path) && shelf.Count < 100) shelf.Add(path);
        pinned = true; ShowPage("Shelf"); e.Handled = true;
    }
    private void ClearShelf(object sender, RoutedEventArgs e) => shelf.Clear();
    private void OpenShelfItem(object sender, MouseButtonEventArgs e) { if (ShelfList.SelectedItem is string path) OpenPath(path); }
    private void BeginShelfDrag(object sender, MouseButtonEventArgs e) => shelfDragOrigin = e.GetPosition(ShelfList);
    private void DragShelfItem(object sender, MouseEventArgs e)
    {
        var delta = e.GetPosition(ShelfList) - shelfDragOrigin;
        if (e.LeftButton == MouseButtonState.Pressed && ShelfList.SelectedItem is string path &&
            (Math.Abs(delta.X) >= SystemParameters.MinimumHorizontalDragDistance || Math.Abs(delta.Y) >= SystemParameters.MinimumVerticalDragDistance))
            DragDrop.DoDragDrop(ShelfList, new DataObject(DataFormats.FileDrop, new[] { path }), DragDropEffects.Copy);
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
        await RefreshAsync();
        if (Height != 64 || Expanded.Visibility != Visibility.Collapsed)
            throw new InvalidOperationException("Collapsed island must not block the desktop below it.");
        foreach (var tab in new[] { "Home", "Clipboard", "Downloads", "Shelf", "Settings" })
        {
            ShowPage(tab);
            UpdateLayout();
            if (Height != 340 || Expanded.Visibility != Visibility.Visible)
                throw new InvalidOperationException("Page did not expand: " + tab);
            var dpi = VisualTreeHelper.GetDpi(this);
            var bitmap = new RenderTargetBitmap((int)(ActualWidth * dpi.DpiScaleX),
                (int)(ActualHeight * dpi.DpiScaleY), dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
            bitmap.Render(this);
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using var file = File.Create(Path.Combine(output, tab + ".png"));
            encoder.Save(file);
        }
        SetExpanded(false);
        if (Height != 64) throw new InvalidOperationException("Collapse failed after navigation.");
    }
    internal void FinishSmokeTest(int code)
    {
        ShutdownApp(code);
    }
}
