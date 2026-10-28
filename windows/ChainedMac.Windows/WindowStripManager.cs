using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Forms = System.Windows.Forms;

namespace ChainedMac.Windows;

internal readonly record struct WindowFrame(int X, int Y, int Width, int Height);

internal sealed class ManagedWindow
{
    public required nint Handle { get; init; }
    public required string Title { get; set; }
    public required string AppName { get; set; }
    public required WindowFrame Frame { get; set; }
    public required WindowFrame OriginalFrame { get; set; }
}

internal sealed class WindowStripManager
{
    private readonly List<ManagedWindow> windows = [];
    private readonly double[] widthSteps = [0.56, 0.68, 0.80, 0.92];
    private int focusedIndex;
    private int widthStepIndex = 1;
    private int baseX;

    public event EventHandler? StateChanged;

    public int Gap { get; set; }
    public bool IsArranged { get; private set; }
    public string Message { get; private set; } = "Ready to arrange your windows.";
    public string ShortcutStatus { get; private set; } = "Checking shortcuts…";
    public int WindowCount => windows.Count;
    public int FocusedIndex => focusedIndex;
    public string FocusedTitle => windows.Count > 0 && focusedIndex < windows.Count ? windows[focusedIndex].Title : "No window selected";

    public WindowStripManager(int gap) => Gap = gap;

    public void SetShortcutStatus(string text)
    {
        ShortcutStatus = text;
        NotifyChanged();
    }

    public void Refresh()
    {
        var discovered = DiscoverWindows();
        if (!IsArranged)
        {
            windows.Clear();
            windows.AddRange(discovered);
            focusedIndex = Math.Clamp(focusedIndex, 0, Math.Max(0, windows.Count - 1));
            Message = windows.Count == 0 ? "No movable app windows are open yet." : $"Ready to arrange {windows.Count} windows.";
            NotifyChanged();
            return;
        }

        var existing = windows.ToDictionary(window => window.Handle);
        var discoveredHandles = discovered.Select(window => window.Handle).ToHashSet();
        var reconciled = new List<ManagedWindow>();
        foreach (var current in discovered)
        {
            if (existing.TryGetValue(current.Handle, out var prior))
            {
                prior.Title = current.Title;
                prior.AppName = current.AppName;
                prior.Frame = current.Frame;
                reconciled.Add(prior);
            }
            else
            {
                current.OriginalFrame = current.Frame;
                reconciled.Add(current);
            }
        }
        // Preserve original frames for minimized or temporarily hidden
        // windows. They are absent from EnumWindows' visible-window list, but
        // they still need to be restored before ChainedMac exits.
        reconciled.AddRange(windows.Where(window =>
            !discoveredHandles.Contains(window.Handle) && IsWindow(window.Handle)));
        reconciled = reconciled.OrderBy(window => window.Frame.X)
            .ThenBy(window => window.AppName, StringComparer.OrdinalIgnoreCase)
            .ToList();
        windows.Clear();
        windows.AddRange(reconciled);
        if (windows.Count == 0)
        {
            IsArranged = false;
            focusedIndex = 0;
            Message = "The arranged windows were closed.";
        }
        else
        {
            focusedIndex = Math.Clamp(focusedIndex, 0, windows.Count - 1);
            _ = Reposition();
        }
        NotifyChanged();
    }

    public void Arrange()
    {
        Refresh();
        if (windows.Count == 0) return;

        foreach (var window in windows) window.OriginalFrame = window.Frame;
        baseX = windows[focusedIndex].Frame.X;
        IsArranged = true;
        var moved = Reposition();
        RaiseFocusedWindow();
        Message = moved == windows.Count
            ? $"{windows.Count} windows are in your strip."
            : $"Moved {moved} of {windows.Count}. Some apps do not allow window positioning.";
        NotifyChanged();
    }

    public void FocusNext()
    {
        if (windows.Count == 0) { Refresh(); return; }
        if (!IsArranged) { Arrange(); return; }
        if (focusedIndex + 1 >= windows.Count) { Message = "You’re at the last window in the strip."; NotifyChanged(); return; }
        focusedIndex++;
        _ = Reposition();
        RaiseFocusedWindow();
        Message = $"Focused {FocusedTitle}.";
        NotifyChanged();
    }

    public void FocusPrevious()
    {
        if (windows.Count == 0) { Refresh(); return; }
        if (!IsArranged) { Arrange(); return; }
        if (focusedIndex == 0) { Message = "You’re at the first window in the strip."; NotifyChanged(); return; }
        focusedIndex--;
        _ = Reposition();
        RaiseFocusedWindow();
        Message = $"Focused {FocusedTitle}.";
        NotifyChanged();
    }

    public void WidenFocusedWindow()
    {
        if (!IsArranged || windows.Count == 0) { Message = "Arrange the strip before changing a window’s width."; NotifyChanged(); return; }
        widthStepIndex = (widthStepIndex + 1) % widthSteps.Length;
        var focused = windows[focusedIndex];
        var screen = Forms.Screen.FromHandle(focused.Handle);
        var width = (int)Math.Round(screen.WorkingArea.Width * widthSteps[widthStepIndex]);
        var frame = focused.Frame with { Width = width };
        if (SetFrame(focused, frame))
        {
            _ = Reposition();
            Message = $"Focused window width: {widthSteps[widthStepIndex] * 100:0}% of the display.";
        }
        else Message = "This app does not allow its window to be resized.";
        NotifyChanged();
    }

    public void CenterFocusedWindow()
    {
        if (!IsArranged || windows.Count == 0) { Message = "Arrange the strip before centering a window."; NotifyChanged(); return; }
        var focused = windows[focusedIndex];
        var workingArea = Forms.Screen.FromHandle(focused.Handle).WorkingArea;
        baseX += workingArea.Left + workingArea.Width / 2 - (focused.Frame.X + focused.Frame.Width / 2);
        _ = Reposition();
        Message = $"Centered {FocusedTitle}.";
        NotifyChanged();
    }

    public void Reflow()
    {
        if (IsArranged) _ = Reposition();
        NotifyChanged();
    }

    public bool Restore()
    {
        if (!IsArranged) return true;
        var restored = 0;
        var total = 0;
        foreach (var window in windows)
        {
            if (!IsWindow(window.Handle)) continue;
            total++;
            if (SetFrame(window, window.OriginalFrame)) restored++;
        }

        if (restored != total)
        {
            Message = $"Restored {restored} of {total} open windows. Some apps refused the change. ChainedMac is still running so you can retry.";
            NotifyChanged();
            return false;
        }

        IsArranged = false;
        focusedIndex = 0;
        windows.Clear();
        windows.AddRange(DiscoverWindows());
        Message = "Restored the original window positions.";
        NotifyChanged();
        return true;
    }

    public void HandleGlobalShortcut(int identifier)
    {
        switch (identifier)
        {
            case 1: FocusPrevious(); break;
            case 2: FocusNext(); break;
            case 3: Restore(); break;
        }
    }

    private List<ManagedWindow> DiscoverWindows()
    {
        var ownProcess = Environment.ProcessId;
        var found = new List<ManagedWindow>();
        EnumWindows((handle, _) =>
        {
            if (!IsWindowVisible(handle) || IsIconic(handle) || GetWindow(handle, GW_OWNER) != 0) return true;
            GetWindowThreadProcessId(handle, out var processId);
            if (processId == 0 || processId == ownProcess) return true;

            var extendedStyle = GetWindowLongPtr(handle, GWL_EXSTYLE).ToInt64();
            if ((extendedStyle & WS_EX_TOOLWINDOW) != 0) return true;

            var length = GetWindowTextLength(handle);
            if (length <= 0) return true;
            var title = new StringBuilder(length + 1);
            _ = GetWindowText(handle, title, title.Capacity);
            var name = title.ToString().Trim();
            if (name.Length == 0) return true;

            if (!TryGetFrame(handle, out var frame) || frame.Width < 160 || frame.Height < 100) return true;
            string appName;
            try { appName = Process.GetProcessById((int)processId).ProcessName; }
            catch (ArgumentException) { appName = "App"; }
            catch (InvalidOperationException) { appName = "App"; }
            found.Add(new ManagedWindow { Handle = handle, Title = name, AppName = appName, Frame = frame, OriginalFrame = frame });
            return true;
        }, 0);

        return found.OrderBy(window => window.Frame.X).ThenBy(window => window.AppName, StringComparer.OrdinalIgnoreCase).ToList();
    }

    private int Reposition()
    {
        if (windows.Count == 0 || focusedIndex >= windows.Count) return 0;
        var offsets = new int[windows.Count];
        for (var index = 1; index < windows.Count; index++)
            offsets[index] = offsets[index - 1] + windows[index - 1].Frame.Width + Gap;

        var focusOffset = offsets[focusedIndex];
        var moved = 0;
        for (var index = 0; index < windows.Count; index++)
        {
            var window = windows[index];
            var frame = window.Frame with { X = baseX + offsets[index] - focusOffset };
            if (SetFrame(window, frame)) moved++;
        }
        return moved;
    }

    private static bool TryGetFrame(nint handle, out WindowFrame frame)
    {
        var result = DwmGetWindowAttribute(handle, DWMWA_EXTENDED_FRAME_BOUNDS, out var bounds, Marshal.SizeOf<NativeRect>());
        if (result != 0 && !GetWindowRect(handle, out bounds))
        {
            frame = default;
            return false;
        }
        frame = new WindowFrame(bounds.Left, bounds.Top, bounds.Right - bounds.Left, bounds.Bottom - bounds.Top);
        return frame.Width > 0 && frame.Height > 0;
    }

    private static bool SetFrame(ManagedWindow window, WindowFrame frame)
    {
        if (!IsWindow(window.Handle)) return false;
        var changed = SetWindowPos(window.Handle, 0, frame.X, frame.Y, frame.Width, frame.Height, SWP_NOZORDER | SWP_NOACTIVATE);
        if (changed) window.Frame = frame;
        return changed;
    }

    private void RaiseFocusedWindow()
    {
        if (windows.Count == 0) return;
        var handle = windows[focusedIndex].Handle;
        _ = ShowWindowAsync(handle, SW_RESTORE);
        _ = SetForegroundWindow(handle);
    }

    private void NotifyChanged() => StateChanged?.Invoke(this, EventArgs.Empty);

    private const int GWL_EXSTYLE = -20;
    private const long WS_EX_TOOLWINDOW = 0x00000080L;
    private const int GW_OWNER = 4;
    private const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
    private const uint SWP_NOZORDER = 0x0004;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const int SW_RESTORE = 9;

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnumWindows(EnumWindowsProc callback, nint extraData);

    private delegate bool EnumWindowsProc(nint handle, nint extraData);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowVisible(nint handle);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsIconic(nint handle);

    [DllImport("user32.dll")]
    private static extern nint GetWindow(nint handle, int command);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern nint GetWindowLongPtr(nint handle, int index);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(nint handle, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowTextLength(nint handle);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(nint handle, StringBuilder text, int maxCount);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(nint handle, out NativeRect rect);

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(nint handle, int attribute, out NativeRect value, int size);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(nint handle, nint insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(nint handle);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ShowWindowAsync(nint handle, int command);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetForegroundWindow(nint handle);
}
