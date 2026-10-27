using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace ChainYourMac.Windows;

public partial class MainWindow : System.Windows.Window
{
    private const int WM_HOTKEY = 0x0312;
    private const uint MOD_ALT = 0x0001;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint MOD_NOREPEAT = 0x4000;
    private const uint VK_LEFT = 0x25;
    private const uint VK_RIGHT = 0x27;
    private const uint VK_R = 0x52;

    private readonly UserPreferences preferences = UserPreferences.Load();
    private WindowStripManager? manager;
    private HwndSource? hwndSource;
    private bool allowClose;
    private bool[] shortcutsRegistered = new bool[3];

    public event EventHandler? QuitRequested;

    public MainWindow()
    {
        InitializeComponent();
        manager = new WindowStripManager(preferences.Gap);
        manager.StateChanged += (_, _) => Dispatcher.InvokeAsync(UpdateView);
        GapSlider.Value = preferences.Gap;
        QuickStartCard.Visibility = preferences.QuickStartComplete
            ? System.Windows.Visibility.Collapsed
            : System.Windows.Visibility.Visible;
        SourceInitialized += Window_SourceInitialized;
        UpdateView();
        manager.Refresh();
    }

    public void ShowFromTray()
    {
        Show();
        WindowState = System.Windows.WindowState.Normal;
        Activate();
        manager?.Refresh();
    }

    public void PrepareForExit()
    {
        if (manager?.IsArranged == true) manager.Restore();
        UnregisterShortcuts();
        allowClose = true;
        Close();
    }

    private void Window_SourceInitialized(object? sender, EventArgs e)
    {
        var handle = new WindowInteropHelper(this).Handle;
        hwndSource = HwndSource.FromHwnd(handle);
        hwndSource?.AddHook(WndProc);

        shortcutsRegistered[0] = RegisterHotKey(handle, 1, MOD_SHIFT | MOD_NOREPEAT, VK_LEFT);
        shortcutsRegistered[1] = RegisterHotKey(handle, 2, MOD_SHIFT | MOD_NOREPEAT, VK_RIGHT);
        shortcutsRegistered[2] = RegisterHotKey(handle, 3, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, VK_R);
        UpdateShortcutStatus();
        UpdateView();
    }

    private IntPtr WndProc(IntPtr handle, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == WM_HOTKEY)
        {
            manager?.HandleGlobalShortcut(wParam.ToInt32());
            handled = true;
            UpdateView();
        }
        return IntPtr.Zero;
    }

    private void UpdateShortcutStatus()
    {
        var registered = shortcutsRegistered.Count(value => value);
        manager?.SetShortcutStatus($"{registered} of 3 global shortcuts registered.");
    }

    private void UpdateView()
    {
        if (manager is null) return;
        WindowSummary.Text = manager.IsArranged
            ? $"{manager.FocusedIndex + 1} of {manager.WindowCount} · {manager.FocusedTitle}"
            : manager.WindowCount == 0 ? "Your workspace, in a line" : $"{manager.WindowCount} windows ready to arrange";
        ArrangeButton.Content = manager.IsArranged ? "Rearrange open windows" : "Arrange open windows";
        RestoreButton.Visibility = manager.IsArranged ? System.Windows.Visibility.Visible : System.Windows.Visibility.Collapsed;
        StatusMessage.Text = manager.Message;
        ShortcutStatus.Text = manager.ShortcutStatus;
        GapValue.Text = $"{manager.Gap} px";
    }

    private void Arrange_Click(object sender, System.Windows.RoutedEventArgs e) { manager?.Arrange(); UpdateView(); }
    private void Previous_Click(object sender, System.Windows.RoutedEventArgs e) { manager?.FocusPrevious(); UpdateView(); }
    private void Next_Click(object sender, System.Windows.RoutedEventArgs e) { manager?.FocusNext(); UpdateView(); }
    private void Widen_Click(object sender, System.Windows.RoutedEventArgs e) { manager?.WidenFocusedWindow(); UpdateView(); }
    private void Center_Click(object sender, System.Windows.RoutedEventArgs e) { manager?.CenterFocusedWindow(); UpdateView(); }
    private void Restore_Click(object sender, System.Windows.RoutedEventArgs e) { manager?.Restore(); UpdateView(); }
    private void Quit_Click(object sender, System.Windows.RoutedEventArgs e) => QuitRequested?.Invoke(this, EventArgs.Empty);

    private void Settings_Click(object sender, System.Windows.RoutedEventArgs e)
    {
        SettingsPanel.Visibility = SettingsPanel.Visibility == System.Windows.Visibility.Visible
            ? System.Windows.Visibility.Collapsed
            : System.Windows.Visibility.Visible;
    }

    private void GapSlider_ValueChanged(object sender, System.Windows.RoutedPropertyChangedEventArgs<double> e)
    {
        if (manager is null || preferences is null) return;
        var gap = (int)Math.Round(e.NewValue / 4) * 4;
        manager.Gap = gap;
        preferences.Gap = gap;
        preferences.Save();
        GapValue.Text = $"{gap} px";
        manager.Reflow();
        UpdateView();
    }

    private void DismissQuickStart_Click(object sender, System.Windows.RoutedEventArgs e)
    {
        preferences.QuickStartComplete = true;
        preferences.Save();
        QuickStartCard.Visibility = System.Windows.Visibility.Collapsed;
    }

    private void ShowQuickStart_Click(object sender, System.Windows.RoutedEventArgs e)
    {
        preferences.QuickStartComplete = false;
        preferences.Save();
        QuickStartCard.Visibility = System.Windows.Visibility.Visible;
        SettingsPanel.Visibility = System.Windows.Visibility.Collapsed;
    }

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        if (allowClose) return;
        e.Cancel = true;
        Hide();
    }

    private void UnregisterShortcuts()
    {
        if (hwndSource is null) return;
        var handle = hwndSource.Handle;
        for (var id = 1; id <= shortcutsRegistered.Length; id++)
        {
            if (shortcutsRegistered[id - 1]) _ = UnregisterHotKey(handle, id);
        }
        hwndSource.RemoveHook(WndProc);
        hwndSource = null;
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterHotKey(IntPtr window, int id);
}
