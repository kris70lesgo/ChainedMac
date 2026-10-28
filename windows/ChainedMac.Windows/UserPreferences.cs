using System.IO;
using System.Text.Json;

namespace ChainedMac.Windows;

internal sealed class UserPreferences
{
    private static readonly string SettingsDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ChainedMac");
    private static readonly string SettingsPath = Path.Combine(SettingsDirectory, "settings.json");
    private static readonly string LegacySettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ChainYourMac",
        "settings.json");

    public int Gap { get; set; } = 28;
    public bool QuickStartComplete { get; set; }

    public static UserPreferences Load()
    {
        try
        {
            foreach (var path in new[] { SettingsPath, LegacySettingsPath })
            {
                if (!File.Exists(path)) continue;
                var loaded = JsonSerializer.Deserialize<UserPreferences>(File.ReadAllText(path));
                if (loaded is null) continue;
                if (path == LegacySettingsPath) loaded.Save();
                return loaded;
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
            Directory.CreateDirectory(SettingsDirectory);
            File.WriteAllText(SettingsPath, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }
}
