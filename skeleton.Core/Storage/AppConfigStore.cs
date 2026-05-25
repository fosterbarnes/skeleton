using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Linq;
using skeleton;
using skeleton.Models;

namespace skeleton.Storage;

public sealed class AppConfigStore
{
    private static readonly JsonSerializerSettings SerializerSettings = new()
    {
        Formatting = Formatting.Indented,
        TypeNameHandling = TypeNameHandling.None,
        MaxDepth = 32,
        MetadataPropertyHandling = MetadataPropertyHandling.Ignore,
        Converters = { new StringEnumConverter() }
    };

    private readonly string _baseDirectory;
    private readonly string _uiPreferencesFilePath;

    public AppConfigStore()
    {
        _baseDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            AppBranding.Slug);
        _uiPreferencesFilePath = Path.Combine(_baseDirectory, "ui.json");
    }

    public UiPreferences LoadUiPreferences()
    {
        if (!File.Exists(_uiPreferencesFilePath))
            return new UiPreferences();

        var json = SafeFileIO.ReadAllText(_uiPreferencesFilePath, SafeFileIO.MaxJsonBytes);
        var token = JToken.Parse(json);
        if (token is not JObject jo)
            return new UiPreferences();

        var prefs = jo.ToObject<UiPreferences>(JsonSerializer.Create(SerializerSettings)) ?? new UiPreferences();
        NormalizeLegacy(prefs, jo);
        ClampFontSizes(prefs);
        NormalizeFontFamilies(prefs);
        return prefs;
    }

    public void SaveUiPreferences(UiPreferences preferences)
    {
        ArgumentNullException.ThrowIfNull(preferences);

        ClampFontSizes(preferences);
        NormalizeFontFamilies(preferences);
        Directory.CreateDirectory(_baseDirectory);
        var json = JsonConvert.SerializeObject(preferences, SerializerSettings);
        AtomicFile.WriteAllBytes(_uiPreferencesFilePath, Encoding.UTF8.GetBytes(json));
    }

    private static void NormalizeLegacy(UiPreferences prefs, JObject jo)
    {
        if (jo["Theme"] is JToken { Type: JTokenType.Integer } legacyInt)
            prefs.Theme = MapLegacyThemeInt(legacyInt.Value<int>());

        if (jo["Theme"] is JToken { Type: JTokenType.String } themeString
            && string.Equals(themeString.Value<string>(), "Dracula", StringComparison.OrdinalIgnoreCase))
        {
            prefs.Theme = UiThemeKind.DraculaLight;
        }

        if (jo["DarkMode"] is JToken { Type: JTokenType.Boolean } darkMode
            && darkMode.Value<bool>()
            && prefs.Theme == UiThemeKind.System)
        {
            prefs.Theme = UiThemeKind.Dark;
        }

        if (string.IsNullOrEmpty(prefs.LastSelectedTabKey)
            && jo["LastSelectedTabIndex"] is JToken { Type: JTokenType.Integer } legacyTabIndex)
        {
            prefs.LastSelectedTabKey = MapLegacyTabIndex(legacyTabIndex.Value<int>());
        }

        if (jo["BodyFontSize"] is JToken { Type: JTokenType.Integer } body
            && jo["MainFontSize"] is null)
        {
            prefs.MainFontSize = body.Value<int>();
        }
    }

    private static string? MapLegacyTabIndex(int index) => index switch
    {
        0 => "AppSettings",
        1 => "About",
        _ => null
    };

    private static UiThemeKind MapLegacyThemeInt(int value) => value switch
    {
        0 => UiThemeKind.Light,
        1 => UiThemeKind.Dark,
        2 => UiThemeKind.DraculaLight,
        3 => UiThemeKind.DraculaDark,
        _ => UiThemeKind.System
    };

    private static void ClampFontSizes(UiPreferences prefs)
    {
        prefs.MainFontSize = UiFontDefaults.Clamp(prefs.MainFontSize);
        prefs.TabFontSize = UiFontDefaults.Clamp(prefs.TabFontSize);
        prefs.TokenFontSize = UiFontDefaults.Clamp(prefs.TokenFontSize);
    }

    private static void NormalizeFontFamilies(UiPreferences prefs)
    {
        prefs.MainFontFamily = UiFontFamilies.NormalizeMain(prefs.MainFontFamily);
        prefs.MonoFontFamily = UiFontFamilies.NormalizeMono(prefs.MonoFontFamily);
    }
}
