using System.Drawing;
using System.Windows;
using Forms = System.Windows.Forms;

namespace ChainedMac.Windows;

public partial class App : System.Windows.Application
{
    private Forms.NotifyIcon? trayIcon;
    private MainWindow? mainWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        mainWindow = new MainWindow();
        mainWindow.QuitRequested += (_, _) => QuitApplication();
        mainWindow.Show();

        trayIcon = new Forms.NotifyIcon
        {
            Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath!) ?? SystemIcons.Application,
            Text = "ChainedMac",
            Visible = true
        };
        trayIcon.DoubleClick += (_, _) => ShowMainWindow();

        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open ChainedMac", null, (_, _) => ShowMainWindow());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => QuitApplication());
        trayIcon.ContextMenuStrip = menu;
    }

    private void ShowMainWindow()
    {
        if (mainWindow is null) return;
        mainWindow.ShowFromTray();
    }

    private void QuitApplication()
    {
        if (mainWindow is not null && !mainWindow.PrepareForExit()) return;
        trayIcon?.Dispose();
        trayIcon = null;
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        trayIcon?.Dispose();
        base.OnExit(e);
    }
}
