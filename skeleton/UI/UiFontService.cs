using Avalonia;
using Avalonia.Media;
using skeleton.Models;
namespace skeleton.UI;

internal static class UiFontService
{
    public static void Apply(Application app, UiPreferences prefs)
    {
        var main = (double)Clamp(prefs.MainFontSize);
        var resources = app.Resources;
        resources[UiFontKeys.Body] = main;
        resources[UiFontKeys.Menu] = main;
        resources[UiFontKeys.Status] = main;
        resources[UiFontKeys.Section] = main;
        resources[UiFontKeys.Tab] = (double)Clamp(prefs.TabFontSize);
        resources[UiFontKeys.Token] = (double)Clamp(prefs.TokenFontSize);
        resources[UiFontKeys.MainFamily] = CreateMainFamily(prefs.MainFontFamily);
        resources[UiFontKeys.MonoFamily] = CreateMonoFamily(prefs.MonoFontFamily);
    }

    public static FontFamily CreateMainFamily(string? name) =>
        new(UiFontFamilies.ResolveMainStack(UiFontFamilies.NormalizeMain(name)));

    public static FontFamily CreateMonoFamily(string? name) =>
        new($"{UiFontFamilies.NormalizeMono(name)}, monospace");

    public static FontFamily CreatePreviewFamily(string name, bool mono) =>
        mono ? new FontFamily($"{name}, monospace") : new FontFamily(UiFontFamilies.ResolveMainStack(name));

    public static double GetTabSize(Application? app) =>
        Get(app, UiFontKeys.Tab, UiFontDefaults.Tab);

    public static double Get(Application? app, string key, int fallback)
    {
        if (app?.Resources.TryGetResource(key, app.ActualThemeVariant, out var value) == true
            && value is double size)
            return size;
        return fallback;
    }

    public static int Clamp(int size) => UiFontDefaults.Clamp(size);
}
