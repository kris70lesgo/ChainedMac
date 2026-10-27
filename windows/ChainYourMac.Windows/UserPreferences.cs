using System.IO;
using System.Text.Json;

namespace ChainYourMac.Windows;

internal sealed class UserPreferences
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ChainYourMac",
        "settings.json");

    public int Gap { get; set; } = 28;
    public bool QuickStartComplete { get; set; }

    public static UserPreferences Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var loaded = JsonSerializer.Deserialize<UserPreferences>(File.ReadAllText(SettingsPath));
                if (loaded is not null) return loaded;
            }
        }
        catch (IOException) { }
        catch (JsonException) { }
        return new UserPreferences();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
            File.WriteAllText(SettingsPath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
